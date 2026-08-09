# Foundation Mobile Light Editions Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the web app's Stripe-style light `@plantagoai/editions` v2 identity onto foundation-mobile's `Theme.swift` for the 4 web-matched editions (foundation/san-francisco/tel-aviv/moma), and give the mobile hero a native animated-mesh treatment.

**Architecture:** Hand-port v2 hex values into `ThemePalette` Swift constants (same pattern the app already uses — `theme.palette` is a name string resolved to a hardcoded struct, never JSON-driven at runtime). Add a new `AnimatedMeshHero` SwiftUI primitive built on native `MeshGradient` (iOS 18+), wired into the existing `PillarsHero` component. The 4 mobile-only security editions are untouched.

**Tech Stack:** SwiftUI, XCTest, Xcode project build settings (`project.pbxproj`), `select-profile.sh` profile switching.

**Spec:** `docs/superpowers/specs/2026-08-09-light-editions-redesign-design.md`

## Global Constraints

- Scope is exactly 4 editions: `foundation`, `san-francisco` (palette name `sunset`), `tel-aviv` (palette name `ocean`), `moma`. Never touch `hisec-global`, `hisec-mdl`, `lowsec-attest`, `standardsec` profiles or the `midnight`/`forest`/`steel` palettes' existing values.
- `IPHONEOS_DEPLOYMENT_TARGET` moves from 16.0 to 18.0 — required for native `MeshGradient`. This is a real device-support drop; call it out in the final commit/PR.
- `brandGreen` on every in-scope palette holds the web `brandInk` value (accessible, ≥4.5:1 on white) — never the bright `brand` value. The bright value goes in the new `brandFill` field.
- Palette hex values are exactly those in the spec / this plan's task bodies — do not invent or approximate.
- Editions without `meshBase`/`meshBlobs` (the 4 out-of-scope editions) must render with **zero visual change** — no flat-color background layer standing in for the mesh, no clipped shape edge visible.
- Commit after every task.

---

### Task 1: `ThemePalette` v2 — new fields, renamed/new/corrected palette catalog

**Files:**
- Modify: `ios/FoundationMobile/Theme.swift`
- Test: `ios/FoundationMobileTests/ThemePaletteTests.swift`

**Interfaces (Produces — used by every later task):**
- `ThemePalette` gains `brandFill: Color`, `meshBase: Color?`, `meshBlobs: [Color]?` (declared in that order, immediately after `brandCyan` and after `isDark` respectively — see full struct below).
- New `ThemePalette.foundation`, `ThemePalette.moma`. `ThemePalette.light` is deleted. `ThemePalette.ocean`/`.sunset` keep their names with corrected `brandGreen`/new `brandFill`/`meshBase`/`meshBlobs`. `.midnight`/`.forest`/`.steel` unchanged except the two new fields (`brandFill` = same value as their existing `brandGreen`, `meshBase`/`meshBlobs` = `nil`).
- `Theme.named(_:)` maps `"foundation"` → `.foundation`, `"moma"` → `.moma`; the `"light"` case is removed; default remains `.midnight`.
- `Theme` enum gains `static var brandFill: Color`, `static var meshBase: Color?`, `static var meshBlobs: [Color]?`.

