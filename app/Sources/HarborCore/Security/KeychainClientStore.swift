import Foundation
import Security

public struct KeychainClientStore: MCPClientStore {
    public enum KeychainError: Error, Equatable, Sendable {
        case status(OSStatus)
        case corruptRecords
    }

    private let service: String
    private let account = "mcp-clients"

    public init(service: String = "dev.harbor.browser.mcp") {
        self.service = service
    }

    public func load() async throws -> [MCPClientRecord] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.status(status)
        }
        guard let records = try? JSONDecoder().decode([MCPClientRecord].self, from: data) else {
            throw KeychainError.corruptRecords
        }
        return records
    }

    public func save(_ records: [MCPClientRecord]) async throws {
        let data = try JSONEncoder().encode(records)
        let deleteStatus = SecItemDelete(baseQuery() as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.status(deleteStatus)
        }
        var query = baseQuery()
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
