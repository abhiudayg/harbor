import HarborCore
import SwiftUI

struct SidebarView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SpacesList(spaces: model.spaces)
                    SidebarSectionHeader(title: "Pinned", count: String(pinnedTabs.count), hint: "⌘1–6")
                    VStack(spacing: 2) {
                        ForEach(pinnedTabs) { tab in
                            SidebarTabRow(tab: tab)
                        }
                    }
                    SidebarSectionHeader(title: "Today (\(todayTabs.count))", trailingSymbol: "icloud.and.arrow.up")
                    VStack(spacing: 2) {
                        ForEach(todayTabs) { tab in
                            SidebarTabRow(tab: tab)
                        }
                    }
                    SidebarSectionHeader(title: "Collections")
                    CollectionFolderRow(title: "Typographic Systems", count: 2, children: ["Klim Type Foundry", "Grilli Type Specimen"])
                    CollectionFolderRow(title: "Systems Architecture", count: 4, children: [])
                    ArchiveRow(count: archivedCount)
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
            ApprovalDock(request: model.pendingApprovals.first) { request, scope in
                await model.approve(request, scope: scope)
            } onDeny: { request in
                await model.deny(request)
            }
        }
    }

    private var pinnedTabs: [SidebarTab] {
        model.tabs
            .filter { $0.isPinned && $0.state != .archived }
            .map(SidebarTab.init(tab:))
    }

    private var todayTabs: [SidebarTab] {
        model.tabs
            .filter { !$0.isPinned && $0.state != .archived }
            .map(SidebarTab.init(tab:))
    }

    private var archivedCount: Int {
        model.tabs.filter { $0.state == .archived }.count
    }
}

private struct SpacesList: View {
    let spaces: [Space]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("SPACES")
                    .font(HarborTypography.mono(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.7))
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            .padding(.horizontal, 8)
            ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                HStack(spacing: 8) {
                    Circle()
                        .fill(index == 0 ? HarborColor.accentTeal : HarborColor.outlineVariant)
                        .frame(width: 8, height: 8)
                    Text(space.name)
                        .font(HarborTypography.chrome(size: 12, weight: index == 0 ? .semibold : .regular))
                        .foregroundStyle(index == 0 ? HarborColor.primary : HarborColor.onSurfaceVariant)
                    Spacer()
                    Text("⌘\(index + 1)")
                        .font(HarborTypography.mono(size: 9))
                        .foregroundStyle(HarborColor.outline)
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
            }
        }
    }
}

private struct SpaceSwitcherCard: View {
    let spaceName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(HarborColor.accentTeal)
                        .frame(width: 8, height: 8)
                    Text(spaceName)
                        .font(HarborTypography.chrome(size: 13, weight: .semibold))
                        .foregroundStyle(HarborColor.onSurface)
                }
                Spacer()
                Text("⌘1")
                    .font(HarborTypography.mono(size: 10))
                    .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.7))
            }
            HStack(spacing: 6) {
                SpaceChip(title: spaceName, selected: true)
                Image(systemName: "archivebox")
                    .font(.system(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
        }
        .padding(8)
        .background(HarborColor.surfaceLowest.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.outlineVariant.opacity(0.4)))
    }
}

private struct SpaceChip: View {
    let title: String
    let selected: Bool

    var body: some View {
        Text(title)
            .font(HarborTypography.chrome(size: 10, weight: .medium))
            .foregroundStyle(selected ? Color.white : HarborColor.onSurfaceVariant)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(selected ? HarborColor.accentTeal : .clear, in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct SidebarSectionHeader: View {
    let title: String
    var count: String?
    var trailingSymbol: String?
    var hint: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.7))
            if let hint {
                Text(hint)
                    .font(HarborTypography.mono(size: 9))
                    .foregroundStyle(HarborColor.outline)
            }
            Spacer()
            if let count {
                Text(count)
                    .font(HarborTypography.mono(size: 10))
                    .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.5))
            }
            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct SidebarTabRow: View {
    let tab: SidebarTab

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tab.symbol)
                .font(.system(size: 12))
                .foregroundStyle(tab.tint)
                .frame(width: 16)
            Text(tab.title)
                .font(HarborTypography.chrome(size: 12, weight: tab.isActive ? .semibold : .regular))
                .foregroundStyle(tab.isActive ? HarborColor.primary : HarborColor.onSurfaceVariant)
                .lineLimit(1)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(
            tab.isActive ? HarborColor.surfaceLowest : .clear,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(tab.isActive ? HarborColor.outlineVariant.opacity(0.4) : .clear)
        )
    }
}

