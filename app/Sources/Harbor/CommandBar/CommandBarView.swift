import SwiftUI

struct CommandBarView: View {
    @Bindable var model: AppModel
    @State private var query = ""

    private var results: CommandBarResults {
        CommandBarResults.make(query: query, tabs: model.tabs, spaceNames: model.spaceNames)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { model.isCommandBarPresented = false }
            palette
                .frame(width: 620)
                .padding(.top, 120)
        }
        .background(cancelButton)
    }

    private var cancelButton: some View {
        Button("Close") { model.isCommandBarPresented = false }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                TextField("Search, navigate, or ask", text: $query)
                    .textFieldStyle(.plain)
                    .font(HarborTypography.chrome(size: 15))
                    .foregroundStyle(HarborColor.onSurface)
                    .accessibilityIdentifier("command-bar-field")
                Text("esc")
                    .font(HarborTypography.mono(size: 10))
                    .foregroundStyle(HarborColor.textSecondary)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(HarborColor.paper, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.hairline))
            }
            .padding(14)
            Divider().overlay(HarborColor.outlineVariant.opacity(0.4))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !results.tabs.isEmpty {
                        group("Tabs") {
                            ForEach(results.tabs) { hit in
                                row(icon: "globe", title: hit.title, detail: hit.detail)
                            }
                        }
                    }
                    if !results.actions.isEmpty {
                        group("Actions") {
                            ForEach(results.actions) { action in
                                Button {
                                    run(action.id)
                                } label: {
                                    row(icon: icon(for: action.id), title: action.title, detail: action.detail)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if results.tabs.isEmpty && results.actions.isEmpty {
                        Text("No matches")
                            .font(HarborTypography.chrome(size: 13))
                            .foregroundStyle(HarborColor.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 420)
        }
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HarborColor.outlineVariant.opacity(0.5)))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.7))
                .padding(.horizontal, 8)
            content()
        }
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(HarborColor.accentTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HarborTypography.chrome(size: 13, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Text(detail)
                    .font(HarborTypography.chrome(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func icon(for action: String) -> String {
        switch action {
        case "triage": "square.stack.3d.up"
        case "clients": "person.badge.key"
        default: "tray.full"
        }
    }

    private func run(_ action: String) {
        model.isCommandBarPresented = false
        switch action {
        case "triage": model.isTriagePresented = true
        case "clients": model.isClientsPresented = true
        default: model.isInboxPresented = true
        }
    }
}
