import AppKit
import HarborCore
import SwiftUI
import Testing
@testable import Harbor

@Suite("Screen rendering")
@MainActor
struct ScreenRenderingTests {
    static func render<Content: View>(_ view: Content, width: CGFloat, height: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = 1
        return renderer.nsImage
    }

    @Test("the main window renders at the Stitch canvas size of 1440 by 900")
    func mainWindowAtCanvas() async {
        let model = AppModel()
        await model.start()

        let image = Self.render(ShellView(model: model), width: 1440, height: 900)

        #expect(image?.size == CGSize(width: 1440, height: 900))
    }

    @Test("the main window still renders when the window is narrow")
    func mainWindowNarrow() async {
        let model = AppModel()
        await model.start()

        #expect(Self.render(ShellView(model: model), width: 900, height: 700)?.size == CGSize(width: 900, height: 700))
    }

    @Test("the command bar renders over the window")
    func commandBarRenders() async {
        let model = AppModel()
        await model.start()
        model.isCommandBarPresented = true

        #expect(Self.render(ShellView(model: model), width: 1440, height: 900) != nil)
    }

    @Test("the triage view renders at the Stitch canvas size")
    func triageRenders() async {
        let model = AppModel()
        await model.start()
        model.isTriagePresented = true

        #expect(Self.render(ShellView(model: model), width: 1440, height: 900) != nil)
    }

    @Test("the task inbox renders its empty state")
    func inboxRendersEmpty() {
        #expect(Self.render(TaskInboxView(model: AppModel()), width: 900, height: 560) != nil)
    }
}
