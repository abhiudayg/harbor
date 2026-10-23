import CoreGraphics

enum ShellLayout {
    static let sidebarCollapseBelowWidth: CGFloat = 960
    static let companionCollapseBelowWidth: CGFloat = 1280

    static func sidebarVisible(requested: Bool, width: CGFloat) -> Bool {
        requested && width >= sidebarCollapseBelowWidth
    }

    static func companionVisible(width: CGFloat) -> Bool {
        width >= companionCollapseBelowWidth
    }
}
