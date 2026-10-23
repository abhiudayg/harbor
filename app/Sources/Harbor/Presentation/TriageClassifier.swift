import Foundation
import HarborCore

enum TriageClassifier {
    static func status(for tab: BrowserTab, duplicateURLs: Set<String>, now: Date) -> TriageStatus {
        if tab.isPinned {
            return .kept
        }
        if duplicateURLs.contains(tab.url.absoluteString) {
            return .duplicate
        }
        if TabMemory.isHighMemory(tab) {
            return .highMemory
        }
        if now.timeIntervalSince(tab.lastActivatedAt) >= BrowserStore.staleAfter {
            return .stale
        }
        return .active
    }

    static func duplicateURLs(in tabs: [BrowserTab]) -> Set<String> {
        let open = tabs.filter { $0.state != .archived }
        let counts = Dictionary(grouping: open, by: \.url.absoluteString).mapValues(\.count)
        return Set(counts.filter { $0.value > 1 }.keys)
    }
}
