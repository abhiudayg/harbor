import Foundation

public enum ActionClass: String, CaseIterable, Codable, Sendable {
    case read
    case navigate
    case click
    case typeText
    case submitForm
    case sendMessage
    case purchase
    case deleteData
    case download
    case fillCredential
    case createTask

    public var isSensitive: Bool {
        switch self {
        case .read, .navigate, .click, .typeText:
            false
        case .submitForm, .sendMessage, .purchase, .deleteData, .download, .fillCredential, .createTask:
            true
        }
    }
}

public enum Grant: Codable, Equatable, Sendable {
    case allow
    case deny
}

public struct PermissionRule: Codable, Equatable, Sendable {
    public static let anySite = "*"

    public let site: String
    public let action: ActionClass
    public let grant: Grant

    public init(site: String, action: ActionClass, grant: Grant) {
        self.site = site
        self.action = action
        self.grant = grant
    }
}

public enum Decision: Equatable, Sendable {
    case allow
    case deny
    case requireApproval
}

public struct PermissionPolicy: Codable, Equatable, Sendable {
    public let rules: [PermissionRule]

    public init(rules: [PermissionRule] = []) {
        self.rules = rules
    }

    public func decide(site: String, action: ActionClass) -> Decision {
        let matching = rules.filter { rule in
            rule.action == action && (rule.site == PermissionRule.anySite || rule.site == site)
        }
        if matching.contains(where: { $0.grant == .deny }) {
            return .deny
        }
        if matching.contains(where: { $0.grant == .allow }) {
            return .allow
        }
        return action.isSensitive ? .requireApproval : .deny
    }
}