- [ ] **Step 1: Update `ThemePaletteTests.swift` to the new/corrected expectations** (this will fail to *compile* until Step 3 lands — that's the RED state for a typed language):

```swift
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
```

- [ ] **Step 2: Run to verify it fails to compile** — `ThemePalette.foundation`/`.moma`/`.brandFill` don't exist yet.

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:FoundationMobileTests/ThemePaletteTests
```
Expected: BUILD FAILED — `type 'ThemePalette' has no member 'foundation'` (and similar).

- [ ] **Step 3: Rewrite `Theme.swift`'s `ThemePalette` struct, `Theme` enum accessors, presets, and `named(_:)`.**

Replace the `struct ThemePalette` declaration with:

```swift
struct ThemePalette: Sendable {
    let bg: Color
    let surface: Color
    let border: Color
    let muted: Color
    let brandGreen: Color    // primary accent — accessible/interactive tier (web: brandInk)
    let brandFill: Color     // bright decorative-fill-only accent (web: brand) — gradients/chip tints, never text
    let brandCyan: Color     // secondary accent (web: brandAlt)
    let voice: Color
    let share: Color
    let market: Color
    let text: Color          // primary text on bg/surface
    let onAccent: Color      // text/glyph on a filled accent
    let isDark: Bool         // drives preferredColorScheme for system chrome
    let meshBase: Color?     // animated mesh hero base wash; nil = no mesh, no background layer at all
    let meshBlobs: [Color]?  // animated mesh hero blob colors (4); nil when meshBase is nil
}
```

Replace the `Theme` enum's accessor block (everything from `static var bg` through `static var pillBg`) with:

```swift
    static var bg: Color { palette.bg }
    static var surface: Color { palette.surface }
    static var border: Color { palette.border }
    static var muted: Color { palette.muted }
    static var brandGreen: Color { palette.brandGreen }
    static var brandFill: Color { palette.brandFill }
    static var brandCyan: Color { palette.brandCyan }
    static var voice: Color { palette.voice }
    static var share: Color { palette.share }
    static var market: Color { palette.market }
    static var text: Color { palette.text }
    static var onAccent: Color { palette.onAccent }
    static var pillBg: Color { palette.brandGreen.opacity(0.12) }
```

Replace the entire `extension ThemePalette { ... }` preset block with:

```swift
extension ThemePalette {
    // midnight = the original dark look. onAccent is black to match the
    // pre-theming `.black` button labels exactly. Still the AppConfig
    // default fallback for any profile that omits `theme` (lowsec-attest,
    // standardsec) and the live palette for the mobile-only security
    // editions that have no web v2 kit.
    static let midnight = ThemePalette(
        bg: Color(hex: 0x0a0e27), surface: Color(hex: 0x0f1636),
        border: Color(hex: 0x1e2a5a), muted: Color(hex: 0x9aa3c7),
        brandGreen: Color(hex: 0x34d399), brandFill: Color(hex: 0x34d399), brandCyan: Color(hex: 0x22d3ee),
        voice: Color(hex: 0x818cf8), share: Color(hex: 0x2dd4bf), market: Color(hex: 0x22d3ee),
        text: Color(hex: 0xffffff), onAccent: Color(hex: 0x000000), isDark: true,
        meshBase: nil, meshBlobs: nil
    )

    // foundation = the Foundation edition's own light identity (v2 kit), the
    // default profile. Matches @plantagoai/editions foundation.json exactly.
    // brandGreen carries the accessible brandInk tier (used broadly — CTAs,
    // active rings, text); brandFill is the bright brand value, decorative-
    // fill only (never text). Replaces the old dark `midnight` default.
    static let foundation = ThemePalette(
        bg: Color(hex: 0xf6f9fc), surface: Color(hex: 0xffffff),
        border: Color(hex: 0xe6ebf1), muted: Color(hex: 0x596171),
        brandGreen: Color(hex: 0x047857), brandFill: Color(hex: 0x34d399), brandCyan: Color(hex: 0x22d3ee),
        voice: Color(hex: 0x6366f1), share: Color(hex: 0x0d9488), market: Color(hex: 0x0891b2),
        text: Color(hex: 0x0a0e27), onAccent: Color(hex: 0xffffff), isDark: false,
        meshBase: Color(hex: 0xe8fbf4),
        meshBlobs: [Color(hex: 0x34d399), Color(hex: 0x22d3ee), Color(hex: 0x60a5fa), Color(hex: 0xa78bfa)]
    )

    // ocean = the Tel Aviv edition. Light mode, matching the web
    // @plantagoai/editions tel-aviv.json v2 kit exactly. Name kept as `ocean`
    // (no longer a dark "ocean" look) to avoid touching tel-aviv.json's
    // `theme.palette: "ocean"` string. brandGreen now carries the accessible
    // brandInk tier (was the bright `brand` value pre-v2); brandFill holds
    // that bright value for decorative-only use.
    static let ocean = ThemePalette(
        bg: Color(hex: 0xeef6fb), surface: Color(hex: 0xffffff),
        border: Color(hex: 0xd6e6f2), muted: Color(hex: 0x5b7184),
        brandGreen: Color(hex: 0x0e7490), brandFill: Color(hex: 0x0ea5b7), brandCyan: Color(hex: 0x38bdf8),
        voice: Color(hex: 0x38bdf8), share: Color(hex: 0x2dd4bf), market: Color(hex: 0x22d3ee),
        text: Color(hex: 0x0a1a2e), onAccent: Color(hex: 0xffffff), isDark: false,
        meshBase: Color(hex: 0xe6f6fb),
        meshBlobs: [Color(hex: 0x0ea5b7), Color(hex: 0x38bdf8), Color(hex: 0x2563eb), Color(hex: 0x67e8f9)]
    )

    static let forest = ThemePalette(
        bg: Color(hex: 0x0a1f14), surface: Color(hex: 0x0f2a1c),
        border: Color(hex: 0x1d4030), muted: Color(hex: 0x93b8a4),
        brandGreen: Color(hex: 0x4ade80), brandFill: Color(hex: 0x4ade80), brandCyan: Color(hex: 0xa3e635),
        voice: Color(hex: 0x86efac), share: Color(hex: 0x4ade80), market: Color(hex: 0x34d399),
        text: Color(hex: 0xf0fdf4), onAccent: Color(hex: 0x052e16), isDark: true,
        meshBase: nil, meshBlobs: nil
    )

    // sunset = the San Francisco edition. Light mode, matching the web
    // @plantagoai/editions san-francisco.json v2 kit exactly. Name kept as
    // `sunset` (no longer a dark "sunset" look) to avoid touching
    // san-francisco.json's `theme.palette: "sunset"` string. brandGreen now
    // carries the accessible brandInk tier (was the bright `brand` value
    // pre-v2); brandFill holds that bright value for decorative-only use.
    static let sunset = ThemePalette(
        bg: Color(hex: 0xfff7f2), surface: Color(hex: 0xffffff),
        border: Color(hex: 0xf1ddd0), muted: Color(hex: 0x8a6f60),
        brandGreen: Color(hex: 0xbe123c), brandFill: Color(hex: 0xfb7185), brandCyan: Color(hex: 0xfbbf24),
        voice: Color(hex: 0xc084fc), share: Color(hex: 0xfb7185), market: Color(hex: 0xfbbf24),
        text: Color(hex: 0x2a160c), onAccent: Color(hex: 0xffffff), isDark: false,
        meshBase: Color(hex: 0xfff1ec),
        meshBlobs: [Color(hex: 0xfb7185), Color(hex: 0xfbbf24), Color(hex: 0xf97316), Color(hex: 0xf43f5e)]
    )

    // steel = the High Security — Global edition. Dark steel-navy base with an
    // electric-blue primary accent — global, secure-tech; distinct from the
    // Foundation green and the MoMA light theme. Pairs with the Aegis lockup.
    static let steel = ThemePalette(
        bg: Color(hex: 0x0a1320), surface: Color(hex: 0x102236),
        border: Color(hex: 0x1e3a5a), muted: Color(hex: 0x8aa0bd),
        brandGreen: Color(hex: 0x38bdf8), brandFill: Color(hex: 0x38bdf8), brandCyan: Color(hex: 0x22d3ee),
        voice: Color(hex: 0x38bdf8), share: Color(hex: 0x22d3ee), market: Color(hex: 0x5eead4),
        text: Color(hex: 0xeaf2fb), onAccent: Color(hex: 0x04121f), isDark: true,
        meshBase: nil, meshBlobs: nil
    )

    // moma = the MoMA Member edition. Light mode, matching the web
    // @plantagoai/editions moma.json v2 kit exactly — a deliberate departure
    // from the app's green identity: silver-gallery monochrome with a single
    // red pop. Replaces the old generic `light` preset (which MoMA
    // incorrectly shared, with no edition-specific identity of its own).
    static let moma = ThemePalette(
        bg: Color(hex: 0xf6f7f8), surface: Color(hex: 0xffffff),
        border: Color(hex: 0xe5e7eb), muted: Color(hex: 0x6b7280),
        brandGreen: Color(hex: 0xb91c1c), brandFill: Color(hex: 0xef4444), brandCyan: Color(hex: 0x9ca3af),
        voice: Color(hex: 0x9ca3af), share: Color(hex: 0x4b5563), market: Color(hex: 0xef4444),
        text: Color(hex: 0x0f0f10), onAccent: Color(hex: 0xffffff), isDark: false,
        meshBase: Color(hex: 0xf3f4f6),
        meshBlobs: [Color(hex: 0xd1d5db), Color(hex: 0x9ca3af), Color(hex: 0xe5e7eb), Color(hex: 0xef4444)]
    )

    static func named(_ name: String) -> ThemePalette {
        switch name.lowercased() {
        case "foundation": return .foundation
        case "ocean":  return .ocean
        case "forest": return .forest
        case "sunset": return .sunset
        case "steel":  return .steel
        case "moma":   return .moma
        default:       return .midnight
        }
    }
}
```

Leave the trailing `extension Color { init(hex:) ... }` untouched.

- [ ] **Step 4: Run to verify pass:**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:FoundationMobileTests/ThemePaletteTests
```
Expected: TEST SUCCEEDED, all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/FoundationMobile/Theme.swift ios/FoundationMobileTests/ThemePaletteTests.swift
git commit -m "feat(theme): v2 palette catalog — foundation/moma light identities, brandInk/brandFill split, mesh data"
```

---

### Task 2: Profile JSON renames — `foundation.json` and `moma.json` point at their new palette names

**Files:**
- Modify: `ios/FoundationMobile/Resources/profiles/foundation.json`
- Modify: `ios/FoundationMobile/Resources/profiles/moma.json`
- Test: `ios/FoundationMobileTests/ProfileTierTests.swift`

**Interfaces:**
- Consumes: `ThemePalette.named(_:)` and `.foundation`/`.moma` from Task 1.
- Produces: `foundation.json`'s `theme.palette` is `"foundation"`; `moma.json`'s is `"moma"`. Nothing else in these files changes.

- [ ] **Step 1: Add a failing test to `ProfileTierTests.swift`** — append this method inside the existing `final class ProfileTierTests: XCTestCase { ... }`, right after `testAllBundledProfilesDecodeAgainstFullAppConfigSchema`:

```swift
    // MARK: - theme.palette strings resolve to their intended v2 Theme names

    /// Reads each web-matched profile JSON straight off disk (same pattern as
    /// the schema test above) and asserts its theme.palette string is the
    /// v2-renamed value, not a leftover pre-redesign name.
    func testWebMatchedEditionsUseTheirV2PaletteNames() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let profilesDir = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FoundationMobile/Resources/profiles")

        let expected: [String: String] = [
            "foundation.json": "foundation",
            "moma.json": "moma",
            "tel-aviv.json": "ocean",
            "san-francisco.json": "sunset",
        ]
        for (file, expectedPaletteName) in expected {
            let data = try Data(contentsOf: profilesDir.appendingPathComponent(file))
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            XCTAssertEqual(config.themePaletteName, expectedPaletteName, "\(file) theme.palette")
        }
    }
