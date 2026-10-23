import Foundation
import Testing
@testable import HarborCore

@Suite("Approval service")
struct ApprovalServiceTests {
    @Test("a new request is pending")
    func newRequestIsPending() async {
        let service = ApprovalService()

        let request = await service.request(taskID: UUID(), site: "bank.example", action: .submitForm)

        #expect(request.status == .pending)
        #expect(await service.pending() == [request])
    }

    @Test("approving records the scope and removes the request from pending")
    func approvingRecordsScope() async throws {
        let service = ApprovalService()
        let request = await service.request(taskID: UUID(), site: "bank.example", action: .submitForm)

        let resolved = try await service.resolve(request.id, with: .approve(.site))

        #expect(resolved.status == .approved(.site))
        #expect(await service.pending().isEmpty)
    }

    @Test("denying records the denial")
    func denyingRecordsDenial() async throws {
        let service = ApprovalService()
        let request = await service.request(taskID: UUID(), site: "shop.example", action: .purchase)

        let resolved = try await service.resolve(request.id, with: .deny)

        #expect(resolved.status == .denied)
    }

    @Test("a request cannot be resolved twice")
    func rejectsSecondResolution() async throws {
        let service = ApprovalService()
        let request = await service.request(taskID: UUID(), site: "bank.example", action: .submitForm)
        _ = try await service.resolve(request.id, with: .approve(.once))

        await #expect(throws: ApprovalError.alreadyResolved(request.id)) {
            try await service.resolve(request.id, with: .deny)
        }
    }

    @Test("resolving an unknown request fails")
    func rejectsUnknownRequest() async {
        let service = ApprovalService()
        let missing = UUID()

        await #expect(throws: ApprovalError.unknownRequest(missing)) {
            try await service.resolve(missing, with: .deny)
        }
    }
}
