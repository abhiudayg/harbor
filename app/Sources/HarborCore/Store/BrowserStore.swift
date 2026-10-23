import Foundation

public enum BrowserStoreError: Error, Equatable, Sendable {
    case invalidName
    case unknownSpace(UUID)
    case unknownTab(UUID)
}

public actor BrowserStore {
    public static let staleAfter: TimeInterval = 3 * 24 * 60 * 60

    public private(set) var spaces: [Space]
    public private(set) var tabs: [BrowserTab] = []

    public init(spaces: [Space] = []) {
        self.spaces = spaces
    }

    public func createSpace(named name: String) throws -> Space {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BrowserStoreError.invalidName
        }
        let space = Space(name: trimmed)
        spaces = spaces + [space]
        return space
    }

    public func openTab(url: URL, title: String, in spaceID: UUID, at now: Date) throws -> BrowserTab {
        try requireSpace(spaceID)
        let tab = BrowserTab(url: url, title: title, spaceID: spaceID, lastActivatedAt: now)
        tabs = tabs + [tab]
        return tab
    }

    public func tabs(in spaceID: UUID) -> [BrowserTab] {
        tabs.filter { $0.spaceID == spaceID }
    }

    public func move(tabID: UUID, to spaceID: UUID) throws {
        try requireSpace(spaceID)
        try update(tabID) { $0.with(spaceID: spaceID) }
    }

    public func setPinned(_ pinned: Bool, tabID: UUID) throws {
        try update(tabID) { $0.with(isPinned: pinned) }
    }

    public func activate(tabID: UUID, at now: Date) throws {
        try update(tabID) { $0.with(lastActivatedAt: now, state: .live) }
    }

    public func hibernate(tabID: UUID) throws {
        try update(tabID) { $0.with(state: .hibernated) }
    }

    public func archive(tabID: UUID) throws {
        try update(tabID) { $0.with(state: .archived) }
    }

    public func close(tabID: UUID) throws {
        guard tabs.contains(where: { $0.id == tabID }) else {
            throw BrowserStoreError.unknownTab(tabID)
        }
        tabs = tabs.filter { $0.id != tabID }
    }

    public func archiveStaleTabs(now: Date) -> [UUID] {
        let staleIDs = tabs
            .filter { tab in
                !tab.isPinned
                    && tab.state != .archived
                    && now.timeIntervalSince(tab.lastActivatedAt) >= Self.staleAfter
            }
            .map(\.id)
        tabs = tabs.map { staleIDs.contains($0.id) ? $0.with(state: .archived) : $0 }
        return staleIDs
    }

    private func requireSpace(_ id: UUID) throws {
        guard spaces.contains(where: { $0.id == id }) else {
            throw BrowserStoreError.unknownSpace(id)
        }
    }

    private func update(_ tabID: UUID, _ transform: (BrowserTab) -> BrowserTab) throws {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
            throw BrowserStoreError.unknownTab(tabID)
        }
        var updated = tabs
        updated[index] = transform(tabs[index])
        tabs = updated
    }
}