```

- [ ] **Step 2: Run to verify it fails:**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:FoundationMobileTests/ProfileTierTests/testWebMatchedEditionsUseTheirV2PaletteNames
```
Expected: FAIL — `foundation.json` still says `"midnight"`, `moma.json` still says `"light"`.

- [ ] **Step 3: Edit `foundation.json`** — inside the `"theme"` block, change:

```json
    "palette": "midnight",
```
to:
```json
    "palette": "foundation",
```

- [ ] **Step 4: Edit `moma.json`** — inside the `"theme"` block, change:

```json
    "palette": "light",
```
to:
```json
    "palette": "moma",
```

- [ ] **Step 5: Run to verify pass** — same command as Step 2. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add ios/FoundationMobile/Resources/profiles/foundation.json ios/FoundationMobile/Resources/profiles/moma.json ios/FoundationMobileTests/ProfileTierTests.swift
git commit -m "feat(profiles): foundation/moma theme.palette point at their new v2 Theme names"
```

---

### Task 3: `AnimatedMeshHero` primitive — native mesh gradient + angled cut

**Files:**
- Create: `ios/FoundationMobile/AnimatedMeshHero.swift`
- Test: `ios/FoundationMobileTests/AnimatedMeshHeroTests.swift`

**Interfaces (Produces — consumed by Task 4):**
- `AnimatedMeshHero<Content: View>(content: () -> Content): View` — wraps `content` with a `.background()` mesh gradient when the active `Theme.palette` carries mesh data; renders `content` with **no** background layer when it doesn't.
- `AnimatedMeshHero.meshPoints(at: TimeInterval) -> [SIMD2<Float>]` and `.meshColors(base: Color, blobs: [Color]) -> [Color]` — internal pure functions, exposed `static` for unit testing.
- `AngledCutShape: Shape` — the diagonal-cut clip shape, reusable independently if a future screen needs it.

**Requires iOS 18** (native `MeshGradient`).

- [ ] **Step 1: Write the failing test** — create `ios/FoundationMobileTests/AnimatedMeshHeroTests.swift`:

```swift
import SwiftUI
import XCTest
@testable import FoundationMobile

