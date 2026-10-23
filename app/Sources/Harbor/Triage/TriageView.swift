import HarborCore
import SwiftUI

struct TriageView: View {
    let model: AppModel
    @State private var filter: TriageFilter = .all

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
                                TriageRow(tab: tab, model: model)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
                summaryPane
                    .frame(width: 300)
            }
        }
        .background(HarborColor.paper)
    }

    private var summary: TriageSummary {
        TriageSummary.make(tabs: model.tabs, now: Date())
    }

    private var filteredTabs: [BrowserTab] {
        switch filter {
        case .all: model.tabs
        case .keep: model.tabs.filter(\.isPinned)
        case .archived: model.tabs.filter { $0.state == .archived }
        case .stale: model.tabs.filter { Date().timeIntervalSince($0.lastActivatedAt) >= BrowserStore.staleAfter && $0.state != .archived }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Tab Triage")
                .font(HarborTypography.editorial(size: 20, weight: .medium))
                .foregroundStyle(HarborColor.onSurface)
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
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    private var columnHeader: some View {
        HStack {
            Text("Tab title and origin").frame(maxWidth: .infinity, alignment: .leading)
            Text("Space").frame(width: 120, alignment: .leading)
            Text("Last active").frame(width: 110, alignment: .leading)
            Text("Actions").frame(width: 160, alignment: .leading)
        }
        .font(HarborTypography.mono(size: 10, weight: .semibold))
        .tracking(1)
        .foregroundStyle(HarborColor.onSurfaceVariant)
        .padding(.horizontal, 16)
        .frame(height: 32)
        .background(HarborColor.surfaceLow)
    }

    private var summaryPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Triage summary")
                .font(HarborTypography.chrome(size: 13, weight: .semibold))
            summaryRow("Open tabs", "\(summary.total)")
            summaryRow("Kept (pinned)", "\(summary.keep)")
            summaryRow("Archived", "\(summary.archived)")
            summaryRow("Duplicate URLs", "\(summary.duplicates)")
            summaryRow("Stale (3+ days)", "\(summary.stale)")
            Spacer()
            Button("Archive stale tabs") {
                Task { await model.archiveStale() }
            }
            .buttonStyle(.borderedProminent)
            .tint(HarborColor.accentTeal)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(HarborColor.surfaceLow)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(HarborTypography.mono(size: 12, weight: .medium))
                .foregroundStyle(HarborColor.onSurface)
        }
    }

    private func count(for option: TriageFilter) -> Int {
        switch option {
        case .all: summary.total
        case .keep: summary.keep
        case .archived: summary.archived
        case .stale: summary.stale
        }
    }
}

enum TriageFilter: CaseIterable {
    case all
    case keep
    case archived
    case stale

    var title: String {
        switch self {
        case .all: "All"
        case .keep: "Keep"
        case .archived: "Archive"
        case .stale: "Stale"
        }
    }
}

private struct TriageRow: View {
    let tab: BrowserTab
    let model: AppModel

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
            Text(model.spaceNames[tab.spaceID] ?? "")
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 120, alignment: .leading)
            Text(tab.lastActivatedAt, style: .relative)
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 110, alignment: .leading)
            HStack(spacing: 6) {
                rowButton("Keep") { await model.keep(tab) }
                rowButton("Archive") { await model.archive(tab) }
                rowButton("Close") { await model.close(tab) }
            }
            .frame(width: 160, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
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
