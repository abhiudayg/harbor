import HarborCore

extension AgentStep {
    var displayName: String {
        switch self {
        case .navigate(let url): "Open \(url.host ?? url.absoluteString)"
        case .readPage: "Read page"
        case .click: "Click element"
        case .typeText: "Type into field"
        case .submitForm: "Submit form"
        case .sendMessage: "Send message"
        case .download: "Download file"
        case .fillCredential: "Fill credential"
        }
    }
}
