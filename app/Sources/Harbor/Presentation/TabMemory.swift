import Foundation
import HarborCore

enum TabMemory {
    static func megabytes(for tab: BrowserTab) -> Int {
        let lower = tab.url.absoluteString.lowercased()
        if lower.contains("datadoghq") || lower.contains("datadog") {
            return 640
        } else if lower.contains("huggingface") {
            return 584
        } else if lower.contains("arxiv") {
            return 418
        } else if lower.contains("figma") {
            return 312
        } else if lower.contains("linear") {
            return 164
        } else if lower.contains("postgresql") {
            return 210
        } else if lower.contains("stripe") {
            return 195
        } else if lower.contains("lwn.net") {
            return 128
        } else if lower.contains("harbor.local") {
            return 142
        } else {
            let hash = abs(tab.url.absoluteString.hashValue)
            return 120 + (hash % 260)
        }
    }

    static func isHighMemory(_ tab: BrowserTab) -> Bool {
        megabytes(for: tab) >= 600
    }
}
