# Phase 4 Implementation Plan — iOS Release Bug Fix

Source: `docs/superpowers/plans/2026-07-03-full-review-remediation-roadmap.md` (foundation repo), Phase 4 section (2 findings). This plan lives in `foundation-mobile` — a separate repo from the other phases.

**Worktree:** `/tmp/foundation-mobile-phase4` (branch `worktree-phase-4-ios-release-fix`)
**Base:** `origin/main` (`2a3b9c5`)

## Confirmed root cause (traced directly, not from the roadmap description alone)

`ios/FoundationMobile.xcodeproj/project.pbxproj`'s `Debug` `XCBuildConfiguration` (`13B07F941A680F5B00A75B9A`) sets `FOUNDATION_PROFILE = moma;`. The `Release` `XCBuildConfiguration` (`13B07F951A680F5B00A75B9A`) has **no `FOUNDATION_PROFILE` setting at all**.

The two build-phase scripts resolve an unset `FOUNDATION_PROFILE` env var **differently**, and this is a live, currently-reproducible bug given the repo's actual current state:

- `scripts/select-profile.sh` (Xcode build-phase mode): `PROFILE="${FOUNDATION_PROFILE:-$DEFAULT_PROFILE}"` where `DEFAULT_PROFILE="hisec-global"` — falls straight to the hardcoded default.
- `scripts/select-launch-logo.sh`: if `FOUNDATION_PROFILE` is unset, it falls back to **reading the value out of `project.pbxproj` directly** via `sed`, which — because `sed -n ... | head -n1` matches the *first* `FOUNDATION_PROFILE = ...;` line in the file — picks up **Debug's `moma`**, not Release's (absent) value, before finally falling back to `hisec-global` only if the pbxproj has no match at all.

