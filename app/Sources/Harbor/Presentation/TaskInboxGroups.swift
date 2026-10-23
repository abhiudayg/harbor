import HarborCore

enum TaskInboxSection: String, CaseIterable, Equatable {
    case waitingForApproval = "Waiting for approval"
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed or stopped"
}

struct TaskInboxGroups: Equatable {
    let sections: [TaskInboxSection: [AgentTask]]

    static func make(tasks: [AgentTask]) -> TaskInboxGroups {
        var sections: [TaskInboxSection: [AgentTask]] = [:]
        for task in tasks {
            sections[section(for: task.state), default: []].append(task)
        }
        return TaskInboxGroups(sections: sections)
    }

    func tasks(in section: TaskInboxSection) -> [AgentTask] {
        sections[section] ?? []
    }

    private static func section(for state: AgentTaskState) -> TaskInboxSection {
        switch state {
        case .awaitingApproval: .waitingForApproval
        case .running: .running
        case .completed: .completed
        case .failed, .stopped: .failed
        }
    }
}
