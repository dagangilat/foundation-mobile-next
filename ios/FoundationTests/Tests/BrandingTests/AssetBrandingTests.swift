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

    /// Regression guard: an earlier pass of this same rebrand accidentally
    /// flattened `DarkerGreenTextGradient`'s dark-appearance value to equal
    /// its light-appearance value (#024A36 for both) while remapping it off
    /// Rarimo's palette. That colorset tints the "RMO" subtitle text over a
    /// near-black background image (HomeWidgetsView.swift), so flattening it
    /// dropped WCAG contrast from ~8.8:1 to ~1.9:1 — unreadable in Dark Mode.
    /// The two appearances must resolve to genuinely different colors, not
    /// just both be off-Rarimo.
    func testDarkerGreenTextGradientHasDistinctDarkAppearance() throws {
        let base = try XCTUnwrap(UIColor(named: "DarkerGreenTextGradient1"))
        let lightColor = base.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let darkColor = base.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
        lightColor.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        darkColor.getRed(&dr, green: &dg, blue: &db, alpha: &da)

        // The dark-appearance value must be meaningfully LIGHTER than the
        // light-appearance value (legible text on a dark background needs a
        // brighter color, not the same dark one) — not just "different by
        // any amount," which a 1-unit rounding difference would trivially
        // satisfy without actually fixing legibility.
        let lightLuminance = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
        let darkLuminance = 0.2126 * dr + 0.7152 * dg + 0.0722 * db
        XCTAssertGreaterThan(darkLuminance, lightLuminance + 0.2, "dark-appearance must be substantially brighter than light-appearance for legibility on a dark background")
    }

    // MARK: - WCAG contrast

    /// WCAG 2.x contrast bars.
    ///
    /// NOTE: the weighted sum a few lines above (`0.2126 * lr + ...` on raw
    /// sRGB components) is a *brightness comparison*, not relative luminance -
    /// it skips the sRGB gamma linearisation. It is fine for "is this one
    /// brighter than that one", but feeding it into a contrast ratio would
    /// report ~2.1:1 for a colour that genuinely passes. The helpers below
    /// implement the real formula, matching Android's `TextContrastTest`
    /// line for line so neither platform can drift into different maths.
    private enum WCAG {
        /// AA, normal-size text.
        static let aaNormal = 4.5
        /// The floor conventionally accepted for placeholder hint copy.
        static let placeholderFloor = 3.0
        /// Disabled text is exempt from 1.4.3 ("Incidental: text that is part
        /// of an inactive user interface component"). This is a regression
        /// floor, not a compliance claim - it pins the perceptual weight the
        /// pre-fork `#141614 @ 0.28` had (1.86:1), which the base-colour swap
        /// had eroded to 1.49:1.
        static let disabledRegressionFloor = 1.8
    }

    private func linearize(_ channel: CGFloat) -> Double {
        let c = Double(channel)
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private func luminance(_ rgb: (Double, Double, Double)) -> Double {
        0.2126 * linearize(CGFloat(rgb.0))
            + 0.7152 * linearize(CGFloat(rgb.1))
            + 0.0722 * linearize(CGFloat(rgb.2))
    }

    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    /// Contrast of a translucent text fill source-over-composited onto an
    /// opaque background token, both resolved for the same appearance.
    private func contrast(text: UIColor, background: UIColor) throws -> Double {
        let fg = components(text)
        let bg = components(background)
        XCTAssertEqual(Double(bg.a), 1.0, accuracy: 0.001, "background token must be opaque to composite against")
        let composited = (
            Double(fg.a * fg.r + (1 - fg.a) * bg.r),
            Double(fg.a * fg.g + (1 - fg.a) * bg.g),
            Double(fg.a * fg.b + (1 - fg.a) * bg.b)
        )
        let l1 = luminance(composited)
        let l2 = luminance((Double(bg.r), Double(bg.g), Double(bg.b)))
        let (hi, lo) = l1 >= l2 ? (l1, l2) : (l2, l1)
        return (hi + 0.05) / (lo + 0.05)
    }

    private func assertContrast(
        _ textToken: String,
        on backgroundToken: String,
        style: UIUserInterfaceStyle,
        atLeast floor: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let text = try XCTUnwrap(UIColor(named: textToken), file: file, line: line)
            .resolvedColor(with: traits)
        let background = try XCTUnwrap(UIColor(named: backgroundToken), file: file, line: line)
            .resolvedColor(with: traits)
        let ratio = try contrast(text: text, background: background)
        let styleName = style == .dark ? "dark" : "light"
        XCTAssertGreaterThanOrEqual(
            ratio, floor,
            String(format: "%@ on %@ (%@ appearance): %.3f:1, needs >= %.1f:1",
                   textToken, backgroundToken, styleName, ratio, floor),
            file: file, line: line
        )
    }

    /// Regression guard for the fix this test was added with.
    ///
    /// Task B3 remapped `TextSecondary`'s base colour from Rarimo's `#141614`
    /// to Foundation's lighter `muted #596171` while keeping Rarimo's `0.560`
    /// alpha, which had been tuned for the darker base. Composited over
    /// `BgPrimary #F6F9FC` that resolved to 2.38:1 - below AA's 4.5:1 for
    /// normal text and below even the 3:1 large-text floor. Nothing caught it,
    /// because every other colour test in this file asserts a *value*, and a
    /// value assertion cannot know a legal-looking hex has gone illegible
    /// against the surface it sits on.
    ///
    /// Both the text and the background are read from the asset catalogue, so
    /// this also fails if a future change moves the *background* under text
    /// that is fine today.
    func testSecondaryTextClearsWcagAaOnEveryAppearance() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            // BgPrimary is the app frame; BgSurface1 (#FFFFFF) backs cards and
            // sheets and is a lighter, independently-failing surface.
            try assertContrast("TextSecondary", on: "BgPrimary", style: style, atLeast: WCAG.aaNormal)
            try assertContrast("TextSecondary", on: "BgSurface1", style: style, atLeast: WCAG.aaNormal)
        }
    }

    func testPlaceholderTextClearsPlaceholderFloorOnEveryAppearance() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            try assertContrast("TextPlaceholder", on: "BgPrimary", style: style, atLeast: WCAG.placeholderFloor)
            try assertContrast("TextPlaceholder", on: "BgSurface1", style: style, atLeast: WCAG.placeholderFloor)
        }
    }

    func testDisabledTextHoldsItsPreForkPerceptualWeight() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            try assertContrast("TextDisabled", on: "BgPrimary", style: style, atLeast: WCAG.disabledRegressionFloor)
            try assertContrast("TextDisabled", on: "BgSurface1", style: style, atLeast: WCAG.disabledRegressionFloor)
        }
    }

    /// The compliance fix must not flatten the tier hierarchy - raising
    /// secondary's alpha to clear AA is only safe while it still reads lighter
    /// than primary and heavier than placeholder and disabled. A future "just
    /// make it opaque" fix trips this.
    func testTextTiersStayVisuallyOrdered() throws {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let background = try XCTUnwrap(UIColor(named: "BgPrimary")).resolvedColor(with: traits)
        func ratio(_ name: String) throws -> Double {
            let color = try XCTUnwrap(UIColor(named: name)).resolvedColor(with: traits)
            return try contrast(text: color, background: background)
        }
        let primary = try ratio("TextPrimary")
        let secondary = try ratio("TextSecondary")
        let placeholder = try ratio("TextPlaceholder")
        let disabled = try ratio("TextDisabled")

        XCTAssertGreaterThan(primary, secondary * 1.2, "primary must clearly out-contrast secondary")
        XCTAssertGreaterThan(secondary, placeholder, "secondary must out-contrast placeholder")
        XCTAssertGreaterThan(placeholder, disabled, "placeholder must out-contrast disabled")
    }

    /// iOS's `BgPrimary` (and every other `Bg*` token) declares the SAME value
    /// for its default and its dark appearance, so `.preferredColorScheme(.dark)`
    /// does not actually darken this surface - dark-mode text still composites
    /// onto `#F6F9FC`. That is why `TextSecondary`'s two appearances now carry
    /// the same alpha: the pre-fix dark value of `0.500` was *lower* than the
    /// light one, i.e. strictly worse contrast against an identical backdrop.
    ///
    /// This test pins that reasoning to the asset catalogue. If someone later
    /// gives `BgPrimary` a genuinely dark appearance, this fails and forces the
    /// dark text alphas to be re-derived rather than silently inherited.
    func testBgPrimaryHasNoDistinctDarkAppearance() throws {
        let background = try XCTUnwrap(UIColor(named: "BgPrimary"))
        let light = components(background.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
        let dark = components(background.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
        XCTAssertEqual(Double(light.r), Double(dark.r), accuracy: 0.002)
        XCTAssertEqual(Double(light.g), Double(dark.g), accuracy: 0.002)
        XCTAssertEqual(Double(light.b), Double(dark.b), accuracy: 0.002)
    }
}
