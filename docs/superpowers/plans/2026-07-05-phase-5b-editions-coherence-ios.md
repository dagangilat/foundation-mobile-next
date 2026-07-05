# Phase 5b — Editions Coherence: iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the iOS half of Phase 5 (Editions Coherence) — the counterpart to the `foundation` repo's Phase 5a (web/backend, merged as PR #178 — see `docs/superpowers/plans/2026-07-04-phase-5a-editions-coherence-web-backend.md` there). Two things, both user-approved:

1. **Fix drifted/inverted branded palettes in `Theme.swift`** so all 4 branded editions (foundation/moma/tel-aviv/san-francisco) render the exact same hex values and light/dark mode as their web `@plantagoai/editions` kit counterpart — a tenant's iOS app and web app should look like the same brand.
2. **Split brand from security tier at the build-artifact level** so any brand can combine with any tier (e.g. "MoMA branding + High Security Global tier") — today one flat profile id conflates both axes into 8 fixed combinations, with no way to get a 9th.

**Not in this plan** (separate concerns, correctly out of scope): `hisec-mdl`/`lowsec-attest`/`standardsec`'s own tier-specific behavior, the mDL wallet feature, biometric gate work (PR #4), CI pipeline work (PR #1 — confirmed stale/divergent, not a live conflict).

**Architecture:** No new files beyond one small test file. Task 1 only edits hardcoded hex/bool literals in `Theme.swift`. Task 2 is additive at the build-settings/script level (`project.pbxproj` gets one new empty-default build setting; `select-profile.sh`/`select-launch-logo.sh` get a merge step) — it does **not** rename or change the meaning of the existing `FOUNDATION_PROFILE` setting, which stays exactly as-is (a security tier id, defaulting to `hisec-global`) so nothing that already depends on it (CI, other scripts, existing memory/docs) needs to change.

**Research already done this session (fresh, post-mDL-work):**
- 8 profile JSONs exist in `ios/FoundationMobile/Resources/profiles/`: 4 branded (`foundation`, `moma`, `tel-aviv`, `san-francisco`) + 4 tier-only (`hisec-global`, `hisec-mdl`, `lowsec-attest`, `standardsec`). `hisec-mdl` is genuinely new (added 2026-07-01, commit `220f203`) but was already counted correctly in prior research.
- `Theme.swift` (144 lines) is **not** flat per-id hardcoding — it's a `ThemePalette` struct with 6 named presets (`midnight`/`light`/`ocean`/`forest`/`sunset`/`steel`) resolved by name via `Theme.named(_:)`, itself driven by each profile JSON's `theme.palette` field. The indirection already exists; only the **preset content** has drifted (moma) or diverged in mode (tel-aviv/san-francisco ship bespoke dark palettes — `ocean`/`sunset` — for editions the web kits define as light).
- `AppConfig.swift` already cleanly separates brand (`ThemeConfig.palette`/`branding`) from tier (`Profile.faceMatchSource`/`trustTier`) as two independent optional sub-structs of one JSON file — the Swift decode model needs no changes. The conflation is purely "one JSON file = one baked id," which is a build/script-level problem, not a type-level one.
- `hisec-global` already has its own bespoke launch-screen branding (steel/Aegis lockup) despite being a "tier, not brand" profile — this plan's merge logic must let an explicit brand override it, while preserving it as the default when no brand is set (backward compatible).
- No existing test touches `Theme.swift`/palettes/profile-JSON-from-disk. `ios/FoundationMobileTests/ProfileTierTests.swift`'s "decode a JSON literal → assert derived Swift value" pattern is the convention to extend.
- `xcodebuild` (Xcode 26.6) is available in this environment; scheme is `FoundationMobile`, targets `FoundationMobile` + `FoundationMobileTests`.

## Global Constraints

