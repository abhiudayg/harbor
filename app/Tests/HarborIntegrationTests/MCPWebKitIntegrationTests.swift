import Foundation
import Testing
@testable import HarborCore
import HarborTestSupport

@Suite("MCP server with WebKit integration")
@MainActor
struct MCPWebKitIntegrationTests {
    static let readExample = PermissionPolicy(rules: [
        PermissionRule(site: "example.com", action: .read, grant: .allow),
    ])

    @Test("a client reads the live WebKit page over HTTP, labelled untrusted")
    func clientReadsLivePageOverHTTP() async throws {
        let engine = WebKitEngine(isBackground: true)
        try await engine.loadHTML("<body><p>Q3 revenue grew 12 percent</p></body>")
        let harness = try Fixtures.makeHarness(
            clientPolicy: Self.readExample,
            driver: WebKitPageDriver(engine: engine)
        )
        let server = try MCPHTTPServer(dispatcher: harness.dispatcher)
        let port = try await server.start()
        defer { server.stop() }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/mcp")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(harness.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Fixtures.toolCall("read_page", arguments: ["site": "example.com"])

        let (data, response) = try await URLSession.shared.data(for: request)

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let text = (((Fixtures.decodeObject(data)["result"] as? [String: Any])?["content"] as? [[String: Any]])?
            .first?["text"] as? String) ?? ""
        #expect(text.contains("Q3 revenue grew 12 percent"))
        #expect(text.contains(#""trust":"untrusted""#))
    }
}
