import HarborCore
import SwiftUI

struct TriageView: View {
    let model: AppModel
    @State private var filter: TriageFilter = .all
    @State private var focused: UUID?
    @State private var selected: Set<UUID> = []
    @State private var currentPage = 0
    @State private var isConsolidating = false
    private let pageSize = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filterBar
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(pagedTabs) { tab in
                            TriageRow(
                                tab: tab,
                                status: status(for: tab),
                                copies: copies(of: tab),
                                isFocused: tab.id == focused,
                                isSelected: selected.contains(tab.id),
                                model: model,
                                toggleSelection: { toggle(tab.id) }
                            )
                            .id(tab.id)
                        }
                        if filteredTabs.isEmpty {
                            Text("No tabs match this filter.")
                                .font(HarborTypography.text(size: 13))
                                .foregroundStyle(HarborColor.onSurfaceVariant)
                                .padding(.top, 40)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.never)
                .onChange(of: focused) { _, new in
                    if let new {
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(new, anchor: .center)
                        }
                    }
                }
            }
            footer
        }
        .background(Color.clear)
        .background(keyboardShortcuts)
        .onChange(of: filter) {
            selected = []
            focused = nil
            currentPage = 0
        }
    }

    private var openTabs: [BrowserTab] {
        model.tabs.filter { $0.state != .archived }
    }

    private var duplicateURLs: Set<String> {
        TriageClassifier.duplicateURLs(in: model.tabs)
    }

    private var keptTabs: [BrowserTab] {
        openTabs.filter(\.isPinned)
    }

    private var duplicateTabs: [BrowserTab] {
        openTabs.filter { duplicateURLs.contains($0.url.absoluteString) }
    }

    private var highMemoryTabs: [BrowserTab] {
        openTabs.filter { status(for: $0) == .highMemory }
    }

    private var staleTabs: [BrowserTab] {
        openTabs.filter { status(for: $0) == .stale }
    }

    private var matchingTabs: [BrowserTab] {
        switch filter {
        case .all: openTabs
        case .keep: keptTabs
        case .duplicates: duplicateTabs
        case .stale: staleTabs
        case .highMemory: highMemoryTabs
        }
    }

    private var filteredTabs: [BrowserTab] {
        matchingTabs.sorted { $0.lastActivatedAt < $1.lastActivatedAt }
    }

    private var totalPages: Int {
        max(1, (filteredTabs.count + pageSize - 1) / pageSize)
    }

    private var validCurrentPage: Int {
        min(max(currentPage, 0), max(0, totalPages - 1))
    }

    private var pagedTabs: [BrowserTab] {
        guard !filteredTabs.isEmpty else { return [] }
        let start = validCurrentPage * pageSize
        guard start < filteredTabs.count else { return [] }
        let end = min(start + pageSize, filteredTabs.count)
        return Array(filteredTabs[start..<end])
    }

    private var selectedTabs: [BrowserTab] {
        filteredTabs.filter { selected.contains($0.id) }
    }

    private var focusedTab: BrowserTab? {
        filteredTabs.first { $0.id == focused }
    }

    private var actionTargets: [BrowserTab] {
        if !selectedTabs.isEmpty {
            return selectedTabs
        }
        return focusedTab.map { [$0] } ?? []
    }

    private func status(for tab: BrowserTab) -> TriageStatus {
        TriageClassifier.status(for: tab, duplicateURLs: duplicateURLs, now: Date())
    }

    private func copies(of tab: BrowserTab) -> [BrowserTab] {
        openTabs.filter { $0.url == tab.url }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func toggleSelectAll() {
        if selected.count == filteredTabs.count, !filteredTabs.isEmpty {
            selected = []
        } else {
            selected = Set(filteredTabs.map(\.id))
        }
    }

    private var allSelected: Bool {
        !filteredTabs.isEmpty && selected.count == filteredTabs.count
    }

    private func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        currentPage = page
        focused = pagedTabs.first?.id
    }

    private func moveFocus(by step: Int) {
        guard !filteredTabs.isEmpty else { return }
        let current = pagedTabs.firstIndex { $0.id == focused }
        if let current {
            let nextIndex = current + step
            if nextIndex < 0 {
                if currentPage > 0 {
                    currentPage -= 1
                    focused = pagedTabs.last?.id
                }
            } else if nextIndex >= pagedTabs.count {
                if currentPage < totalPages - 1 {
                    currentPage += 1
                    focused = pagedTabs.first?.id
                }
            } else {
                focused = pagedTabs[nextIndex].id
            }
        } else {
            focused = pagedTabs.first?.id
        }
    }

    private func perform(_ action: BulkAction) {
        let targets = actionTargets
        guard !targets.isEmpty else { return }
        selected = []
        Task {
            switch action {
            case .archive: await model.archive(targets)
            case .keep: await model.keepAll(targets)
            case .discard: await model.close(targets)
            }
        }
    }

    private var keyboardShortcuts: some View {
        VStack {
            Button("") { moveFocus(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("") { moveFocus(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("") { goToPage(currentPage - 1) }
                .keyboardShortcut("[", modifiers: .command)
            Button("") { goToPage(currentPage + 1) }
                .keyboardShortcut("]", modifiers: .command)
            Button("") { perform(.archive) }
                .keyboardShortcut("e", modifiers: [])
            Button("") { perform(.keep) }
                .keyboardShortcut("k", modifiers: [])
            Button("") { perform(.discard) }
                .keyboardShortcut(.delete, modifiers: .command)
            Button("") { toggleSelectAll() }
                .keyboardShortcut("a", modifiers: .command)
            Button("") { model.hideTriage() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    MaterialIcon("auto_awesome", size: 16)
                        .foregroundStyle(HarborColor.primaryContainer)
                    Text("Tab Triage")
                        .font(HarborTypography.headline(size: 17, weight: .semibold))
                        .foregroundStyle(HarborColor.onSurface)
                    Text("Autonomous Heuristic")
                        .font(HarborTypography.text(size: 10))
                        .foregroundStyle(Color(hex: 0x047857))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: 0xECFDF5), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0xA7F3D0)))
                }
                Text("\(openTabs.count) active tabs. Review automated retention recommendations.")
                    .font(HarborTypography.text(size: 12))
                    .foregroundStyle(HarborColor.outline)
                    .lineLimit(1)
            }
            Spacer(minLength: 16)
            HStack(spacing: 8) {
                if selectedTabs.isEmpty {
                    Button {
                        Task { await model.archive(staleTabs) }
                    } label: {
                        HStack(spacing: 6) { MaterialIcon("archive", size: 12); Text("Archive \(staleTabs.count) Stale Tabs") }
                    }
                    .buttonStyle(FilledTriageButtonStyle())
                    .disabled(staleTabs.isEmpty)
                } else {
                    Button {
                        perform(.archive)
                    } label: {
                        HStack(spacing: 6) { MaterialIcon("archive", size: 12); Text("Archive Selected (\(selectedTabs.count))") }
                    }
                    .buttonStyle(FilledTriageButtonStyle())
                }
                Button {
                    Task { await model.deduplicate(duplicateTabs) }
                } label: {
                    HStack(spacing: 6) { MaterialIcon("call_merge", size: 12); Text("Deduplicate \(duplicateTabs.count) Tabs") }
                }
                .buttonStyle(OutlinedTriageButtonStyle())
                .disabled(duplicateTabs.isEmpty)
                Button {
                    isConsolidating = true
                } label: {
                    HStack(spacing: 6) { MaterialIcon("folder", size: 12); Text("Consolidate into Space") }
                }
                .buttonStyle(OutlinedTriageButtonStyle())
                .disabled(actionTargets.isEmpty || model.spaces.isEmpty)
                .popover(isPresented: $isConsolidating, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(model.spaces) { space in
                            Button(space.name) {
                                isConsolidating = false
                                Task { await model.consolidate(actionTargets, into: space.id) }
                            }
                            .buttonStyle(.plain)
                            .font(HarborTypography.text(size: 12))
                            .foregroundStyle(HarborColor.onSurface)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(6)
                    .frame(width: 200)
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassPanel()
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(TriageFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    HStack(spacing: 6) {
                        if let dot = option.dot {
                            Circle()
                                .fill(dot)
                                .frame(width: 6, height: 6)
                        }
                        Text(option.title)
                            .font(HarborTypography.text(size: 12, weight: filter == option ? .medium : .regular))
                            .foregroundStyle(filter == option ? HarborColor.onSurface : HarborColor.outline)
                        Text("\(count(for: option))")
                            .font(HarborTypography.text(size: 11, weight: filter == option ? .medium : .regular))
                            .foregroundStyle(filter == option ? HarborColor.onSurface : HarborColor.outline)
                            .padding(.horizontal, filter == option ? 6 : 0)
                            .padding(.vertical, filter == option ? 1 : 0)
                            .background(filter == option ? HarborColor.surfaceContainerLow : .clear, in: Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(filter == option ? HarborColor.surfaceLowest : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(filter == option ? HarborColor.borderSubtle : .clear))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 12)
            Button {
                toggleSelectAll()
            } label: {
                HStack(spacing: 6) {
                    MaterialIcon(allSelected ? "check_box" : "check_box_outline_blank")
                        .font(.system(size: 13))
                        .foregroundStyle(allSelected ? HarborColor.primaryContainer : HarborColor.outline)
                    Text("Select All (\(filteredTabs.count))")
                        .font(HarborTypography.text(size: 11))
                }
                .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .disabled(filteredTabs.isEmpty)

            Divider()
                .frame(height: 14)
                .overlay(HarborColor.borderSubtle)

            HStack(spacing: 6) {
                MaterialIcon("tune", size: 11)
                Text("Sorted by Inactivity Duration")
                    .font(HarborTypography.text(size: 11))
            }
            .foregroundStyle(HarborColor.outline)

            Divider()
                .frame(height: 14)
                .overlay(HarborColor.borderSubtle)

            Text("⌘A")
                .font(HarborTypography.text(size: 10, weight: .medium))
                .foregroundStyle(HarborColor.outline)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.borderSubtle))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassPanel()
        .overlay(alignment: .bottom) {
            Divider().overlay(HarborColor.borderSubtle)
        }
    }

    private var showingRangeText: String {
        guard !filteredTabs.isEmpty else {
            return "Showing 0 of \(openTabs.count) triage candidates"
        }
        let start = validCurrentPage * pageSize + 1
        let end = min((validCurrentPage + 1) * pageSize, filteredTabs.count)
        return "Showing \(start)–\(end) of \(filteredTabs.count) triage candidates"
    }

    private var footer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Text(showingRangeText)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.outline)
                Text("•")
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.outline)
                HStack(spacing: 4) {
                    Text("Auto-pilot:")
                        .font(HarborTypography.text(size: 11))
                        .foregroundStyle(HarborColor.outline)
                    Text("enabled")
                        .font(HarborTypography.text(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: 0x059669))
                }
            }

            Spacer()

            if totalPages > 1 {
                paginationControl
            }

            Spacer()

            HStack(spacing: 12) {
                keyHint("↑/↓", "navigate")
                keyHint("E", "archive")
                keyHint("K", "keep")
                keyHint("⌘⌫", "discard")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 42)
        .glassPanel()
        .overlay(alignment: .top) {
            Divider().overlay(HarborColor.borderSubtle)
        }
    }

    private var paginationControl: some View {
        HStack(spacing: 5) {
            Button {
                goToPage(validCurrentPage - 1)
            } label: {
                HStack(spacing: 3) {
                    MaterialIcon("chevron_left", size: 10)
                    Text("Prev")
                        .font(HarborTypography.text(size: 11, weight: .medium))
                }
                .foregroundStyle(validCurrentPage > 0 ? HarborColor.onSurface : HarborColor.outline.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.borderSubtle))
            }
            .buttonStyle(.plain)
            .disabled(validCurrentPage == 0)

            ForEach(pageNumbersToDisplay, id: \.self) { page in
                if page == -1 {
                    Text("…")
                        .font(HarborTypography.text(size: 11))
                        .foregroundStyle(HarborColor.outline)
                        .frame(width: 18)
                } else {
                    Button {
                        goToPage(page)
                    } label: {
                        Text("\(page + 1)")
                            .font(HarborTypography.text(size: 11, weight: validCurrentPage == page ? .semibold : .regular))
                            .foregroundStyle(validCurrentPage == page ? Color.white : HarborColor.onSurface)
                            .frame(minWidth: 26, minHeight: 24)
                            .background(validCurrentPage == page ? HarborColor.primaryContainer : HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(validCurrentPage == page ? HarborColor.primaryContainer : HarborColor.borderSubtle))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                goToPage(validCurrentPage + 1)
            } label: {
                HStack(spacing: 3) {
                    Text("Next")
                        .font(HarborTypography.text(size: 11, weight: .medium))
                    MaterialIcon("chevron_right", size: 10)
                }
                .foregroundStyle(validCurrentPage < totalPages - 1 ? HarborColor.onSurface : HarborColor.outline.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(HarborColor.borderSubtle))
            }
            .buttonStyle(.plain)
            .disabled(validCurrentPage >= totalPages - 1)
        }
    }

    private var pageNumbersToDisplay: [Int] {
        if totalPages <= 7 {
            return Array(0..<totalPages)
        }
        var pages: [Int] = [0]
        let start = max(1, validCurrentPage - 1)
        let end = min(totalPages - 2, validCurrentPage + 1)

        if start > 1 {
            pages.append(-1)
        }
        for p in start...end {
            pages.append(p)
        }
        if end < totalPages - 2 {
            pages.append(-1)
        }
        pages.append(totalPages - 1)
        return pages
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(HarborTypography.text(size: 11, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            Text(label)
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
    }

    private func count(for option: TriageFilter) -> Int {
        switch option {
        case .all: openTabs.count
        case .keep: keptTabs.count
        case .duplicates: duplicateTabs
            .count
        case .stale: staleTabs.count
        case .highMemory: highMemoryTabs.count
        }
    }

    private enum BulkAction {
        case archive
        case keep
        case discard
    }
}

enum TriageFilter: CaseIterable {
    case all
    case keep
    case duplicates
    case stale
    case highMemory

    var title: String {
        switch self {
        case .all: "All"
        case .keep: "Keep"
        case .duplicates: "Duplicate"
        case .stale: "Stale"
        case .highMemory: "High Memory"
        }
    }

    var dot: Color? {
        switch self {
        case .all, .keep: nil
        case .duplicates: Color(hex: 0xF59E0B)
        case .stale: Color(hex: 0xF97316)
        case .highMemory: Color(hex: 0xEF4444)
        }
    }
}

enum TriageStatus: Equatable, Sendable {
    case kept
    case duplicate
    case stale
    case active
    case highMemory

    var label: String {
        switch self {
        case .kept: "KEPT"
        case .duplicate: "DUPLICATE"
        case .stale: "STALE"
        case .active: "ACTIVE"
        case .highMemory: "HIGH MEMORY"
        }
    }

    var badgeText: Color {
        switch self {
        case .kept: HarborColor.primary
        case .duplicate, .stale: Color(hex: 0x92400E)
        case .active: Color(hex: 0x047857)
        case .highMemory: Color(hex: 0xBE123C)
        }
    }

    var badgeFill: Color {
        switch self {
        case .kept: Color(hex: 0xE6F7F7)
        case .duplicate, .stale: Color(hex: 0xFFFBEB)
        case .active: Color(hex: 0xECFDF5)
        case .highMemory: Color(hex: 0xFFE4E6)
        }
    }

    var badgeBorder: Color {
        switch self {
        case .kept: HarborColor.primaryFixed
        case .duplicate, .stale: Color(hex: 0xFDE68A)
        case .active: Color(hex: 0xA7F3D0)
        case .highMemory: Color(hex: 0xFECDD3)
        }
    }

    func recommendation(for tab: BrowserTab) -> String {
        let lower = tab.url.absoluteString.lowercased()
        switch self {
        case .kept:
            return "Pinned in this space. It is never archived automatically."
        case .duplicate:
            if lower.contains("figma") {
                return "Duplicate session with Kernel RFC & Primary Figma window. Merge state."
            }
            return "The same address is open in another tab. Keep the most recent copy."
        case .highMemory:
            return "Stale tab - auto-archive candidate. High resident memory leak detected."
        case .stale:
            if lower.contains("arxiv") {
                return "Stale tab — auto-archive candidate. PDF stored in Research cache."
            } else if lower.contains("huggingface") {
                return "Stale tab — auto-archive candidate. Model specifications bookmarked locally."
            }
            return "Stale tab — auto-archive candidate."
        case .active:
            if lower.contains("linear") {
                return "Active research context — retain in Systems workspace."
            }
            return "Active research context — retain in this space."
        }
    }
}

private struct TriageRow: View {
    let tab: BrowserTab
    let status: TriageStatus
    let copies: [BrowserTab]
    let isFocused: Bool
    let isSelected: Bool
    let model: AppModel
    let toggleSelection: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TriageCheckbox(isSelected: isSelected, action: toggleSelection)
                .padding(.top, 9)

            TabFaviconView(tab: tab)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(tab.title)
                        .font(HarborTypography.text(size: 14, weight: .semibold))
                        .foregroundStyle(HarborColor.onSurface)
                        .lineLimit(1)
                    Text(status.label)
                        .font(HarborTypography.text(size: 10, weight: .semibold))
                        .tracking(0.35)
                        .foregroundStyle(status.badgeText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(status.badgeFill, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(status.badgeBorder))
                        .fixedSize()
                }

                metadataLine

                recommendationView
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 8) {
                actions
                Button {
                    Task { await model.close(tab) }
                } label: {
                    MaterialIcon("close", size: 11)
                        .foregroundStyle(HarborColor.outline)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close tab")
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? HarborColor.primaryContainer : HarborColor.borderSubtle, lineWidth: isFocused ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.035), radius: 3, y: 1)
    }

    private var formattedURL: String {
        let host = tab.url.host ?? ""
        var path = tab.url.path
        if path == "/" {
            path = ""
        }
        return host + path
    }

    private var relativeAccess: String {
        let seconds = max(0, Int(Date().timeIntervalSince(tab.lastActivatedAt)))
        if seconds < 60 {
            return "\(seconds)s ago"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = hours / 24
        if days == 1 {
            return "1 day ago"
        }
        return "\(days) days ago"
    }

    private var metadataLine: some View {
        let mb = TabMemory.megabytes(for: tab)
        let isHighRAM = mb >= 400

        return HStack(spacing: 8) {
            Text(formattedURL)
            Text("•")
            Text("Last accessed: \(relativeAccess)")
            Text("•")
            Text("\(mb) MB RAM")
                .foregroundStyle(isHighRAM ? Color(hex: 0xDC2626) : HarborColor.outline)
                .fontWeight(isHighRAM ? .semibold : .regular)
        }
        .font(HarborTypography.text(size: 12))
        .foregroundStyle(HarborColor.outline)
        .lineLimit(1)
    }

    private var recommendationView: some View {
        HStack(spacing: 8) {
            MaterialIcon("auto_awesome", size: 12)
                .foregroundStyle(HarborColor.primary)
            Text("AI Recommendation:")
                .font(HarborTypography.text(size: 12, weight: .medium))
                .foregroundStyle(HarborColor.primary)
            Text(status.recommendation(for: tab))
                .font(HarborTypography.text(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.borderSubtle))
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 6) {
            switch status {
            case .kept:
                rowButton("Archive", filled: true) { await model.archive([tab]) }
            case .duplicate:
                rowButton("Deduplicate", filled: true) { await model.deduplicate(copies) }
                rowButton("Keep", filled: false) { await model.keep(tab) }
            case .stale:
                rowButton("Archive", filled: true) { await model.archive([tab]) }
                rowButton("Keep", filled: false) { await model.keep(tab) }
            case .active:
                rowButton("Keep", filled: false) { await model.keep(tab) }
                rowButton("Archive", filled: false) { await model.archive([tab]) }
            case .highMemory:
                rowButton("Archive", filled: true) { await model.archive([tab]) }
                rowButton("Hibernate", filled: false) { await model.hibernate(tab) }
            }
        }
    }

    private func rowButton(_ title: String, filled: Bool, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(filled ? AnyButtonStyle(FilledTriageButtonStyle(compact: true)) : AnyButtonStyle(OutlinedTriageButtonStyle(compact: true)))
    }
}

private struct TriageCheckbox: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(HarborColor.primaryContainer)
                        .frame(width: 18, height: 18)
                    MaterialIcon("check", size: 11)
                        .foregroundStyle(Color.white)
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(HarborColor.borderSubtle, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TabFaviconView: View {
    let tab: BrowserTab

    var body: some View {
        let lower = tab.url.absoluteString.lowercased()

        if lower.contains("arxiv") {
            Text("Ψ")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(Color(hex: 0xB91C1C))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xFEE2E2), in: RoundedRectangle(cornerRadius: 8))
        } else if lower.contains("figma") {
            MaterialIcon("palette", size: 15)
                .foregroundStyle(Color(hex: 0x7E22CE))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xF3E8FF), in: RoundedRectangle(cornerRadius: 8))
        } else if lower.contains("linear") {
            Text("LN")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x1D4ED8))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xDBEAFE), in: RoundedRectangle(cornerRadius: 8))
        } else if lower.contains("datadog") {
            Text("🐶")
                .font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xFCE7F3), in: RoundedRectangle(cornerRadius: 8))
        } else if lower.contains("huggingface") {
            Text("🤗")
                .font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xFEF3C7), in: RoundedRectangle(cornerRadius: 8))
        } else if lower.contains("stripe") {
            Text("S")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x4338CA))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xEEF2FF), in: RoundedRectangle(cornerRadius: 8))
        } else if lower.contains("postgresql") {
            MaterialIcon("database", size: 15)
                .foregroundStyle(Color(hex: 0x0284C7))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xE0F2FE), in: RoundedRectangle(cornerRadius: 8))
        } else if lower.contains("lwn") || lower.contains("kernel") {
            MaterialIcon("terminal", size: 14)
                .foregroundStyle(Color(hex: 0x334155))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xF1F5F9), in: RoundedRectangle(cornerRadius: 8))
        } else {
            MaterialIcon("tab", size: 15)
                .foregroundStyle(HarborColor.outline)
                .frame(width: 40, height: 40)
                .background(HarborColor.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.borderSubtle))
        }
    }
}

private struct FilledTriageButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborTypography.text(size: 12, weight: .medium))
            .foregroundStyle(Color.white)
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 6 : 8)
            .background(HarborColor.primaryContainer.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct OutlinedTriageButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborTypography.text(size: 12, weight: .medium))
            .foregroundStyle(HarborColor.onSurface)
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 6 : 8)
            .background(HarborColor.surfaceLowest.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.borderSubtle))
    }
}

private struct AnyButtonStyle: ButtonStyle {
    private let make: (ButtonStyleConfiguration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
