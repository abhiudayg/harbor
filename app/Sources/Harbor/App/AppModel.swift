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

    var isCommandBarPresented = false
    var isTriagePresented = false
    var isInboxPresented = false

    private let store: BrowserStore
    private let approvals: ApprovalService
    private let runner: AgentRunner

    init(
        store: BrowserStore = BrowserStore(),
        approvals: ApprovalService = ApprovalService(),
        runner: AgentRunner? = nil
    ) {
        self.store = store
        self.approvals = approvals
        self.runner = runner ?? AgentRunner(
            policy: PermissionPolicy(),
            approvals: approvals,
            audit: AuditLog(),
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
        await refresh()
    }

    func refresh() async {
        spaces = await store.spaces
        tabs = await store.tabs
        pendingApprovals = await approvals.pending()
        tasks = await runner.allTasks
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
