import Foundation

public struct MCPClient: Sendable {
    public let id: String
    public let tokenDigest: Data
    public let policy: PermissionPolicy

    public init(id: String, tokenDigest: Data, policy: PermissionPolicy) {
        self.id = id
        self.tokenDigest = tokenDigest
        self.policy = policy
    }
}

public struct MCPResponse: Equatable, Sendable {
    public let status: Int
    public let body: Data

    public init(status: Int, body: Data = Data()) {
        self.status = status
        self.body = body
    }
}

public actor MCPDispatcher {
    public static let maxBodyBytes = 64 * 1024
    public static let protocolVersion = "2025-06-18"
    public static let allowedHostNames: Set<String> = ["127.0.0.1", "localhost"]

    private let authenticator: any MCPClientAuthenticating
    private let runner: AgentRunner
    private let store: BrowserStore
    private let auditLog: AuditLog
    private let now: @Sendable () -> Date

    public init(
        authenticator: any MCPClientAuthenticating,
        runner: AgentRunner,
        store: BrowserStore,
        auditLog: AuditLog,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.authenticator = authenticator
        self.runner = runner
        self.store = store
        self.auditLog = auditLog
        self.now = now
    }

    public init(
        clients: [MCPClient],
        runner: AgentRunner,
        store: BrowserStore,
        auditLog: AuditLog,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.init(
            authenticator: StaticClients(clients),
            runner: runner,
            store: store,
            auditLog: auditLog,
            now: now
        )
    }

    public func handle(hostHeader: String?, authorization: String?, body: Data) async -> MCPResponse {
        guard let host = Self.hostName(hostHeader), Self.allowedHostNames.contains(host) else {
            return Self.httpError(403, code: -32000, message: "host not allowed")
        }
        guard let client = await authenticator.authenticate(authorization) else {
            return Self.httpError(401, code: -32001, message: "unauthorized")
        }
        guard body.count <= Self.maxBodyBytes else {
            return Self.httpError(413, code: -32600, message: "body too large")
        }
        guard let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: body), request.jsonrpc == "2.0" else {
            return Self.httpError(400, code: -32700, message: "parse error")
        }
        guard let id = request.id else {
            return MCPResponse(status: 202)
        }
        let result = await route(request, client: client)
        return Self.encode(id: id, result: result)
    }

    private func route(_ request: JSONRPCRequest, client: MCPClient) async -> Result<JSONValue, RPCError> {
        switch request.method {
        case "initialize":
            return .success(.object([
                "protocolVersion": .string(Self.protocolVersion),
                "capabilities": .object(["tools": .object([:])]),
                "serverInfo": .object(["name": .string("harbor"), "version": .string("0.1.0")]),
            ]))
        case "tools/list":
            return .success(.object(["tools": .array(MCPTools.all.map(\.json))]))
        case "tools/call":
            return await callTool(request.params, client: client)
        default:
            return .failure(RPCError(code: -32601, message: "method not found"))
        }
    }

    private func callTool(_ params: JSONValue?, client: MCPClient) async -> Result<JSONValue, RPCError> {
        guard let name = params?["name"]?.stringValue else {
            return .failure(RPCError(code: -32602, message: "tool name required"))
        }
        let arguments = params?["arguments"] ?? .object([:])
        let outcome = await dispatch(name, arguments: arguments, client: client)
        await recordCall(name, client: client, succeeded: (try? outcome.get()) != nil)
        return outcome.map(\.json)
    }

    private func dispatch(_ name: String, arguments: JSONValue, client: MCPClient) async -> Result<ToolOutcome, RPCError> {
        switch name {
        case "list_tabs":
            return await listTabs(client: client)
        case "navigate":
            return await navigate(arguments, client: client)
        case "read_page":
            return await readPage(arguments, client: client)
        case "task_status":
            return await taskStatus(arguments["taskId"], client: client)
        case "stop_task":
            return await stopTask(arguments["taskId"], client: client)
        default:
            return .failure(RPCError(code: -32602, message: "unknown tool"))
        }
    }

    private func listTabs(client: MCPClient) async -> Result<ToolOutcome, RPCError> {
        guard client.policy.decide(site: PermissionRule.anySite, action: .read) == .allow else {
            return .failure(RPCError(code: -32003, message: "forbidden"))
        }
        let rows = await store.tabs.map { ["title": $0.title, "url": $0.url.absoluteString, "state": "\($0.state)"] }
        return .success(.untrusted(rows))
    }

    private func navigate(_ arguments: JSONValue, client: MCPClient) async -> Result<ToolOutcome, RPCError> {
        let dto = AgentStepDTO(type: "navigate", url: arguments["url"]?.stringValue)
        guard let step = try? AgentStep(dto: dto), let host = step.targetHost else {
            return .failure(RPCError(code: -32602, message: "invalid url"))
        }
        return await submit(step, site: host, client: client)
    }

    private func readPage(_ arguments: JSONValue, client: MCPClient) async -> Result<ToolOutcome, RPCError> {
        guard let site = arguments["site"]?.stringValue?.lowercased(), !site.isEmpty else {
            return .failure(RPCError(code: -32602, message: "site required"))
        }
        return await submit(.readPage, site: site, client: client)
    }

    private func submit(_ step: AgentStep, site: String, client: MCPClient) async -> Result<ToolOutcome, RPCError> {
        let clientDecision = client.policy.decide(site: site, action: step.action)
        guard clientDecision != .deny else {
            return .failure(RPCError(code: -32003, message: "forbidden"))
        }
        let grants: Set<ActionClass> = clientDecision == .allow ? [step.action] : []
        let task = AgentTask(ownerID: client.id, site: site, steps: [step], taskGrants: grants)
        return .success(.task(await runner.submit(task)))
    }

    private func taskStatus(_ id: JSONValue?, client: MCPClient) async -> Result<ToolOutcome, RPCError> {
        guard let task = await ownedTask(id, client: client) else {
            return .failure(RPCError(code: -32004, message: "unknown task"))
        }
        return .success(.task(task))
    }

    private func stopTask(_ id: JSONValue?, client: MCPClient) async -> Result<ToolOutcome, RPCError> {
        guard let task = await ownedTask(id, client: client) else {
            return .failure(RPCError(code: -32004, message: "unknown task"))
        }
        guard let stopped = try? await runner.stop(task.id) else {
            return .failure(RPCError(code: -32004, message: "unknown task"))
        }
        return .success(.task(stopped))
    }

    private func ownedTask(_ id: JSONValue?, client: MCPClient) async -> AgentTask? {
        guard let raw = id?.stringValue, let uuid = UUID(uuidString: raw), let task = await runner.task(uuid) else {
            return nil
        }
        return task.ownerID == client.id ? task : nil
    }

    private func recordCall(_ name: String, client: MCPClient, succeeded: Bool) async {
        _ = await auditLog.append(AuditRecord(
            timestamp: now(),
            taskID: nil,
            site: "mcp:\(client.id)",
            tool: name,
            arguments: [:],
            result: succeeded ? "ok" : "rejected",
            approval: nil
        ))
    }

    private static func hostName(_ header: String?) -> String? {
        guard let header, !header.hasPrefix("[") else {
            return nil
        }
        return header.split(separator: ":", maxSplits: 1).first.map { String($0).lowercased() }
    }

    private static func httpError(_ status: Int, code: Int, message: String) -> MCPResponse {
        let envelope = JSONValue.object([
            "jsonrpc": .string("2.0"),
            "id": .null,
            "error": .object(["code": .number(Double(code)), "message": .string(message)]),
        ])
        return MCPResponse(status: status, body: (try? JSONEncoder().encode(envelope)) ?? Data())
    }

    private static func encode(id: JSONValue, result: Result<JSONValue, RPCError>) -> MCPResponse {
        let envelope: JSONValue
        switch result {
        case .success(let value):
            envelope = .object(["jsonrpc": .string("2.0"), "id": id, "result": value])
        case .failure(let error):
            envelope = .object([
                "jsonrpc": .string("2.0"),
                "id": id,
                "error": .object(["code": .number(Double(error.code)), "message": .string(error.message)]),
            ])
        }
        return MCPResponse(status: 200, body: (try? JSONEncoder().encode(envelope)) ?? Data())
    }
}

struct JSONRPCRequest: Decodable {
    let jsonrpc: String
    let id: JSONValue?
    let method: String
    let params: JSONValue?
}

struct RPCError: Error, Equatable {
    let code: Int
    let message: String
}

enum ToolOutcome {
    case task(AgentTask)
    case untrusted([[String: String]])

    var json: JSONValue {
        let payload: String
        switch self {
        case .task(let task):
            payload = ToolPayload.task(task)
        case .untrusted(let rows):
            payload = ToolPayload.tabs(rows)
        }
        return .object([
            "content": .array([.object(["type": .string("text"), "text": .string(payload)])]),
            "isError": .bool(false),
        ])
    }
}
