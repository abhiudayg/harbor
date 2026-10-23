import Foundation
import Testing
@testable import HarborCore

@Suite("Keychain client store integration")
struct KeychainClientStoreTests {
    static func isolatedService() -> String {
        "dev.harbor.browser.mcp.test.\(UUID().uuidString.lowercased())"
    }

    @Test("records written to the Keychain are read back unchanged")
    func roundTrip() async throws {
        let service = Self.isolatedService()
        let store = KeychainClientStore(service: service)
        let record = MCPClientRecord(
            id: "client-1",
            name: "Research agent",
            tokenDigest: AccessToken.digest(of: "example-token"),
            policy: PermissionPolicy(rules: [PermissionRule(site: "example.com", action: .read, grant: .allow)])
        )
        defer {
            Task { try? await store.save([]) }
        }

        try await store.save([record])

        #expect(try await store.load() == [record])
    }

    @Test("an empty Keychain loads as no clients")
    func emptyKeychain() async throws {
        let store = KeychainClientStore(service: Self.isolatedService())

        #expect(try await store.load().isEmpty)
    }
}
