import SwiftUI

struct CommandBarView: View {
    @Bindable var model: AppModel
    @State private var query = ""
    @State private var selection: Int?
    @State private var hovered: Int?
    @FocusState private var isFieldFocused: Bool

    private var results: CommandBarResults {
        CommandBarResults.make(query: query, tabs: model.tabs, spaceNames: model.spaceNames)
    }

    private var tabRows: [Row] {
        let pinnedIDs = model.tabs.filter(\.isPinned).map(\.id)
        return results.tabs
            .sorted { lhs, rhs in
                (lhs.id == model.activeTabID ? 0 : 1) < (rhs.id == model.activeTabID ? 0 : 1)
            }
            .map { hit in
                let isActive = hit.id == model.activeTabID
                let shortcut = pinnedIDs.firstIndex(of: hit.id).flatMap { $0 < 6 ? "⌘\($0 + 1)" : nil }
                return .tab(hit, isActive: isActive, shortcut: shortcut)
            }
    }

    private var actionRows: [Row] {
        results.actions.map { action in
            .action(action, shortcut: Self.shortcut(for: action.id))
        }
    }

    private var rows: [Row] {
        tabRows + actionRows
    }

    private var completionTitle: String? {
        guard !query.isEmpty else {
            return nil
        }
        return tabRows.lazy.compactMap { row -> String? in
            if case .tab(let hit, _, _) = row {
                return hit.title
            }
            return nil
        }
        .first { $0.lowercased().hasPrefix(query.lowercased()) && $0.count > query.count }
    }

