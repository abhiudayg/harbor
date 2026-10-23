import Foundation

public struct MCPClientRecord: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let tokenDigest: Data
    public let policy: PermissionPolicy

    public init(id: String, name: String, tokenDigest: Data, policy: PermissionPolicy) {
        self.id = id
        self.name = name
        self.tokenDigest = tokenDigest
        self.policy = policy
    }
}

public protocol MCPClientStore: Sendable {
    func load() async throws -> [MCPClientRecord]
    func save(_ records: [MCPClientRecord]) async throws
}

public enum MCPClientDirectoryError: Error, Equatable, Sendable {
    case invalidName
    case unknownClient(String)
}

public protocol MCPClientAuthenticating: Sendable {
    func authenticate(_ authorization: String?) async -> MCPClient?
}

public actor MCPClientDirectory: MCPClientAuthenticating {
    public static let maxNameLength = 64

    public struct Summary: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let grantCount: Int
    }

    private var records: [MCPClientRecord]
    private let store: any MCPClientStore

    public init(store: any MCPClientStore) async throws {
        self.store = store
        self.records = try await store.load()
    }

    public func summaries() -> [Summary] {
        records.map { Summary(id: $0.id, name: $0.name, grantCount: $0.policy.rules.count) }
    }

    public func issue(name: String) async throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxNameLength else {
            throw MCPClientDirectoryError.invalidName
        }
        let token = try AccessToken.generate()
        let record = MCPClientRecord(
            id: UUID().uuidString.lowercased(),
            name: trimmed,
            tokenDigest: token.digest,
            policy: PermissionPolicy()
        )
        let updated = records + [record]
        try await store.save(updated)
        records = updated
        return token.value
    }

    public func revoke(id: String) async throws {
        guard records.contains(where: { $0.id == id }) else {
            throw MCPClientDirectoryError.unknownClient(id)
        }
        let updated = records.filter { $0.id != id }
        try await store.save(updated)
        records = updated
    }

    public func authenticate(_ authorization: String?) async -> MCPClient? {
        guard let authorization, authorization.hasPrefix("Bearer ") else {
            return nil
        }
        let candidate = String(authorization.dropFirst("Bearer ".count))
        return records
            .first { AccessToken.matches(candidate, digest: $0.tokenDigest) }
            .map { MCPClient(id: $0.id, tokenDigest: $0.tokenDigest, policy: $0.policy) }
    }
}

public struct StaticClients: MCPClientAuthenticating {
    private let clients: [MCPClient]

    public init(_ clients: [MCPClient]) {
        self.clients = clients
    }

    public func authenticate(_ authorization: String?) async -> MCPClient? {
        guard let authorization, authorization.hasPrefix("Bearer ") else {
            return nil
        }
        let candidate = String(authorization.dropFirst("Bearer ".count))
        return clients.first { AccessToken.matches(candidate, digest: $0.tokenDigest) }
    }
}

public actor MemoryClientStore: MCPClientStore {
    private var saved: [MCPClientRecord]

    public init(_ records: [MCPClientRecord] = []) {
        self.saved = records
    }

    public func load() -> [MCPClientRecord] {
        saved
    }

    public func save(_ records: [MCPClientRecord]) {
        saved = records
    }
}
