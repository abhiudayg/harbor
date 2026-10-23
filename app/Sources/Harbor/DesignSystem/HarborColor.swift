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
    static let paper = Color(hex: 0xF6F8F6)
    static let hairline = Color(hex: 0xD9DADC)
    static let text = Color(hex: 0x19221F)

    static let surface = Color(hex: 0xF6F8F6)
    static let surfaceLowest = Color(hex: 0xFFFFFF)
    static let surfaceLow = Color(hex: 0xEDF5F2)
    static let surfaceContainer = Color(hex: 0xE7EEEA)
    static let surfaceContainerHigh = Color(hex: 0xD5DFD9)

    static let onSurface = Color(hex: 0x19221F)
    static let onSurfaceVariant = Color(hex: 0x3E4948)
    static let outline = Color(hex: 0x6E7979)
    static let outlineVariant = Color(hex: 0xC8D8D1)

    static let primary = Color(hex: 0x1E473D)
    static let primaryContainer = Color(hex: 0x2A6557)
    static let onPrimaryContainer = Color(hex: 0xE3ECE7)
    static let accentTeal = Color(hex: 0x3D7B6F)
    static let primaryFixed = Color(hex: 0xD5E8DF)

    static let approvalFill = Color(hex: 0xF59E0B, opacity: 0.10)
    static let approvalBorder = Color(hex: 0xB45309, opacity: 0.25)
    static let approvalAction = Color(hex: 0xB45309)
    static let approvalText = Color(hex: 0x78350F)
    static let tertiaryGreen = Color(hex: 0x1B4D3E)
    static let error = Color(hex: 0xBA1A1A)

    static let surfaceContainerLow = Color(hex: 0xEEF4F1)
    static let borderSubtle = Color(hex: 0xD9DADC)
    static let metricPositive = Color(hex: 0x3D7B6F)
    static let codeString = Color(hex: 0x904D00)
    static let statusAmber = Color(hex: 0xD97706)
    static let amberBadgeFill = Color(hex: 0xFEF3C7)
    static let amberBadgeBorder = Color(hex: 0xFDE68A)
}
