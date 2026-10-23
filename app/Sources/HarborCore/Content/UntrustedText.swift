import Foundation

public struct UntrustedText: Equatable, Sendable {
    public let source: String
    public let value: String

    public init(source: String, value: String) {
        self.source = source
        self.value = value
    }
}
