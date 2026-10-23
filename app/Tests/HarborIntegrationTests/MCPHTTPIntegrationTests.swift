import Foundation
import Testing
@testable import HarborCore
import HarborTestSupport

@Suite("MCP HTTP server integration")
@MainActor
struct MCPHTTPIntegrationTests {
    struct Running {
        let server: MCPHTTPServer
        let port: UInt16
        let token: String
    }

    static func start() async throws -> Running {
        let harness = try Fixtures.makeHarness(
            clientPolicy: PermissionPolicy(),
            driver: FakePageDriver(pageText: "served")
        )
        let server = try MCPHTTPServer(dispatcher: harness.dispatcher)
        let port = try await server.start()
        return Running(server: server, port: port, token: harness.token)
    }

    static func post(_ running: Running, body: Data, token: String?, path: String = "/mcp") async throws -> (Int, Data) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(running.port)\(path)")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? -1, data)
    }

    @Test("answers initialize over loopback with a JSON-RPC result")
    func initializeOverLoopback() async throws {
        let running = try await Self.start()
        defer { running.server.stop() }

        let (status, data) = try await Self.post(running, body: Fixtures.rpc("initialize"), token: running.token)

        #expect(status == 200)
        let result = Fixtures.decodeObject(data)["result"] as? [String: Any]
        #expect((result?["serverInfo"] as? [String: Any])?["name"] as? String == "harbor")
    }

    @Test("rejects a wrong token over the network with 401")
    func wrongTokenOverNetwork() async throws {
        let running = try await Self.start()
        defer { running.server.stop() }

        let (status, _) = try await Self.post(running, body: Fixtures.rpc("initialize"), token: "not-the-token")

        #expect(status == 401)
    }

    @Test("rejects a missing token over the network with 401")
    func missingTokenOverNetwork() async throws {
        let running = try await Self.start()
        defer { running.server.stop() }

        let (status, _) = try await Self.post(running, body: Fixtures.rpc("initialize"), token: nil)

        #expect(status == 401)
    }

    @Test("an unknown path is not found")
    func unknownPathNotFound() async throws {
        let running = try await Self.start()
        defer { running.server.stop() }

        let (status, _) = try await Self.post(running, body: Fixtures.rpc("initialize"), token: running.token, path: "/other")

        #expect(status == 404)
    }

    @Test("a GET on the endpoint is not allowed")
    func getNotAllowed() async throws {
        let running = try await Self.start()
        defer { running.server.stop() }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(running.port)/mcp")!)
        request.httpMethod = "GET"

        let (_, response) = try await URLSession.shared.data(for: request)

        #expect((response as? HTTPURLResponse)?.statusCode == 405)
    }

    @Test("an oversized body is refused before dispatch")
    func oversizedBodyOverNetwork() async throws {
        let running = try await Self.start()
        defer { running.server.stop() }
        let oversized = Data(repeating: UInt8(ascii: " "), count: MCPDispatcher.maxBodyBytes + 1)

        let (status, _) = try await Self.post(running, body: oversized, token: running.token)

        #expect(status == 413)
    }
}
