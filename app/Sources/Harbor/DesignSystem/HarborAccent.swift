import SwiftUI

struct HarborAccent: Equatable, Sendable {
    let fill: Color
    let ink: Color

    static let home = HarborAccent(fill: Color(hex: 0x275D50), ink: Color(hex: 0x1E473D))
    static let triage = HarborAccent(fill: Color(hex: 0x2A6557), ink: Color(hex: 0x235C4E))
    static let commandBar = HarborAccent(fill: Color(hex: 0x2A6557), ink: Color(hex: 0x1D5246))
    static let inbox = HarborAccent(fill: Color(hex: 0x0F6E6E), ink: Color(hex: 0x005454))
    static let assistant = HarborAccent(fill: Color(hex: 0x2B6B5C), ink: Color(hex: 0x143C34))
}

private struct HarborAccentKey: EnvironmentKey {
    static let defaultValue = HarborAccent.home
}

extension EnvironmentValues {
    var harborAccent: HarborAccent {
        get { self[HarborAccentKey.self] }
        set { self[HarborAccentKey.self] = newValue }
    }
}
