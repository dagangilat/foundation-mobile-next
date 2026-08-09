# Foundation Mobile — Light Editions Redesign (Design Spec)

**Date:** 2026-08-09 · **Status:** Approved via brainstorm (user-signed-off)
**Web reference:** `~/dev/dagangilat/foundation/docs/superpowers/specs/2026-08-09-light-editions-redesign-design.md`
and `~/dev/dagangilat/foundation/docs/superpowers/plans/2026-08-09-light-editions-redesign.md` — the web app's
Stripe-style light redesign of `@plantagoai/editions` v2. This spec is the mobile follow-on (web plan Task 15).

## 1. Goal

Bring foundation-mobile's theming onto the same light-first `@plantagoai/editions` v2 identity the web app
now uses, for the editions that have a web counterpart. Replace the dark, ad-hoc `midnight`/generic-`light`
palettes with hand-ported v2 hex values, and give the mobile hero a native equivalent of the web's animated
mesh treatment.

### Locked decisions (from brainstorm)

| Decision | Choice |
|---|---|
| Scope | Only the 4 web-matched editions: `foundation`, `san-francisco`, `tel-aviv`, `moma`. The 4 mobile-only security editions (`hisec-global`, `hisec-mdl`, `lowsec-attest`, `standardsec`) are untouched — no web design reference exists for them. |
| Hero treatment | Full animated mesh via native `MeshGradient` (iOS 18+) — highest fidelity to the web design. |
| Platform | `IPHONEOS_DEPLOYMENT_TARGET` bumped 16.0 → 18.0. **This drops iOS 16/17 device support** — an App Store Connect minimum-OS change, not just a code change; call this out explicitly in the PR. |
| Palette naming | Rename to match edition ids: new `foundation` and `moma` cases replace the misleading `midnight` (Foundation) and the incorrectly-shared generic `light` (MoMA). `ocean` (Tel Aviv) and `sunset` (San Francisco) keep their existing names — already edition-specific, already close to web parity. |
| Accent contrast | `brandGreen` (93 call sites — the broad primary-accent token) maps to web's accessible `brandInk` tier, not the bright decorative `brand` fill. New `brandFill` token added for any purely-decorative spot that needs the bright value. |
| Data flow | Hand-port hex values into `ThemePalette` Swift constants — same pattern the app already uses (`theme.palette` is a *name* string that resolves to a hardcoded Swift struct). The `palette` JSON blob the sync script writes is a build-time reference/audit artifact, **not** parsed at runtime. |

### Non-goals

- No change to the 4 mobile-only security editions' look.
- No runtime JSON parsing of the new `palette` block in profile JSONs (kept as reference data only).
- No dark-mode removal from the app as a whole — `midnight`/`steel` remain live, dark palettes for the
  out-of-scope editions and as the AppConfig default fallback.

## 2. Token mapping

Mobile's `bg`/`surface` naming is inverted relative to web's `canvas`/`surface` (already true for the
existing `ocean`/`sunset` presets — preserved here):

| Mobile `ThemePalette` field | Source | Note |
|---|---|---|
| `bg` | web `surface` | tinted section background |
| `surface` | web `canvas` | white — cards/panels |
| `border` | web `border` | direct |
| `muted` | web `muted` | direct |
| `text` | web `ink` | direct |
| `brandGreen` | web `brandInk` | accessible (≥4.5:1) tier — the broad 93-call-site accent |
| `brandCyan` | web `brandAlt` | secondary/decorative accent |
| `brandFill` *(new field)* | web `brand` | bright decorative-fill-only value, for any spot that isn't text/interactive |
| `onAccent` | `#ffffff` | `brandGreen` is now a dark fill (e.g. `#047857`), needs white text/glyphs |
| `isDark` | `false` | all 4 in-scope editions |
| `voice`/`share`/`market` | derived per edition | only consumed by Foundation's `PillarsHero` (1 call site each); picked from each edition's gradient stops during implementation for adequate hue separation — not independently specified here |
| `meshBase` *(new field, `Color?`)* | web `mesh.base` | `nil` for out-of-scope editions |
| `meshBlobs` *(new field, `[Color]?`, 4 entries)* | web `mesh.blobs` | `nil` for out-of-scope editions |

