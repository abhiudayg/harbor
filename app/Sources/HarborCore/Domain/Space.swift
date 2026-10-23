import Foundation

public struct Space: Equatable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