- **User-approved design decisions (already made, do not re-litigate):** (a) tel-aviv and san-francisco become **light** mode on iOS, matching the web kit's real hex values exactly — not kept as bespoke dark variants; (b) the brand×tier build plumbing **is** in scope for this plan (not deferred).
- **Do not touch `voice`/`share`/`market` fields in any `ThemePalette` preset.** These are the pillar-identity colors (Your Voice/Your Share/Your Market) — a *separate* concern from tenant/edition branding, exactly parallel to the lesson learned in the web repo's Phase 5a (where 3 pillar-card components were correctly reverted after almost being collapsed into tenant branding). Only `bg`/`surface`/`border`/`muted`/`brandGreen`/`brandCyan`/`text`/`onAccent`/`isDark` are edition-branding concerns; `voice`/`share`/`market` stay whatever they already are in each preset, untouched.
- **`onAccent` values proposed in Task 1 are a first-pass, reasoned default (contrast-paired against the file's own existing convention), not a verified design decision.** Flag them explicitly for a manual visual/contrast check — do not present them as final without that caveat.
- **`FOUNDATION_PROFILE`'s name, default (`hisec-global`), and existing meaning (security tier) do not change.** `FOUNDATION_BRAND` is purely additive, defaults to empty (= no brand override, exactly today's behavior).
- No time/week estimates — ordered tasks only.
- Push discipline: commit locally per task; do not `git push` without an explicit go-ahead in this session.
- Test/build commands: `cd ios && xcodebuild -scheme FoundationMobile -destination 'generic/platform=iOS Simulator' build`; `xcodebuild test -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16'` (or whatever simulator is available — implementer's call, list with `xcrun simctl list devices available`).

---

### Task 1: Fix branded palette drift + tel-aviv/san-francisco light-mode correction in `Theme.swift`

**Files:**
- Modify: `ios/FoundationMobile/Theme.swift`
- Test: `ios/FoundationMobileTests/ThemePaletteTests.swift` (new)

**Interfaces:** none new — only changes literal values inside the existing `ThemePalette` presets (`light`, `ocean` → repurposed content, `sunset` → repurposed content). No signature changes.

**Research (exact values, from the real web kit JSON files at `/Users/dagan/dev/shared/packages/editions/src/kits/*.json`, cross-checked against the current `Theme.swift`):**

| Token | moma (web) | moma (iOS today) | tel-aviv (web) | tel-aviv (iOS today, "ocean") | san-francisco (web) | san-francisco (iOS today, "sunset") |
|---|---|---|---|---|---|---|
| bg | `#f6f8fc` | `0xf6f8fc` ✓ | `#eef6fb` | `0x041e2e` (dark) | `#fff7f2` | `0x1c1018` (dark) |
| surface | `#ffffff` | `0xffffff` ✓ | `#ffffff` | `0x07293c` | `#ffffff` | `0x271521` |
| border | `#e2e8f0` | `0xe2e7f0` (drifted) | `#d6e6f2` | `0x11455c` | `#f1ddd0` | `0x45283a` |
| text | `#0a0e27` | `0x0a0e27` ✓ | `#0a1a2e` | `0xeaf6fb` | `#2a160c` | `0xfdf2f8` |
| muted | `#64748b` | `0x64708c` (drifted) | `#5b7184` | `0x8fb6c7` | `#8a6f60` | `0xc7a3b4` |
| brand (→brandGreen) | `#34d399` | `0x0fb37d` (drifted) | `#0ea5b7` | `0x22d3ee` | `#fb7185` | `0xfb923c` |
| brandAlt (→brandCyan) | `#22d3ee` | `0x0891b2` (drifted) | `#38bdf8` | `0x5eead4` | `#fbbf24` | `0xf472b6` |
| mode | light | light ✓ | light | **dark** (mismatch) | light | **dark** (mismatch) |

- [ ] **Step 1: Confirm the current `Theme.swift` state is unchanged from this plan's research**

Read `ios/FoundationMobile/Theme.swift` in full. Confirm the `light`, `ocean`, `sunset` preset definitions match what's quoted in this plan (lines ~81-87, ~89-95, ~105-111 as of this writing — re-derive the real line numbers, don't trust these blindly). If they've changed, stop and report.

- [ ] **Step 2: Update the `light` preset (moma) to fix drift**

