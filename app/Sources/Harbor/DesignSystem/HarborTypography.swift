import AppKit
import SwiftUI

enum HarborFace: Equatable {
    case installed(String)
    case system
}

enum HarborTypography {
    static let editorialFamily = "Newsreader"
    static let monoFamily = "JetBrains Mono"

    static func face(for family: String, installed: Set<String>) -> HarborFace {
        installed.contains(family) ? .installed(family) : .system
    }

    static func editorial(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        font(for: face(for: editorialFamily, installed: installedFamilies), size: size, weight: weight)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        font(for: face(for: monoFamily, installed: installedFamilies), size: size, weight: weight)
    }

    static func chrome(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func font(for face: HarborFace, size: CGFloat, weight: Font.Weight) -> Font {
        switch face {
        case .installed(let family):
            .custom(family, size: size).weight(weight)
        case .system:
            .system(size: size, weight: weight)
        }
    }

    private static let installedFamilies = Set(NSFontManager.shared.availableFontFamilies)
}
