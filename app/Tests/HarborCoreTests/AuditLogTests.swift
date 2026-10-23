import Foundation
import Testing
@testable import HarborCore

@Suite("Audit log")
struct AuditLogTests {
    static let timestamp = Date(timeIntervalSince1970: 1_000_000)

    static func record(
        result: String = "ok",
        arguments: [String: String] = ["url": "https://example.com"]
    ) -> AuditRecord {
        AuditRecord(
            timestamp: timestamp,
            taskID: UUID(),
            site: "example.com",
            tool: "navigate",
            arguments: arguments,
            result: result,
            approval: nil
        )
    }

    @Test("appended entries form a verifiable hash chain")
    func appendedEntriesVerify() async {
        let log = AuditLog()

        let first = await log.append(Self.record(result: "one"))
        let second = await log.append(Self.record(result: "two"))

        #expect(first.previousHash == AuditLog.genesisHash)
        #expect(second.previousHash == first.hash)
        #expect(await log.verify())
    }

    @Test("an empty log verifies")
    func emptyLogVerifies() async {
        #expect(await AuditLog().verify())
    }

    @Test("secret arguments are redacted and other arguments are kept")
    func redactsSecretArguments() async {
        let log = AuditLog()

        let entry = await log.append(Self.record(arguments: [
            "url": "https://example.com/login",
            "password": "hunter2",
            "authToken": "abc123",
        ]))

        #expect(entry.record.arguments["url"] == "https://example.com/login")
        #expect(entry.record.arguments["password"] == AuditRecord.redactedValue)
        #expect(entry.record.arguments["authToken"] == AuditRecord.redactedValue)
    }

    @Test("a modified entry fails verification")
    func detectsModifiedEntry() async {
        let log = AuditLog()
        let original = await log.append(Self.record(result: "allowed"))
        let tampered = AuditEntry(
            index: original.index,
            record: Self.record(result: "denied"),
            previousHash: original.previousHash,
            hash: original.hash
        )

        #expect(await AuditLog(entries: [tampered]).verify() == false)
    }

    @Test("an entry stored at the wrong position fails verification")
    func detectsMisplacedEntry() async {
        let source = AuditLog()
        let entry = await source.append(Self.record(result: "one"))
        let misplaced = AuditEntry(
            index: 1,
            record: entry.record,
            previousHash: entry.previousHash,
            hash: entry.hash
        )

        #expect(await AuditLog(entries: [misplaced]).verify() == false)
    }

    @Test("a removed entry breaks the chain")
    func detectsRemovedEntry() async {
        let log = AuditLog()
        _ = await log.append(Self.record(result: "one"))
        let second = await log.append(Self.record(result: "two"))
        let withoutFirst = AuditLog(entries: [second])

        #expect(await withoutFirst.verify() == false)
    }
}
