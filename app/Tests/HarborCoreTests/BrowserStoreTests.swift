import Foundation
import Testing
@testable import HarborCore

@Suite("Browser store")
struct BrowserStoreTests {
    static let start = Date(timeIntervalSince1970: 1_000_000)
    static let example = URL(string: "https://example.com")!

    @Test("creates a space with a trimmed name")
    func createsTrimmedSpace() async throws {
        let store = BrowserStore()

        let space = try await store.createSpace(named: "  Research  ")

        #expect(space.name == "Research")
        #expect(await store.spaces == [space])
    }

    @Test("rejects a blank space name")
    func rejectsBlankName() async {
        let store = BrowserStore()

        await #expect(throws: BrowserStoreError.invalidName) {
            try await store.createSpace(named: "   ")
        }
    }

    @Test("opens a tab in an existing space")
    func opensTabInSpace() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])

        let tab = try await store.openTab(url: Self.example, title: "Example", in: space.id, at: Self.start)

        #expect(tab.spaceID == space.id)
        #expect(tab.state == .live)
        #expect(await store.tabs(in: space.id) == [tab])
    }

    @Test("refuses to open a tab in an unknown space")
    func rejectsUnknownSpace() async {
        let store = BrowserStore()
        let missing = UUID()

        await #expect(throws: BrowserStoreError.unknownSpace(missing)) {
            try await store.openTab(url: Self.example, title: "Example", in: missing, at: Self.start)
        }
    }

    @Test("moves a tab into another space")
    func movesTab() async throws {
        let research = Space(name: "Research")
        let studio = Space(name: "Studio")
        let store = BrowserStore(spaces: [research, studio])
        let tab = try await store.openTab(url: Self.example, title: "Example", in: research.id, at: Self.start)

        try await store.move(tabID: tab.id, to: studio.id)

        #expect(await store.tabs(in: studio.id).map(\.id) == [tab.id])
        #expect(await store.tabs(in: research.id).isEmpty)
    }

    @Test("archives only unpinned tabs idle for the stale threshold")
    func archivesStaleUnpinnedTabs() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let stale = try await store.openTab(url: Self.example, title: "Stale", in: space.id, at: Self.start)
        let pinned = try await store.openTab(url: Self.example, title: "Pinned", in: space.id, at: Self.start)
        let recent = try await store.openTab(url: Self.example, title: "Recent", in: space.id, at: Self.start)
        try await store.setPinned(true, tabID: pinned.id)
        try await store.activate(tabID: recent.id, at: Self.start.addingTimeInterval(BrowserStore.staleAfter))

        let now = Self.start.addingTimeInterval(BrowserStore.staleAfter)
        let archived = await store.archiveStaleTabs(now: now)

        #expect(archived == [stale.id])
        let states = Dictionary(uniqueKeysWithValues: await store.tabs.map { ($0.id, $0.state) })
        #expect(states[stale.id] == .archived)
        #expect(states[pinned.id] == .live)
        #expect(states[recent.id] == .live)
    }

    @Test("does not archive a tab just under the threshold")
    func keepsTabBelowThreshold() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        _ = try await store.openTab(url: Self.example, title: "Fresh", in: space.id, at: Self.start)

        let archived = await store.archiveStaleTabs(now: Self.start.addingTimeInterval(BrowserStore.staleAfter - 1))

        #expect(archived.isEmpty)
    }

    @Test("activating an archived tab restores it to live")
    func activationRestoresArchivedTab() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let tab = try await store.openTab(url: Self.example, title: "Example", in: space.id, at: Self.start)
        _ = await store.archiveStaleTabs(now: Self.start.addingTimeInterval(BrowserStore.staleAfter))

        try await store.activate(tabID: tab.id, at: Self.start.addingTimeInterval(BrowserStore.staleAfter))

        #expect(await store.tabs.first?.state == .live)
    }

    @Test("hibernates a tab without changing its space")
    func hibernatesTab() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let tab = try await store.openTab(url: Self.example, title: "Example", in: space.id, at: Self.start)

        try await store.hibernate(tabID: tab.id)

        let stored = try #require(await store.tabs.first)
        #expect(stored.state == .hibernated)
        #expect(stored.spaceID == space.id)
    }

    @Test("archiving a tab moves it out of the live set without closing it")
    func archivesTabExplicitly() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let tab = try await store.openTab(url: Self.example, title: "Example", in: space.id, at: Self.start)

        try await store.archive(tabID: tab.id)

        #expect(await store.tabs.first?.state == .archived)
        #expect(await store.tabs.count == 1)
    }

    @Test("closing a tab removes it from the store")
    func closesTab() async throws {
        let space = Space(name: "Research")
        let store = BrowserStore(spaces: [space])
        let tab = try await store.openTab(url: Self.example, title: "Example", in: space.id, at: Self.start)

        try await store.close(tabID: tab.id)

        #expect(await store.tabs.isEmpty)
    }

    @Test("closing an unknown tab is rejected")
    func rejectsCloseUnknown() async {
        let store = BrowserStore()
        let missing = UUID()

        await #expect(throws: BrowserStoreError.unknownTab(missing)) {
            try await store.close(tabID: missing)
        }
    }

    @Test("refuses to change an unknown tab")
    func rejectsUnknownTab() async {
        let store = BrowserStore()
        let missing = UUID()

        await #expect(throws: BrowserStoreError.unknownTab(missing)) {
            try await store.hibernate(tabID: missing)
        }
    }
}
