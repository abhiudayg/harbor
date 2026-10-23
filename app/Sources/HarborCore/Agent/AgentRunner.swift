import Foundation

public enum AgentRunnerError: Error, Equatable, Sendable {
    case unknownTask(UUID)
    case notAwaitingApproval(UUID)
    case unknownApproval(UUID)
}

public actor AgentRunner {
    public private(set) var tasks: [UUID: AgentTask] = [:]
    public private(set) var policy: PermissionPolicy

    private let approvals: ApprovalService
    private let audit: AuditLog
    private let driver: any PageDriver
    private let now: @Sendable () -> Date

    public init(
        policy: PermissionPolicy,
        approvals: ApprovalService,
        audit: AuditLog,
        driver: any PageDriver,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.policy = policy
        self.approvals = approvals
        self.audit = audit
        self.driver = driver
        self.now = now
    }

    public func submit(_ task: AgentTask) async -> AgentTask {
        tasks[task.id] = task
        return await advance(task.id, fallback: task)
    }

    public func task(_ id: UUID) -> AgentTask? {
        tasks[id]
    }

    public var allTasks: [AgentTask] {
        tasks.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    public func stop(_ id: UUID) throws(AgentRunnerError) -> AgentTask {
        guard let task = tasks[id] else {
            throw AgentRunnerError.unknownTask(id)
        }
        guard !task.state.isTerminal else {
            return task
        }
        let stopped = task.with(state: .stopped)
        tasks[id] = stopped
        return stopped
    }

    public func resume(_ id: UUID) async throws(AgentRunnerError) -> AgentTask {
        guard let task = tasks[id] else {
            throw AgentRunnerError.unknownTask(id)
        }
        guard case .awaitingApproval(let requestID) = task.state else {
            throw AgentRunnerError.notAwaitingApproval(id)
        }
        guard let request = await approvals.requests.first(where: { $0.id == requestID }) else {
            throw AgentRunnerError.unknownApproval(requestID)
        }
        switch request.status {
        case .pending:
            return task
        case .denied:
            let failed = task.with(state: .failed("approval denied for \(request.action.rawValue) on \(request.site)"))
            tasks[id] = failed
            return failed
        case .approved(let scope):
            let granted = grant(task, scope: scope, action: request.action, site: request.site)
            tasks[id] = granted.with(state: .running)
            let executed = await execute(granted.steps[granted.cursor], in: granted.with(state: .running))
            tasks[id] = executed
            return await advance(id, fallback: executed)
        }
    }

    private func advance(_ id: UUID, fallback: AgentTask) async -> AgentTask {
        while let task = tasks[id], task.state == .running, task.cursor < task.steps.count {
            let step = task.steps[task.cursor]
            let next = await process(step, in: task)
            if tasks[id]?.state == .running {
                tasks[id] = next
            }
        }
        if let task = tasks[id], task.state == .running {
            tasks[id] = task.with(state: .completed)
        }
        return tasks[id] ?? fallback
    }

    private func process(_ step: AgentStep, in task: AgentTask) async -> AgentTask {
        let site = step.targetHost ?? task.site
        if let pageHost = await driver.currentHost, step.targetHost == nil, pageHost != task.site.lowercased() {
            await record(task, step, site: site, result: "denied: page is not on site", approval: nil)
            return task.with(state: .failed("page is not on \(task.site)"))
        }
        if task.taskGrants.contains(step.action) {
            return await execute(step, in: task)
        }
        switch policy.decide(site: site, action: step.action) {
        case .allow:
            return await execute(step, in: task)
        case .deny:
            await record(task, step, site: site, result: "denied", approval: nil)
            return task.with(state: .failed("denied \(step.action.rawValue) on \(site)"))
        case .requireApproval:
            let request = await approvals.request(taskID: task.id, site: site, action: step.action)
            await record(task, step, site: site, result: "awaiting approval", approval: request.status)
            return task.with(state: .awaitingApproval(request.id))
        }
    }

    private func execute(_ step: AgentStep, in task: AgentTask) async -> AgentTask {
        let site = step.targetHost ?? task.site
        do {
            let output = try await driver.perform(step)
            await record(task, step, site: site, result: "ok", approval: nil)
            var outputs = task.outputs
            if case .text(let text) = output {
                outputs = outputs + [text]
            }
            return task.with(cursor: task.cursor + 1, outputs: outputs)
        } catch {
            await record(task, step, site: site, result: "error", approval: nil)
            return task.with(state: .failed("\(step.action.rawValue) failed"))
        }
    }

    private func grant(_ task: AgentTask, scope: ApprovalScope, action: ActionClass, site: String) -> AgentTask {
        switch scope {
        case .once:
            return task
        case .task:
            return task.with(taskGrants: task.taskGrants.union([action]))
        case .site:
            policy = PermissionPolicy(rules: policy.rules + [PermissionRule(site: site, action: action, grant: .allow)])
            return task
        }
    }

    private func record(
        _ task: AgentTask,
        _ step: AgentStep,
        site: String,
        result: String,
        approval: ApprovalStatus?
    ) async {
        let record = AuditRecord(
            timestamp: now(),
            taskID: task.id,
            site: site,
            tool: step.action.rawValue,
            arguments: step.auditArguments,
            result: result,
            approval: approval
        )
        _ = await audit.append(record)
    }
}
