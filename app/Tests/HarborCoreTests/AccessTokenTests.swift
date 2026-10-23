import Foundation
import Testing
@testable import HarborCore

@Suite("Access token")
struct AccessTokenTests {
    @Test("generated tokens carry 32 random bytes")
    func generatedTokenHasThirtyTwoBytes() throws {
        let token = try AccessToken.generate()

        let decoded = try #require(Data(base64Encoded: token.value))
        #expect(decoded.count == 32)
    }

    @Test("two generated tokens differ")
    func generatedTokensAreUnique() throws {
        #expect(try AccessToken.generate().value != AccessToken.generate().value)
    }

    @Test("a token matches its own digest and no other")
    func matchesOnlyItsDigest() throws {
        let token = try AccessToken.generate()

        #expect(AccessToken.matches(token.value, digest: token.digest))
        #expect(AccessToken.matches(token.value + "x", digest: token.digest) == false)
    }

    @Test("the digest is not the token itself")
    func digestHidesToken() {
        let token = AccessToken(value: "secret-value")

        #expect(token.digest != Data("secret-value".utf8))
        #expect(token.digest.count == 32)
    }

    @Test("constant-time comparison rejects different lengths")
    func rejectsDifferentLengths() {
        #expect(AccessToken.constantTimeEquals(Data([1, 2]), Data([1, 2, 3])) == false)
    }

    @Test("constant-time comparison rejects a single differing byte")
    func rejectsSingleByteDifference() {
        #expect(AccessToken.constantTimeEquals(Data([1, 2, 3]), Data([1, 2, 4])) == false)
    }

    @Test("constant-time comparison accepts identical data")
    func acceptsIdenticalData() {
        #expect(AccessToken.constantTimeEquals(Data([9, 8, 7]), Data([9, 8, 7])))
    }
}
