import Testing
@testable import HarborCore

@Suite("Permission policy")
struct PermissionPolicyTests {
    @Test("denies a non-sensitive action when no rule grants it")
    func deniesUngrantedReadByDefault() {
        let policy = PermissionPolicy()

        #expect(policy.decide(site: "example.com", action: .read) == .deny)
    }

    @Test("requires approval for a sensitive action when no rule covers it", arguments: [
        ActionClass.submitForm, .sendMessage, .purchase, .deleteData, .download, .fillCredential,
    ])
    func requiresApprovalForSensitiveActions(action: ActionClass) {
        let policy = PermissionPolicy()

        #expect(policy.decide(site: "example.com", action: action) == .requireApproval)
    }

    @Test("allows a non-sensitive action granted for the site")
    func allowsGrantedAction() {
        let policy = PermissionPolicy(rules: [
            PermissionRule(site: "example.com", action: .read, grant: .allow),
        ])

        #expect(policy.decide(site: "example.com", action: .read) == .allow)
    }

    @Test("allows a sensitive action only through an explicit allow rule")
    func allowsSensitiveActionWithExplicitRule() {
        let policy = PermissionPolicy(rules: [
            PermissionRule(site: "bank.example", action: .submitForm, grant: .allow),
        ])

        #expect(policy.decide(site: "bank.example", action: .submitForm) == .allow)
    }

    @Test("an explicit deny overrides an allow for the same site and action")
    func explicitDenyWins() {
        let policy = PermissionPolicy(rules: [
            PermissionRule(site: "example.com", action: .read, grant: .allow),
            PermissionRule(site: "example.com", action: .read, grant: .deny),
        ])

        #expect(policy.decide(site: "example.com", action: .read) == .deny)
    }

    @Test("a rule for another site does not apply")
    func ruleIsScopedToSite() {
        let policy = PermissionPolicy(rules: [
            PermissionRule(site: "example.com", action: .read, grant: .allow),
        ])

        #expect(policy.decide(site: "other.example", action: .read) == .deny)
    }

    @Test("a wildcard rule applies to every site")
    func wildcardAppliesToAnySite() {
        let policy = PermissionPolicy(rules: [
            PermissionRule(site: PermissionRule.anySite, action: .navigate, grant: .allow),
        ])

        #expect(policy.decide(site: "anywhere.example", action: .navigate) == .allow)
    }

    @Test("a rule for one action does not grant another action")
    func ruleIsScopedToAction() {
        let policy = PermissionPolicy(rules: [
            PermissionRule(site: "example.com", action: .read, grant: .allow),
        ])

        #expect(policy.decide(site: "example.com", action: .click) == .deny)
    }
}