Change `border`, `muted`, `brandGreen`, `brandCyan` to the exact web values (`0xe2e8f0`, `0x64748b`, `0x34d399`, `0x22d3ee`). Leave `bg`/`surface`/`text`/`isDark` unchanged (already correct). For `onAccent`: the file's own convention pairs `brandGreen: 0x34d399` with `onAccent: 0x000000` (black) in the `midnight` preset — since moma's `brandGreen` is now the identical color, change moma's `onAccent` from `0xffffff` to `0x000000` to match that established contrast pairing. **Flag this specific change for a manual visual check** — it's a reasoned default, not a verified design decision. Do not touch `voice`/`share`/`market`.

- [ ] **Step 3: Repurpose the `ocean` preset's content for tel-aviv (light, matching web exactly)**

Change every non-pillar field to the tel-aviv web values: `bg: 0xeef6fb`, `surface: 0xffffff`, `border: 0xd6e6f2`, `muted: 0x5b7184`, `brandGreen: 0x0ea5b7`, `brandCyan: 0x38bdf8`, `text: 0x0a1a2e`, `isDark: false`. For `onAccent`: `brandGreen` (`0x0ea5b7`) is a medium-saturation teal at moderate luminance — set `onAccent: 0xffffff` (white) as a reasoned default, matching how the file pairs darker/more-saturated accents with white text elsewhere (e.g. `steel`'s `0x38bdf8` pairs with a dark `onAccent`, but `steel` is an overall-dark theme; for a light-mode moderate-saturation accent, white text is the more common convention — **flag for a manual contrast check**, this is the least-certain of the three onAccent decisions in this task). Keep the constant named `ocean` (renaming it is optional cosmetic follow-up, not required — a rename would require updating the `theme.palette: "ocean"` string in `tel-aviv.json` too; only do the rename if you also update that JSON file to match, otherwise leave the Swift constant name as `ocean` even though its content is no longer a dark ocean theme). Do not touch `voice`/`share`/`market`.

- [ ] **Step 4: Repurpose the `sunset` preset's content for san-francisco (light, matching web exactly)**

Change every non-pillar field to the san-francisco web values: `bg: 0xfff7f2`, `surface: 0xffffff`, `border: 0xf1ddd0`, `muted: 0x8a6f60`, `brandGreen: 0xfb7185`, `brandCyan: 0xfbbf24`, `text: 0x2a160c`, `isDark: false`. For `onAccent`: `brandGreen` (`0xfb7185`, a medium-bright rose/coral) — set `onAccent: 0xffffff` (white), same reasoning as Step 3. **Flag for a manual contrast check.** Same naming note as Step 3 — keep the Swift constant named `sunset` unless you also update `san-francisco.json`'s `theme.palette` string to match a rename. Do not touch `voice`/`share`/`market`.

- [ ] **Step 5: Update the doc comment**

The file's own header comment (lines ~15-17) says "in the `ocean`/`sunset` palettes the primary accent isn't green" — this is still true after this change (tel-aviv's accent is teal, san-francisco's is rose), so it doesn't need editing, but re-read it after your changes and confirm it's still accurate; adjust only if it's now misleading.

- [ ] **Step 6: Write the characterization test**

Create `ios/FoundationMobileTests/ThemePaletteTests.swift`, following `ProfileTierTests.swift`'s existing conventions (no memberwise init exists for `ThemePalette`, so this asserts on the actual `static let` presets directly, not a JSON-decode round-trip):

```swift
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
```

Note: `Color` (SwiftUI) doesn't conform to `Equatable` in a way that reliably compares by RGB value across all SwiftUI/XCTest versions — if `XCTAssertEqual` on `Color` doesn't compile or doesn't reliably distinguish values, use `Color.resolve(in:)` or compare via `UIColor(p.bg).cgColor.components` instead. Implementer's call on the exact comparison mechanism; the point is asserting the real hex values are present, not the exact API shape above.

- [ ] **Step 7: Run the test, confirm it passes**

Run: `cd ios && xcodebuild test -scheme FoundationMobile -destination 'platform=iOS Simulator,name=<available simulator>' -only-testing:FoundationMobileTests/ThemePaletteTests`
Expected: PASS (3 tests). If it fails on the `Color` equality mechanism rather than the actual values, fix the comparison approach (Step 6's note), not the values.

- [ ] **Step 8: Build the app for each of the 4 branded profiles, confirm no compile errors**

```bash
for p in foundation moma tel-aviv san-francisco; do
  xcodebuild -scheme FoundationMobile -destination 'generic/platform=iOS Simulator' \
    FOUNDATION_PROFILE=$p build 2>&1 | tail -5
done
```
Expected: `** BUILD SUCCEEDED **` for all 4.

- [ ] **Step 9: Commit**

```bash
git add ios/FoundationMobile/Theme.swift ios/FoundationMobileTests/ThemePaletteTests.swift
git commit -m "fix(theme): correct moma's drifted hex + make tel-aviv/san-francisco light (matching web @plantagoai/editions kits exactly)"
```

---

### Task 2: Split brand from tier at the build-artifact level (`FOUNDATION_BRAND`)

**Files:**
- Modify: `ios/FoundationMobile.xcodeproj/project.pbxproj` (add one new Debug build setting)
- Modify: `ios/scripts/select-profile.sh` (merge brand JSON's `theme` block over the tier JSON's, when a brand is set)
- Modify: `ios/scripts/select-launch-logo.sh` (resolve launch assets from brand first, falling back to tier, falling back to `foundation` default)
- Test: manual build verification (Step in this task) — no new automated test framework exists for build-script behavior in this repo; follow existing precedent (`xcodebuild build` + inspect the emitted bundle) rather than inventing new script-testing infrastructure for this one change.

**Interfaces:**
- New Xcode build setting `FOUNDATION_BRAND` (Debug config, default empty string) — consumed by both scripts.
- No change to `FOUNDATION_PROFILE`'s name, default (`hisec-global`), or meaning.

**Research (already done):** `project.pbxproj:645` sets `FOUNDATION_PROFILE = moma;` in the Debug `XCBuildConfiguration` (`13B07F941A680F5B00A75B9A`) — no separate Release-config value exists (Release/TestFlight builds resolve `FOUNDATION_PROFILE` some other way, per the scripts' own SRCROOT/pbxproj-resolution fallback — do not touch Release config, only Debug, mirroring how `FOUNDATION_PROFILE` itself is Debug-only). `select-profile.sh` (214 lines) copies `Resources/profiles/<id>.json` wholesale into the bundle. `select-launch-logo.sh` (87 lines) resolves launch assets from `Resources/launch-logos/<profile>/` and `Resources/launch-backgrounds/<profile>/`, falling back to `foundation/` if the profile-named dir doesn't exist; only `foundation`, `hisec-global`, `moma`, `san-francisco`, `tel-aviv` currently have their own asset dirs.

- [ ] **Step 1: Add the `FOUNDATION_BRAND` build setting**

In `project.pbxproj`, in the Debug `XCBuildConfiguration` block (`13B07F941A680F5B00A75B9A`, the same block containing `FOUNDATION_PROFILE = moma;` at line ~645), add a new line directly after it:
```
FOUNDATION_BRAND = "";
```
(empty string = no brand override, preserving today's exact behavior for every existing build). Confirm via `xcodebuild -showBuildSettings -scheme FoundationMobile | grep FOUNDATION_BRAND` that it resolves to an empty value by default.

- [ ] **Step 2: Read both scripts in full before editing**

Read `ios/scripts/select-profile.sh` and `ios/scripts/select-launch-logo.sh` completely — re-verify the line numbers/logic this plan describes are still accurate (this research is fresh as of this session, but re-confirm before editing rather than trusting the summary blindly).

- [ ] **Step 3: Add brand-merge logic to `select-profile.sh`**

After the script resolves `PROFILE` (the tier id, from `FOUNDATION_PROFILE`, unchanged logic) and copies the tier JSON to the output path, add a merge step: if `FOUNDATION_BRAND` is set (non-empty) and `Resources/profiles/${FOUNDATION_BRAND}.json` exists, use a JSON merge (this repo doesn't have `jq` guaranteed available in all environments — check for `jq` first; if unavailable, do the merge in Swift/Python/whatever's actually installed in this environment, or shell out to a small inline Python one-liner using the stdlib `json` module, which is universally available in the macOS build environment) that takes the tier JSON as the base and overwrites its `theme` key (and only `theme` — not `faceMatchSource`/`documentNoun`/other tier-specific fields) with the brand JSON's `theme` key. Print a clear log line either way (`echo "Brand override: ${FOUNDATION_BRAND} (theme only)"` or `echo "No brand override — using ${PROFILE}'s own branding"`) so a build log makes the resolution legible, matching the script's existing logging style (check existing `echo` lines in the file for the exact style to match).

- [ ] **Step 4: Add brand-first asset resolution to `select-launch-logo.sh`**

Change the asset-directory resolution to: if `FOUNDATION_BRAND` is set and `Resources/launch-logos/${FOUNDATION_BRAND}/` exists, use it; else if `Resources/launch-logos/${FOUNDATION_PROFILE}/` exists (today's behavior — covers `hisec-global`'s own bespoke launch, and the 4 branded profiles when used standalone with no separate brand set), use it; else fall back to `foundation/` (today's existing final fallback, unchanged). Apply the identical precedence to the `launch-backgrounds` resolution. This preserves every existing build's output byte-for-byte when `FOUNDATION_BRAND` is unset (the default), while letting an explicit brand claim visual precedence when set.

- [ ] **Step 5: Verify backward compatibility — no `FOUNDATION_BRAND` set (today's exact behavior)**

```bash
for p in foundation moma tel-aviv san-francisco hisec-global hisec-mdl lowsec-attest standardsec; do
  xcodebuild -scheme FoundationMobile -destination 'generic/platform=iOS Simulator' \
    FOUNDATION_PROFILE=$p build 2>&1 | tail -5
done
```
Expected: all 8 `** BUILD SUCCEEDED **`, and the emitted `foundationmobile.json`/launch assets for each should be byte-identical to what they were before this task's changes (spot-check `hisec-global`'s output specifically — its bespoke steel/Aegis launch branding must be unchanged when no brand is set).

- [ ] **Step 6: Verify the new capability — a brand×tier combo that didn't exist before**

```bash
xcodebuild -scheme FoundationMobile -destination 'generic/platform=iOS Simulator' \
  FOUNDATION_PROFILE=hisec-global FOUNDATION_BRAND=moma build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`, build log shows the "Brand override: moma" line, and the emitted bundle's `foundationmobile.json` has `hisec-global`'s `faceMatchSource`/tier fields but `moma`'s `theme` block — and the launch assets used are moma's, not hisec-global's steel ones. Inspect the actual built bundle's `foundationmobile.json` (find it under the build's derived-data products dir) to confirm this concretely, not just that the build succeeded.

- [ ] **Step 7: Commit**

```bash
git add ios/FoundationMobile.xcodeproj/project.pbxproj ios/scripts/select-profile.sh ios/scripts/select-launch-logo.sh
git commit -m "feat(profile): add FOUNDATION_BRAND build setting — brand and security tier are now orthogonal and combinable, not one flat 8-value id"
```

---

### Task 3: Whole-plan verification pass

**Files:** none (verification only).

- [ ] **Step 1: Full test target**

Run: `cd ios && xcodebuild test -scheme FoundationMobile -destination 'platform=iOS Simulator,name=<available simulator>'`
Expected: all existing tests + the 3 new `ThemePaletteTests` pass, no regressions.

- [ ] **Step 2: Build matrix**

Re-run Task 2 Step 5's 8-profile matrix plus Task 2 Step 6's combo build, all in one pass, confirm all succeed.

- [ ] **Step 3: Diff review**

Read through the full diff once. Confirm: Task 1 touched only `Theme.swift` + the new test file, and did not touch `voice`/`share`/`market` fields anywhere. Task 2 touched only `project.pbxproj` (one new line) + the 2 scripts, and `FOUNDATION_PROFILE`'s own definition/default/meaning is unchanged.

- [ ] **Step 4: Note the manual follow-ups for the user**

Report back explicitly: (a) the 3 `onAccent` contrast decisions in Task 1 need a human visual check on an actual device/simulator screenshot, not just a passing test; (b) whether to also update `tel-aviv.json`/`san-francisco.json`'s `theme.palette` field name from `"ocean"`/`"sunset"` to something more accurate is an optional cosmetic follow-up, not done in this plan.
