import Foundation
import Testing
@testable import HarborCore

@Suite("Content blocking in the WebKit engine")
@MainActor
struct ContentBlockingEngineIntegrationTests {
    @Test("the standard policy installs tracker rules before the first load")
    func standardPolicyInstallsRules() async throws {
        let engine = WebKitEngine(isBackground: true, contentBlocking: .standard)

        #expect(await engine.isContentBlocking)
        try await engine.loadHTML("<p>page</p>")
    }

    @Test("a disabled policy installs no rules")
    func disabledPolicyInstallsNoRules() async throws {
        let engine = WebKitEngine(
            isBackground: true,
            contentBlocking: ContentBlockingPolicy(isEnabled: false, exceptions: [])
        )

        #expect(await engine.isContentBlocking == false)
        try await engine.loadHTML("<p>page</p>")
    }

    @Test("a site exception still installs the rules for other sites")
    func exceptionKeepsRulesOn() async throws {
        let engine = WebKitEngine(
            isBackground: true,
            contentBlocking: ContentBlockingPolicy.standard.exempting("example.com")
        )

        #expect(await engine.isContentBlocking)
    }
}
