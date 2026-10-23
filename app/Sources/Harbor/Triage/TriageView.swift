import HarborCore
import SwiftUI

struct TriageView: View {
    let model: AppModel
    @State private var filter: TriageFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filters
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredTabs) { tab in
                        TriageRow(tab: tab, status: status(for: tab), model: model)
                    }
                    if filteredTabs.isEmpty {
                        Text("No tabs match this filter.")
                            .font(HarborTypography.chrome(size: 12))
                            .foregroundStyle(HarborColor.onSurfaceVariant)
                            .padding(.top, 40)
                    }
                }
                .padding(28)
            }
            .scrollIndicators(.never)
            footer
        }
        .background(HarborColor.surface)
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

    private var keptTabs: [BrowserTab] {
        openTabs.filter(\.isPinned)
    }

    private var filteredTabs: [BrowserTab] {
        switch filter {
        case .all: openTabs
        case .keep: keptTabs
        case .stale: staleTabs
        case .duplicates: duplicateTabs
        }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tab Triage & Memory Optimization")
                    .font(HarborTypography.editorial(size: 26, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                Spacer()
                Button("Back to reader") {
                    model.isTriagePresented = false
                }
                .buttonStyle(.plain)
                .font(HarborTypography.chrome(size: 11, weight: .medium))
                .foregroundStyle(HarborColor.primary)
            }
            Text("Autonomous heuristic · \(openTabs.count) open tabs")
                .font(HarborTypography.chrome(size: 13))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            HStack(spacing: 8) {
                Button("Archive \(staleTabs.count) stale tabs") {
                    Task { await model.archiveStale() }
                }
                .buttonStyle(.borderedProminent)
                .tint(HarborColor.accentTeal)
                .disabled(staleTabs.isEmpty)
                Button("Deduplicate \(duplicateTabs.count) tabs") {
                    Task { await model.deduplicate(duplicateTabs) }
                }
                .buttonStyle(.bordered)
                .disabled(duplicateTabs.isEmpty)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var filters: some View {
        HStack(spacing: 6) {
            ForEach(TriageFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text("\(option.title) \(count(for: option))")
                        .font(HarborTypography.chrome(size: 11, weight: .medium))
                        .foregroundStyle(filter == option ? Color.white : HarborColor.onSurfaceVariant)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(filter == option ? HarborColor.accentTeal : HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.hairline))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Text("Showing \(filteredTabs.count) of \(openTabs.count) triage candidates")
                .font(HarborTypography.chrome(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(height: 34)
        .background(HarborColor.surfaceLow)
    }

    private func count(for option: TriageFilter) -> Int {
        switch option {
        case .all: openTabs.count
        case .keep: keptTabs.count
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
        case .stale: HarborColor.error
        case .active: HarborColor.tertiaryGreen
        }
    }

    var recommendation: String {
        switch self {
        case .kept: "Pinned in this space. It is never archived automatically."
        case .duplicate: "The same address is open in another tab. Close the extra copy."
        case .stale: "Inactive for 3 days or more. Auto-archive candidate."
        case .active: "Recently used. Keep it in this space."
        }
    }
}

private struct TriageRow: View {
    let tab: BrowserTab
    let status: TriageStatus
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(tab.title)
                    .font(HarborTypography.editorial(size: 16, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Text(status.label)
                    .font(HarborTypography.mono(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(status.tint)
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(status.tint.opacity(0.4)))
                Spacer()
                Text(tab.lastActivatedAt, style: .relative)
                    .font(HarborTypography.chrome(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            Text(tab.url.host ?? tab.url.absoluteString)
                .font(HarborTypography.mono(size: 10))
                .foregroundStyle(HarborColor.outline)
            HStack(alignment: .center, spacing: 8) {
                Text(status.recommendation)
                    .font(HarborTypography.chrome(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                actions
            }
        }
        .padding(14)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HarborColor.hairline))
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 6) {
            switch status {
            case .kept:
                EmptyView()
            case .duplicate:
                rowButton("Keep") { await model.keep(tab) }
                rowButton("Close copy") { await model.close(tab) }
            case .stale:
                rowButton("Keep") { await model.keep(tab) }
                rowButton("Archive") { await model.archive(tab) }
            case .active:
                rowButton("Keep") { await model.keep(tab) }
            }
        }
    }

    private func rowButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(.plain)
        .font(HarborTypography.chrome(size: 11, weight: .medium))
        .foregroundStyle(HarborColor.primary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(HarborColor.surfaceLow, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.hairline))
    }
}