final class AnimatedMeshHeroTests: XCTestCase {
    func testMeshPointsKeepCornersPinnedAtAnyTime() {
        for t: TimeInterval in [0.0, 5.0, 12.3, 100.0] {
            let points = AnimatedMeshHero<EmptyView>.meshPoints(at: t)
            XCTAssertEqual(points.count, 9)
            XCTAssertEqual(points[0], SIMD2<Float>(0, 0), "top-left corner must stay pinned at t=\(t)")
            XCTAssertEqual(points[2], SIMD2<Float>(1, 0), "top-right corner must stay pinned at t=\(t)")
            XCTAssertEqual(points[6], SIMD2<Float>(0, 1), "bottom-left corner must stay pinned at t=\(t)")
            XCTAssertEqual(points[8], SIMD2<Float>(1, 1), "bottom-right corner must stay pinned at t=\(t)")
        }
    }

    func testMeshColorsPlacesBlobsAtTheFourEdgeMidpoints() {
        let base = Color.white
        let blobs = [Color.red, Color.green, Color.blue, Color.yellow]
        let colors = AnimatedMeshHero<EmptyView>.meshColors(base: base, blobs: blobs)
        XCTAssertEqual(colors.count, 9)
        XCTAssertEqual(colors[1], .red)    // top-mid
        XCTAssertEqual(colors[3], .green)  // mid-left
        XCTAssertEqual(colors[5], .blue)   // mid-right
        XCTAssertEqual(colors[7], .yellow) // bottom-mid
        XCTAssertEqual(colors[0], base)
        XCTAssertEqual(colors[4], base)
        XCTAssertEqual(colors[8], base)
    }

