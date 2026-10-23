import HarborCore
import SwiftUI

struct SidebarView: View {
    let model: AppModel
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SpacesRow(spaces: model.spaces)
                    filterField
                    pinnedSection
                    todaySection
                    tabGroupsSection
                    ArchiveRow(count: archivedCount)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.never)
            footer
        }
        .background(Color.white.opacity(0.55))
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Pinned", trailing: "⌘1-6", trailingIsCode: true)
            ForEach(Array(pinnedTabs.enumerated()), id: \.element.id) { index, tab in
                PinnedRow(tab: tab, shortcut: index < 6 ? "⌘\(index + 1)" : nil)
            }
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Today", trailing: "\(todayTabs.count) tabs", trailingIsCode: true)
            ForEach(todayTabs) { tab in
                TodayRow(tab: tab, isActive: tab.id == model.activeTabID)
            }
        }
    }

    private var tabGroupsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Workspaces", trailing: nil, trailingIsCode: false)
            ForEach(groupSpaces, id: \.id) { space in
                TabGroupRow(name: space.name, count: openCount(in: space))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            statusChip
            HStack {
                Button {
                    Task { await model.newTab() }
                } label: {
                    HStack(spacing: 6) {
                        MaterialIcon("add_box", size: 16)
                        Text("⌘ + T New Tab")
                            .font(HarborTypography.text(size: 13, weight: .medium))
                    }
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                Spacer()
                IconButton(symbol: "download", help: "Downloads (not built yet)")
                IconButton(symbol: "settings", help: "Settings (not built yet)")
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .overlay(alignment: .top) {
            Divider().overlay(HarborColor.outlineVariant)
        }
    }

    private var statusChip: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(HarborColor.statusAmber)
                    .frame(width: 8, height: 8)
                Text(runningStatus)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if !model.pendingApprovals.isEmpty {
                Button {
                    model.showInbox()
                } label: {
                    Text("Approval")
                        .font(HarborTypography.text(size: 10, weight: .medium))
                        .textCase(.uppercase)
                        .foregroundStyle(HarborColor.statusAmber)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(HarborColor.amberBadgeFill, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.amberBadgeBorder))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(HarborColor.surface, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
    }

    private var filterField: some View {
        HStack(spacing: 6) {
            MaterialIcon("search", size: 12)
                .foregroundStyle(HarborColor.outline)
            TextField("Filter tabs & pages...", text: $query)
                .textFieldStyle(.plain)
                .font(HarborTypography.text(size: 12))
                .foregroundStyle(HarborColor.onSurface)
                .accessibilityIdentifier("sidebar-filter")
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
    }

    private var pinnedTabs: [BrowserTab] {
        openTabs.filter { $0.isPinned && matchesQuery($0) }
    }

    private var todayTabs: [SidebarTab] {
        openTabs
            .filter { !$0.isPinned && $0.spaceID == model.spaces.first?.id && matchesQuery($0) }
            .map { SidebarTab(tab: $0) }
    }

    private var openTabs: [BrowserTab] {
        model.tabs.filter { $0.state != .archived }
    }

    private func matchesQuery(_ tab: BrowserTab) -> Bool {
        query.isEmpty || tab.title.localizedCaseInsensitiveContains(query)
    }

    private var groupSpaces: [Space] {
        model.spaces.dropFirst().filter { openCount(in: $0) > 0 }
    }

    private func openCount(in space: Space) -> Int {
        model.tabs.filter { $0.spaceID == space.id && $0.state != .archived }.count
    }

    private var runningStatus: String {
        let running = model.tasks.filter { $0.state == .running }.count
        return "\(running) running · \(model.pendingApprovals.count) awaiting"
    }

    private var archivedCount: Int {
        model.tabs.filter { $0.state == .archived }.count
    }
}

private struct SpacesRow: View {
    let spaces: [Space]

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                        SpaceButton(name: space.name, isSelected: index == 0)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            MaterialIcon("add", size: 13)
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 24, height: 24)
        }
        .padding(4)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Divider().overlay(HarborColor.outlineVariant)
        }
    }
}

