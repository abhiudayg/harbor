import Foundation
import Testing
import WebKit
@testable import HarborCore

@Suite("Content blocking")
struct ContentBlockingTests {
    @Test("standard policy is on with no site exceptions")
    func standardPolicyIsOn() {
        let policy = ContentBlockingPolicy.standard

        #expect(policy.isEnabled)
        #expect(policy.exceptions.isEmpty)
    }

    @Test("exempting a site keeps the policy on and records the exception")
    func exemptingASite() {
        let policy = ContentBlockingPolicy.standard.exempting("example.com")

        #expect(policy.isEnabled)
        #expect(policy.exceptions == ["example.com"])
        #expect(ContentBlockingPolicy.standard.exceptions.isEmpty)
    }

    @Test("a disabled policy produces no rule list")
    func disabledPolicyHasNoRules() {
        let policy = ContentBlockingPolicy(isEnabled: false, exceptions: [])

        #expect(policy.ruleListJSON == nil)
    }

    @Test("the rule list blocks every tracker domain once")
    func ruleListCoversEveryTracker() throws {
        let rules = try decodedRules(ContentBlockingPolicy.standard)

        #expect(rules.count == ContentBlockingPolicy.trackerDomains.count)
        for rule in rules {
            let action = try #require(rule["action"] as? [String: String])
            #expect(action == ["type": "block"])
        }
    }

    @Test("each rule matches its tracker domain and its subdomains")
    func ruleMatchesTrackerDomain() throws {
        let rules = try decodedRules(ContentBlockingPolicy.standard)
        let filters = try rules.map { rule -> String in
            let trigger = try #require(rule["trigger"] as? [String: Any])
            return try #require(trigger["url-filter"] as? String)
        }

        let doubleclick = try #require(filters.first { $0.contains("doubleclick") })
        let regex = try NSRegularExpression(pattern: doubleclick)
        #expect(matches(regex, "https://ad.doubleclick.net/pixel"))
        #expect(!matches(regex, "https://example.com/doubleclick.net"))
    }

    @Test("a site exception is excluded from every rule, including its subdomains")
    func exceptionIsExcluded() throws {
        let rules = try decodedRules(ContentBlockingPolicy.standard.exempting("example.com"))

        #expect(rules.count == ContentBlockingPolicy.trackerDomains.count)
        for rule in rules {
            let trigger = try #require(rule["trigger"] as? [String: Any])
            #expect(trigger["unless-domain"] as? [String] == ["*example.com"])
        }
    }

    @Test("rules without exceptions carry no unless-domain key")
    func noExceptionNoUnlessDomain() throws {
        let rules = try decodedRules(ContentBlockingPolicy.standard)

        for rule in rules {
            let trigger = try #require(rule["trigger"] as? [String: Any])
            #expect(trigger["unless-domain"] == nil)
        }
    }

    @Test("WebKit accepts the generated rule list")
    @MainActor
    func webKitCompilesRuleList() async throws {
        let json = try #require(ContentBlockingPolicy.standard.exempting("example.com").ruleListJSON)

        let list = try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "harbor-content-blocking-test",
            encodedContentRuleList: json
        )

        #expect(list != nil)
    }

    private func matches(_ regex: NSRegularExpression, _ url: String) -> Bool {
        regex.firstMatch(in: url, range: NSRange(location: 0, length: (url as NSString).length)) != nil
    }

    private func decodedRules(_ policy: ContentBlockingPolicy) throws -> [[String: Any]] {
        let json = try #require(policy.ruleListJSON)
        let data = Data(json.utf8)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
}
