import Foundation

public enum AgentStep: Equatable, Sendable {
    case navigate(URL)
    case readPage
    case click(selector: String)
    case typeText(selector: String, text: String)
    case submitForm(selector: String)
    case sendMessage(selector: String, text: String)
    case download(URL)
    case fillCredential(selector: String)

    public var action: ActionClass {
        switch self {
        case .navigate: .navigate
        case .readPage: .read
        case .click: .click
        case .typeText: .typeText
        case .submitForm: .submitForm
        case .sendMessage: .sendMessage
        case .download: .download
        case .fillCredential: .fillCredential
        }
    }

    public var targetHost: String? {
        switch self {
        case .navigate(let url), .download(let url):
            url.host
        default:
            nil
        }
    }

    public var auditArguments: [String: String] {
        switch self {
        case .navigate(let url), .download(let url):
            ["url": Self.urlWithoutQuery(url)]
        case .readPage:
            [:]
        case .click(let selector), .submitForm(let selector), .fillCredential(let selector):
            ["selector": selector]
        case .typeText(let selector, let text), .sendMessage(let selector, let text):
            ["selector": selector, "characters": String(text.count)]
        }
    }
}

public struct AgentStepDTO: Codable, Equatable, Sendable {
    public let type: String
    public let url: String?
    public let selector: String?
    public let text: String?

    public init(type: String, url: String? = nil, selector: String? = nil, text: String? = nil) {
        self.type = type
        self.url = url
        self.selector = selector
        self.text = text
    }
}

public enum AgentStepError: Error, Equatable, Sendable {
    case unknownType(String)
    case missingField(String)
    case invalidURL(String)
    case disallowedDestination(String)
    case invalidSelector
    case textTooLong
}

public enum AgentStepLimits {
    public static let maxSelectorLength = 256
    public static let maxTextLength = 4_096
}

extension AgentStep {
    static func urlWithoutQuery(_ url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "[unparseable]"
        }
        parts.query = nil
        parts.fragment = nil
        parts.user = nil
        parts.password = nil
        return parts.string ?? "[unparseable]"
    }

    public init(dto: AgentStepDTO) throws(AgentStepError) {
        switch dto.type {
        case "navigate":
            self = .navigate(try Self.destination(dto.url))
        case "download":
            self = .download(try Self.destination(dto.url))
        case "readPage":
            self = .readPage
        case "click":
            self = .click(selector: try Self.selector(dto.selector))
        case "submitForm":
            self = .submitForm(selector: try Self.selector(dto.selector))
        case "fillCredential":
            self = .fillCredential(selector: try Self.selector(dto.selector))
        case "typeText":
            self = .typeText(selector: try Self.selector(dto.selector), text: try Self.text(dto.text))
        case "sendMessage":
            self = .sendMessage(selector: try Self.selector(dto.selector), text: try Self.text(dto.text))
        default:
            throw AgentStepError.unknownType(dto.type)
        }
    }

    private static func destination(_ raw: String?) throws(AgentStepError) -> URL {
        guard let raw else {
            throw AgentStepError.missingField("url")
        }
        guard let url = URL(string: raw) else {
            throw AgentStepError.invalidURL(raw)
        }
        guard DestinationPolicy.isAllowed(url) else {
            throw AgentStepError.disallowedDestination(raw)
        }
        return url
    }

    private static func selector(_ raw: String?) throws(AgentStepError) -> String {
        guard let raw else {
            throw AgentStepError.missingField("selector")
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= AgentStepLimits.maxSelectorLength,
              !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else {
            throw AgentStepError.invalidSelector
        }
        return trimmed
    }

    private static func text(_ raw: String?) throws(AgentStepError) -> String {
        guard let raw else {
            throw AgentStepError.missingField("text")
        }
        guard raw.count <= AgentStepLimits.maxTextLength else {
            throw AgentStepError.textTooLong
        }
        return raw
    }
}
