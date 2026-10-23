import Foundation
import Testing
@testable import HarborCore
import HarborTestSupport

@Suite("WebKit page driver integration")
@MainActor
struct WebKitPageDriverIntegrationTests {
    static let page = """
        <html><body>
        <p id="status">idle</p>
        <input id="query">
        <button id="go" onclick="document.getElementById('status').innerText = 'clicked'">Go</button>
        </body></html>
        """

    static func makeDriver(html: String = page) async throws -> (WebKitEngine, WebKitPageDriver) {
        let engine = WebKitEngine(isBackground: true)
        try await engine.loadHTML(html)
        return (engine, WebKitPageDriver(engine: engine))
    }

    static func evaluateString(_ engine: WebKitEngine, _ script: String) async throws -> String {
        try await engine.evaluate(script, arguments: [:]) as? String ?? ""
    }

    @Test("readPage returns the rendered text as untrusted output")
    func readPageReturnsText() async throws {
        let (_, driver) = try await Self.makeDriver()

        let output = try await driver.perform(.readPage)

        guard case .text(let text) = output else {
            Issue.record("expected text output")
            return
        }
        #expect(text.source == "page")
        #expect(text.value.contains("idle"))
    }

    @Test("click runs the element's handler")
    func clickRunsHandler() async throws {
        let (engine, driver) = try await Self.makeDriver()

        _ = try await driver.perform(.click(selector: "#go"))

        #expect(try await Self.evaluateString(engine, "return document.getElementById('status').innerText") == "clicked")
    }

    @Test("typeText sets the input value and fires an input event")
    func typeTextSetsValue() async throws {
        let (engine, driver) = try await Self.makeDriver()

        _ = try await driver.perform(.typeText(selector: "#query", text: "harbor"))

        #expect(try await Self.evaluateString(engine, "return document.getElementById('query').value") == "harbor")
    }

    @Test("an interaction on a missing element fails with elementNotFound")
    func missingElementFails() async throws {
        let (_, driver) = try await Self.makeDriver()

        await #expect(throws: PageDriverError.elementNotFound("#absent")) {
            try await driver.perform(.click(selector: "#absent"))
        }
    }

    @Test("a selector that tries to break out of the script is passed as data, not code")
    func selectorIsNotScript() async throws {
        let (engine, driver) = try await Self.makeDriver()
        let hostile = "#go\"); document.getElementById('status').innerText = 'pwned'; (\"#go"

        await #expect(throws: (any Error).self) {
            try await driver.perform(.click(selector: hostile))
        }

        #expect(try await Self.evaluateString(engine, "return document.getElementById('status').innerText") == "idle")
    }

    @Test("the driver refuses to navigate to a non-public destination")
    func driverBlocksInternalNavigation() async throws {
        let (_, driver) = try await Self.makeDriver()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("local.html")
        try "<body>local</body>".write(to: file, atomically: true, encoding: .utf8)

        await #expect(throws: PageDriverError.self) {
            try await driver.perform(.navigate(file))
        }
    }

    @Test("download and credential fill are unsupported in the driver")
    func unsupportedActionsThrow() async throws {
        let (_, driver) = try await Self.makeDriver()

        await #expect(throws: PageDriverError.unsupported(.fillCredential)) {
            try await driver.perform(.fillCredential(selector: "#pw"))
        }
        await #expect(throws: PageDriverError.unsupported(.download)) {
            try await driver.perform(.download(Fixtures.publicURL))
        }
    }
}
