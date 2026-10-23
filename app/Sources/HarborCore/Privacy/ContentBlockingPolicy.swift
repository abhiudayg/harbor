import Foundation

public struct ContentBlockingPolicy: Equatable, Sendable {
    public static let standard = ContentBlockingPolicy(isEnabled: true, exceptions: [])

    public static let trackerDomains = [
        "doubleclick.net",
        "google-analytics.com",
        "googletagmanager.com",
        "facebook.net",
        "scorecardresearch.com",
        "adnxs.com",
    ]

    public let isEnabled: Bool
    public let exceptions: Set<String>

    public init(isEnabled: Bool, exceptions: Set<String>) {
        self.isEnabled = isEnabled
        self.exceptions = exceptions
    }

    public func exempting(_ host: String) -> ContentBlockingPolicy {
        ContentBlockingPolicy(isEnabled: isEnabled, exceptions: exceptions.union([host]))
    }

    public var ruleListJSON: String? {
        guard isEnabled else {
            return nil
        }
        let unlessDomain = exceptions.sorted().map { "*\($0)" }
        let rules: [[String: Any]] = Self.trackerDomains.map { domain in
            var trigger: [String: Any] = [
                "url-filter": "^[^:]+://([^/]+\\.)?\(NSRegularExpression.escapedPattern(for: domain))[:/]",
            ]
            if !unlessDomain.isEmpty {
                trigger["unless-domain"] = unlessDomain
            }
            return ["trigger": trigger, "action": ["type": "block"]]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rules) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }
}
