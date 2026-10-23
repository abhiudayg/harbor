import Foundation
import HarborCore
import HarborTestSupport
import Testing
@testable import Harbor

@Suite("App model")
@MainActor
struct AppModelTests {
    static func makeModel(driver: FakePageDriver = FakePageDriver()) -> (AppModel, AgentRunner, ApprovalService) {
        let approvals = ApprovalService()
        let runner = AgentRunner(
            policy: PermissionPolicy(),
            approvals: approvals,
            audit: AuditLog(),
            driver: driver
        )
        let model = AppModel(store: BrowserStore(), approvals: approvals, runner: runner)
        return (model, runner, approvals)
    }

    @Test("starting seeds one space with six pinned and three open tabs")
    func startSeedsWorkspace() async {
        let (model, _, _) = Self.makeModel()

        await model.start()

        #expect(model.spaces.map(\.name) == ["Research"])
        #expect(model.tabs.count == 9)
        #expect(model.tabs.filter(\.isPinned).count == 6)
    }

    @Test("starting twice does not seed again")
    func startIsIdempotent() async {
        let (model, _, _) = Self.makeModel()

        await model.start()
        await model.start()

        #expect(model.tabs.count == 9)
    }

    @Test("a pending approval appears in the model and approving it completes the held task")
    func approvalFlowThroughModel() async throws {
        let driver = FakePageDriver()
        let (model, runner, _) = Self.makeModel(driver: driver)
        await model.start()
        let paused = await runner.submit(AgentTask(
            ownerID: "user",
            site: "shop.example",
            steps: [.submitForm(selector: "#buy")]
        ))
        await model.refresh()

        let request = try #require(model.pendingApprovals.first)
        #expect(request.site == "shop.example")
        #expect(request.action == .submitForm)

        await model.approve(request, scope: .once)

        #expect(model.pendingApprovals.isEmpty)
        #expect(await runner.task(paused.id)?.state == .completed)
        #expect(driver.performed == [.submitForm(selector: "#buy")])
    }

    @Test("denying an approval fails the held task and clears the queue")
    func denialFlowThroughModel() async throws {
        let driver = FakePageDriver()
        let (model, runner, _) = Self.makeModel(driver: driver)
        await model.start()
        let paused = await runner.submit(AgentTask(
            ownerID: "user",
            site: "shop.example",
            steps: [.submitForm(selector: "#buy")]
        ))
        await model.refresh()
        let request = try #require(model.pendingApprovals.first)

        await model.deny(request)

        #expect(model.pendingApprovals.isEmpty)
        guard case .failed = await runner.task(paused.id)?.state else {
            Issue.record("a denied task must fail")
            return
        }
        #expect(driver.performed.isEmpty)
    }
}