    func testAngledCutShapeStaysWithinItsRect() {
        let shape = AngledCutShape()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        XCTAssertEqual(path.boundingRect.minX, 0, accuracy: 0.01)
        XCTAssertEqual(path.boundingRect.maxX, 300, accuracy: 0.01)
        XCTAssertEqual(path.boundingRect.minY, 0, accuracy: 0.01)
        XCTAssertEqual(path.boundingRect.maxY, 200, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run to verify it fails to compile** — `AnimatedMeshHero`/`AngledCutShape` don't exist yet.

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:FoundationMobileTests/AnimatedMeshHeroTests
```
Expected: BUILD FAILED — `cannot find type 'AnimatedMeshHero' in scope`.

- [ ] **Step 3: Create `ios/FoundationMobile/AnimatedMeshHero.swift`:**

```swift
import SwiftUI
import Foundation

// Native SwiftUI equivalent of the web app's animated MeshHero (see
// docs/superpowers/specs/2026-08-09-light-editions-redesign-design.md §3).
// Wraps hero content in a living gradient mesh with an angled bottom cut,
// sourced from the active edition's Theme.palette.meshBase/meshBlobs.
// Editions without mesh data (the mobile-only security editions) render
// their content with no background layer at all — pixel-identical to
// pre-redesign behavior.
//
// Requires iOS 18 (SwiftUI's MeshGradient).
struct AnimatedMeshHero<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(meshBackground)
    }

    @ViewBuilder
    private var meshBackground: some View {
        if let base = Theme.palette.meshBase,
           let blobs = Theme.palette.meshBlobs,
           blobs.count == 4 {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: Self.meshPoints(at: timeline.date.timeIntervalSinceReferenceDate),
                    colors: Self.meshColors(base: base, blobs: blobs)
                )
            }
            .clipShape(AngledCutShape())
        }
        // else: no background layer — out-of-scope editions render exactly
        // as they did before this component existed.
    }

    /// 3x3 control-point grid for MeshGradient, in unit-square (0...1)
    /// space. Corners stay pinned so the mesh always fully covers its
    /// bounding rect; the 4 edge-midpoints and the center drift slowly on
    /// independent sine phases for an organic, non-repeating feel — the
    /// SwiftUI-native equivalent of the web mesh's 21-30s blob drift.
    static func meshPoints(at time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time)
        func wobble(_ seed: Float, amplitude: Float = 0.05, speed: Float = 0.25) -> Float {
            amplitude * sin(t * speed + seed)
        }
        return [
            SIMD2(0, 0),
            SIMD2(0.5 + wobble(0.0, amplitude: 0.03), 0 + wobble(1.4, amplitude: 0.03)),
            SIMD2(1, 0),
            SIMD2(0 + wobble(2.1, amplitude: 0.03), 0.5 + wobble(0.7)),
            SIMD2(0.5 + wobble(3.6), 0.5 + wobble(4.2)),
            SIMD2(1 + wobble(1.9, amplitude: 0.03), 0.5 + wobble(2.8)),
            SIMD2(0, 1),
            SIMD2(0.5 + wobble(5.0, amplitude: 0.03), 1 + wobble(0.3, amplitude: 0.03)),
            SIMD2(1, 1),
        ]
    }

    /// Maps base + 4 blob colors onto the 3x3 grid: blobs sit at the 4
    /// edge-midpoints (the points that actually drift), base fills the
    /// corners and center.
    static func meshColors(base: Color, blobs: [Color]) -> [Color] {
        [
            base, blobs[0], base,
            blobs[1], base, blobs[2],
            base, blobs[3], base,
        ]
    }
}

