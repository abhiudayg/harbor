import Foundation
import Testing
@testable import HarborCore

@Suite("WebKit engine integration")
@MainActor
struct WebKitEngineIntegrationTests {
    static let page = """
        <html><body>
        <p id="status">idle</p>
        <input id="query">
        <button id="go" onclick="document.getElementById('status').innerText = 'clicked'">Go</button>
        </body></html>
        """

    static func bodyText(_ engine: WebKitEngine) async throws -> String {
        try await engine.evaluate("return document.body.innerText", arguments: [:]) as? String ?? ""
    }

    @Test("a background engine never uses the persistent data store")
    func backgroundEngineIsNotPersistent() {
        #expect(WebKitEngine(isBackground: true).isPersistent == false)
    }

    @Test("a foreground engine uses the persistent data store")
    func foregroundEngineIsPersistent() {
        #expect(WebKitEngine(isBackground: false).isPersistent)
    }

    @Test("loading HTML makes its text readable")
    func loadedHTMLIsReadable() async throws {
        let engine = WebKitEngine(isBackground: true)

        try await engine.loadHTML("<body>Hello <b>harbor</b></body>")

        #expect(try await Self.bodyText(engine) == "Hello harbor")
    }

    @Test("loading a file URL completes and exposes the page")
    func loadsFileURL() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("index.html")
        try Self.page.write(to: file, atomically: true, encoding: .utf8)
        let engine = WebKitEngine(isBackground: true)

        try await engine.load(file)

        #expect(try await Self.bodyText(engine).contains("idle"))
    }

    @Test("a navigation to an unreachable host fails with a navigation error")
    func unreachableHostFails() async throws {
        let engine = WebKitEngine(isBackground: true)
        let url = try #require(URL(string: "http://unresolvable.invalid/"))

        await #expect(throws: PageDriverError.self) {
            try await engine.load(url)
        }
    }

    @Test("clicking a button runs its handler")
    func clickRunsHandler() async throws {
        let engine = WebKitEngine(isBackground: true)
        try await engine.loadHTML(Self.page)

        _ = try await engine.evaluate(
            "const element = document.querySelector(selector); element.click(); return 'ok';",
            arguments: ["selector": "#go"]
        )

        #expect(try await Self.bodyText(engine).contains("clicked"))
    }
}
