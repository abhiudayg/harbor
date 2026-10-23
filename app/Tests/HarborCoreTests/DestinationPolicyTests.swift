import Foundation
import Testing
@testable import HarborCore

@Suite("Destination policy")
struct DestinationPolicyTests {
    @Test("allows public http and https destinations", arguments: [
        "https://example.com",
        "http://news.example.org/article?id=1",
        "https://172.15.0.1/",
        "https://172.32.0.1/",
    ])
    func allowsPublicDestinations(raw: String) throws {
        let url = try #require(URL(string: raw))

        #expect(DestinationPolicy.isAllowed(url))
    }

    @Test("blocks loopback, private, and metadata destinations", arguments: [
        "http://localhost:8080/",
        "https://foo.localhost/",
        "http://127.0.0.1/",
        "http://10.1.2.3/",
        "http://192.168.1.10/",
        "http://172.16.0.1/",
        "http://172.31.255.1/",
        "http://169.254.169.254/latest/meta-data",
        "http://0.0.0.0/",
        "http://[::1]/",
    ])
    func blocksInternalDestinations(raw: String) throws {
        let url = try #require(URL(string: raw))

        #expect(DestinationPolicy.isAllowed(url) == false)
    }

    @Test("blocks non-web schemes", arguments: [
        "file:///etc/passwd",
        "javascript:alert(1)",
        "ftp://example.com/file",
        "data:text/html,hello",
    ])
    func blocksNonWebSchemes(raw: String) throws {
        let url = try #require(URL(string: raw))

        #expect(DestinationPolicy.isAllowed(url) == false)
    }
}
