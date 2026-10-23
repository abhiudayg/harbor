import Foundation
import HarborCore

struct CommandBarResults: Equatable {
    struct TabHit: Equatable, Identifiable {
        let id: UUID
        let title: String
        let detail: String
    }

    struct Action: Equatable, Identifiable {
        let id: String
        let title: String
        let detail: String
    }

    let tabs: [TabHit]
    let actions: [Action]

    static func make(query: String, tabs: [BrowserTab], spaceNames: [UUID: String]) -> CommandBarResults {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchingTabs = tabs
            .filter { $0.state != .archived }
            .filter { needle.isEmpty || $0.title.lowercased().contains(needle) || $0.url.absoluteString.lowercased().contains(needle) }
            .prefix(5)
            .map { tab in
                TabHit(
                    id: tab.id,
                    title: tab.title,
                    detail: "Space: \(spaceNames[tab.spaceID] ?? "Unknown") · \(tab.url.host ?? tab.url.absoluteString)"
                )
            }
        let matchingActions = actions.filter { needle.isEmpty || $0.title.lowercased().contains(needle) }
        return CommandBarResults(tabs: Array(matchingTabs), actions: matchingActions)
    }

    static let actions: [Action] = [
        Action(id: "triage", title: "Triage tabs", detail: "Review every open tab and keep, archive, or close it"),
        Action(id: "inbox", title: "Open Task Inbox", detail: "See background tasks and pending approvals"),
    ]
}
