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
    private(set) var policyRules: [PermissionRule] = []
    private(set) var serverPort: UInt16?

    var isCommandBarPresented = false
    var isTriagePresented = false
    var isInboxPresented = false
    var isClientsPresented = false
    var isAssistantPresented = false

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
        policyRules = await runner.policy.rules
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

    func deduplicate(_ tabs: [BrowserTab]) async {
        var seen = Set<String>()
        for tab in tabs {
            if seen.insert(tab.url.absoluteString).inserted {
                continue
            }
            try? await store.close(tabID: tab.id)
        }
        await refresh()
    }

    func keepAll(_ tabs: [BrowserTab]) async {
        for tab in tabs where !tab.isPinned {
            try? await store.setPinned(true, tabID: tab.id)
        }
        await refresh()
    }

    func stop(_ task: AgentTask) async {
        _ = try? await runner.stop(task.id)
        await refresh()
    }

    var authorizedSites: [String] {
        Array(Set(policyRules.filter { $0.grant == .allow && $0.site != PermissionRule.anySite }.map(\.site))).sorted()
    }

    var permittedActions: [String] {
        Array(Set(policyRules.filter { $0.grant == .allow }.map { $0.action.rawValue })).sorted()
    }

    func archive(_ tab: BrowserTab) async {
        try? await store.archive(tabID: tab.id)
        await refresh()
    }

    func close(_ tab: BrowserTab) async {
        try? await store.close(tabID: tab.id)
        await refresh()
    }

    func showTriage() {
        isInboxPresented = false
        isTriagePresented = true
    }

    func hideTriage() {
        isTriagePresented = false
    }

    func showInbox() {
        isTriagePresented = false
        isInboxPresented = true
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
        guard let research = try? await store.createSpace(named: "Research"),
              let systems = try? await store.createSpace(named: "Systems")
        else {
            return
        }
        let pinned: [(String, String)] = [
            ("ArXiv: LLM Memory", "https://arxiv.org/abs/2402.19"),
            ("Kernel RFC #412", "https://lwn.net/Articles/412"),
            ("Figma Design Tokens", "https://figma.com/file/tokens"),
            ("Linear Core Backlog", "https://linear.app/harbor/core"),
            ("Postgres Indexing", "https://postgresql.org/docs/indexes"),
            ("Stripe API Reference", "https://stripe.com/docs/api"),
        ]
        let today: [(String, String)] = [
            ("Cognitive Ergonomics & Screen Restraint", "https://harbor.local/reading/cognitive-ergonomics"),
            ("Distributed Consensus Protocols", "https://example.com/consensus"),
            ("Typography in Digital Tools", "https://example.com/typography"),
        ]
        for sample in pinned {
            guard let url = URL(string: sample.1),
                  let tab = try? await store.openTab(url: url, title: sample.0, in: research.id, at: Date())
            else {
                continue
            }
            try? await store.setPinned(true, tabID: tab.id)
        }
        for sample in today {
            guard let url = URL(string: sample.1) else {
                continue
            }
            _ = try? await store.openTab(url: url, title: sample.0, in: research.id, at: Date())
        }
        for title in ["Vector Math Engine", "Local Runtimes"] {
            if let url = URL(string: "https://example.com/\(title.lowercased().replacingOccurrences(of: " ", with: "-"))") {
                _ = try? await store.openTab(url: url, title: title, in: systems.id, at: Date())
            }
        }
    }
}
