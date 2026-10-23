import SwiftUI

struct ChromeHeaderView: View {
    static let height: CGFloat = 48
    static let trafficLightInset: CGFloat = 78
    static let omnibarMaxWidth: CGFloat = 560
    static let compactBelowWidth: CGFloat = 1200

    let windowWidth: CGFloat
    let sidebarVisible: Bool
    let toggleSidebar: () -> Void
    let openCommandBar: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            navigationCluster
                .padding(.leading, Self.trafficLightInset)
            Spacer(minLength: 8)
            omnibar
                .frame(maxWidth: Self.omnibarMaxWidth)
            Spacer(minLength: 8)
            trailingCluster
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
        .background(HarborColor.surfaceLow)
    }

    private var isCompact: Bool { windowWidth < Self.compactBelowWidth }

    private var navigationCluster: some View {
        HStack(spacing: 2) {
            ChromeIconButton(symbol: "chevron.backward", help: "Back (⌘[)")
            ChromeIconButton(symbol: "chevron.forward", help: "Forward (⌘])", muted: true)
            ChromeIconButton(symbol: "arrow.clockwise", help: "Reload (⌘R)")
            ChromeIconButton(
                symbol: "sidebar.left",
                help: "Toggle Sidebar (⌘S)",
                highlighted: sidebarVisible,
                action: toggleSidebar
            )
        }
    }

    private var omnibar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(HarborColor.primary)
            Text(addressText)
                .font(HarborTypography.mono(size: 12))
                .foregroundStyle(HarborColor.onSurface)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            assistantTrigger
            Text("⌘K")
                .font(HarborTypography.mono(size: 10))
                .foregroundStyle(HarborColor.textSecondary)
                .padding(.horizontal, 6)
                .frame(height: 18)
                .background(HarborColor.paper, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.hairline))
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.hairline))
        .contentShape(Rectangle())
        .onTapGesture(perform: openCommandBar)
        .accessibilityIdentifier("omnibar")
    }

    private var addressText: AttributedString {
        var prefix = AttributedString("harbor://")
        prefix.foregroundColor = HarborColor.onSurfaceVariant.opacity(0.6)
        var page = AttributedString("reading")
        page.foregroundColor = HarborColor.accentTeal
        var path = AttributedString("/the-architecture-of-open-systems")
        path.foregroundColor = HarborColor.onSurface
        return prefix + page + path
    }

    private var assistantTrigger: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
            Text("Assistant")
                .font(HarborTypography.chrome(size: 11, weight: .medium))
        }
        .foregroundStyle(HarborColor.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(HarborColor.surfaceLow, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.outlineVariant.opacity(0.3)))
    }

    private var trailingCluster: some View {
        HStack(spacing: 6) {
            splitViewControl
            ChromeIconButton(symbol: "square.grid.2x2", help: "Tab Overview (⌘⇧A)")
            ChromeIconButton(symbol: "book", help: "Reader Mode (⌘⇧R)", highlighted: true)
            profilePill
        }
        .foregroundStyle(HarborColor.onSurfaceVariant)
    }

    private var splitViewControl: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 13))
            if !isCompact {
                Text("65 / 35")
                    .font(HarborTypography.chrome(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(HarborColor.primary)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(HarborColor.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.primary.opacity(0.20)))
        .help("Split Pane View")
    }

    private var profilePill: some View {
        Text("EV")
            .font(HarborTypography.mono(size: 9, weight: .semibold))
            .foregroundStyle(HarborColor.onPrimaryContainer)
            .frame(width: 20, height: 20)
            .background(HarborColor.primaryContainer, in: Circle())
            .padding(.horizontal, 4)
    }
}

private struct ChromeIconButton: View {
    let symbol: String
    let help: String
    var muted = false
    var highlighted = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .foregroundStyle(foreground)
                .background(highlighted ? HarborColor.surfaceContainerHigh : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var foreground: Color {
        if highlighted { return HarborColor.primary }
        return muted ? HarborColor.onSurfaceVariant.opacity(0.4) : HarborColor.onSurfaceVariant
    }
}
