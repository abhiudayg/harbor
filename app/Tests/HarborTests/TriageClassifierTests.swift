import Foundation
import HarborCore
import HarborTestSupport
import Testing
@testable import Harbor

@Suite("Triage classification")
struct TriageClassifierTests {
    @Test("a pinned tab is kept even when it is a duplicate or stale")
    func pinnedIsKept() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let url = try #require(URL(string: "https://example.com/pinned"))
        let tab = try await store.openTab(url: url, title: "Pinned", in: space.id, at: Fixtures.start)
        try await store.setPinned(true, tabID: tab.id)
        let tabs = await store.tabs
        let now = Fixtures.start.addingTimeInterval(BrowserStore.staleAfter)

        let pinnedTab = try #require(tabs.first { $0.id == tab.id })

        let status = TriageClassifier.status(for: pinnedTab, duplicateURLs: TriageClassifier.duplicateURLs(in: tabs), now: now)

        #expect(status == .kept)
    }

    @Test("a tab whose address is open elsewhere is a duplicate, even when it is stale")
    func duplicateBeatsStale() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let url = try #require(URL(string: "https://example.com/same"))
        let older = try await store.openTab(url: url, title: "Older", in: space.id, at: Fixtures.start)
        _ = try await store.openTab(url: url, title: "Newer", in: space.id, at: Fixtures.start.addingTimeInterval(3600))
        let tabs = await store.tabs
        let now = Fixtures.start.addingTimeInterval(BrowserStore.staleAfter)

        let status = TriageClassifier.status(for: older, duplicateURLs: TriageClassifier.duplicateURLs(in: tabs), now: now)

        #expect(status == .duplicate)
    }

    @Test("an unpinned, unique tab idle for the stale threshold is stale")
    func idleUniqueTabIsStale() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let url = try #require(URL(string: "https://example.com/old"))
        let tab = try await store.openTab(url: url, title: "Old", in: space.id, at: Fixtures.start)
        let tabs = await store.tabs
        let now = Fixtures.start.addingTimeInterval(BrowserStore.staleAfter)

        let status = TriageClassifier.status(for: tab, duplicateURLs: TriageClassifier.duplicateURLs(in: tabs), now: now)

        #expect(status == .stale)
    }

    @Test("an unpinned, unique tab used within the threshold is active")
    func recentUniqueTabIsActive() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let url = try #require(URL(string: "https://example.com/fresh"))
        let tab = try await store.openTab(url: url, title: "Fresh", in: space.id, at: Fixtures.start)
        let tabs = await store.tabs
        let now = Fixtures.start.addingTimeInterval(BrowserStore.staleAfter - 1)

        let status = TriageClassifier.status(for: tab, duplicateURLs: TriageClassifier.duplicateURLs(in: tabs), now: now)

        #expect(status == .active)
    }

    @Test("an unpinned, unique tab with high resident memory leak is classified as high memory")
    func highMemoryTabIsClassified() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let url = try #require(URL(string: "https://app.datadoghq.com/apm/traces"))
        let tab = try await store.openTab(url: url, title: "Datadog APM", in: space.id, at: Fixtures.start)
        let tabs = await store.tabs
        let now = Fixtures.start

        let status = TriageClassifier.status(for: tab, duplicateURLs: TriageClassifier.duplicateURLs(in: tabs), now: now)

        #expect(status == .highMemory)
    }
}

@Suite("Consolidating tabs into a space")
@MainActor
struct ConsolidateTests {
    @Test("consolidating moves every given tab into the chosen space")
    func movesTabsIntoSpace() async throws {
        let research = Space(name: "Research")
        let systems = Space(name: "Systems")
        let store = BrowserStore(spaces: [research, systems])
        let url = try #require(URL(string: "https://example.com/a"))
        _ = try await store.openTab(url: url, title: "A", in: research.id, at: Fixtures.start)
        let model = AppModel(store: store, clientStore: MemoryClientStore(), serverEnabled: false)
        await model.refresh()

        await model.consolidate(model.tabs, into: systems.id)

        #expect(model.tabs.allSatisfy { $0.spaceID == systems.id })
    }
}

@Suite("Harbor memory")
struct ProcessMemoryTests {
    @Test("the operating system reports a non-zero peak resident size for the running process")
    func reportsPeakResidentSize() {
        #expect((ProcessMemory.peakResidentBytes() ?? 0) > 0)
    }
}