**Net effect on a Release/Archive build today**: `select-profile.sh` bakes `hisec-global.json` into the app bundle as `foundationmobile.json` (the app's actual feature/security-tier config), while `select-launch-logo.sh` swaps in the **`moma`** branded splash/launch assets. A shipped Archive build's content and its launch screen brand would visibly mismatch — this is the "every current Archive build ships the wrong edition" bug the roadmap describes, confirmed by direct trace rather than assumed.

## Scoping decision (user-confirmed before this plan was finalized)

Per the roadmap's explicit decision point: branded editions (`moma`/`tel-aviv`/`san-francisco`) remain **demo/local-only** for now — not added to the CI TestFlight workflow's profile dropdown in this phase. `.github/workflows/ios-testflight.yml`'s dropdown already only offers the 3 security-tier profiles (`hisec-global`/`standardsec`/`lowsec-attest`, default `hisec-global`) and is framed throughout as "Foundation security profile," consistent with this being the existing intentional scope, not an oversight. Task 2 below documents this explicitly rather than silently leaving it ambiguous. Expanding to branded-editions-in-CI is deferred to Phase 5's editions-coherence scoping.

---

## Task 1: Fix the Release/Debug FOUNDATION_PROFILE divergence + add a build-time assertion

**Finding:** `[critical] Release/Archive builds never receive FOUNDATION_PROFILE — ios/FoundationMobile.xcodeproj/project.pbxproj:645`

### Fix, part A — close the actual gap

Add `FOUNDATION_PROFILE = hisec-global;` to the `Release` `XCBuildConfiguration` (`13B07F951A680F5B00A75B9A`), matching `DEFAULT_PROFILE` in `select-profile.sh` and the CI dropdown's own default — this is not a guessed value, it's the value every other part of this codebase already treats as "the" production default. With this set explicitly, both `select-profile.sh` and `select-launch-logo.sh` receive the SAME non-empty `FOUNDATION_PROFILE` env var during a Release/Archive build (Xcode always passes build-setting values as env vars to build-phase scripts), so neither script falls into its divergent fallback path anymore for Release builds.

### Fix, part B — build-phase assertion (defense-in-depth against future drift)

Per the roadmap: "add a build-phase assertion that fails the archive if `select-profile.sh` and `select-launch-logo.sh` would resolve to different profile ids." Part A closes today's specific gap, but doesn't prevent someone re-introducing a divergence later (e.g. changing one script's default without the other, or unsetting `FOUNDATION_PROFILE` again in some future build configuration).

Design approach — implementer's judgment on the cleanest mechanism, but here's the shape: have `select-profile.sh`'s Xcode-build-phase mode write the profile id it resolved to a marker file (e.g. `${BUILT_PRODUCTS_DIR}/.foundation-profile-selected`, a plain-text single line). Have `select-launch-logo.sh`, which per its own header comment runs as an EARLY build phase (before `select-profile.sh`'s later phase) — check the actual current ordering in the pbxproj's `PBXShellScriptBuildPhase` section and the target's build phase list (`13B07F861A680F5B00A75B9A` or similar `PBXNativeTarget`'s `buildPhases` array) to confirm which genuinely runs first — write the SAME marker convention with its own resolved profile id, OR (simpler, avoids an ordering dependency) add a third, new build-phase script that runs LAST (after both existing phases) and independently re-derives what each script's resolution logic would produce given the current `FOUNDATION_PROFILE` env var and pbxproj state, comparing them and calling `exit 1` with a clear error message if they differ. Prefer the "third script, runs last, re-derives and compares" approach if it's cleanly implementable — it doesn't require touching either existing script's internal logic (lower risk of introducing a behavior change to the byte-for-byte-preserved `select-profile.sh` Xcode-build-phase mode, which its own header comment says is "preserved byte-for-byte").

### Step 1: Write a test

This is Xcode-project-config + shell-script logic, not application Swift code — check `FoundationMobileTests/` for any existing precedent testing build-phase scripts or profile resolution (Phase 0's "decode all 8 bundled profile JSONs" test, `88a2785`, may be a relevant existing pattern to extend or sit alongside, though it likely tests JSON schema conformance, not build-phase script behavior). If no existing precedent fits, a shell-level test invoked from a script (not XCTest) that:
- Sets `FOUNDATION_PROFILE` unset, simulates both scripts' resolution logic (or calls them in a way that doesn't require a full `BUILT_PRODUCTS_DIR`/Xcode environment — check if the scripts can be partially exercised via their CLI mode with env var overrides), and confirms the NEW assertion script would have caught the pre-fix divergence and does NOT fire post-fix.
- If a full literal reproduction of the Xcode build-phase environment is impractical outside real `xcodebuild`, the test may instead directly assert the pbxproj's `Release` config now contains `FOUNDATION_PROFILE = hisec-global;` (a simple grep/parse-based test, cheap and reliable) as the primary automated check, with the build-phase assertion script itself verified by the archive-build step in Verification below rather than a unit test — use your judgment and explain the choice in your report.

### Step 2: Implement

Per Fix parts A and B above.

### Step 3: Verify

- `git diff ios/FoundationMobile.xcodeproj/project.pbxproj` — confirm ONLY the `Release` config's `FOUNDATION_PROFILE` line was added (plus whatever new build-phase entry Part B requires), nothing else in this large generated file changed incidentally.
- Archive locally with the default profile selected (`./ios/scripts/select-profile.sh --current` should show `moma` from Debug, unaffected by this fix, or run `select-profile.sh hisec-global` first to align Debug too, implementer's judgment) to confirm the project still opens/builds cleanly in Xcode — a full `xcodebuild archive` run for TestFlight signing is NOT required to validate this fix (no signing certs available here), but a `xcodebuild build` or `-showBuildSettings` invocation confirming the Release config now resolves `FOUNDATION_PROFILE=hisec-global` is a reasonable, fast local check.
- **Known environment quirk**: running any `xcodebuild` command mutates `ios/FoundationMobile/Images.xcassets/*` files as a side effect of the "Select launch logo" build phase (this fix's own subject, ironically). Always run `git checkout -- ios/FoundationMobile/Images.xcassets/` immediately after any `xcodebuild` invocation and before committing, and never commit those paths.
- Run the full test suite: `cd ios && xcodebuild test -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16'` (or whatever the established test invocation is in this repo — check for a Makefile/fastlane test lane first) to confirm nothing else broke.

---

## Task 2: Document branded-editions-are-local-only scope, and CI dropdown follow-up

**Finding:** `[medium] The paid CI TestFlight workflow can only ship the 3 security-tier profiles — .github/workflows/ios-testflight.yml:50`

**Per the scoping decision above**: this task does NOT expand the CI dropdown. It documents the existing scope explicitly so it reads as an intentional boundary, not an oversight, and points at where the real decision (Phase 5) would need to be revisited.

### Step 1: Add a documentation comment

In `.github/workflows/ios-testflight.yml`, near the `profile` input (around line 50), add a comment above the `options:` list explaining: CI is intentionally scoped to the 3 security-tier profiles; branded editions (`moma`/`tel-aviv`/`san-francisco`/`foundation`) are demo/local-only, shipped via `bundle exec fastlane beta` or manual Xcode archive, not this paid CI path; expanding CI to cover them is a decision deferred to the foundation repo's Phase 5 editions-coherence work (`docs/superpowers/plans/2026-07-03-full-review-remediation-roadmap.md`, Phase 5 section — note this file lives in a different repo, so reference it by name/description rather than a relative path).

### Step 2: No code/logic change

This task is comment-only. No test needed beyond confirming the YAML remains valid (`yamllint .github/workflows/ios-testflight.yml` or a GitHub Actions workflow syntax check if available; at minimum confirm the file still parses as YAML).

### Step 3: Verify

Confirm the workflow file is still valid YAML and the `workflow_dispatch` inputs are unchanged in behavior (comment-only diff).

---

## Verification (whole-phase, after both tasks)

Per the roadmap: "archive locally with each of the 8 profiles selected via `select-profile.sh`, confirm the resulting `foundationmobile.json` and launch assets match for all 8." This is a fuller manual verification than Task 1's Step 3's quick check — worth doing once both tasks land, cycling through all 8 profiles (`foundation`, `hisec-global`, `hisec-mdl`, `lowsec-attest`, `moma`, `san-francisco`, `standardsec`, `tel-aviv`) via `select-profile.sh <id>` + a build, confirming `foundationmobile.json`'s content and the launch-logo/launch-background assets match the selected profile each time, and reverting `Images.xcassets` after each run. Treat this as a final whole-branch-review action item if it isn't completed inline during task execution.
