import SwiftUI
import UIKit
import Foundation
import XCTest
@testable import FoundationMobile

final class ThemePaletteTests: XCTestCase {
    // Locks the branded presets to the exact hex values from the web
    // @plantagoai/editions v2 kits (foundation.json / moma.json / tel-aviv.json /
    // san-francisco.json), as of this test's authoring. If the web kits change
    // their palette, this test must be manually re-synced — there is no
    // automated cross-repo coupling between the two codebases.
    //
    // brandGreen asserts the accessible brandInk tier; brandFill asserts the
    // bright decorative brand value — the same accessibility split the web
    // package enforces via its own contrast test.

    func testFoundationPaletteMatchesWebKit() {
        let p = ThemePalette.foundation
        XCTAssertEqual(p.bg, Color(hex: 0xf6f9fc))
        XCTAssertEqual(p.border, Color(hex: 0xe6ebf1))
        XCTAssertEqual(p.muted, Color(hex: 0x596171))
        XCTAssertEqual(p.brandGreen, Color(hex: 0x047857))
        XCTAssertEqual(p.brandFill, Color(hex: 0x34d399))
        XCTAssertEqual(p.brandCyan, Color(hex: 0x22d3ee))
        XCTAssertFalse(p.isDark)
    }

    func testMomaPaletteMatchesWebKit() {
        let p = ThemePalette.moma
        XCTAssertEqual(p.bg, Color(hex: 0xf6f7f8))
        XCTAssertEqual(p.border, Color(hex: 0xe5e7eb))
        XCTAssertEqual(p.muted, Color(hex: 0x6b7280))
        XCTAssertEqual(p.brandGreen, Color(hex: 0xb91c1c))
        XCTAssertEqual(p.brandFill, Color(hex: 0xef4444))
        XCTAssertEqual(p.brandCyan, Color(hex: 0x9ca3af))
        XCTAssertFalse(p.isDark)
    }

    func testTelAvivPaletteMatchesWebKitAndIsLight() {
        let p = ThemePalette.ocean
        XCTAssertEqual(p.bg, Color(hex: 0xeef6fb))
        XCTAssertEqual(p.brandGreen, Color(hex: 0x0e7490))
        XCTAssertEqual(p.brandFill, Color(hex: 0x0ea5b7))
        XCTAssertEqual(p.brandCyan, Color(hex: 0x38bdf8))
        XCTAssertFalse(p.isDark, "tel-aviv must render light to match the web kit's mode")
    }

    func testSanFranciscoPaletteMatchesWebKitAndIsLight() {
        let p = ThemePalette.sunset
        XCTAssertEqual(p.bg, Color(hex: 0xfff7f2))
        XCTAssertEqual(p.brandGreen, Color(hex: 0xbe123c))
        XCTAssertEqual(p.brandFill, Color(hex: 0xfb7185))
        XCTAssertEqual(p.brandCyan, Color(hex: 0xfbbf24))
        XCTAssertFalse(p.isDark, "san-francisco must render light to match the web kit's mode")
    }

    // MARK: - Accessibility gate (mirrors the web package's contrast test)

    /// WCAG relative luminance / contrast (sRGB) — same formula the web
    /// package's surfaces.test.ts uses.
    private func contrast(_ a: Color, _ b: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            let ui = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &bl, alpha: &al)
            func channel(_ c: CGFloat) -> Double {
                let cd = Double(c)
                return cd <= 0.03928 ? cd / 12.92 : pow((cd + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(bl)
        }
        let values = [luminance(a), luminance(b)].sorted(by: >)
        return (values[0] + 0.05) / (values[1] + 0.05)
    }

    func testBrandGreenIsAccessibleOnSurfaceForEveryLightEdition() {
        for (name, palette) in [
            ("foundation", ThemePalette.foundation),
            ("moma", ThemePalette.moma),
            ("tel-aviv", ThemePalette.ocean),
            ("san-francisco", ThemePalette.sunset),
        ] {
            XCTAssertGreaterThanOrEqual(
                contrast(palette.brandGreen, palette.surface), 4.5,
                "\(name) brandGreen must be >=4.5:1 on its white surface"
            )
        }
    }
}
