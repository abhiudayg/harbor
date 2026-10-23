import Foundation
import HarborCore

struct TriageSummary: Equatable {
    let total: Int
    let keep: Int
    let archived: Int
    let duplicates: Int
    let stale: Int

    static func make(tabs: [BrowserTab], now: Date) -> TriageSummary {
        let open = tabs.filter { $0.state != .archived }
        let urlCounts = Dictionary(grouping: open, by: \.url.absoluteString).mapValues(\.count)
        let duplicateCount = urlCounts.values.filter { $0 > 1 }.reduce(0) { $0 + $1 }
        let staleCount = open.filter { now.timeIntervalSince($0.lastActivatedAt) >= BrowserStore.staleAfter }.count
        return TriageSummary(
            total: tabs.count,
            keep: tabs.filter { $0.isPinned }.count,
            archived: tabs.filter { $0.state == .archived }.count,
            duplicates: duplicateCount,
            stale: staleCount
        )
    }
}
