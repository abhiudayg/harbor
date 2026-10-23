import HarborCore
import SwiftUI

struct TabDiagnosticsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HarborColor.outlineVariant)
            TimelineView(.periodic(from: .now, by: 2)) { context in
                VStack(alignment: .leading, spacing: 16) {
                    memoryCard
                    tabTable(now: context.date)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider().overlay(HarborColor.outlineVariant)
            footer
        }
        .frame(width: 800, height: 580)
        .background(HarborColor.surface)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Tab Diagnostics")
                .font(HarborTypography.headline(size: 20, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            Spacer()
            Button("Done") { model.isDiagnosticsPresented = false }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var memoryCard: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                Text("HARBOR PEAK MEMORY")
                    .font(HarborTypography.text(size: 10, weight: .medium))
                    .tracking(0.55)
                    .foregroundStyle(HarborColor.outline)
                Text(footprintText)
                    .font(HarborTypography.headline(size: 28, weight: .semibold))
                    .foregroundStyle(HarborColor.onSurface)
                    .accessibilityIdentifier("diagnostics-footprint")
            }
            Spacer()
            HStack(spacing: 24) {
                stat("Open", count: openTabs.count)
                stat("Live", count: model.tabs.filter { $0.state == .live }.count)
                stat("Hibernated", count: model.tabs.filter { $0.state == .hibernated }.count)
                stat("Archived", count: model.tabs.filter { $0.state == .archived }.count)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.outlineVariant))
    }

    private func stat(_ label: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(HarborTypography.headline(size: 18, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            Text(label)
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.outline)
        }
    }

    private func tabTable(now: Date) -> some View {
        let duplicates = TriageClassifier.duplicateURLs(in: model.tabs)
        let rows = model.tabs.sorted { $0.lastActivatedAt > $1.lastActivatedAt }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                column("Tab").frame(maxWidth: .infinity, alignment: .leading)
                column("Space").frame(width: 110, alignment: .leading)
                column("State").frame(width: 92, alignment: .leading)
                column("Status").frame(width: 96, alignment: .leading)
                column("Last active").frame(width: 110, alignment: .leading)
                column("Memory").frame(width: 110, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(HarborColor.surfaceLow)
            ForEach(rows) { tab in
                row(tab, status: TriageClassifier.status(for: tab, duplicateURLs: duplicates, now: now), now: now)
                Divider().overlay(HarborColor.outlineVariant.opacity(0.5))
            }
        }
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.outlineVariant))
    }

    private func column(_ title: String) -> some View {
        Text(title.uppercased())
            .font(HarborTypography.text(size: 10, weight: .medium))
            .tracking(0.55)
            .foregroundStyle(HarborColor.outline)
    }

    private func row(_ tab: BrowserTab, status: TriageStatus, now: Date) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(HarborTypography.text(size: 13, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Text(tab.url.host ?? tab.url.absoluteString)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.outline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(model.spaceNames[tab.spaceID] ?? "Unknown")
                .font(HarborTypography.text(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 110, alignment: .leading)
            Text(stateLabel(tab.state))
                .font(HarborTypography.text(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 92, alignment: .leading)
            Text(status.label)
                .font(HarborTypography.text(size: 9, weight: .medium))
                .foregroundStyle(status.badgeText)
                .frame(width: 96, alignment: .leading)
            Text(RelativeDateTimeFormatter().localizedString(for: tab.lastActivatedAt, relativeTo: now))
                .font(HarborTypography.text(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(width: 110, alignment: .leading)
            Text("Not measured")
                .font(HarborTypography.text(size: 12))
                .foregroundStyle(HarborColor.outline)
                .frame(width: 110, alignment: .leading)
                .help("WebKit does not expose per-tab memory through its public API.")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    private var footer: some View {
        Text("Harbor reports its peak resident memory from the operating system. WebKit does not expose per-tab memory, so tab rows show state and status instead.")
            .font(HarborTypography.text(size: 11))
            .foregroundStyle(HarborColor.onSurfaceVariant)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HarborColor.surfaceLow)
    }

    private var openTabs: [BrowserTab] {
        model.tabs.filter { $0.state != .archived }
    }

    private var footprintText: String {
        guard let bytes = ProcessMemory.peakResidentBytes() else {
            return "Unavailable"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private func stateLabel(_ state: TabState) -> String {
        switch state {
        case .live: "Live"
        case .hibernated: "Hibernated"
        case .archived: "Archived"
        }
    }
}
