import Foundation

enum ToolPayload {
    static func task(_ task: AgentTask) -> String {
        encode(TaskPayload(task))
    }

    static func tabs(_ rows: [[String: String]]) -> String {
        encode(TabsPayload(rows: rows))
    }

    private static func encode(_ value: some Encodable) -> String {
        guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }
}

private struct TaskPayload: Encodable {
    let trust = "untrusted"
    let id: String
    let state: String
    let outputs: [UntrustedPayload]

    init(_ task: AgentTask) {
        id = task.id.uuidString
        state = Self.label(task.state)
        outputs = task.outputs.map { UntrustedPayload(source: $0.source, value: $0.value) }
    }

    private static func label(_ state: AgentTaskState) -> String {
        switch state {
        case .running: "running"
        case .awaitingApproval(let request): "awaiting_approval:\(request.uuidString)"
        case .completed: "completed"
        case .failed(let reason): "failed:\(reason)"
        case .stopped: "stopped"
        }
    }
}

private struct TabsPayload: Encodable {
    let trust = "untrusted"
    let rows: [[String: String]]
}

private struct UntrustedPayload: Encodable {
    let trust = "untrusted"
    let source: String
    let value: String
}
