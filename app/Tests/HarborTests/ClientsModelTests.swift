import Foundation
import HarborCore
import HarborTestSupport
import Testing
@testable import Harbor

@Suite("Clients in the app model")
@MainActor
struct ClientsModelTests {
    @Test("issuing a client returns its token once and lists the client without the token")
    func issueListsClient() async throws {
        let model = AppModel(clientStore: MemoryClientStore(), serverEnabled: false)
        await model.start()

        let token = try await model.issueClient(name: "Research agent")

        #expect(token.isEmpty == false)
        #expect(model.clients.map(\.name) == ["Research agent"])
    }

    @Test("revoking a client removes it from the list")
    func revokeRemovesClient() async throws {
        let model = AppModel(clientStore: MemoryClientStore(), serverEnabled: false)
        await model.start()
        _ = try await model.issueClient(name: "Research agent")
        let id = try #require(model.clients.first?.id)

        try await model.revokeClient(id: id)

        #expect(model.clients.isEmpty)
    }

    @Test("an invalid client name is rejected and nothing is listed")
    func invalidNameRejected() async throws {
        let model = AppModel(clientStore: MemoryClientStore(), serverEnabled: false)
        await model.start()

        await #expect(throws: MCPClientDirectoryError.invalidName) {
            try await model.issueClient(name: "   ")
        }
        #expect(model.clients.isEmpty)
    }

    @Test("starting the model starts a loopback server that accepts issued tokens")
    func serverAcceptsIssuedToken() async throws {
        let model = AppModel(clientStore: MemoryClientStore(), serverEnabled: true)
        await model.start()
        let port = try #require(model.serverPort)
        let token = try await model.issueClient(name: "Research agent")

        var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(port)/mcp")))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#.utf8)
        let (_, response) = try await URLSession.shared.data(for: request)

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test("a revoked client's token is refused by the running server")
    func serverRefusesRevokedToken() async throws {
        let model = AppModel(clientStore: MemoryClientStore(), serverEnabled: true)
        await model.start()
        let port = try #require(model.serverPort)
        let token = try await model.issueClient(name: "Research agent")
        try await model.revokeClient(id: try #require(model.clients.first?.id))

        var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(port)/mcp")))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#.utf8)
        let (_, response) = try await URLSession.shared.data(for: request)

        #expect((response as? HTTPURLResponse)?.statusCode == 401)
    }
}
