import Foundation

@MainActor
public final class WebKitPageDriver: PageDriver {
    private let engine: WebKitEngine

    public init(engine: WebKitEngine) {
        self.engine = engine
    }

    public var currentHost: String? {
        engine.webView.url?.host?.lowercased()
    }

    public func perform(_ step: AgentStep) async throws -> StepOutput {
        switch step {
        case .navigate(let url):
            guard DestinationPolicy.isAllowed(url) else {
                throw PageDriverError.navigationFailed("destination is not public web")
            }
            try await engine.load(url, restrictToPublicWeb: true)
            return .none
        case .readPage:
            let text = try await engine.evaluate(
                "return document.body ? document.body.innerText : ''",
                arguments: [:]
            ) as? String ?? ""
            return .text(UntrustedText(source: "page", value: text))
        case .click(let selector), .submitForm(let selector):
            try await interact(selector: selector, text: nil)
            return .none
        case .typeText(let selector, let text), .sendMessage(let selector, let text):
            try await interact(selector: selector, text: text)
            return .none
        case .download, .fillCredential:
            throw PageDriverError.unsupported(step.action)
        }
    }

    private func interact(selector: String, text: String?) async throws {
        let outcome = try await engine.evaluate(Self.interactScript, arguments: [
            "selector": selector,
            "text": text ?? NSNull(),
        ]) as? String
        guard outcome == "ok" else {
            throw PageDriverError.elementNotFound(selector)
        }
    }

    private static let interactScript = """
        const element = document.querySelector(selector);
        if (!element) { return 'missing'; }
        if (text !== null && text !== undefined) {
            element.focus();
            element.value = text;
            element.dispatchEvent(new Event('input', { bubbles: true }));
        } else {
            element.click();
        }
        return 'ok';
        """
}
