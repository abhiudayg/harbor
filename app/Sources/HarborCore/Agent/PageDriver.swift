import Foundation

public enum StepOutput: Equatable, Sendable {
    case none
    case text(UntrustedText)
}

public enum PageDriverError: Error, Equatable, Sendable {
    case unsupported(ActionClass)
    case elementNotFound(String)
    case navigationFailed(String)
}

@MainActor
public protocol PageDriver: Sendable {
    var currentHost: String? { get }
    func perform(_ step: AgentStep) async throws -> StepOutput
}