### Palette catalog changes (`Theme.swift`)

- New `static let foundation` — light values per web `foundation` kit; `isDark: false`.
- New `static let moma` — light values per web `moma` kit (red/gray, distinct from Foundation's green); `isDark: false`.
- `ocean` (Tel Aviv), `sunset` (San Francisco) — hex values corrected to match the finalized v2 kit exactly; names unchanged.
- Old generic `light` preset **removed** (nothing references it once `moma.json` is repointed).
- `midnight`, `forest`, `steel` — unchanged, still defined; `midnight` remains the `AppConfig` default fallback for profiles that omit `theme` (`lowsec-attest`, `standardsec`).

### Profile JSON changes

- `foundation.json`: `theme.palette` `"midnight"` → `"foundation"`.
- `moma.json`: `theme.palette` `"light"` → `"moma"`.
- `san-francisco.json` / `tel-aviv.json`: `theme.palette` unchanged (`"sunset"` / `"ocean"`).
- The top-level `palette` block already synced into all 4 profiles by `sync-edition-profiles.mjs --write` stays as-is (reference data).

## 3. Hero / mesh treatment

**New primitive — `AnimatedMeshHero`:** a SwiftUI view analogous to web's `MeshHero`, built on native
`MeshGradient` (iOS 18+):

- 3×3 control-point grid seeded from the edition's `meshBase` + 4 `meshBlobs` colors.
- Slow organic drift via `TimelineView(.animation)` nudging control points on a 21–30s cycle (mirrors the
  web's mesh-drift timing).
- Angled bottom cut: a custom `Shape` (diagonal trapezoid) applied as a `clipShape`, equivalent to the web's
  `polygon(0 0, 100% 0, 100% 62%, 0 100%)`.
- **Reduced motion:** reads `@Environment(\.accessibilityReduceMotion)` — freezes to a static mesh (no
  `TimelineView` ticking) when enabled, matching the web's `prefers-reduced-motion` behavior.
- **Graceful fallback:** when `Theme.palette.meshBase` is `nil` (the 4 out-of-scope editions), renders
  today's flat `Theme.bg` rectangle — zero behavior change for `steel`/`midnight`.

**Where it renders:** wraps the hero content at its two existing call sites — `PillarsHero`
(`HomeView.swift:157`, `LoadingView.swift:31`) — replacing the flat background behind both the "pillars" and
"image" hero modes; content stacks above via `ZStack` (mirrors web's mesh-behind-children pattern). Neither
call site sits on a camera/liveness/capture screen, so the animation never competes with camera preview
rendering or runs during a security-sensitive capture step.

## 4. Testing & verification

- **Unit tests:** extend `ThemePaletteTests.swift` — assert `isDark == false` for
  `foundation`/`ocean`/`sunset`/`moma`; port the web package's WCAG contrast check (`brandGreen` vs
  `bg`/`surface` ≥ 4.5:1) as a Swift helper, one assertion per in-scope edition.
- **Grep gate:** after the rename/removal, grep for dangling `ThemePalette.light` / `case "light"` /
  a stray `"midnight"` reference in `foundation.json` to confirm nothing was missed.
- **Simulator verification (required before done):** build and run in iOS Simulator (iOS 18+ device) for
  **Foundation** (default, pillars-mode hero) and **one branded edition** — Tel Aviv or San Francisco
  (image-mode hero) — using `ios/scripts/select-profile.sh` to switch the baked profile. Screenshot both.
  Toggle Simulator's Reduce Motion accessibility setting and confirm the mesh freezes to static.
- No formal perf benchmarking — a visual smoke check that the mesh animation doesn't visibly stutter is
  sufficient for this scope.

## 5. Rollout

Single phase (this is a much smaller surface than the web redesign):

1. `Theme.swift` — new/renamed palette constants, new `brandFill`/`meshBase`/`meshBlobs` fields.
2. Profile JSON `theme.palette` renames (`foundation.json`, `moma.json`).
3. `AnimatedMeshHero` primitive + wire into `PillarsHero` call sites.
4. `IPHONEOS_DEPLOYMENT_TARGET` bump to 18.0.
5. Unit test updates + grep gate.
6. Simulator verification across Foundation + one branded edition, screenshots attached to PR.
