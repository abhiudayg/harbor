import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum HarborColor {
    static let paper = Color(hex: 0xF6F5F2)
    static let hairline = Color(hex: 0xD8D6CE)
    static let text = Color(hex: 0x1E2024)
    static let textSecondary = Color(hex: 0x575A61)

    static let surface = Color(hex: 0xF9F9FE)
    static let surfaceLowest = Color(hex: 0xFFFFFF)
    static let surfaceLow = Color(hex: 0xF3F3F9)
    static let surfaceContainer = Color(hex: 0xEDEDF3)
    static let surfaceContainerHigh = Color(hex: 0xE8E8ED)

    static let onSurface = Color(hex: 0x1A1C20)
    static let onSurfaceVariant = Color(hex: 0x3E4948)
    static let outline = Color(hex: 0x6E7979)
    static let outlineVariant = Color(hex: 0xBEC9C8)

    static let primary = Color(hex: 0x005454)
    static let primaryContainer = Color(hex: 0x0F6E6E)
    static let onPrimaryContainer = Color(hex: 0x9EEDEC)
    static let accentTeal = Color(hex: 0x0F6E6E)

    static let approvalFill = Color(hex: 0xF59E0B, opacity: 0.10)
    static let approvalBorder = Color(hex: 0xB45309, opacity: 0.25)
    static let approvalAction = Color(hex: 0xB45309)
    static let approvalText = Color(hex: 0x78350F)
    static let approvalDot = Color(hex: 0xF59E0B)
}
