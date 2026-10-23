import Testing
@testable import Harbor

@Suite("Harbor typography fallback")
struct HarborTypographyTests {
    @Test("uses the installed family when the OS provides it")
    func usesInstalledFamily() {
        let face = HarborTypography.face(for: "Newsreader", installed: ["Newsreader", "Helvetica"])

        #expect(face == .installed("Newsreader"))
    }

    @Test("falls back to the system font when the family is missing")
    func fallsBackToSystemFont() {
        let face = HarborTypography.face(for: "JetBrains Mono", installed: ["Helvetica"])

        #expect(face == .system)
    }

    @Test("falls back to the system font when no families are installed")
    func fallsBackWhenNothingInstalled() {
        let face = HarborTypography.face(for: "Newsreader", installed: [])

        #expect(face == .system)
    }
}
