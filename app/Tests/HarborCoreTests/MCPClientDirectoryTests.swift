import HarborTestSupport
import Foundation
import Testing
@testable import HarborCore

@Suite("MCP client directory")
struct MCPClientDirectoryTests {
    static func directory(_ store: MemoryClientStore = MemoryClientStore()) async throws -> MCPClientDirectory {
        try await MCPClientDirectory(store: store)
    }

    @Test("an issued token authenticates the client it was issued to")
    func issuedTokenAuthenticates() async throws {
        let directory = try await Self.directory()

        let token = try await directory.issue(name: "Research agent")
        let client = await directory.authenticate("Bearer \(token)")

        #expect(client != nil)
        #expect(await directory.summaries().map(\.name) == ["Research agent"])
    }

    @Test("a token that was never issued does not authenticate")
    func unknownTokenRejected() async throws {
        let directory = try await Self.directory()
        _ = try await directory.issue(name: "Research agent")

        #expect(await directory.authenticate("Bearer not-issued") == nil)
    }

    @Test("a revoked client's token stops authenticating at once")
    func revokedTokenRejected() async throws {
        let directory = try await Self.directory()
        let token = try await directory.issue(name: "Research agent")
        let id = try #require(await directory.summaries().first?.id)

        try await directory.revoke(id: id)

        #expect(await directory.authenticate("Bearer \(token)") == nil)
        #expect(await directory.summaries().isEmpty)
    }

    @Test("revoking an unknown client is rejected")
    func revokeUnknown() async throws {
        let directory = try await Self.directory()

        await #expect(throws: MCPClientDirectoryError.unknownClient("missing")) {
            try await directory.revoke(id: "missing")
        }
    }

    @Test("blank and over-long names are rejected", arguments: [
        "",
        "   ",
        String(repeating: "n", count: MCPClientDirectory.maxNameLength + 1),
    ])
    func rejectsBadNames(name: String) async throws {
        let directory = try await Self.directory()

        await #expect(throws: MCPClientDirectoryError.invalidName) {
            try await directory.issue(name: name)
        }
    }

    @Test("clients and their tokens persist across directory instances")
    func persistsAcrossInstances() async throws {
        let store = MemoryClientStore()
        let first = try await Self.directory(store)
        let token = try await first.issue(name: "Research agent")

        let reopened = try await Self.directory(store)

        #expect(await reopened.authenticate("Bearer \(token)") != nil)
        #expect(await reopened.summaries().map(\.name) == ["Research agent"])
    }

    @Test("a new client has no grants until one is given")
    func newClientHasNoGrants() async throws {
        let directory = try await Self.directory()
        _ = try await directory.issue(name: "Research agent")

        #expect(await directory.summaries().first?.grantCount == 0)
    }

    @Test("the token is never stored, only its digest")
    func storesDigestOnly() async throws {
        let store = MemoryClientStore()
        let directory = try await Self.directory(store)
        let token = try await directory.issue(name: "Research agent")

        let records = await store.load()
        #expect(records.first?.tokenDigest == AccessToken.digest(of: token))
        #expect(records.first?.tokenDigest != Data(token.utf8))
    }
}

@Suite("MCP client revocation at the dispatcher")
@MainActor
struct MCPRevocationTests {
    @Test("a revoked client gets 401 from the dispatcher immediately")
    func revokedClientGetsUnauthorized() async throws {
        let directory = try await MCPClientDirectory(store: MemoryClientStore())
        let token = try await directory.issue(name: "Research agent")
        let id = try #require(await directory.summaries().first?.id)
        let dispatcher = MCPDispatcher(
            authenticator: directory,
            runner: AgentRunner(
                policy: PermissionPolicy(),
                approvals: ApprovalService(),
                audit: AuditLog(),
                driver: FakePageDriver()
            ),
            store: BrowserStore(),
            auditLog: AuditLog()
        )

        let before = await dispatcher.handle(
            hostHeader: "127.0.0.1:1",
            authorization: "Bearer \(token)",
            body: Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#.utf8)
        )
        try await directory.revoke(id: id)
        let after = await dispatcher.handle(
            hostHeader: "127.0.0.1:1",
            authorization: "Bearer \(token)",
            body: Data(#"{"jsonrpc":"2.0","id":2,"method":"initialize"}"#.utf8)
        )

        #expect(before.status == 200)
        #expect(after.status == 401)
    }
}
