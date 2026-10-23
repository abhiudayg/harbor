import SwiftUI

@main
struct HarborApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ShellView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
