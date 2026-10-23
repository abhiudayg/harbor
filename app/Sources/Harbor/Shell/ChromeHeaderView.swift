import SwiftUI

struct ChromeHeaderView: View {
    static let height: CGFloat = 44
    static let omnibarMaxWidth: CGFloat = 672

    let toggleSidebar: () -> Void
    let openCommandBar: () -> Void
    let toggleAssistant: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            navigationCluster
                .fixedSize()
            omnibar
                .frame(maxWidth: Self.omnibarMaxWidth)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            trailingCluster
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
        .glassPanel()
    }

    private var navigationCluster: some View {
        HStack(spacing: 4) {
            TrafficLights()
                .padding(.trailing, 12)
            ChromeIconButton(symbol: "arrow_back", help: "Back (⌘[)", action: nil)
            ChromeIconButton(symbol: "arrow_forward", help: "Forward (⌘])", action: nil)
            ChromeIconButton(symbol: "refresh", help: "Reload (⌘R)", action: nil)
            HStack(spacing: 6) {
                MaterialIcon("anchor", size: 18)
                    .foregroundStyle(HarborColor.primary)
                Text("Harbor")
                    .font(HarborTypography.headline(size: 15, weight: .semibold))
                    .tracking(-0.075)
                    .foregroundStyle(HarborColor.onSurface)
                Text("Zen")
                    .font(HarborTypography.text(size: 10, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(HarborColor.primary.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HarborColor.primary.opacity(0.05), in: Capsule())
                    .overlay(Capsule().stroke(HarborColor.primary.opacity(0.1)))
            }
            .padding(.leading, 8)
        }
    }

    private var omnibar: some View {
        HStack(spacing: 8) {
            MaterialIcon("lock", size: 12)
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Text("harbor://reading/the-architecture-of-quiet-interfaces")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.onSurface)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("⌘K")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.outline)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(HarborColor.surfaceContainer, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
            Button(action: toggleAssistant) {
                HStack(spacing: 4) {
                    MaterialIcon("auto_awesome", size: 12)
                        .foregroundStyle(HarborColor.primary)
                    Text("Ask")
                        .font(HarborTypography.text(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(HarborColor.primary, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Ask Harbor")
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(HarborColor.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
        .contentShape(Rectangle())
        .onTapGesture(perform: openCommandBar)
        .accessibilityIdentifier("omnibar")
    }

    private var trailingCluster: some View {
        HStack(spacing: 4) {
            ChromeIconButton(symbol: "menu_book", help: "Reader Mode", tint: HarborColor.primary, highlighted: true, action: nil)
            ChromeIconButton(symbol: "view_sidebar", help: "Toggle Sidebar (⌘S)", action: toggleSidebar)
            ChromeIconButton(symbol: "download", help: "Downloads (not built yet)", action: nil)
            ChromeIconButton(symbol: "auto_awesome", help: "AI Companion", action: toggleAssistant)
            ChromeIconButton(symbol: "tune", help: "Settings (not built yet)", action: nil)
            Rectangle()
                .fill(HarborColor.outlineVariant)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)
            Text("EV")
                .font(HarborTypography.text(size: 11, weight: .semibold))
                .foregroundStyle(HarborColor.onPrimaryContainer)
                .frame(width: 24, height: 24)
                .background(HarborColor.primaryContainer, in: Circle())
        }
    }
}

private struct ChromeIconButton: View {
    let symbol: String
    let help: String
    var tint: Color = HarborColor.onSurfaceVariant
    var highlighted = false
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            MaterialIcon(symbol)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(highlighted ? HarborColor.surfaceContainerHigh : .clear, in: RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
