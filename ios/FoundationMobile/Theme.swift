import SwiftUI

// App theming.
//
// `Theme` is the single access point every view reads colors from
// (`Theme.bg`, `Theme.brandGreen`, …). Those used to be `static let`
// constants; they now forward to the active `ThemePalette`, which is
// resolved once at launch from the baked profile JSON
// (`theme.palette` → see FoundationMobileApp.init + AppConfig).
//
// Because the profile is baked at build time, the palette is set before
// any view renders and never mutated again — so a mutable static is safe
// here (marked nonisolated(unsafe) to say so explicitly).
//
// Token naming note: `brandGreen` is the *primary accent* (CTAs, active
// rings) and `brandCyan` the *secondary accent*. The names are historical
// — in the `ocean`/`sunset` palettes the primary accent isn't green. They
// were kept verbatim to avoid churning the ~100 call sites. `text` is the
// primary on-background text color and `onAccent` the text/glyph color
// that sits on a filled accent (e.g. the black label on the green button).

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

enum Theme {
    nonisolated(unsafe) static var palette: ThemePalette = .midnight

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

    static let ringLabels: [Int: String] = [
        0: "Ring 0 — Founder",
        1: "Ring 1 — Admin",
        2: "Ring 2 — Steward",
        3: "Ring 3 — Contributor",
        4: "Ring 4 — Member",
        5: "Ring 5 — Guest",
    ]

    /// Resolve and install the palette named in the baked profile JSON.
    /// Unknown names fall back to `midnight` rather than failing — a
    /// branding typo should not brick the app.
    static func apply(paletteNamed name: String) {
        palette = ThemePalette.named(name)
    }
}

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

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