/// Angled-cut trapezoid — the SwiftUI equivalent of the web mesh hero's
/// `clip-path: polygon(0 0, 100% 0, 100% 62%, 0 100%)`.
struct AngledCutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 4: Run to verify pass:**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:FoundationMobileTests/AnimatedMeshHeroTests
```
Expected: TEST SUCCEEDED, all 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/FoundationMobile/AnimatedMeshHero.swift ios/FoundationMobileTests/AnimatedMeshHeroTests.swift
git commit -m "feat(hero): AnimatedMeshHero primitive — native MeshGradient, angled cut, reduced-motion gated"
```

---

### Task 4: Wire `AnimatedMeshHero` into `PillarsHero`

**Files:**
- Modify: `ios/FoundationMobile/PillarsHero.swift`

**Interfaces:**
- Consumes: `AnimatedMeshHero` from Task 3.
- No new test — `PillarsHero` has no existing unit test (it's a SwiftUI view with no snapshot-testing infra in this codebase); covered by Task 7's Simulator verification.

- [ ] **Step 1: Edit `PillarsHero.swift`** — replace the `struct PillarsHero: View` body:

```swift
struct PillarsHero: View {
    var body: some View {
        // A white-label profile (e.g. MoMA) can replace the
        // composed three-pillar wordmark with a single bundled hero image
        // by setting theme.branding.hero.mode = "image" in its profile JSON.
        // Falls through to the built-in pillars otherwise.
        if let hero = AppConfig.shared.theme?.branding?.hero,
           hero.mode == "image",
           let assetName = Theme.palette.isDark ? (hero.darkAsset ?? hero.asset) : hero.asset {
            brandedHero(assetName)
        } else {
            pillars
        }
    }
```

with:

```swift
struct PillarsHero: View {
    var body: some View {
        AnimatedMeshHero {
            heroContent
        }
    }

    // A white-label profile (e.g. MoMA) can replace the composed
    // three-pillar wordmark with a single bundled hero image by setting
    // theme.branding.hero.mode = "image" in its profile JSON. Falls through
    // to the built-in pillars otherwise. Wrapped in AnimatedMeshHero above
    // so both modes get the same living-mesh background for editions that
    // carry mesh data.
    @ViewBuilder
    private var heroContent: some View {
        if let hero = AppConfig.shared.theme?.branding?.hero,
           hero.mode == "image",
           let assetName = Theme.palette.isDark ? (hero.darkAsset ?? hero.asset) : hero.asset {
            brandedHero(assetName)
        } else {
            pillars
        }
    }
```

(Everything below — `pillars`, `brandedHero(_:)`, `pillar(asset:label:color:)` — is unchanged.)

- [ ] **Step 2: Build to confirm it compiles** (no test target — this is a pure integration step, verified visually in Task 7):

```bash
cd ios && xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ios/FoundationMobile/PillarsHero.swift
git commit -m "feat(hero): wire AnimatedMeshHero into PillarsHero (both pillars and image modes)"
```

---

### Task 5: Bump `IPHONEOS_DEPLOYMENT_TARGET` to iOS 18

**Files:**
- Modify: `ios/FoundationMobile.xcodeproj/project.pbxproj`

**Interfaces:** No code interface — build setting only. Required by Task 3's `MeshGradient` usage (already landed; this task makes it buildable for device/App Store targets, not just this machine's iOS 26.5 simulator).

