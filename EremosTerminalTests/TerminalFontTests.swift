import AppKit
import XCTest
@testable import Eremos_Terminal

/// The bundled JetBrains Mono loads, with the bold and italic faces the terminal uses.
@MainActor
final class TerminalFontTests: XCTestCase {
    func testJetBrainsMonoIsBundledWithBoldAndItalic() throws {
        let font = TerminalFont.font
        XCTAssertEqual(font.familyName, "JetBrains Mono")
        XCTAssertTrue(font.isFixedPitch)

        let manager = NSFontManager.shared
        let bold = manager.convert(font, toHaveTrait: .boldFontMask)
        let italic = manager.convert(font, toHaveTrait: .italicFontMask)
        XCTAssertEqual(bold.fontName, "JetBrainsMono-Bold")
        XCTAssertEqual(italic.fontName, "JetBrainsMono-Italic")
    }
}