private struct SpaceButton: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isSelected ? HarborColor.primaryContainer : HarborColor.outline)
                .frame(width: 8, height: 8)
            Text(name)
                .font(HarborTypography.text(size: 13, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? HarborColor.onSurface : HarborColor.onSurfaceVariant)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.white.opacity(0.95) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? HarborColor.outlineVariant : .clear))
    }
}

private struct SectionHeader: View {
    let title: String
    let trailing: String?
    let trailingIsCode: Bool

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(HarborTypography.text(size: 11, weight: .medium))
                .tracking(0.55)
                .foregroundStyle(HarborColor.outline)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(trailingIsCode ? HarborColor.onSurfaceVariant : HarborColor.outline)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

private struct PinnedRow: View {
    let tab: BrowserTab
    let shortcut: String?

    var body: some View {
        HStack(spacing: 8) {
            MaterialIcon(SidebarTab.symbol(for: tab.title))
                .font(.system(size: 13))
                .foregroundStyle(HarborColor.outline)
                .frame(width: 15)
            Text(tab.title)
                .font(HarborTypography.text(size: 13))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let shortcut {
                Text(shortcut)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.outline)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

private struct TodayRow: View {
    let tab: SidebarTab
    let isActive: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if isActive {
                Circle()
                    .fill(HarborColor.primaryContainer)
                    .frame(width: 6, height: 6)
                    .frame(width: 15)
            } else {
                MaterialIcon(tab.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(HarborColor.outline)
                    .frame(width: 15)
            }
            Text(tab.title)
                .font(HarborTypography.text(size: 13, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? HarborColor.onSurface : HarborColor.onSurfaceVariant)
                .lineLimit(1)
            Spacer(minLength: 4)
            MaterialIcon("close", size: 10)
                .foregroundStyle(HarborColor.outline)
                .opacity(isActive || isHovered ? 1 : 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(isActive ? HarborColor.surfaceLowest : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle()
                    .fill(HarborColor.primary)
                    .frame(width: 2)
            }
        }
        .onHover { isHovered = $0 }
    }
}

private struct TabGroupRow: View {
    let name: String
    let count: Int

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                MaterialIcon("chevron_right", size: 10)
                    .foregroundStyle(HarborColor.outline)
                MaterialIcon("folder", size: 13)
                    .foregroundStyle(HarborColor.outline)
                Text(name)
                    .font(HarborTypography.text(size: 13))
                    .lineLimit(1)
            }
            .foregroundStyle(HarborColor.onSurfaceVariant)
            Spacer()
            Text("\(count)")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.outline)
                .padding(.horizontal, 4)
                .background(HarborColor.surfaceContainer, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

private struct ArchiveRow: View {
    let count: Int

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                MaterialIcon("chevron_right", size: 10)
                    .foregroundStyle(HarborColor.outline)
                MaterialIcon("inventory_2", size: 13)
                    .foregroundStyle(HarborColor.outline)
                Text("Archive")
                    .font(HarborTypography.text(size: 13))
            }
            .foregroundStyle(HarborColor.onSurfaceVariant)
            Spacer()
            Text("\(count)")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.outline)
                .padding(.horizontal, 6)
                .background(HarborColor.surfaceContainer, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

private struct IconButton: View {
    let symbol: String
    let help: String

    var body: some View {
        MaterialIcon(symbol)
            .font(.system(size: 17))
            .foregroundStyle(HarborColor.onSurfaceVariant)
            .frame(width: 28, height: 28)
            .help(help)
    }
}

struct SidebarTab: Identifiable {
    let id: UUID
    let title: String
    let symbol: String

    static func symbol(for title: String) -> String {
        let known: [(String, String)] = [
            ("ArXiv", "folder"),
            ("Kernel", "menu_book"),
            ("Figma", "code"),
            ("Linear", "memory"),
            ("Postgres", "archive"),
            ("Stripe", "bookmark"),
            ("Distributed", "hub"),
            ("Typography", "text_fields"),
        ]
        return known.first { title.contains($0.0) }?.1 ?? "tab"
    }

    init(tab: BrowserTab) {
        id = tab.id
        title = tab.title
        symbol = Self.symbol(for: tab.title)
    }
}
