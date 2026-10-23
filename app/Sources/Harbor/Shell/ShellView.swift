import SwiftUI

struct ShellView: View {
    @Bindable var model: AppModel

    @State private var sidebarRequested = true

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let sidebarVisible = ShellLayout.sidebarVisible(requested: sidebarRequested, width: width)
            VStack(spacing: 0) {
                ChromeHeaderView(
                    windowWidth: width,
                    sidebarVisible: sidebarVisible,
                    toggleSidebar: { sidebarRequested.toggle() },
                    openCommandBar: { model.isCommandBarPresented = true }
                )
                Divider()
                    .overlay(HarborColor.outlineVariant.opacity(0.3))
                HStack(spacing: 0) {
                    if sidebarVisible {
                        SidebarView(model: model)
                            .frame(width: 260)
                            .background(HarborColor.surfaceLow)
                        Divider()
                            .overlay(HarborColor.outlineVariant.opacity(0.3))
                    }
                    content(companionVisible: ShellLayout.companionVisible(width: width))
                }
            }
            .background(HarborColor.paper)
            .overlay {
                if model.isCommandBarPresented {
                    CommandBarView(model: model)
                }
            }
            .background(shortcuts)
        }
        .task {
            await model.start()
        }
        .sheet(isPresented: $model.isInboxPresented) {
            TaskInboxView(model: model)
        }
        .sheet(isPresented: $model.isClientsPresented) {
            ClientsSheetView(model: model)
        }
    }

    private var shortcuts: some View {
        VStack {
            Button("Command Bar") { model.isCommandBarPresented.toggle() }
                .keyboardShortcut("k", modifiers: .command)
            Button("Tab Triage") { model.isTriagePresented.toggle() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            Button("Task Inbox") { model.isInboxPresented = true }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func content(companionVisible: Bool) -> some View {
        if model.isTriagePresented {
            TriageView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                ReaderArticleView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if companionVisible {
                    Divider()
                        .overlay(HarborColor.outlineVariant.opacity(0.3))
                    CompanionPanelView()
                        .frame(width: 300)
                }
            }
        }
    }
}
