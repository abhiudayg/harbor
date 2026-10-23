import Foundation
import Testing
@testable import HarborCore

@Suite("HTTP request parser")
struct HTTPRequestParserTests {
    static func raw(_ head: String, body: String = "") -> Data {
        Data((head + "\r\n\r\n" + body).utf8)
    }

    @Test("waits for the header terminator")
    func incompleteWithoutHeaderEnd() {
        #expect(HTTPRequestParser.parse(Data("POST /mcp HTTP/1.1\r\nHost: x".utf8)) == .incomplete)
    }

    @Test("parses method, path, headers, and body")
    func parsesCompleteRequest() {
        let data = Self.raw(
            "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 2",
            body: "{}"
        )

        guard case .complete(let request) = HTTPRequestParser.parse(data) else {
            Issue.record("expected a complete request")
            return
        }
        #expect(request.method == "POST")
        #expect(request.path == "/mcp")
        #expect(request.headers["host"] == "127.0.0.1")
        #expect(request.body == Data("{}".utf8))
    }

    @Test("waits for the full body")
    func incompleteBody() {
        let data = Self.raw("POST /mcp HTTP/1.1\r\nContent-Length: 10", body: "{}")

        #expect(HTTPRequestParser.parse(data) == .incomplete)
    }

    @Test("rejects a malformed request line")
    func rejectsRequestLine() {
        #expect(HTTPRequestParser.parse(Self.raw("POST /mcp")) == .invalid(status: 400))
    }

    @Test("rejects a header without a colon")
    func rejectsHeaderWithoutColon() {
        #expect(HTTPRequestParser.parse(Self.raw("POST /mcp HTTP/1.1\r\nBadHeader")) == .invalid(status: 400))
    }

    @Test("rejects a non-numeric content length")
    func rejectsBadContentLength() {
        #expect(HTTPRequestParser.parse(Self.raw("POST /mcp HTTP/1.1\r\nContent-Length: abc")) == .invalid(status: 400))
    }

    @Test("rejects a body over the limit before reading it")
    func rejectsOversizedBody() {
        let length = MCPDispatcher.maxBodyBytes + 1
        let data = Self.raw("POST /mcp HTTP/1.1\r\nContent-Length: \(length)")

        #expect(HTTPRequestParser.parse(data) == .invalid(status: 413))
    }

    @Test("rejects headers past the size limit")
    func rejectsOversizedHeaders() {
        let data = Data(repeating: UInt8(ascii: "a"), count: HTTPRequestParser.maxHeaderBytes + 1)

        #expect(HTTPRequestParser.parse(data) == .invalid(status: 431))
    }
}
