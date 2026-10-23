import AppKit
import Testing
@testable import Harbor

@Suite("Harbor typography")
struct HarborTypographyTests {
    @Test("the bundled Inter family registers with the system")
    func bundledInterRegisters() {
        HarborFonts.register()

        #expect(NSFontManager.shared.availableFontFamilies.contains("Inter"))
    }
}
