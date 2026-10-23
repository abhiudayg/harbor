import CryptoKit
import Foundation

public struct AuditRecord: Equatable, Sendable {
    public static let redactedValue = "[redacted]"
    static let secretKeyFragments = ["password", "token", "cookie", "secret", "authorization"]

    public let timestamp: Date
    public let taskID: UUID?
    public let site: String
    public let tool: String
    public let arguments: [String: String]
    public let result: String
    public let approval: ApprovalStatus?

    public init(
        timestamp: Date,
        taskID: UUID?,
        site: String,
        tool: String,
        arguments: [String: String],
        result: String,
        approval: ApprovalStatus?
    ) {
        self.timestamp = timestamp
        self.taskID = taskID
        self.site = site
        self.tool = tool
        self.arguments = Self.redact(arguments)
        self.result = result
        self.approval = approval
    }

    private static func redact(_ arguments: [String: String]) -> [String: String] {
        arguments.reduce(into: [:]) { redacted, pair in
            let key = pair.key.lowercased()
            let isSecret = secretKeyFragments.contains { key.contains($0) }
            redacted[pair.key] = isSecret ? redactedValue : pair.value
        }
    }
}

public struct AuditEntry: Equatable, Sendable {
    public let index: Int
    public let record: AuditRecord
    public let previousHash: String
    public let hash: String
}

public actor AuditLog {
    public static let genesisHash = String(repeating: "0", count: 64)

    public private(set) var entries: [AuditEntry]

    public init(entries: [AuditEntry] = []) {
        self.entries = entries
    }

    public func append(_ record: AuditRecord) -> AuditEntry {
        let index = entries.count
        let previousHash = entries.last?.hash ?? Self.genesisHash
        let entry = AuditEntry(
            index: index,
            record: record,
            previousHash: previousHash,
            hash: Self.digest(index: index, record: record, previousHash: previousHash)
        )
        entries = entries + [entry]
        return entry
    }

    public func verify() -> Bool {
        var expectedPrevious = Self.genesisHash
        for (position, entry) in entries.enumerated() {
            guard entry.index == position,
                  entry.previousHash == expectedPrevious,
                  Self.digest(index: entry.index, record: entry.record, previousHash: entry.previousHash) == entry.hash
            else {
                return false
            }
            expectedPrevious = entry.hash
        }
        return true
    }

    static func digest(index: Int, record: AuditRecord, previousHash: String) -> String {
        let arguments = record.arguments
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        let fields = [
            String(index),
            String(record.timestamp.timeIntervalSince1970),
            record.taskID?.uuidString ?? "",
            record.site,
            record.tool,
            arguments,
            record.result,
            String(describing: record.approval),
            previousHash,
        ]
        let digest = SHA256.hash(data: Data(fields.joined(separator: "|").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