- [ ] **Step 1: Bump the deployment target** — there are 6 occurrences, all currently `16.0`:

```bash
cd ios && sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 16.0;/IPHONEOS_DEPLOYMENT_TARGET = 18.0;/g' FoundationMobile.xcodeproj/project.pbxproj
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 18.0;" FoundationMobile.xcodeproj/project.pbxproj
```
Expected: `6`.

- [ ] **Step 2: Build to confirm the project still resolves cleanly at the new target:**

```bash
xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ios/FoundationMobile.xcodeproj/project.pbxproj
git commit -m "chore(ios)!: bump IPHONEOS_DEPLOYMENT_TARGET 16.0 -> 18.0 for native MeshGradient

BREAKING: drops iOS 16/17 device support."
```

---

### Task 6: Full suite + grep gate

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full unit test suite:**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```
Expected: TEST SUCCEEDED, zero failures (including the pre-existing `ProfileTierTests`, `DocumentProfileTests`, etc. — this confirms nothing in Tasks 1–5 regressed unrelated behavior).

- [ ] **Step 2: Grep gate — confirm no dangling references to the removed/renamed names:**

```bash
grep -rn "ThemePalette\.light\b" ios/FoundationMobile ios/FoundationMobileTests --include="*.swift" && echo LEAK || echo CLEAN
grep -n '"palette": "midnight"' ios/FoundationMobile/Resources/profiles/foundation.json && echo LEAK || echo CLEAN
grep -n '"palette": "light"' ios/FoundationMobile/Resources/profiles/moma.json && echo LEAK || echo CLEAN
```
Expected: `CLEAN` on all three.

- [ ] **Step 3:** No commit — this task only verifies Tasks 1–5; proceed to Task 7 if clean, otherwise go back and fix the offending task.

---

### Task 7 (final gate): Simulator verification — Foundation + one branded edition

**Files:** none modified — verification only. **Do not consider this plan done until this task passes.**

- [ ] **Step 1: Build and launch the Foundation edition** (default profile, pillars-mode hero):

```bash
cd ios && FOUNDATION_PROFILE=foundation xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```
Then use the iOS Simulator tooling to boot `iPhone 17 Pro`, install/launch the built `.app`, and take a screenshot of the loading screen and home screen (both render `PillarsHero`). Confirm:
- Background is light (white/near-white), not the old dark navy.
- The three pillar rows (Voice/Share/Market) are legible against the light background.
- A living mesh gradient with an angled bottom edge is visible behind the pillar text, using Foundation's green/cyan/blue/violet hues.

- [ ] **Step 2: Repeat for one branded edition — Tel Aviv (image-mode hero):**

```bash
FOUNDATION_PROFILE=tel-aviv xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```
Install/launch, screenshot. Confirm:
- Tel Aviv's teal/blue palette renders (not the old value equal to `brand`, but the corrected `brandInk` teal on any text/button elements).
- The branded hero image renders with the animated mesh visible behind it in Tel Aviv's teal/blue/cyan hues.

- [ ] **Step 3: Reduced-motion check** — in the Simulator, enable Settings → Accessibility → Motion → Reduce Motion, relaunch either edition, and confirm the mesh is visibly static (no drift) rather than frozen mid-animation-glitch.

- [ ] **Step 4:** If any visual issue surfaces (e.g. the mesh panel's padding/sizing needs adjustment, a contrast issue on real content), fix it in the relevant task's file, re-run that task's tests, and re-verify here. Once clean, this plan is complete — no further commit needed beyond what Tasks 1–5 already made.
