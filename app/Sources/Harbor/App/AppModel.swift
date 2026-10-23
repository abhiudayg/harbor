import Foundation
import HarborCore
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var spaces: [Space] = []
    private(set) var tabs: [BrowserTab] = []
    private(set) var pendingApprovals: [ApprovalRequest] = []
    private(set) var tasks: [AgentTask] = []
    private(set) var clients: [MCPClientDirectory.Summary] = []
    private(set) var serverPort: UInt16?

    var isCommandBarPresented = false
    var isTriagePresented = false
    var isInboxPresented = false
    var isClientsPresented = false

    private let store: BrowserStore
    private let approvals: ApprovalService
    private let runner: AgentRunner
    private let auditLog: AuditLog
    private let clientStore: any MCPClientStore
    private let serverEnabled: Bool
    private var directory: MCPClientDirectory?
    private var server: MCPHTTPServer?

    init(
        store: BrowserStore = BrowserStore(),
        approvals: ApprovalService = ApprovalService(),
        runner: AgentRunner? = nil,
        auditLog: AuditLog = AuditLog(),
        clientStore: any MCPClientStore = KeychainClientStore(),
        serverEnabled: Bool = true
    ) {
        self.store = store
        self.approvals = approvals
        self.auditLog = auditLog
        self.clientStore = clientStore
        self.serverEnabled = serverEnabled
        self.runner = runner ?? AgentRunner(
            policy: PermissionPolicy(),
            approvals: approvals,
            audit: auditLog,
            driver: WebKitPageDriver(engine: WebKitEngine(isBackground: true))
        )
    }

    var spaceNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: spaces.map { ($0.id, $0.name) })
    }

    var activeSpaceName: String {
        spaces.first?.name ?? "Harbor"
    }

    func start() async {
        if spaces.isEmpty {
            await seedWorkspace()
        }
        if directory == nil {
            directory = try? await MCPClientDirectory(store: clientStore)
        }
        if serverEnabled, server == nil, let directory {
            await startServer(directory: directory)
        }
        await refresh()
    }

    func refresh() async {
        spaces = await store.spaces
        tabs = await store.tabs
        pendingApprovals = await approvals.pending()
        tasks = await runner.allTasks
        clients = await directory?.summaries() ?? []
    }

    func issueClient(name: String) async throws -> String {
        guard let directory else {
            throw MCPClientDirectoryError.invalidName
        }
        let token = try await directory.issue(name: name)
        await refresh()
        return token
    }

    func revokeClient(id: String) async throws {
        try await directory?.revoke(id: id)
        await refresh()
    }

    func approve(_ request: ApprovalRequest, scope: ApprovalScope) async {
        _ = try? await approvals.resolve(request.id, with: .approve(scope))
        await resume(taskFor: request)
        await refresh()
    }

    func deny(_ request: ApprovalRequest) async {
        _ = try? await approvals.resolve(request.id, with: .deny)
        await resume(taskFor: request)
        await refresh()
    }

    func keep(_ tab: BrowserTab) async {
        try? await store.setPinned(true, tabID: tab.id)
        await refresh()
    }

    func archive(_ tab: BrowserTab) async {
        try? await store.archive(tabID: tab.id)
        await refresh()
    }

    func close(_ tab: BrowserTab) async {
        try? await store.close(tabID: tab.id)
        await refresh()
    }

    func archiveStale() async {
        _ = await store.archiveStaleTabs(now: Date())
        await refresh()
    }

    private func startServer(directory: MCPClientDirectory) async {
        let dispatcher = MCPDispatcher(
            authenticator: directory,
            runner: runner,
            store: store,
            auditLog: auditLog
        )
        guard let server = try? MCPHTTPServer(dispatcher: dispatcher) else {
            return
        }
        self.server = server
        serverPort = try? await server.start()
    }

    private func resume(taskFor request: ApprovalRequest) async {
        let all = await runner.allTasks
        guard let waiting = all.first(where: { $0.state == .awaitingApproval(request.id) }) else {
            return
        }
        _ = try? await runner.resume(waiting.id)
    }

    private func seedWorkspace() async {
        guard let research = try? await store.createSpace(named: "Research") else {
            return
        }
        let samples: [(title: String, address: String, pinned: Bool)] = [
            ("Figma - Harbor Shell", "https://figma.com", true),
            ("Linear - Sprint 14", "https://linear.app", true),
            ("GitHub - core-runtime", "https://github.com", true),
            ("Notion - RFC Specs", "https://notion.so", true),
            ("Readwise Reader", "https://read.readwise.io", true),
            ("Claude / Research", "https://claude.ai", true),
            ("Distributed Consensus in Paxos", "https://example.com/paxos", false),
            ("HN: SQLite Internals Deep Dive", "https://news.ycombinator.com", false),
            ("PostgreSQL 17 Release Notes", "https://postgresql.org", false),
        ]
        for sample in samples {
            guard let url = URL(string: sample.address),
                  let tab = try? await store.openTab(url: url, title: sample.title, in: research.id, at: Date())
            else {
                continue
            }
            if sample.pinned {
                try? await store.setPinned(true, tabID: tab.id)
            }
        }
    }
}
