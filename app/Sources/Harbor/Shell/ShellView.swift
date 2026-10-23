import SwiftUI

struct ShellView: View {
    static let sidebarWidth: CGFloat = 260
    static let collapseBelowWidth: CGFloat = 960

    let model: AppModel

    @State private var sidebarRequested = true

    var body: some View {
        GeometryReader { proxy in
            let sidebarVisible = sidebarRequested && proxy.size.width >= Self.collapseBelowWidth
            VStack(spacing: 0) {
                ChromeHeaderView(windowWidth: proxy.size.width, sidebarVisible: sidebarVisible) {
                    sidebarRequested.toggle()
                }
                Divider()
                    .overlay(HarborColor.outlineVariant.opacity(0.3))
                HStack(spacing: 0) {
                    if sidebarVisible {
                        SidebarView(model: model)
                            .frame(width: Self.sidebarWidth)
                            .background(HarborColor.surfaceLow)
                        Divider()
                            .overlay(HarborColor.outlineVariant.opacity(0.3))
                    }
                    ContentPlaceholderView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(HarborColor.paper)
        }
        .task {
            await model.start()
        }
    }
}
