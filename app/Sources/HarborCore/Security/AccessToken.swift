import CryptoKit
import Foundation
import Security

public struct AccessToken: Equatable, Sendable {
    public let value: String
    public let digest: Data

    public static func generate() throws -> AccessToken {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AccessTokenError.randomSourceUnavailable(status)
        }
        let value = Data(bytes).base64EncodedString()
        return AccessToken(value: value)
    }

    public init(value: String) {
        self.value = value
        self.digest = Self.digest(of: value)
    }

    public static func digest(of value: String) -> Data {
        Data(SHA256.hash(data: Data(value.utf8)))
    }

    public static func matches(_ candidate: String, digest expected: Data) -> Bool {
        constantTimeEquals(digest(of: candidate), expected)
    }

    static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

public enum AccessTokenError: Error, Equatable, Sendable {
    case randomSourceUnavailable(OSStatus)
}
