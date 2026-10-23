import Foundation
import Network

public struct HTTPRequest: Equatable, Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data
}

public enum HTTPParseResult: Equatable, Sendable {
    case incomplete
    case complete(HTTPRequest)
    case invalid(status: Int)
}

public enum HTTPRequestParser {
    public static let maxHeaderBytes = 8 * 1024

    public static func parse(_ data: Data, maxBodyBytes: Int = MCPDispatcher.maxBodyBytes) -> HTTPParseResult {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator) else {
            return data.count > maxHeaderBytes ? .invalid(status: 431) : .incomplete
        }
        guard let head = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            return .invalid(status: 400)
        }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count == 3 else {
            return .invalid(status: 400)
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else {
                return .invalid(status: 400)
            }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        let length = Int(headers["content-length"] ?? "0") ?? -1
        guard length >= 0 else {
            return .invalid(status: 400)
        }
        guard length <= maxBodyBytes else {
            return .invalid(status: 413)
        }
        let bodyStart = headerRange.upperBound
        guard data.count - bodyStart >= length else {
            return .incomplete
        }
        let body = data[bodyStart..<(bodyStart + length)]
        return .complete(HTTPRequest(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: Data(body)
        ))
    }
}

public final class MCPHTTPServer: @unchecked Sendable {
    public static let endpointPath = "/mcp"

    private let dispatcher: MCPDispatcher
    private let listener: NWListener
    private let queue = DispatchQueue(label: "harbor.mcp.http")

    public init(dispatcher: MCPDispatcher) throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        self.dispatcher = dispatcher
        self.listener = try NWListener(using: parameters)
    }

    public func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    if let port = listener.port?.rawValue {
                        continuation.resume(returning: port)
                    } else {
                        continuation.resume(throwing: MCPServerError.noPort)
                    }
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
        }
    }

    public func stop() {
        listener.cancel()
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            let combined = buffer + (data ?? Data())
            switch HTTPRequestParser.parse(combined) {
            case .complete(let request):
                Task {
                    let response = await self.respond(to: request)
                    Self.send(response, on: connection)
                }
            case .invalid(let status):
                Self.send(MCPResponse(status: status), on: connection)
            case .incomplete:
                if isComplete || error != nil {
                    connection.cancel()
                } else {
                    self.receive(connection, buffer: combined)
                }
            }
        }
    }

    private func respond(to request: HTTPRequest) async -> MCPResponse {
        guard request.path == Self.endpointPath else {
            return MCPResponse(status: 404)
        }
        guard request.method == "POST" else {
            return MCPResponse(status: 405)
        }
        return await dispatcher.handle(
            hostHeader: request.headers["host"],
            authorization: request.headers["authorization"],
            body: request.body
        )
    }

    private static func send(_ response: MCPResponse, on connection: NWConnection) {
        let head = "HTTP/1.1 \(response.status) \(reasonPhrase(response.status))\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(response.body.count)\r\n"
            + "Connection: close\r\n\r\n"
        var payload = Data(head.utf8)
        payload.append(response.body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func reasonPhrase(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 202: "Accepted"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 413: "Payload Too Large"
        case 431: "Request Header Fields Too Large"
        default: "Error"
        }
    }
}

public enum MCPServerError: Error, Equatable, Sendable {
    case noPort
}
