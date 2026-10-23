import Foundation
import Testing
@testable import HarborCore
import HarborTestSupport

@Suite("Agent scenarios")
@MainActor
struct AgentScenarioTests {
    @Test("F-AGENT-1: a sensitive step is held, approved once, run once, and audited")
    func approvalGatedActionRunsOnceAfterApproval() async throws {
        let driver = FakePageDriver()
        let approvals = ApprovalService()
        let audit = AuditLog()
        let runner = AgentRunner(
            policy: PermissionPolicy(),
            approvals: approvals,
            audit: audit,
            driver: driver,
            now: { Fixtures.start }
        )
        let paused = await runner.submit(AgentTask(
            ownerID: "user",
            site: "bank.example",
            steps: [.submitForm(selector: "#transfer")]
        ))
        guard case .awaitingApproval(let requestID) = paused.state else {
            Issue.record("the transfer must wait for approval")
            return
        }
        #expect(driver.performed.isEmpty)

        _ = try await approvals.resolve(requestID, with: .approve(.once))
        let finished = try await runner.resume(paused.id)

        #expect(finished.state == .completed)
        #expect(driver.performed == [.submitForm(selector: "#transfer")])
        #expect(await audit.entries.map(\.record.result) == ["awaiting approval", "ok"])
        #expect(await audit.verify())
    }

    @Test("F-AGENT-2: a denied sensitive step never runs and the task fails")
    func deniedSensitiveStepNeverRuns() async throws {
        let driver = FakePageDriver()
        let approvals = ApprovalService()
        let runner = AgentRunner(
            policy: PermissionPolicy(),
            approvals: approvals,
            audit: AuditLog(),
            driver: driver,
            now: { Fixtures.start }
        )
        let paused = await runner.submit(AgentTask(
            ownerID: "user",
            site: "shop.example",
            steps: [.submitForm(selector: "#buy")]
        ))
        guard case .awaitingApproval(let requestID) = paused.state else {
            Issue.record("expected approval wait")
            return
        }

        _ = try await approvals.resolve(requestID, with: .deny)
        let finished = try await runner.resume(paused.id)

        guard case .failed = finished.state else {
            Issue.record("a denied task must fail")
            return
        }
        #expect(driver.performed.isEmpty)
    }

    @Test("F-AGENT-3: a site approval lets later tasks on that site run without asking")
    func siteApprovalCarriesToLaterTasks() async throws {
        let driver = FakePageDriver()
        let approvals = ApprovalService()
        let runner = AgentRunner(
            policy: PermissionPolicy(),
            approvals: approvals,
            audit: AuditLog(),
            driver: driver,
            now: { Fixtures.start }
        )
        let first = await runner.submit(AgentTask(ownerID: "user", site: "forms.example", steps: [.submitForm(selector: "#a")]))
        guard case .awaitingApproval(let requestID) = first.state else {
            Issue.record("expected approval wait")
            return
        }
        _ = try await approvals.resolve(requestID, with: .approve(.site))
        _ = try await runner.resume(first.id)

        let second = await runner.submit(AgentTask(ownerID: "user", site: "forms.example", steps: [.submitForm(selector: "#b")]))

        #expect(second.state == .completed)
        #expect(driver.performed.count == 2)
    }

    @Test("F-AGENT-4: stopping a waiting task prevents its held step from ever running")
    func stoppedTaskNeverRunsItsStep() async throws {
        let driver = FakePageDriver()
        let approvals = ApprovalService()
        let runner = AgentRunner(
            policy: PermissionPolicy(),
            approvals: approvals,
            audit: AuditLog(),
            driver: driver,
            now: { Fixtures.start }
        )
        let paused = await runner.submit(AgentTask(ownerID: "user", site: "shop.example", steps: [.submitForm(selector: "#buy")]))
        guard case .awaitingApproval(let requestID) = paused.state else {
            Issue.record("expected approval wait")
            return
        }

        _ = try await runner.stop(paused.id)
        _ = try? await approvals.resolve(requestID, with: .approve(.once))
        let afterApproval = try? await runner.resume(paused.id)

        #expect(afterApproval == nil || afterApproval?.state == .stopped)
        #expect(driver.performed.isEmpty)
    }
}
