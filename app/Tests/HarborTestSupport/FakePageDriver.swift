import Foundation
import HarborCore

@MainActor
public final class FakePageDriver: PageDriver {
    public private(set) var performed: [AgentStep] = []
    public var failingActions: Set<ActionClass> = []
    public var pageText: String
    public var currentHost: String?

    public init(pageText: String = "", currentHost: String? = nil) {
        self.pageText = pageText
        self.currentHost = currentHost
    }

    public func perform(_ step: AgentStep) async throws -> StepOutput {
        performed.append(step)
        if failingActions.contains(step.action) {
            throw PageDriverError.unsupported(step.action)
        }
        if case .readPage = step {
            return .text(UntrustedText(source: "fake-page", value: pageText))
        }
        return .none
    }
}
