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

    @Test("keeping a tab pins it and moves it into the kept group")
    func keepPinsTab() async throws {
        let (model, _, _) = Self.makeModel()
        await model.start()
        let tab = try #require(model.tabs.first { !$0.isPinned })

        await model.keep(tab)

        #expect(model.tabs.first { $0.id == tab.id }?.isPinned == true)
    }

    @Test("archiving a tab hides it from the live set")
    func archiveHidesTab() async throws {
        let (model, _, _) = Self.makeModel()
        await model.start()
        let tab = try #require(model.tabs.first)

        await model.archive(tab)

        #expect(model.tabs.first { $0.id == tab.id }?.state == .archived)
    }

    @Test("closing a tab removes it from the workspace")
    func closeRemovesTab() async throws {
        let (model, _, _) = Self.makeModel()
        await model.start()
        let tab = try #require(model.tabs.first)

        await model.close(tab)

        #expect(model.tabs.count == 8)
        #expect(model.tabs.contains { $0.id == tab.id } == false)
    }

    @Test("archiving stale tabs leaves the seeded tabs open because they are fresh")
    func archiveStaleKeepsFreshTabs() async {
        let (model, _, _) = Self.makeModel()
        await model.start()

        await model.archiveStale()

        #expect(model.tabs.allSatisfy { $0.state == .live })
    }

    @Test("the model lists every task the runner has seen")
    func modelListsTasks() async {
        let (model, runner, _) = Self.makeModel()
        await model.start()
        _ = await runner.submit(AgentTask(ownerID: "user", site: "shop.example", steps: [.submitForm(selector: "#buy")]))

        await model.refresh()

        #expect(model.tasks.count == 1)
        guard case .awaitingApproval = model.tasks.first?.state else {
            Issue.record("a sensitive step must wait for approval")
            return
        }
    }

    @Test("the command bar, triage, and inbox start closed")
    func presentationStartsClosed() {
        let (model, _, _) = Self.makeModel()

        #expect(model.isCommandBarPresented == false)
        #expect(model.isTriagePresented == false)
        #expect(model.isInboxPresented == false)
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
