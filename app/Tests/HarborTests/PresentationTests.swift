import Foundation
import HarborCore
import Testing
@testable import Harbor

@Suite("Shell layout rules")
struct ShellLayoutTests {
    @Test("the sidebar shows at the Stitch canvas width when requested")
    func sidebarShowsAtCanvasWidth() {
        #expect(ShellLayout.sidebarVisible(requested: true, width: 1440))
    }

    @Test("the sidebar collapses below 960 points even when requested", arguments: [959, 700, 480])
    func sidebarCollapsesNarrow(width: Double) {
        #expect(ShellLayout.sidebarVisible(requested: true, width: width) == false)
    }

    @Test("a hidden sidebar stays hidden at any width")
    func sidebarHiddenWhenNotRequested() {
        #expect(ShellLayout.sidebarVisible(requested: false, width: 1440) == false)
    }

    @Test("the companion panel shows only at 1280 points and wider")
    func companionThreshold() {
        #expect(ShellLayout.companionVisible(width: 1280))
        #expect(ShellLayout.companionVisible(width: 1279) == false)
    }
}

@Suite("Command bar results")
struct CommandBarResultsTests {
    static let research = Space(name: "Research")
    static let now = Date(timeIntervalSince1970: 2_000_000)

    static func tab(_ title: String, _ address: String, archived: Bool = false) -> BrowserTab {
        BrowserTab(
            url: URL(string: address)!,
            title: title,
            spaceID: research.id,
            lastActivatedAt: now,
            state: archived ? .archived : .live
        )
    }

    static let names = [research.id: research.name]

    @Test("an empty query lists open tabs and both actions")
    func emptyQueryListsEverything() {
        let results = CommandBarResults.make(
            query: "",
            tabs: [Self.tab("Paxos", "https://example.com/a")],
            spaceNames: Self.names
        )

        #expect(results.tabs.map(\.title) == ["Paxos"])
        #expect(results.actions.map(\.id) == ["triage", "inbox"])
    }

    @Test("a query filters tabs by title and by address")
    func queryFiltersTabs() {
        let tabs = [
            Self.tab("Paxos notes", "https://example.com/a"),
            Self.tab("Cooking", "https://recipes.example/b"),
        ]

        let byTitle = CommandBarResults.make(query: "paxos", tabs: tabs, spaceNames: Self.names)
        let byAddress = CommandBarResults.make(query: "recipes", tabs: tabs, spaceNames: Self.names)

        #expect(byTitle.tabs.map(\.title) == ["Paxos notes"])
        #expect(byAddress.tabs.map(\.title) == ["Cooking"])
    }

    @Test("archived tabs never appear as results")
    func archivedTabsExcluded() {
        let results = CommandBarResults.make(
            query: "",
            tabs: [Self.tab("Old", "https://example.com/old", archived: true)],
            spaceNames: Self.names
        )

        #expect(results.tabs.isEmpty)
    }

    @Test("a query that matches nothing returns no tabs and no actions")
    func noMatches() {
        let results = CommandBarResults.make(query: "zzzz-no-match", tabs: [], spaceNames: Self.names)

        #expect(results.tabs.isEmpty)
        #expect(results.actions.isEmpty)
    }

    @Test("a tab hit shows its space and host")
    func tabDetailShowsSpaceAndHost() {
        let results = CommandBarResults.make(
            query: "",
            tabs: [Self.tab("Paxos", "https://example.com/a")],
            spaceNames: Self.names
        )

        #expect(results.tabs.first?.detail == "Space: Research · example.com")
    }

    @Test("results are capped at five tabs")
    func capsTabResults() {
        let tabs = (1...8).map { Self.tab("Tab \($0)", "https://example.com/\($0)") }

        #expect(CommandBarResults.make(query: "", tabs: tabs, spaceNames: Self.names).tabs.count == 5)
    }
}

@Suite("Triage summary")
struct TriageSummaryTests {
    static let now = Date(timeIntervalSince1970: 3_000_000)
    static let space = Space(name: "Research")

    static func tab(_ address: String, activatedDaysAgo: Double = 0, pinned: Bool = false, archived: Bool = false) -> BrowserTab {
        BrowserTab(
            url: URL(string: address)!,
            title: address,
            spaceID: space.id,
            isPinned: pinned,
            lastActivatedAt: now.addingTimeInterval(-activatedDaysAgo * 86_400),
            state: archived ? .archived : .live
        )
    }

    @Test("counts kept, archived, duplicate, and stale tabs")
    func countsEachBucket() {
        let tabs = [
            Self.tab("https://a.example/1", pinned: true),
            Self.tab("https://b.example/x", archived: true),
            Self.tab("https://c.example/same"),
            Self.tab("https://c.example/same"),
            Self.tab("https://d.example/old", activatedDaysAgo: 5),
        ]

        let summary = TriageSummary.make(tabs: tabs, now: Self.now)

        #expect(summary.total == 5)
        #expect(summary.keep == 1)
        #expect(summary.archived == 1)
        #expect(summary.duplicates == 2)
        #expect(summary.stale == 1)
    }

    @Test("an archived stale tab is not counted as stale")
    func archivedTabNotStale() {
        let summary = TriageSummary.make(
            tabs: [Self.tab("https://e.example/", activatedDaysAgo: 10, archived: true)],
            now: Self.now
        )

        #expect(summary.stale == 0)
    }
}

@Suite("Task inbox grouping")
struct TaskInboxGroupsTests {
    static func task(_ state: AgentTaskState) -> AgentTask {
        AgentTask(ownerID: "user", site: "example.com", steps: [.readPage], taskGrants: [])
            .with(state: state)
    }

    @Test("each task state lands in its inbox section")
    func statesMapToSections() {
        let groups = TaskInboxGroups.make(tasks: [
            Self.task(.awaitingApproval(UUID())),
            Self.task(.running),
            Self.task(.completed),
            Self.task(.failed("boom")),
            Self.task(.stopped),
        ])

        #expect(groups.tasks(in: .waitingForApproval).count == 1)
        #expect(groups.tasks(in: .running).count == 1)
        #expect(groups.tasks(in: .completed).count == 1)
        #expect(groups.tasks(in: .failed).count == 2)
    }

    @Test("no tasks gives empty sections")
    func emptyInbox() {
        let groups = TaskInboxGroups.make(tasks: [])

        #expect(TaskInboxSection.allCases.allSatisfy { groups.tasks(in: $0).isEmpty })
    }
}