private struct CollectionFolderRow: View {
    let title: String
    let count: Int
    let children: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: children.isEmpty ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10))
                Text(title)
                    .font(HarborTypography.chrome(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(String(count))
                    .font(HarborTypography.mono(size: 9))
                    .foregroundStyle(HarborColor.outline)
            }
            .foregroundStyle(HarborColor.onSurface)
            .padding(.horizontal, 8)
            .frame(height: 28)
            ForEach(children, id: \.self) { child in
                Text(child)
                    .font(HarborTypography.chrome(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                    .padding(.leading, 26)
                    .frame(height: 24, alignment: .leading)
            }
        }
    }
}

private struct ArchiveRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.system(size: 12))
            Text("Archive")
                .font(HarborTypography.chrome(size: 12))
            Spacer()
            Text(String(count))
                .font(HarborTypography.mono(size: 10))
                .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.8))
            Text("⌘E")
                .font(HarborTypography.mono(size: 9))
                .foregroundStyle(HarborColor.outline)
        }
        .foregroundStyle(HarborColor.onSurfaceVariant)
        .padding(.horizontal, 8)
        .frame(height: 32)
    }
}

private struct ApprovalDock: View {
    let request: ApprovalRequest?
    let onApprove: (ApprovalRequest, ApprovalScope) async -> Void
    let onDeny: (ApprovalRequest) async -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let request {
                approvalCard(request)
            }
            HStack {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14))
                Spacer()
                Text("⌘T New Tab")
                    .font(HarborTypography.chrome(size: 11, weight: .medium))
            }
            .foregroundStyle(HarborColor.onSurfaceVariant)
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(HarborColor.surfaceLow)
        .overlay(alignment: .top) {
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
        }
    }

    private func approvalCard(_ request: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(HarborColor.approvalDot)
                        .frame(width: 8, height: 8)
                    Text("Awaiting Approval")
                        .font(HarborTypography.chrome(size: 11, weight: .semibold))
                        .foregroundStyle(HarborColor.approvalText)
                }
                Spacer()
            }
            Text("\(request.action.rawValue) on \(request.site)")
                .font(HarborTypography.chrome(size: 11, weight: .medium))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .lineLimit(1)
            HStack(spacing: 6) {
                Button {
                    Task { await onApprove(request, .once) }
                } label: {
                    Text("Approve once")
                        .font(HarborTypography.chrome(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(HarborColor.approvalAction, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                Button {
                    Task { await onDeny(request) }
                } label: {
                    Text("Deny")
                        .font(HarborTypography.chrome(size: 10, weight: .medium))
                        .foregroundStyle(HarborColor.approvalText)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.approvalBorder))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.approvalBorder))
    }
}

struct SidebarTab: Identifiable {
    let id: UUID
    let title: String
    let symbol: String
    let tint: Color
    let isActive: Bool

    static func symbol(for title: String) -> String {
        let known: [(String, String)] = [
            ("Figma", "pencil.and.outline"),
            ("Linear", "checkmark.circle"),
            ("GitHub", "chevron.left.forwardslash.chevron.right"),
            ("Notion", "doc.text"),
            ("Readwise", "books.vertical"),
            ("Claude", "brain"),
            ("Paxos", "doc.plaintext"),
            ("HN", "bubble.left.and.bubble.right"),
            ("PostgreSQL", "cylinder"),
        ]
        return known.first { title.contains($0.0) }?.1 ?? "globe"
    }

    init(tab: BrowserTab) {
        id = tab.id
        title = tab.title
        symbol = Self.symbol(for: tab.title)
        tint = HarborColor.outline
        isActive = false
    }
}
