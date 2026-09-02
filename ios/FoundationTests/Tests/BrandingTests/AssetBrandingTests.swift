import SwiftUI
import XCTest
@testable import FoundationMobile

/// Catches brand assets that survived the rebrand. An icon or splash mark is
/// exactly the kind of leak the spec calls out as an App Store submission risk.
final class AssetBrandingTests: XCTestCase {
    func testRarimeSplashMarkIsGone() {
        // The upstream symbol must no longer resolve.
        XCTAssertNil(UIImage(named: "Rarime"))
    }

    func testFoundationMarkExists() {
        XCTAssertNotNil(UIImage(named: "FoundationMark"))
    }

    func testAlternateAppIconsAreFoundations() {
        // Upstream shipped BlackIcon/WhiteIcon/GreenIcon/GradientIcon/CatIcon.
        // CatIcon is a Rarimo in-joke and must not ship.
        XCTAssertNil(UIImage(named: "CatIcon"))
        XCTAssertNotNil(UIImage(named: "BlackIcon"))
    }

    func testPrimaryAccentMatchesFoundationBrand() throws {
        let color = try XCTUnwrap(UIColor(named: "PrimaryMain"))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Foundation brandGreen = #047857, from the `foundation` ThemePalette
        // in the pre-fork shell's Theme.swift (the palette foundation.json
        // selects, which is the default profile for Debug and Release).
        XCTAssertEqual(Double(r), 4.0 / 255.0, accuracy: 0.01)     // 0x04
        XCTAssertEqual(Double(g), 120.0 / 255.0, accuracy: 0.01)   // 0x78
        XCTAssertEqual(Double(b), 87.0 / 255.0, accuracy: 0.01)    // 0x57
    }

    /// `Gradients.gradientFirst` (`AdditionalGradientFirstStart`/`End`) tints
    /// the FoundationMark splash logo (AppView.swift), the welcome screen
    /// (IntroView.swift), and the home onboarding step icon
    /// (HomeOnboardingView.swift) — the app's most prominent brand surfaces.
    /// A static asset-existence check can't catch this gradient still
    /// carrying Rarimo's old neon-lime hex values under a renamed symbol, so
    /// this test asserts the actual rendered color.
    func testSplashGradientMatchesFoundationBrand() throws {
        let start = try XCTUnwrap(UIColor(named: "AdditionalGradientFirstStart"))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        start.getRed(&r, green: &g, blue: &b, alpha: &a)
        // brandGreen #047857
        XCTAssertEqual(Double(r), 4.0 / 255.0, accuracy: 0.01)     // 0x04
        XCTAssertEqual(Double(g), 120.0 / 255.0, accuracy: 0.01)   // 0x78
        XCTAssertEqual(Double(b), 87.0 / 255.0, accuracy: 0.01)    // 0x57

        let end = try XCTUnwrap(UIColor(named: "AdditionalGradientFirstEnd"))
        end.getRed(&r, green: &g, blue: &b, alpha: &a)
        // brandFill #34D399
        XCTAssertEqual(Double(r), 52.0 / 255.0, accuracy: 0.01)    // 0x34
        XCTAssertEqual(Double(g), 211.0 / 255.0, accuracy: 0.01)   // 0xD3
        XCTAssertEqual(Double(b), 153.0 / 255.0, accuracy: 0.01)   // 0x99
    }
}
