import Foundation
import Testing
@testable import HarborCore

@Suite("Agent step parsing")
struct AgentStepParsingTests {
    @Test("parses a navigate step to a public URL")
    func parsesNavigate() throws {
        let step = try AgentStep(dto: AgentStepDTO(type: "navigate", url: "https://example.com/a"))

        #expect(step == .navigate(URL(string: "https://example.com/a")!))
    }

    @Test("parses a readPage step with no fields")
    func parsesReadPage() throws {
        #expect(try AgentStep(dto: AgentStepDTO(type: "readPage")) == .readPage)
    }

    @Test("trims a click selector")
    func trimsSelector() throws {
        let step = try AgentStep(dto: AgentStepDTO(type: "click", selector: "  #go  "))

        #expect(step == .click(selector: "#go"))
    }

    @Test("parses a typeText step with its text")
    func parsesTypeText() throws {
        let step = try AgentStep(dto: AgentStepDTO(type: "typeText", selector: "#q", text: "hello"))

        #expect(step == .typeText(selector: "#q", text: "hello"))
    }

    @Test("rejects an unknown step type")
    func rejectsUnknownType() {
        #expect(throws: AgentStepError.unknownType("exec")) {
            try AgentStep(dto: AgentStepDTO(type: "exec"))
        }
    }

    @Test("rejects a navigate step without a URL")
    func rejectsMissingURL() {
        #expect(throws: AgentStepError.missingField("url")) {
            try AgentStep(dto: AgentStepDTO(type: "navigate"))
        }
    }

    @Test("rejects a navigate step to an internal address")
    func rejectsInternalDestination() {
        #expect(throws: AgentStepError.disallowedDestination("http://127.0.0.1/")) {
            try AgentStep(dto: AgentStepDTO(type: "navigate", url: "http://127.0.0.1/"))
        }
    }

    @Test("rejects a file URL")
    func rejectsFileURL() {
        #expect(throws: AgentStepError.disallowedDestination("file:///etc/passwd")) {
            try AgentStep(dto: AgentStepDTO(type: "download", url: "file:///etc/passwd"))
        }
    }

    @Test("rejects an empty or whitespace selector", arguments: ["", "   "])
    func rejectsEmptySelector(raw: String) {
        #expect(throws: AgentStepError.invalidSelector) {
            try AgentStep(dto: AgentStepDTO(type: "click", selector: raw))
        }
    }

    @Test("rejects a selector containing a control character")
    func rejectsControlCharacterSelector() {
        #expect(throws: AgentStepError.invalidSelector) {
            try AgentStep(dto: AgentStepDTO(type: "click", selector: "#a\u{0007}"))
        }
    }

    @Test("accepts a selector at the length limit and rejects one past it")
    func enforcesSelectorLength() throws {
        let atLimit = String(repeating: "a", count: AgentStepLimits.maxSelectorLength)
        let overLimit = atLimit + "a"

        #expect(try AgentStep(dto: AgentStepDTO(type: "click", selector: atLimit)) == .click(selector: atLimit))
        #expect(throws: AgentStepError.invalidSelector) {
            try AgentStep(dto: AgentStepDTO(type: "click", selector: overLimit))
        }
    }

    @Test("rejects text past the length limit")
    func enforcesTextLength() {
        let overLimit = String(repeating: "t", count: AgentStepLimits.maxTextLength + 1)

        #expect(throws: AgentStepError.textTooLong) {
            try AgentStep(dto: AgentStepDTO(type: "typeText", selector: "#q", text: overLimit))
        }
    }

    @Test("rejects typeText without text")
    func rejectsMissingText() {
        #expect(throws: AgentStepError.missingField("text")) {
            try AgentStep(dto: AgentStepDTO(type: "typeText", selector: "#q"))
        }
    }

    @Test("maps each step to its action class", arguments: [
        (AgentStep.readPage, ActionClass.read),
        (AgentStep.click(selector: "#a"), ActionClass.click),
        (AgentStep.typeText(selector: "#a", text: "x"), ActionClass.typeText),
        (AgentStep.submitForm(selector: "#a"), ActionClass.submitForm),
        (AgentStep.sendMessage(selector: "#a", text: "x"), ActionClass.sendMessage),
        (AgentStep.fillCredential(selector: "#a"), ActionClass.fillCredential),
    ])
    func mapsActionClass(step: AgentStep, action: ActionClass) {
        #expect(step.action == action)
    }

    @Test("audit arguments drop the query and fragment, which can carry secrets")
    func auditDropsQueryAndFragment() throws {
        let step = try AgentStep(dto: AgentStepDTO(type: "navigate", url: "https://example.com/a?token=abc#frag"))

        #expect(step.auditArguments == ["url": "https://example.com/a"])
    }

    @Test("audit arguments record the length of typed text, never the text")
    func auditRecordsOnlyLength() {
        let arguments = AgentStep.typeText(selector: "#pw", text: "hunter2").auditArguments

        #expect(arguments == ["selector": "#pw", "characters": "7"])
        #expect(arguments.values.contains("hunter2") == false)
    }
}
