import Foundation
import HarborCore

public enum Fixtures {
    public static let start = Date(timeIntervalSince1970: 1_000_000)
    public static let publicURL = URL(string: "https://example.com/article")!

    public struct Harness: Sendable {
        public let dispatcher: MCPDispatcher
        public let runner: AgentRunner
        public let store: BrowserStore
        public let approvals: ApprovalService
        public let auditLog: AuditLog
        public let token: String
    }

    public static func makeHarness(
        policy: PermissionPolicy = PermissionPolicy(),
        clientPolicy: PermissionPolicy,
        driver: any PageDriver
    ) throws -> Harness {
        let token = try AccessToken.generate()
        let approvals = ApprovalService()
        let auditLog = AuditLog()
        let runner = AgentRunner(
            policy: policy,
            approvals: approvals,
            audit: auditLog,
            driver: driver,
            now: { start }
        )
        let store = BrowserStore(spaces: [Space(name: "Research")])
        let client = MCPClient(id: "client-a", tokenDigest: token.digest, policy: clientPolicy)
        let dispatcher = MCPDispatcher(
            clients: [client],
            runner: runner,
            store: store,
            auditLog: auditLog,
            now: { start }
        )
        return Harness(
            dispatcher: dispatcher,
            runner: runner,
            store: store,
            approvals: approvals,
            auditLog: auditLog,
            token: token.value
        )
    }

    public static func rpc(_ method: String, id: Int = 1, params: [String: Any] = [:]) -> Data {
        var envelope: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method]
        if !params.isEmpty {
            envelope["params"] = params
        }
        return (try? JSONSerialization.data(withJSONObject: envelope)) ?? Data()
    }

    public static func toolCall(_ name: String, arguments: [String: Any] = [:], id: Int = 1) -> Data {
        rpc("tools/call", id: id, params: ["name": name, "arguments": arguments])
    }

    public static func decodeObject(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
