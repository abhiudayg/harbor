import Foundation

public enum TabState: Equatable, Sendable {
    case live
    case hibernated
    case archived
}

public struct BrowserTab: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let url: URL
    public let title: String
    public let spaceID: UUID
    public let isPinned: Bool
    public let lastActivatedAt: Date
    public let state: TabState

    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        spaceID: UUID,
        isPinned: Bool = false,
        lastActivatedAt: Date,
        state: TabState = .live
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.spaceID = spaceID
        self.isPinned = isPinned
        self.lastActivatedAt = lastActivatedAt
        self.state = state
    }

    public func with(
        spaceID: UUID? = nil,
        isPinned: Bool? = nil,
        lastActivatedAt: Date? = nil,
        state: TabState? = nil
    ) -> BrowserTab {
        BrowserTab(
            id: id,
            url: url,
            title: title,
            spaceID: spaceID ?? self.spaceID,
            isPinned: isPinned ?? self.isPinned,
            lastActivatedAt: lastActivatedAt ?? self.lastActivatedAt,
            state: state ?? self.state
        )
    }
}