    private var completionSuffix: String? {
        completionTitle.map { String($0.dropFirst(query.count)) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .onTapGesture { model.isCommandBarPresented = false }
            palette
                .frame(width: 600)
                .padding(.top, 120)
        }
        .background(cancelButton)
        .onAppear {
            DispatchQueue.main.async {
                isFieldFocused = true
            }
        }
        .onChange(of: query) { selection = nil }
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
            searchField
            Divider().overlay(HarborColor.outlineVariant)
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !tabRows.isEmpty {
                        section("Tabs") {
                            ForEach(Array(tabRows.enumerated()), id: \.offset) { index, row in
                                rowView(row, index: index)
                            }
                        }
                    }
                    if !actionRows.isEmpty {
                        section("Actions") {
                            ForEach(Array(actionRows.enumerated()), id: \.offset) { offset, row in
                                rowView(row, index: tabRows.count + offset)
                            }
                        }
                    }
                    if rows.isEmpty {
                        Text("No matches")
                            .font(HarborTypography.text(size: 13))
                            .foregroundStyle(HarborColor.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 420)
            .onChange(of: selection) { _, new in
                if let new {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }
            }
            Divider().overlay(HarborColor.outlineVariant)
            footer
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HarborColor.outlineVariant))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            MaterialIcon("search", size: 16)
                .foregroundStyle(HarborColor.onSurfaceVariant)
            ZStack(alignment: .leading) {
                if let completion = completionSuffix {
                    HStack(spacing: 0) {
                        Text(query).opacity(0)
                        Text(completion).foregroundStyle(HarborColor.outline)
                    }
                    .font(HarborTypography.text(size: 16))
                    .allowsHitTesting(false)
                }
                TextField("Search, navigate, or ask", text: $query)
                    .textFieldStyle(.plain)
                    .font(HarborTypography.text(size: 16))
                    .foregroundStyle(HarborColor.onSurface)
                    .focused($isFieldFocused)
                    .onSubmit(runSelected)
                    .onKeyPress(.tab) {
                        if let title = completionTitle {
                            query = title
                        }
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        move(by: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        move(by: -1)
                        return .handled
                    }
                    .accessibilityIdentifier("command-bar-field")
            }
            keyBadge("esc")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            footerHint(icon: "swap_vert", label: "Navigate")
            footerHint(icon: "keyboard_return", label: "Select")
            footerHint(icon: nil, label: "Close", key: "esc")
            Spacer()
            Text("Harbor")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.outline)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(HarborColor.surfaceLow)
    }

    private func footerHint(icon: String?, label: String, key: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon {
                keyBadge(icon: icon)
            }
            if let key {
                keyBadge(key)
            }
            Text(label)
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(HarborTypography.text(size: 10, weight: .medium))
                .tracking(0.55)
                .foregroundStyle(HarborColor.outline)
                .padding(.horizontal, 16)
            content()
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row, index: Int) -> some View {
        let isHighlighted = selection == index || hovered == index
        switch row {
        case .tab(let hit, let isActive, let shortcut):
            resultRow(
                symbol: "tab",
                title: hit.title,
                detail: detail(for: hit, isActive: isActive),
                trailing: isHighlighted ? "Jump" : shortcut,
                isHighlighted: isHighlighted,
                index: index
            ) {
                model.activateTab(hit.id)
            }
        case .action(let action, let shortcut):
            resultRow(
                symbol: Self.symbol(for: action.id),
                title: action.title,
                detail: action.detail,
                trailing: shortcut,
                isHighlighted: isHighlighted,
                index: index
            ) {
                run(action.id)
            }
        }
    }

    private func resultRow(
        symbol: String,
        title: String,
        detail: String,
        trailing: String?,
        isHighlighted: Bool,
        index: Int,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack(spacing: 12) {
                MaterialIcon(symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(isHighlighted ? HarborColor.tertiaryGreen : HarborColor.onSurfaceVariant)
                    .frame(width: 28, height: 28)
                    .background(HarborColor.surfaceLow, in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HarborTypography.text(size: 14, weight: .medium))
                        .foregroundStyle(isHighlighted ? HarborColor.tertiaryGreen : HarborColor.onSurface)
                        .lineLimit(1)
                    Text(detail)
                        .font(HarborTypography.text(size: 12))
                        .foregroundStyle(HarborColor.outline)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let trailing {
                    keyBadge(trailing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isHighlighted ? HarborColor.tertiaryGreen.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighlighted ? HarborColor.tertiaryGreen.opacity(0.35) : .clear)
            )
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hovered = index
            } else if hovered == index {
                hovered = nil
            }
        }
        .id(index)
    }

    private func detail(for hit: CommandBarResults.TabHit, isActive: Bool) -> String {
        isActive ? "Active Tab · \(hit.detail)" : hit.detail
    }

    private func keyBadge(_ key: String) -> some View {
        Text(key)
            .font(HarborTypography.text(size: 11))
            .foregroundStyle(HarborColor.outline)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
    }

    private func keyBadge(icon: String) -> some View {
        MaterialIcon(icon)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(HarborColor.outline)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
    }

    private func move(by step: Int) {
        guard !rows.isEmpty else {
            return
        }
        guard let current = selection else {
            selection = step > 0 ? 0 : rows.count - 1
            return
        }
        selection = (current + step + rows.count) % rows.count
    }

    private func runSelected() {
        let index = selection ?? 0
        guard rows.indices.contains(index) else {
            return
        }
        switch rows[index] {
        case .tab(let hit, _, _):
            model.activateTab(hit.id)
        case .action(let action, _):
            run(action.id)
        }
    }

    private static func shortcut(for action: String) -> String? {
        switch action {
        case "triage": "⇧⌘A"
        case "inbox": "⇧⌘I"
        default: nil
        }
    }

    private static func symbol(for action: String) -> String {
        switch action {
        case "triage": "layers"
        case "clients": "key"
        case "diagnostics": "dashboard"
        default: "inbox"
        }
    }

    private func run(_ action: String) {
        model.isCommandBarPresented = false
        switch action {
        case "triage": model.showTriage()
        case "clients": model.isClientsPresented = true
        case "diagnostics": model.isDiagnosticsPresented = true
        default: model.showInbox()
        }
    }

    private enum Row {
        case tab(CommandBarResults.TabHit, isActive: Bool, shortcut: String?)
        case action(CommandBarResults.Action, shortcut: String?)
    }
}
