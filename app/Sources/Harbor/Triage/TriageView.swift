import HarborCore
import SwiftUI

struct TriageView: View {
    let model: AppModel
    @State private var filter: TriageFilter = .all
    @State private var selection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    columnHeader
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredTabs) { tab in
                                TriageRow(
                                    tab: tab,
                                    model: model,
                                    status: status(for: tab),
                                    isSelected: tab.id == selected?.id
                                ) {
                                    selection = tab.id
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    footer
                }
                Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
                inspector
                    .frame(width: 300)
            }
        }
        .background(HarborColor.paper)
    }

    private var summary: TriageSummary {
        TriageSummary.make(tabs: model.tabs, now: Date())
    }

    private var openTabs: [BrowserTab] {
        model.tabs.filter { $0.state != .archived }
    }

    private var duplicateURLs: Set<String> {
        let counts = Dictionary(grouping: openTabs, by: \.url.absoluteString).mapValues(\.count)
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    private var staleTabs: [BrowserTab] {
        openTabs.filter { !$0.isPinned && isStale($0) }
    }

    private var duplicateTabs: [BrowserTab] {
        openTabs.filter { duplicateURLs.contains($0.url.absoluteString) }
    }

    private var filteredTabs: [BrowserTab] {
        switch filter {
        case .all: openTabs
        case .keep: openTabs.filter(\.isPinned)
        case .stale: staleTabs
        case .duplicates: duplicateTabs
        }
    }

    private var selected: BrowserTab? {
        model.tabs.first { $0.id == selection } ?? filteredTabs.first
    }

    private func isStale(_ tab: BrowserTab) -> Bool {
        Date().timeIntervalSince(tab.lastActivatedAt) >= BrowserStore.staleAfter
    }

    private func status(for tab: BrowserTab) -> TriageStatus {
        if tab.isPinned {
            return .kept
        }
        if duplicateURLs.contains(tab.url.absoluteString) {
            return .duplicate
        }
        if isStale(tab) {
            return .stale
        }
        return .active
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Tab Triage & Memory Optimization")
                .font(HarborTypography.editorial(size: 20, weight: .medium))
                .foregroundStyle(HarborColor.onSurface)
                .lineLimit(1)
            Button("Back to reader") {
                model.isTriagePresented = false
            }
            .buttonStyle(.plain)
            .font(HarborTypography.chrome(size: 11, weight: .medium))
            .foregroundStyle(HarborColor.primary)
            ForEach(TriageFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text("\(option.title) \(count(for: option))")
                        .font(HarborTypography.chrome(size: 11, weight: .medium))
                        .foregroundStyle(filter == option ? Color.white : HarborColor.onSurfaceVariant)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(filter == option ? HarborColor.accentTeal : HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.hairline))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button("Archive \(staleTabs.count) stale tabs") {
                Task { await model.archiveStale() }
            }
            .buttonStyle(.borderedProminent)
            .tint(HarborColor.accentTeal)
            Button("Deduplicate \(duplicateTabs.count) tabs") {
                Task { await model.deduplicate(duplicateTabs) }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    private var columnHeader: some View {
        HStack {
            Text("Tab title and origin").frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: 110, alignment: .leading)
            Text("Space").frame(width: 110, alignment: .leading)
            Text("Last active").frame(width: 100, alignment: .leading)
            Text("Actions").frame(width: 160, alignment: .leading)
        }
        .font(HarborTypography.mono(size: 10, weight: .semibold))
        .tracking(1)
        .foregroundStyle(HarborColor.onSurfaceVariant)
        .padding(.horizontal, 16)
        .frame(height: 32)
        .background(HarborColor.surfaceLow)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("Showing \(filteredTabs.count) of \(openTabs.count) triage candidates")
                .font(HarborTypography.chrome(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Spacer()
            hint("↑/↓", "navigate")
            hint("A", "archive")
            hint("K", "keep")
            hint("D", "discard")
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(HarborColor.surfaceLow)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(HarborTypography.mono(size: 10))
                .padding(.horizontal, 5)
                .frame(height: 16)
                .background(HarborColor.paper, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.hairline))
            Text(label)
                .font(HarborTypography.chrome(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let tab = selected {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tab Inspector")
                    .font(HarborTypography.chrome(size: 13, weight: .semibold))
                Text(tab.title)
                    .font(HarborTypography.editorial(size: 17, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                Text(tab.url.absoluteString)
                    .font(HarborTypography.mono(size: 11))
                    .foregroundStyle(HarborColor.outline)
                    .lineLimit(2)
                Text(recommendation(for: status(for: tab)))
                    .font(HarborTypography.chrome(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 8))
                HStack(spacing: 8) {
                    rowAction("Keep") { await model.keep(tab) }
                    rowAction("Archive") { await model.archive(tab) }
                    rowAction("Close") { await model.close(tab) }
                }
                Spacer()
            }
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(HarborColor.surfaceLow)
        } else {
            Text("No tab selected")
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HarborColor.surfaceLow)
        }
    }

    private func recommendation(for status: TriageStatus) -> String {
        switch status {
        case .kept: "Kept in this space. It will not be archived automatically."
        case .duplicate: "The same address is open in another tab. Merge candidate."
        case .stale: "Inactive for 3 days or more. Auto-archive candidate."
        case .active: "Recently used. Retain in this space."
        }
    }

    private func rowAction(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(.plain)
        .font(HarborTypography.chrome(size: 11, weight: .medium))
        .foregroundStyle(HarborColor.primary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.hairline))
    }

    private func count(for option: TriageFilter) -> Int {
        switch option {
        case .all: openTabs.count
        case .keep: summary.keep
        case .stale: staleTabs.count
        case .duplicates: duplicateTabs.count
        }
    }
}

enum TriageFilter: CaseIterable {
    case all
    case keep
    case duplicates
    case stale

    var title: String {
        switch self {
        case .all: "All"
        case .keep: "Keep"
        case .duplicates: "Duplicate"
        case .stale: "Stale"
        }
    }
}

enum TriageStatus {
    case kept
    case duplicate
    case stale
    case active

    var label: String {
        switch self {
        case .kept: "KEPT"
        case .duplicate: "DUPLICATE"
        case .stale: "STALE"
        case .active: "ACTIVE"
        }
    }

    var tint: Color {
        switch self {
        case .kept: HarborColor.primary
        case .duplicate: HarborColor.approvalText
        case .stale: HarborColor.approvalText
        case .active: HarborColor.onSurfaceVariant
        }
    }
}

private struct TriageRow: View {
    let tab: BrowserTab
    let model: AppModel
    let status: TriageStatus
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(HarborTypography.chrome(size: 13, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Text(tab.url.host ?? tab.url.absoluteString)
                    .font(HarborTypography.mono(size: 10))
                    .foregroundStyle(HarborColor.outline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(status.label)
                .font(HarborTypography.mono(size: 9, weight: .semibold))
                .foregroundStyle(status.tint)
                .frame(width: 110, alignment: .leading)
            Text(model.spaceNames[tab.spaceID] ?? "")
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 110, alignment: .leading)
            Text(tab.lastActivatedAt, style: .relative)
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 100, alignment: .leading)
            HStack(spacing: 6) {
                rowButton("Keep") { await model.keep(tab) }
                rowButton("Archive") { await model.archive(tab) }
                rowButton("Close") { await model.close(tab) }
            }
            .frame(width: 160, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(isSelected ? HarborColor.surfaceLowest : .clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .overlay(alignment: .bottom) {
            Divider().overlay(HarborColor.outlineVariant.opacity(0.2))
        }
    }

    private func rowButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(.plain)
        .font(HarborTypography.chrome(size: 11, weight: .medium))
        .foregroundStyle(HarborColor.primary)
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.hairline))
    }
}
