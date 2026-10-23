import Foundation

public enum AgentTaskState: Equatable, Sendable {
    case running
    case awaitingApproval(UUID)
    case completed
    case failed(String)
    case stopped

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .stopped:
            true
        case .running, .awaitingApproval:
            false
        }
    }
}

public struct AgentTask: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let ownerID: String
    public let site: String
    public let steps: [AgentStep]
    public let cursor: Int
    public let state: AgentTaskState
    public let outputs: [UntrustedText]
    public let taskGrants: Set<ActionClass>

    public init(
        id: UUID = UUID(),
        ownerID: String,
        site: String,
        steps: [AgentStep],
        taskGrants: Set<ActionClass> = []
    ) {
        self.id = id
        self.ownerID = ownerID
        self.site = site
        self.steps = steps
        self.cursor = 0
        self.state = .running
        self.outputs = []
        self.taskGrants = taskGrants
    }

    private init(
        id: UUID,
        ownerID: String,
        site: String,
        steps: [AgentStep],
        cursor: Int,
        state: AgentTaskState,
        outputs: [UntrustedText],
        taskGrants: Set<ActionClass>
    ) {
        self.id = id
        self.ownerID = ownerID
        self.site = site
        self.steps = steps
        self.cursor = cursor
        self.state = state
        self.outputs = outputs
        self.taskGrants = taskGrants
    }

    public func with(
        cursor: Int? = nil,
        state: AgentTaskState? = nil,
        outputs: [UntrustedText]? = nil,
        taskGrants: Set<ActionClass>? = nil
    ) -> AgentTask {
        AgentTask(
            id: id,
            ownerID: ownerID,
            site: site,
            steps: steps,
            cursor: cursor ?? self.cursor,
            state: state ?? self.state,
            outputs: outputs ?? self.outputs,
            taskGrants: taskGrants ?? self.taskGrants
        )
    }
}
