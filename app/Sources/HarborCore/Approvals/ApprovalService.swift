import Foundation

public enum ApprovalScope: Equatable, Sendable {
    case once
    case task
    case site
}

public enum ApprovalDecision: Equatable, Sendable {
    case approve(ApprovalScope)
    case deny
}

public enum ApprovalStatus: Equatable, Sendable {
    case pending
    case approved(ApprovalScope)
    case denied
}

public struct ApprovalRequest: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let taskID: UUID
    public let site: String
    public let action: ActionClass
    public let status: ApprovalStatus

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        site: String,
        action: ActionClass,
        status: ApprovalStatus = .pending
    ) {
        self.id = id
        self.taskID = taskID
        self.site = site
        self.action = action
        self.status = status
    }

    public func resolved(_ status: ApprovalStatus) -> ApprovalRequest {
        ApprovalRequest(id: id, taskID: taskID, site: site, action: action, status: status)
    }
}

public enum ApprovalError: Error, Equatable, Sendable {
    case unknownRequest(UUID)
    case alreadyResolved(UUID)
}

public actor ApprovalService {
    public private(set) var requests: [ApprovalRequest] = []

    public init() {}

    public func request(taskID: UUID, site: String, action: ActionClass) -> ApprovalRequest {
        let request = ApprovalRequest(taskID: taskID, site: site, action: action)
        requests = requests + [request]
        return request
    }

    public func pending() -> [ApprovalRequest] {
        requests.filter { $0.status == .pending }
    }

    public func resolve(_ id: UUID, with decision: ApprovalDecision) throws -> ApprovalRequest {
        guard let index = requests.firstIndex(where: { $0.id == id }) else {
            throw ApprovalError.unknownRequest(id)
        }
        let current = requests[index]
        guard current.status == .pending else {
            throw ApprovalError.alreadyResolved(id)
        }
        let status: ApprovalStatus = switch decision {
        case .approve(let scope): .approved(scope)
        case .deny: .denied
        }
        let resolved = current.resolved(status)
        var updated = requests
        updated[index] = resolved
        requests = updated
        return resolved
    }
}
