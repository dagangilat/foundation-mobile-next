import SwiftUI
import XCTest
@testable import FoundationMobile

final class ThemePaletteTests: XCTestCase {
    // Locks the branded presets to the exact hex values from the web
    // @plantagoai/editions kits (moma.json / tel-aviv.json / san-francisco.json),
    // as of this test's authoring. If the web kits change their palette,
    // this test must be manually re-synced — there is no automated
    // cross-repo coupling between the two codebases.

    func testMomaPaletteMatchesWebKit() {
        let p = ThemePalette.light
        XCTAssertEqual(p.bg, Color(hex: 0xf6f8fc))
        XCTAssertEqual(p.border, Color(hex: 0xe2e8f0))
        XCTAssertEqual(p.muted, Color(hex: 0x64748b))
        XCTAssertEqual(p.brandGreen, Color(hex: 0x34d399))
        XCTAssertEqual(p.brandCyan, Color(hex: 0x22d3ee))
        XCTAssertFalse(p.isDark)
    }

    func testTelAvivPaletteMatchesWebKitAndIsLight() {
        let p = ThemePalette.ocean
        XCTAssertEqual(p.bg, Color(hex: 0xeef6fb))
        XCTAssertEqual(p.brandGreen, Color(hex: 0x0ea5b7))
        XCTAssertEqual(p.brandCyan, Color(hex: 0x38bdf8))
        XCTAssertFalse(p.isDark, "tel-aviv must render light to match the web kit's mode")
    }

    func testSanFranciscoPaletteMatchesWebKitAndIsLight() {
        let p = ThemePalette.sunset
        XCTAssertEqual(p.bg, Color(hex: 0xfff7f2))
        XCTAssertEqual(p.brandGreen, Color(hex: 0xfb7185))
        XCTAssertEqual(p.brandCyan, Color(hex: 0xfbbf24))
        XCTAssertFalse(p.isDark, "san-francisco must render light to match the web kit's mode")
    }
}
