import AppKit
import SwiftUI

struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 8) {
            light(color: Color(hex: 0xFF5F56), border: Color(hex: 0xE0443E), help: "Close") {
                NSApp.keyWindow?.performClose(nil)
            }
            light(color: Color(hex: 0xFFBD2E), border: Color(hex: 0xDEA123), help: "Minimize") {
                NSApp.keyWindow?.miniaturize(nil)
            }
            light(color: Color(hex: 0x27C93F), border: Color(hex: 0x1AAB29), help: "Zoom") {
                NSApp.keyWindow?.zoom(nil)
            }
        }
    }

    private func light(color: Color, border: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .overlay(Circle().stroke(border))
                .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(nsView.window)
    }

    private func configure(_ window: NSWindow?) {
        guard let window else {
            return
        }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
