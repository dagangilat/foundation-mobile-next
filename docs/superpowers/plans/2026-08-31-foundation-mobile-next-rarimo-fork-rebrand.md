# Foundation Mobile Next — Rarimo Fork & Rebrand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `foundation-mobile-next`'s mostly-unbuilt native-MOPRO-proving app with rebranded forks of Rarimo's shipped `rarime-ios-app` and `rarime-android-app`, adding platform attestation, Firebase Auth, and Solana commitment write-back, shipped as a public open-source repo.

**Architecture:** Rarimo's apps become the base codebase (26k LOC Swift / 54k LOC Kotlin of shipped passport-NFC + Groth16 proving + liveness). A small, named subset of the existing Foundation Mobile SwiftUI shell — App Attest, Keychain, the Firebase callable client, and OTP sign-in — is **ported into** the fork; the rest of the shell is deleted. Foundation's backend is reached in-process: the app calls `startL2Verification`, takes the returned `getProofParamsUrl`, and feeds it straight into Rarimo's existing `ExternalRequestsManager` proof-request flow, so **no deep link and no backend change are required**. The repo ships public under GPL-3.0 because both platforms link `witnesscalc` (GPL-3.0) and `rapidsnark` (LGPL-3.0).

**Tech Stack:** Swift 5.9 / SwiftUI / Xcode 15+ (iOS 16+); Kotlin / Jetpack Compose / Gradle KTS / Android NDK (minSdk 27, targetSdk 35); Go + gomobile (`rarime-mobile-identity-sdk` → `Identity.xcframework`); Firebase (Auth, Functions, Messaging, App Check) on project `foundation-next-app`; Solana devnet via Foundation Cloud Functions.

**Spec:** `/Users/dagan/dev/dagangilat/foundation-next/docs/superpowers/specs/2026-08-30-foundation-rarimo-consolidation-design.md` § 3 ("Identity consolidation (mobile)", lines 246–387).

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Bundle / application identifier (iOS):** `com.foundationnext.mobile` (already set in the current shell; the fork must land on the same value). Test target: `com.foundationnext.mobile.tests`.
- **Application ID (Android):** `com.foundationnext.mobile`. The Kotlin **package namespace stays `com.rarilabs.rarime`** — see Open Decision OD-3.
- **User-visible app name:** `Foundation` (matches the existing shell's `CFBundleDisplayName`). Never "Foundation Mobile" in UI chrome — that string is an internal identifier only, per `foundation-next/CLAUDE.md`.
- **Apple `DEVELOPMENT_TEAM`:** `F9F26FQW95`.
- **Firebase project:** `foundation-next-app` (single tier — this fork has **no staging tier**). The iOS app is already registered; the Android app is not (Task C1).
- **iOS deployment target:** iOS 16+ (inherited constraint from the existing shell's App Attest work; Rarimo's app targets iOS 16 as well — verify in Task B2 and do not lower it).
- **Android:** `minSdk = 27`, `targetSdk = 35`, `compileSdk = 35`, NDK ABI filter `arm64-v8a`, JVM target 17.
- **Licensing posture (binding, from spec § 3):** ship **free and fully open source, public repo from day one**. Both platforms carry real GPL-3.0 (`witnesscalc`) and LGPL-3.0 (`rapidsnark`) exposure. Rarimo's own MIT copyright notice must be preserved verbatim wherever their code is redistributed.
- **Solana invariant (inherited, hard):** the mobile app **never holds a Solana keypair**. All chain writes go through the `anchorCommitment` Cloud Functions callable. See `ios/FoundationMobile/SolanaRPC.swift:4` in the pre-fork tree for the original statement of this rule.
- **Backend is a fixed, already-available dependency — do not re-plan it.** The callables this plan consumes already exist in `foundation-next`:
  - `startL2Verification` (`functions/founders/passport.js:79`) → `{ status, deepLink, getProofParamsUrl }`
  - `getL2VerificationStatus` (`functions/founders/passport.js:129`)
  - `issueAttestationNonce`, `recordMobileAttestation` (`functions/index.js`, region `us-east1`)
  - `anchorCommitment` (`functions/index.js:2940`, region `us-east1`)
  - `requestSignInCode`, `verifySignInCode` (OTP sign-in)
  - `foundation-next` has its own isolated `verificator-svc` instance (Neon-backed, own event ID, own Cloud Run URL). Treat as live.
- **`anchorCommitment` contract (verified against `functions/index.js:2830-2837`):**
  - `ANCHOR_COMMITMENT_REQUIRED_KINDS = ["appAttest"]` — **`appAttest` is the only mandatory artifact kind.**
  - `ALLOWED_ARTIFACT_KINDS = { appAttest, liveness, nfcZk, antiSpoof, faceMatch }`.
  - Requires `requireAuth` **and** `requireVerifiedMember`, so it can only be called **after** the L2 passport lane has flipped the member to `verificationLevel: "l2"`.
  - `commitment.hashHex` must be 64 lowercase hex chars; the server re-derives canonical bytes and rejects a mismatch (`"anchorCommitment seal-mismatch"`).
- **`recordMobileAttestation` accepts both platforms** (`functions/index.js:2770`): `attestation.platform` must be `"ios"` or `"android"`. `@plantagoai/attestation` already implements `verifyPlayIntegrity` (`/Users/dagan/dev/shared/packages/attestation/src/server.ts:121`) and its wire type is `{ platform: 'android', token: string }` (`.../src/types.ts:15`). **No backend work is needed for the Android attestation track.**
- **No time/week estimates** anywhere — ordered phases only (repo convention).
- **Do not run any fastlane lane** until Task B10 repoints it. The inherited `ios/fastlane/Fastfile` `beta` lane rewrites the bundle ID to the LIVE `com.foundationglobal.mobile` and uploads to live Foundation Mobile's App Store Connect record.

---

## Architectural decisions (made here, binding on all tasks)

### AD-1 — Rarimo's app is the base; the Foundation shell is ported in, not the reverse

`rarime-ios-app` is 255 Swift files / 26,154 LOC of shipped, App-Store-distributed passport NFC reading, Groth16 proving, liveness and anti-spoof. `foundation-mobile-next`'s shell is 75 files / 12,163 LOC, of which the proving direction (MOPRO/Self circuits) is exactly what the spec drops. Rebuilding Rarimo's proving inside the shell is not on the table; carrying the shell's UI into Rarimo's app would mean rewriting every screen that consumes Rarimo's managers.

**Decision: Rarimo's tree becomes `ios/` and `android/`. Exactly these files are ported forward from the shell** (all paths relative to the pre-fork `ios/FoundationMobile/`):

| Shell file | Fate | Why |
|---|---|---|
| `AttestationService.swift` | **Port verbatim** (115 lines) | Complete, tested App Attest implementation incl. `DCError.invalidKey` self-healing. Rarimo ships nothing equivalent. |
| `Keychain.swift` | **Port, change `service` constant** | Backing store for the attested key id + pending OTP email. |
| `AppCheckFactory.swift` | **Port verbatim** | Real App Attest provider on device, debug provider on simulator. |
| `ProofArtifact.swift` | **Port, trim `Kind` enum** | Defines the exact canonical bytes `anchorCommitment` re-derives server-side. Contract-frozen — must not be rewritten. |
| `EnclaveSeal.swift` | **Port verbatim** | `seal(uid:artifacts:)` mirrors the server's `canonicalSealBytes`. |
| `FunctionsService.swift` | **Port a named subset** | Only: `issueAttestationNonce`, `recordMobileAttestation`, `requestSignInCode`, `verifySignInCode`, `anchorCommitment`, plus `refreshIDTokenIfStale` and the `encodeToDict`/`decode` helpers. Drop pairing, support, web-session, biometric-consent, deployment-picker wrappers. |
| `AuthService.swift`, `SignInView.swift` | **Port, restyled** | Rarimo has no Firebase Auth at all (it is identity-key based via `DecentralizedAuthManager`); every Foundation callable needs `requireAuth`. |
| Everything else (63 files) | **Delete** | Capture/liveness/face-match/NFC/MRZ/wallet-document pipeline is superseded by Rarimo's shipped equivalents; `Theme.swift`, `HomeView`, `PillarsHero`, `AnimatedMeshHero`, `DeploymentConfig`, `MoproSmokeBridge`, `SolanaRPC` are shell-specific. |

### AD-2 — In-process proof request; no deep link, no backend change

`functions/founders/passport-provider.js:80` builds `https://app.rarime.com/external?type=proof-request&proof_params_url=<url>` and `startL2Verification` returns it as `deepLink` **alongside the raw `getProofParamsUrl`**. Rarimo's `ExternalRequestsManager.isValidExternalUrl` only accepts `rarime://external` or `https://app.rarime.com/external` — hosts we do not own, so the universal link would open RariMe (if installed) rather than our fork.

**Decision: the fork ignores `deepLink` entirely.** It calls `startL2Verification`, takes `getProofParamsUrl`, and calls `ExternalRequestsManager.shared.setRequest(.proofRequest(proofParamsUrl:urlQueryParams:))` directly (the setter is already `internal`, at `Rarime/Code/Managers/ExternalRequestsManager.swift:127`). This needs zero backend change, zero domain ownership, and zero app-switch. Android does the same through `ExtIntQueryProofHandler`.

The external-URL handler is still **retained and re-scoped** to `foundationmobile://external` (Task B8 / C8) so QR-based flows keep working, but it is not on the primary verification path.

### AD-3 — iOS GPL exposure is CONFIRMED, upgrading the spec's "likely"

Spec § 3 rates iOS as "likely also exposed… not confirmed with the same hard evidence as Android." Direct inspection of `rarime-ios-app` at HEAD closes that gap with the same evidence class Android had:

- `git ls-files Frameworks` shows **34 tracked binaries**, including `Frameworks/librapidsnark.a` (LGPL-3.0, 215 KB) and thirteen `Frameworks/libwitnesscalc_*.a` (GPL-3.0, e.g. `libwitnesscalc_queryIdentity.a` at 5.5 MB).
- `Rarime.xcodeproj/project.pbxproj` links every one of them into the app target.

This is not circumstantial: the GPL-3.0 witness calculators are checked into the repo and statically linked into the shipped binary. **Both platforms are confirmed exposed.** The plan's licensing tasks proceed on that basis, which is also the spec's recommended posture, so no decision changes — only the confidence behind it.

### AD-4 — Upstream import via `git subtree` from a tracked remote, not a flat copy

Spec § 3 explicitly names ongoing upstream merges as a maintenance surface ("merging their updates means re-checking rebranded surfaces each time"). A flat copy makes every future merge a manual diff. `git subtree` keeps upstream history joinable while letting the fork live in `ios/` and `android/` subdirectories of one repo.

Cost accepted: ~40 MB of tracked `.a` binaries on the iOS side and ~15 `.so` files on the Android side land in this repo's history. Android's `.gitattributes` declares `*.aar filter=lfs` — see Open Decision OD-7.

---

## File Structure

After Phase A the repo looks like this. Files marked **new** are created by this plan.

```
foundation-mobile-next/
  LICENSE                      # new — GPL-3.0 (replaces nothing; repo had none)
  NOTICE                       # new — Rarimo MIT attribution, upstream provenance
  THIRD_PARTY_LICENSES.md      # new — witnesscalc/rapidsnark/gmp/Identity SDK inventory
  README.md                    # modified — fork provenance, build instructions, license
  CLAUDE.md                    # modified — supersede the "deferred remnants" list
  scripts/
    brand-sweep.sh             # new — CI gate: fails on any residual Rarimo brand token
    import-upstream.sh         # new — documented subtree pull for both platforms
  ios/                         # REPLACED — was the SwiftUI shell, now the Rarime fork
    Frameworks/                # from upstream: librapidsnark.a, libwitnesscalc_*.a
    Rarime.xcodeproj/          # renamed to FoundationMobile.xcodeproj in Task B2
    Rarime/                    # renamed to Foundation/ in Task B2
      Code/
        Foundation/            # new dir — ported shell files live here
          AttestationService.swift
          Keychain.swift
          AppCheckFactory.swift
          ProofArtifact.swift
          EnclaveSeal.swift
          FunctionsService.swift
          AuthService.swift
          FoundationVerificationManager.swift   # new — AD-2 wiring
          CommitmentAnchorService.swift         # new — anchorCommitment write-back
      Resources/
      SupportingFiles/Configs/  # Rarimo xcconfigs replaced in Task B1
    prebuild.sh                # modified — points at the forked identity SDK
  android/                     # NEW — the rarime-android-app fork
    app/src/main/java/com/rarilabs/rarime/
      config/Keys.kt           # new — reconstructs the gitignored upstream file
      foundation/              # new package — ported Foundation integration
        FoundationFunctionsService.kt
        FoundationAuthManager.kt
        PlayIntegrityService.kt
        FoundationVerificationManager.kt
        CommitmentAnchorService.kt
  legacy-ios-shell/            # temporary — deleted at the end of Task B9
```

---

# Phase A — Repo posture, licensing, and upstream import

## Task A1: Public repo, GPL-3.0 licensing, and upstream attribution

**Model tier:** Sonnet (mechanical, but the license text must be exact).

**Files:**
- Create: `LICENSE`
- Create: `NOTICE`
- Create: `THIRD_PARTY_LICENSES.md`
- Create: `scripts/brand-sweep.sh`
- Modify: `README.md`
- Test: `scripts/brand-sweep.sh` is itself the test harness for later tasks; this task verifies it runs and reports.

**Interfaces:**
- Consumes: nothing.
- Produces: `scripts/brand-sweep.sh` — exits `0` when no forbidden brand token is found under the paths passed as arguments (default: `ios android`), exits `1` and prints `path:line:match` otherwise. Every later rebrand task uses it as its failing test.

- [ ] **Step 1: Write the failing test — the brand sweep script**

Create `scripts/brand-sweep.sh`:

```bash
#!/usr/bin/env bash
# Fails if any user-visible Rarimo brand token survives in the forked source.
# Every rebrand task in docs/superpowers/plans/2026-08-31-foundation-mobile-next-rarimo-fork-rebrand.md
# uses this as its red/green gate.
#
# Usage: scripts/brand-sweep.sh [path ...]     (default: ios android)
set -uo pipefail

ROOTS=("$@")
if [ ${#ROOTS[@]} -eq 0 ]; then ROOTS=(ios android); fi

# Case-insensitive brand tokens that must not appear in shipped source.
# NOTE: `\b` is a GNU-grep extension and does NOT work in macOS BSD grep, so the
# RMO token is written with explicit non-letter boundaries. Without this the
# gate would pass locally on a Mac and fail in CI (ubuntu) — or worse, silently
# miss RMO locally.
PATTERN='rarime|rarimo|rarilabs|freedomtool|appsflyer|(^|[^A-Za-z])RMO([^A-Za-z]|$)'

# Paths intentionally exempt:
#  - Frameworks/ and cpp/lib/: upstream GPL binaries, named by their own project
#  - NOTICE / THIRD_PARTY_LICENSES.md: attribution MUST name Rarimo
#  - .git, build outputs
EXCLUDES=(
  --exclude-dir=.git
  --exclude-dir=Frameworks
  --exclude-dir=build
  --exclude-dir=Build
  --exclude-dir=lib
  --exclude-dir=.gradle
  --exclude=NOTICE
  --exclude=THIRD_PARTY_LICENSES.md
  --exclude='*.a'
  --exclude='*.so'
)

hits=$(grep -rniE "$PATTERN" "${EXCLUDES[@]}" "${ROOTS[@]}" 2>/dev/null)

if [ -n "$hits" ]; then
  echo "brand-sweep: FAIL — residual Rarimo brand tokens found:"
  echo "$hits"
  echo
  echo "brand-sweep: $(echo "$hits" | wc -l | tr -d ' ') occurrence(s)"
  exit 1
fi

echo "brand-sweep: PASS — no residual Rarimo brand tokens under: ${ROOTS[*]}"
exit 0
```

- [ ] **Step 2: Make it executable and run it against the current tree**

```bash
chmod +x scripts/brand-sweep.sh
./scripts/brand-sweep.sh ios
```

Expected: `brand-sweep: PASS` — the pre-fork shell has no Rarimo strings yet. This confirms the script runs clean before the import, so every failure after Task A3 is genuinely from imported code.

- [ ] **Step 3: Write the LICENSE file**

Download the canonical GPL-3.0 text (do not hand-type it):

```bash
curl -fsSL https://www.gnu.org/licenses/gpl-3.0.txt -o LICENSE
head -3 LICENSE
```

Expected first lines:

```
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007
```

- [ ] **Step 4: Write NOTICE with upstream attribution**

Create `NOTICE`:

```
Foundation Mobile
Copyright (c) 2026 Dagan Gilat / Foundation

This product is a fork of, and includes source code from, the following
upstream projects. Their copyright notices are reproduced here as required
by their licenses.

--------------------------------------------------------------------------
rarime-ios-app        — https://github.com/rarimo/rarime-ios-app
rarime-android-app    — https://github.com/rarimo/rarime-android-app
rarime-mobile-identity-sdk
                      — https://github.com/rarimo/rarime-mobile-identity-sdk

MIT License

Copyright (c) 2024 Rarimo Foundation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--------------------------------------------------------------------------

The combined work is distributed under the GNU General Public License v3.0
(see LICENSE), because it statically links GPL-3.0 and LGPL-3.0 native
proving libraries. See THIRD_PARTY_LICENSES.md for the component inventory.
```

- [ ] **Step 5: Write THIRD_PARTY_LICENSES.md**

Create `THIRD_PARTY_LICENSES.md`:

```markdown
# Third-party components and their licenses

This app statically links native zero-knowledge proving libraries that carry
copyleft obligations. This inventory is why the combined work ships under
GPL-3.0 (see LICENSE) with full source available in this public repository.

## Copyleft components — the reason this repo is GPL-3.0

| Component | License | Where it enters the build |
|---|---|---|
| `witnesscalc` (circuit witness calculators) | **GPL-3.0** | iOS: `ios/Frameworks/libwitnesscalc_*.a`, linked by `ios/FoundationMobile.xcodeproj/project.pbxproj`. Android: `android/app/src/main/cpp/lib/libwitnesscalc_*.so` + `lib/light/`, linked by `android/app/src/main/cpp/CMakeLists.txt`. |
| `rapidsnark` (Groth16 prover) | **LGPL-3.0** | iOS: `ios/Frameworks/librapidsnark.a`. Android: `android/app/src/main/cpp/lib/librapidsnark.so`. |
| `GMP` (GNU Multiple Precision) | LGPL-3.0 / GPL-2.0 dual | iOS: `ios/Frameworks/libgmp.a` (transitively via rapidsnark). |

Concrete iOS witness calculators present in the tree:
`libwitnesscalc_auth.a`, `libwitnesscalc_queryIdentity.a`,
`libwitnesscalc_faceRegistryNoInclusion.a`,
`libwitnesscalc_registerIdentityLight{160,224,256,384,512}.a`, and five
`libwitnesscalc_registerIdentity_*` variants.

## Permissive components

| Component | License |
|---|---|
| `rarime-ios-app`, `rarime-android-app`, `rarime-mobile-identity-sdk` (Rarimo Foundation) | MIT — see NOTICE |
| `libfq.a`, `libfr.a`, `libbionet.a` | Distributed with the upstream apps; treated as part of the Rarimo MIT distribution pending upstream clarification. See Open Decision OD-1. |
| Inter, Playfair Display (fonts) | SIL Open Font License 1.1 |

## Source availability

Complete corresponding source for the GPL-3.0 combined work is this
repository: https://github.com/dagangilat/foundation-mobile-next

Upstream sources for the native proving libraries:
- witnesscalc — https://github.com/0xPolygonID/witnesscalc
- rapidsnark  — https://github.com/iden3/rapidsnark
```

- [ ] **Step 6: Rewrite README.md's header for the public repo**

Replace the top of `README.md` (keep any build sections below it) with:

```markdown
# Foundation Mobile

A privacy-preserving identity app for the Foundation governance platform.
Prove you are a unique human with a passport, without revealing who you are.

**This is a fork of [Rarimo](https://github.com/rarimo)'s
[rarime-ios-app](https://github.com/rarimo/rarime-ios-app) and
[rarime-android-app](https://github.com/rarimo/rarime-android-app)**, rebranded
and integrated with Foundation's backend. See NOTICE for upstream attribution.

## License

GPL-3.0 (see LICENSE). The app statically links GPL-3.0 `witnesscalc` and
LGPL-3.0 `rapidsnark` proving libraries; see THIRD_PARTY_LICENSES.md.
This repository is the complete corresponding source.
```

- [ ] **Step 7: Make the GitHub repo public**

```bash
gh repo view dagangilat/foundation-mobile-next --json visibility
gh repo edit dagangilat/foundation-mobile-next --visibility public --accept-visibility-change-consequences
gh repo view dagangilat/foundation-mobile-next --json visibility
```

Expected final output: `{"visibility":"PUBLIC"}`

> **Gate before running Step 7:** confirm no secret is currently tracked. Run
> `git log --all -p -- '*GoogleService-Info*.plist' | head -40` and
> `git grep -nE 'PRIVATE_KEY|_SECRET|api[_-]?key' -- ':!docs' | head -20`.
> `GoogleService-Info.plist` is gitignored in this repo (verify with
> `git check-ignore -v ios/FoundationMobile/GoogleService-Info.plist`). If
> anything sensitive is in history, stop and surface it — do not flip
> visibility.

- [ ] **Step 8: Verify the brand sweep still passes and commit**

```bash
./scripts/brand-sweep.sh ios
```

Expected: `brand-sweep: PASS`

```bash
git add LICENSE NOTICE THIRD_PARTY_LICENSES.md README.md scripts/brand-sweep.sh
git commit -m "chore: GPL-3.0 licensing, Rarimo attribution, and brand-sweep CI gate

The forked proving stack statically links GPL-3.0 witnesscalc and LGPL-3.0
rapidsnark on both platforms (iOS: tracked .a files in Frameworks/ linked by
project.pbxproj; Android: .so files linked by cpp/CMakeLists.txt), so the
combined work ships GPL-3.0 with public source from day one, per spec 3.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task A2: Quarantine the legacy shell and import `rarime-ios-app` as `ios/`

**Model tier:** Sonnet.

**Files:**
- Modify (move): `ios/` → `legacy-ios-shell/` (whole tree, `git mv`)
- Create: `ios/` (imported subtree from `rarime-ios-app`)
- Create: `scripts/import-upstream.sh`
- Test: `scripts/brand-sweep.sh ios` — must now FAIL, proving the import landed.

**Interfaces:**
- Consumes: `scripts/brand-sweep.sh` from Task A1.
- Produces: git remote `upstream-ios` → `https://github.com/rarimo/rarime-ios-app.git`; subtree prefix `ios`; `scripts/import-upstream.sh` with function `pull_ios()` and `pull_android()`.
- Produces: `legacy-ios-shell/FoundationMobile/*.swift` — the port source for Tasks B6/B7/B9. Deleted at the end of Task B9.

- [ ] **Step 1: Move the existing shell out of the way**

```bash
git mv ios legacy-ios-shell
git commit -m "chore: quarantine the pre-fork SwiftUI shell as legacy-ios-shell/

Kept in-tree (not deleted) so Tasks B6/B7/B9 can port AttestationService,
Keychain, AppCheckFactory, ProofArtifact, EnclaveSeal, FunctionsService and
AuthService into the Rarimo fork. Deleted at the end of Task B9.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Add the upstream remote and import the subtree**

```bash
git remote add upstream-ios https://github.com/rarimo/rarime-ios-app.git
git fetch upstream-ios --depth=1
git subtree add --prefix=ios upstream-ios main --squash
```

Expected: a merge commit `Squashed 'ios/' content from commit …` plus `Merge commit '…' as 'ios'`.

> If `git subtree` refuses the shallow history (`fatal: refusing to merge
> unrelated histories`, or a complaint about a grafted commit), re-fetch without
> the depth limit and retry:
>
>     git fetch upstream-ios
>     git subtree add --prefix=ios upstream-ios main --squash
>
> The full fetch is larger — the repo tracks ~40 MB of `.a` binaries — but the
> `--squash` still keeps only one commit's worth of that in our history.

- [ ] **Step 3: Verify the GPL binaries came through**

```bash
git ls-files ios/Frameworks | grep -cE 'librapidsnark\.a|libwitnesscalc_.*\.a'
```

Expected: `14` (one rapidsnark + thirteen witnesscalc).

```bash
ls -la ios/Frameworks/librapidsnark.a
```

Expected: a real file, ~215 KB — not an LFS pointer.

- [ ] **Step 4: Run the brand sweep and watch it fail**

```bash
./scripts/brand-sweep.sh ios
```

Expected: `brand-sweep: FAIL` with well over a hundred hits across
`ios/Rarime/Code/**`, `ios/Rarime/SupportingFiles/Configs/*.xcconfig`,
`ios/Info.plist`, and `ios/Rarime.xcodeproj/project.pbxproj`.
This is the red state Tasks B1–B5 turn green.

- [ ] **Step 5: Write the upstream re-import helper**

Create `scripts/import-upstream.sh`:

```bash
#!/usr/bin/env bash
# Pull upstream Rarimo changes into the fork.
#
# IMPORTANT: after every pull, run scripts/brand-sweep.sh. Upstream commits
# reintroduce Rarimo branding into files this fork has rebranded; the sweep
# is what catches it. See spec section 3: "merging their updates means
# re-checking rebranded surfaces each time."
set -euo pipefail

usage() { echo "usage: $0 {ios|android|both}"; exit 2; }

pull_ios() {
  git remote get-url upstream-ios >/dev/null 2>&1 || \
    git remote add upstream-ios https://github.com/rarimo/rarime-ios-app.git
  git fetch upstream-ios
  git subtree pull --prefix=ios upstream-ios main --squash
}

pull_android() {
  git remote get-url upstream-android >/dev/null 2>&1 || \
    git remote add upstream-android https://github.com/rarimo/rarime-android-app.git
  git fetch upstream-android
  git subtree pull --prefix=android upstream-android main --squash
}

case "${1:-}" in
  ios)     pull_ios ;;
  android) pull_android ;;
  both)    pull_ios; pull_android ;;
  *)       usage ;;
esac

echo
echo "Upstream pulled. Now run:  ./scripts/brand-sweep.sh"
```

- [ ] **Step 6: Commit**

```bash
chmod +x scripts/import-upstream.sh
git add scripts/import-upstream.sh
git commit -m "chore(ios): import rarime-ios-app as the ios/ subtree

Subtree (not a flat copy) so upstream merges stay mechanical. Adds
scripts/import-upstream.sh, which reminds the operator to re-run
brand-sweep.sh after every pull.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task A3: Import `rarime-android-app` as `android/`

**Model tier:** Sonnet.

**Files:**
- Create: `android/` (imported subtree from `rarime-android-app`)
- Test: `scripts/brand-sweep.sh android` — must FAIL.

**Interfaces:**
- Consumes: `scripts/import-upstream.sh` (`pull_android`) from Task A2.
- Produces: git remote `upstream-android`; subtree prefix `android`.

- [ ] **Step 1: Import the subtree**

```bash
git remote add upstream-android https://github.com/rarimo/rarime-android-app.git
git fetch upstream-android --depth=1
git subtree add --prefix=android upstream-android main --squash
```

> Same shallow-history caveat as Task A2: if `git subtree` refuses the grafted
> history, re-run `git fetch upstream-android` without `--depth` and retry.
>
> Also check `android/.gitattributes` after the import — upstream declares
> `*.aar filter=lfs`. No `.aar` is currently tracked, so LFS stays inactive, but
> a future upstream merge that adds one would silently activate it. See Open
> Decision OD-7.

- [ ] **Step 2: Verify the GPL native libraries came through**

```bash
find android/app/src/main/cpp/lib -name '*.so' | wc -l
grep -c 'libwitnesscalc' android/app/src/main/cpp/CMakeLists.txt
```

Expected: `15` shared objects (10 in `lib/`, 5 in `lib/light/`), and at least `13`
`libwitnesscalc` references in `CMakeLists.txt`.

- [ ] **Step 3: Confirm the known upstream build blocker is present**

```bash
grep -n 'com.rarilabs.rarime.config' android/.gitignore
ls android/app/src/main/java/com/rarilabs/rarime/config/ 2>&1
grep -n 'import com.rarilabs.rarime.config.Keys' android/app/src/main/java/com/rarilabs/rarime/BaseConfig.kt
```

Expected: `.gitignore` lists `/app/src/main/java/com/rarilabs/rarime/config/`; the
directory does **not** exist; `BaseConfig.kt` imports `config.Keys` anyway.
**The upstream Android app therefore does not compile as cloned.** Task C1
reconstructs that file. Record this expectation here so C1's failure is
recognised as the known blocker, not a botched import.

- [ ] **Step 4: Run the brand sweep and watch it fail**

```bash
./scripts/brand-sweep.sh android
```

Expected: `brand-sweep: FAIL`, with hits concentrated in
`android/app/src/main/res/values/strings.xml`,
`android/app/src/main/java/com/rarilabs/rarime/BaseConfig.kt`,
`android/app/src/main/AndroidManifest.xml`, and
`android/app/src/main/java/com/rarilabs/rarime/ui/theme/*.kt`.

- [ ] **Step 5: Commit**

```bash
git commit --allow-empty -m "chore(android): import rarime-android-app as the android/ subtree

Unblocks the Android track, previously deferred in foundation-mobile for lack
of a near-term path (spec section 3, 'Android track'). Note: upstream does not
compile as cloned - app/src/main/java/com/rarilabs/rarime/config/Keys.kt is
gitignored upstream and reconstructed in Task C1.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task A4: Fork the identity SDK and repoint the iOS prebuild

**Model tier:** Sonnet.

**Files:**
- Modify: `ios/prebuild.sh`
- Create: `docs/build-identity-sdk.md`
- Test: `ios/prebuild.sh` runs to completion and produces `ios/Frameworks/Identity.xcframework`.

**Interfaces:**
- Consumes: `ios/` subtree from Task A2.
- Produces: `ios/Frameworks/Identity.xcframework` — the `Identity` Swift module that `ios/Rarime/Code/Modules/App/Views/AppView.swift:1` and `UserManager` import (`IdentityProfile`, `IdentityCallDataBuilder`). Gitignored build output, not committed.

- [ ] **Step 1: Fork the SDK on GitHub**

```bash
gh repo fork rarimo/rarime-mobile-identity-sdk --org dagangilat --clone=false --fork-name rarime-mobile-identity-sdk
gh repo view dagangilat/rarime-mobile-identity-sdk --json name,parent
```

Expected: the fork exists with `parent.name = "rarime-mobile-identity-sdk"`.

> Forking (rather than pinning upstream) matters for two reasons: the SDK is
> the CGO boundary where the GPL native code is linked (spec § 3 — `build/patch.sh`
> patches Go's cgo tool via a Rarimo-forked toolchain), so our corresponding-source
> obligation covers it; and upstream's `prebuild.sh` clones over **SSH**
> (`git@github.com:…`), which fails in CI without a deploy key.

- [ ] **Step 2: Read the current prebuild script before editing**

```bash
sed -n '1,40p' ios/prebuild.sh
```

Expected to contain `git clone git@github.com:rarimo/rarime-mobile-identity-sdk.git`
and `git pull origin main`.

- [ ] **Step 3: Repoint it at the fork over HTTPS**

Edit `ios/prebuild.sh` — replace the clone/pull block:

```bash
# Clone repository if it does not exist
if [ ! -d "rarime-mobile-identity-sdk" ]; then
    echo "⏳ Cloning the repository"
    git clone https://github.com/dagangilat/rarime-mobile-identity-sdk.git
fi

# Pull latest changes
echo "⏳ Pulling latest changes"
cd rarime-mobile-identity-sdk
git stash
git pull origin main
cd ..
```

(Only the clone URL changes: `git@github.com:rarimo/…` → `https://github.com/dagangilat/…`. Leave the gomobile build steps untouched.)

- [ ] **Step 4: Document the toolchain prerequisite**

Create `docs/build-identity-sdk.md`:

```markdown
# Building `Identity.xcframework`

`ios/prebuild.sh` produces `ios/Frameworks/Identity.xcframework` from
`dagangilat/rarime-mobile-identity-sdk` (our fork of Rarimo's SDK). It is a
build output — gitignored, never committed.

## Prerequisites

- Go toolchain on `PATH` (`/usr/local/go/bin` and `$HOME/go/bin`, which
  `prebuild.sh` prepends).
- `gomobile` (`go install golang.org/x/mobile/cmd/gomobile@latest` then
  `gomobile init`).
- Xcode command line tools.

## Why a fork, not a pin

The SDK's own `build/patch.sh` patches Go's `cgo` tool using a Rarimo-forked
Go toolchain. That patch exists because real native C code is linked through
CGO — the same GPL-3.0 `witnesscalc` / LGPL-3.0 `rapidsnark` stack the app
links directly on the Swift side. Because that native linkage is part of our
combined work, our GPL-3.0 corresponding-source obligation covers the SDK too,
so we host our own copy rather than depending on upstream availability.

## Run

    cd ios && ./prebuild.sh

Expected tail: `✅ Build completed successfully`, and
`ios/Frameworks/Identity.xcframework` present.

## If the build fails

`gomobile bind` failing on the cgo patch is the known failure mode. Check the
SDK's `build/patch.sh` ran, and that `go env CC` points at the patched
toolchain. Do not work around it by stubbing the framework: without the real
`Identity` module the app cannot prove anything.
```

- [ ] **Step 5: Run the build**

```bash
cd ios && ./prebuild.sh
```

Expected tail: `✅ Build completed successfully`

```bash
ls -d ios/Frameworks/Identity.xcframework
```

Expected: the directory exists.

- [ ] **Step 6: Confirm the framework stays untracked, then commit**

```bash
git check-ignore -v ios/Frameworks/Identity.xcframework || echo "NOT IGNORED - add to .gitignore"
```

If not ignored, append to `.gitignore`:

```
ios/Frameworks/Identity.xcframework/
ios/Build/
```

```bash
git add ios/prebuild.sh docs/build-identity-sdk.md .gitignore
git commit -m "build(ios): point prebuild.sh at our identity-SDK fork over HTTPS

Upstream cloned rarimo/rarime-mobile-identity-sdk over SSH, which fails in CI.
Forking also keeps the CGO boundary where the GPL native stack is linked under
our own corresponding-source obligation.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

# Phase B — iOS track

Tasks B1–B10 are sequential. The Android track (Phase C) shares only the
backend contract and the licensing posture, so it can run in parallel with
Phase B from Task C1 onward.

## Task B1: Replace Rarimo's build configuration and strip their checked-in secrets

**Model tier:** Sonnet.

**Files:**
- Modify: `ios/Rarime/SupportingFiles/Configs/Production.xcconfig`
- Modify: `ios/Rarime/SupportingFiles/Configs/Development.xcconfig`
- Create: `ios/Rarime/SupportingFiles/Configs/README.md`
- Test: `ios/RarimeTests/Tests/ConfigTests/FoundationConfigTests.swift` (new)

**Interfaces:**
- Consumes: the `ios/` subtree from Task A2.
- Produces: xcconfig keys consumed by `ios/Rarime/Code/Managers/ConfigManager.swift` — the existing key names are kept so `ConfigManager` needs no change; only their values change. Two keys are **added**: `FOUNDATION_FUNCTIONS_REGION` and `FOUNDATION_APP_SCHEME`.

> **Security finding — act on this first.** Upstream's
> `ios/Rarime/SupportingFiles/Configs/Development.xcconfig` contains two live
> secrets committed to a public repo:
> `LIGHT_SIGNATURE_PRIVATE_KEY="86494b0b…"` and `JOIN_REWARDS_KEY="15690e44…"`.
> They are Rarimo's, not ours. Republishing them from our public repo is both
> a security problem for them and a liability for us. They must be blanked in
> the first commit that touches this file.

- [ ] **Step 1: Write the failing test**

Create `ios/RarimeTests/Tests/ConfigTests/FoundationConfigTests.swift`:

```swift
import XCTest
@testable import Rarime

/// Guards the fork's build configuration against two regressions:
///  1. re-inheriting Rarimo's hosted endpoints (analytics/referrals would
///     flow into Rarimo's systems), and
///  2. re-inheriting Rarimo's checked-in private keys.
final class FoundationConfigTests: XCTestCase {
    private func configValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }

    func testAppsFlyerIsDisabled() {
        // Rarimo's dev key must never ship in a Foundation build - it would
        // attribute our installs to their AppsFlyer account.
        XCTAssertEqual(configValue("APPSFLYER_DEV_KEY"), "")
    }

    func testNoRarimoReferralCode() {
        XCTAssertEqual(configValue("DEFAULT_REFERRAL_CODE"), "")
    }

    func testFeedbackEmailIsFoundations() {
        XCTAssertFalse(configValue("FEEDBACK_EMAIL").contains("rarilabs"))
        XCTAssertFalse(configValue("FEEDBACK_EMAIL").isEmpty)
    }

    func testLegalUrlsAreFoundations() {
        XCTAssertFalse(configValue("TERMS_OF_USE_URL").contains("rarime.com"))
        XCTAssertFalse(configValue("PRIVACY_POLICY_URL").contains("rarime.com"))
    }

    func testNoInheritedPrivateKeys() {
        // Upstream committed real keys here. Blanked in the fork.
        XCTAssertEqual(configValue("LIGHT_SIGNATURE_PRIVATE_KEY"), "")
        XCTAssertEqual(configValue("JOIN_REWARDS_KEY"), "")
    }

    func testFoundationFunctionsRegionIsSet() {
        XCTAssertEqual(configValue("FOUNDATION_FUNCTIONS_REGION"), "us-east1")
    }

    func testAppSchemeIsFoundations() {
        XCTAssertEqual(configValue("FOUNDATION_APP_SCHEME"), "foundationmobile")
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd ios && xcodebuild test \
  -project Rarime.xcodeproj -scheme Rarime \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:RarimeTests/FoundationConfigTests 2>&1 | tail -20
```

Expected: FAIL — `testAppsFlyerIsDisabled` (Rarimo's committed AppsFlyer dev key ≠ `""`),
`testNoInheritedPrivateKeys`, `testFoundationFunctionsRegionIsSet` (key absent),
and the legal-URL assertions.

- [ ] **Step 3: Rewrite Production.xcconfig**

Replace `ios/Rarime/SupportingFiles/Configs/Production.xcconfig` entirely:

```
// MARK: Utils
SLASH=/

// MARK: General
// Foundation-owned. AppsFlyer and the referral programme are Rarimo-ecosystem
// features stripped in Task B5 - the keys are blanked, not repointed.
FEEDBACK_EMAIL="support@foundation-global.com"
DEFAULT_REFERRAL_CODE=""
WEB_APP_URL="https:${SLASH}/foundation-next-app-web.web.app"
TERMS_OF_USE_URL="https:${SLASH}/foundation-next-app-web.web.app/legal/terms"
PRIVACY_POLICY_URL="https:${SLASH}/foundation-next-app-web.web.app/legal/privacy"
APP_API_URL="https:${SLASH}/api.app.rarime.com"

// MARK: Foundation backend
// Cloud Functions region for every callable this app uses (see the plan's
// Global Constraints). Firebase project comes from GoogleService-Info.plist.
FOUNDATION_FUNCTIONS_REGION="us-east1"
FOUNDATION_APP_SCHEME="foundationmobile"

// MARK: Notifications
GENERAL_NOTIFICATION_TOPIC="foundation"
CLAIMABLE_NOTIFICATION_TOPIC="foundation-rewardable"

// MARK: Contracts
// RETAINED FROM UPSTREAM. Passport registration is anchored on Rarimo's L2 and
// our verificator-svc validates against that same registration state, so these
// addresses must keep matching Rarimo's mainnet deployment. See Open Decision
// OD-5 before changing any of them.
REGISTRATION2_CONTRACT_ADDRESS="0x11BB4B14AA6e4b836580F3DBBa741dD89423B971"
REGISTRATION_SIMPLE_CONTRACT_ADRRESS="0x497D6957729d3a39D43843BD27E6cbD12310F273"
CERTIFICATES_SMT_CONTRACT_ADDRESS="0xA8b350d699632569D5351B20ffC1b31202AcEDD8"
REGISTRATION_SMT_CONTRACT_ADDRESS="0x479F84502Db545FA8d2275372E0582425204A879"
STATE_KEEPER_CONTRACT_ADDRESS="0x61aa5b68D811884dA4FEC2De4a7AA0464df166E1"
MULTICALL3_CONTRACT_ADDRESS="0xb4EE49BDf7cf199081b2a286B2B9B5f87AE930b1"
VOTING_REGISTRATION_SMT_CONTRACT_ADDRESS="0x479F84502Db545FA8d2275372E0582425204A879"
PROPOSALS_STATE_CONTRACT_ADDRESS="0x9C4b84a940C9D3140a1F40859b3d4367DC8d099a"
FACE_REGISTRY_CONTRACT_ADDRESS="0x15DCd57B70D97F1D1F220ccb4e6B8E886aF3e3B9"
GUESS_CELEBRITY_CONTRACT_ADDRESS="0x0000000000000000000000000000000000000000"

// MARK: EVM
// RETAINED: the registration relayer and RPC are the proving substrate.
EVM_RPC_URL="https:${SLASH}/l2.rarimo.com"
EVM_CHAIN_ID="7368"
EVM_SCAN_URL="https:${SLASH}/scan.rarimo.com"
EVM_SCAN_API_URL="https:${SLASH}/evmscan.l2.rarimo.com"

// MARK: Freedom Tool
// STRIPPED in Task B5 - the Polls module is removed. Blanked rather than
// deleted so ConfigManager's decoding stays total.
FREEDOM_TOOL_RPC_URL=""
FREEDOM_TOOL_IPFS_NODE_URL="https:${SLASH}/ipfs.rarimo.com"
FREEDOM_TOOL_WEBSITE_URL=""
FREEDOM_TOOL_API_URL=""

// MARK: AppsFlyer
// STRIPPED - see Task B5. Blank keys make AppsFlyerLib a no-op.
APPSFLYER_DEV_KEY=""
APPSFLYER_APP_ID=""

// MARK: Secrets
// Upstream committed live Rarimo keys here. Never repopulate from upstream.
JOIN_REWARDS_KEY=""
LIGHT_SIGNATURE_PRIVATE_KEY=""
```

- [ ] **Step 4: Point Development.xcconfig at the same single tier**

This fork has no staging tier (Global Constraints). Replace
`ios/Rarime/SupportingFiles/Configs/Development.xcconfig` with a copy of the
production file plus a marker:

```bash
cd ios/Rarime/SupportingFiles/Configs
cp Production.xcconfig Development.xcconfig
```

Then edit `Development.xcconfig`, changing only the notification topics so a
debug build cannot receive production pushes:

```
GENERAL_NOTIFICATION_TOPIC="foundation-dev"
CLAIMABLE_NOTIFICATION_TOPIC="foundation-rewardable-dev"
```

- [ ] **Step 5: Document why the two configs are near-identical**

Create `ios/Rarime/SupportingFiles/Configs/README.md`:

```markdown
# Build configurations

This fork has a **single Firebase/backend tier** (`foundation-next-app`) — see
the repo CLAUDE.md. Upstream Rarimo shipped genuinely different
staging/production backends here; we do not have a staging tier, so
`Development.xcconfig` is a copy of `Production.xcconfig` differing only in the
FCM topic names, so a debug build cannot receive production pushes.

## Never copy these back from upstream

Upstream's `Development.xcconfig` contains **live Rarimo private keys**
(`LIGHT_SIGNATURE_PRIVATE_KEY`, `JOIN_REWARDS_KEY`) and their AppsFlyer dev key.
This is a public repository. `scripts/brand-sweep.sh` catches the AppsFlyer key
by name; the private keys are guarded by
`RarimeTests/Tests/ConfigTests/FoundationConfigTests.swift`.

## Retained Rarimo endpoints — deliberate

`APP_API_URL`, `EVM_RPC_URL`, and the contract addresses still point at
Rarimo's infrastructure. Passport registration is anchored on Rarimo's L2, and
`foundation-next`'s `verificator-svc` validates proofs against that same
registration state. Repointing them means running our own registration relayer
and SMT contracts. See Open Decision OD-5.
```

- [ ] **Step 6: Re-run the test**

```bash
cd ios && xcodebuild test \
  -project Rarime.xcodeproj -scheme Rarime \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:RarimeTests/FoundationConfigTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, 7 tests passing.

- [ ] **Step 7: Commit**

```bash
git add ios/Rarime/SupportingFiles/Configs ios/RarimeTests/Tests/ConfigTests
git commit -m "chore(ios): Foundation build config; strip Rarimo's committed secrets

Upstream Development.xcconfig committed live LIGHT_SIGNATURE_PRIVATE_KEY and
JOIN_REWARDS_KEY values plus their AppsFlyer dev key. All blanked - this repo
is public and those are Rarimo's keys, not ours. Retains APP_API_URL and the
L2 contract addresses deliberately: verificator-svc validates against that
same registration state (Open Decision OD-5).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B2: Xcode project identity — target rename, bundle ID, display name, URL scheme

**Model tier:** Sonnet (mechanical but `project.pbxproj` edits are unforgiving — verify after each).

**Files:**
- Modify (rename): `ios/Rarime.xcodeproj` → `ios/FoundationMobile.xcodeproj`
- Modify (rename): `ios/Rarime/` → `ios/FoundationMobile/`
- Modify (rename): `ios/RarimeTests/` → `ios/FoundationTests/`
- Modify: `ios/FoundationMobile.xcodeproj/project.pbxproj`
- Modify: `ios/Info.plist`
- Modify (rename): `ios/FoundationMobile/Code/RarimeApp.swift` → `ios/FoundationMobile/Code/FoundationApp.swift`
- Test: `scripts/brand-sweep.sh ios` (partial — still fails on strings/assets until B3/B4)

**Interfaces:**
- Consumes: Task B1's xcconfig key `FOUNDATION_APP_SCHEME`.
- Produces: Xcode scheme name `FoundationMobile`, product bundle id `com.foundationnext.mobile`, URL scheme `foundationmobile://`. Every later `xcodebuild` invocation in this plan uses `-project FoundationMobile.xcodeproj -scheme FoundationMobile`.

> **The target/module MUST be `FoundationMobile`, not `Foundation`.** A Swift
> module named `Foundation` shadows the system framework: all 255 of Rarimo's
> files begin `import Foundation`, and every one would fail with "cannot load
> underlying module". (Same footgun for a target named `SwiftUI` or `Combine`.)
> The **display name is still `Foundation`** — `INFOPLIST_KEY_CFBundleDisplayName`
> is independent of the module name, so the launcher label and the module name
> deliberately differ here.

- [ ] **Step 1: Record the exact strings to change (the failing observation)**

```bash
cd ios
grep -n 'PRODUCT_BUNDLE_IDENTIFIER\|INFOPLIST_KEY_CFBundleDisplayName\|DEVELOPMENT_TEAM' \
  Rarime.xcodeproj/project.pbxproj | sort -u -t= -k2
grep -n -A3 CFBundleURLSchemes Info.plist
```

Expected (the red state):
```
PRODUCT_BUNDLE_IDENTIFIER = Rarilabs.Rarime;
PRODUCT_BUNDLE_IDENTIFIER = Rarilabs.Rarime.NotificationBackgroundProcessor;
INFOPLIST_KEY_CFBundleDisplayName = Rarimo;
INFOPLIST_KEY_CFBundleDisplayName = NotificationBackgroundProcessor;
DEVELOPMENT_TEAM = P7Z93A3C8U;
...
<key>CFBundleURLSchemes</key>
<array>
    <string>rarime</string>
```

- [ ] **Step 2: Rename the directories and project**

```bash
cd ios
git mv Rarime.xcodeproj FoundationMobile.xcodeproj
git mv Rarime FoundationMobile
git mv RarimeTests FoundationTests
git mv Foundation/Code/RarimeApp.swift Foundation/Code/FoundationApp.swift
```

- [ ] **Step 3: Rewrite the path and identifier references inside the project file**

```bash
cd ios
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("FoundationMobile.xcodeproj/project.pbxproj")
s = p.read_text()

subs = [
    # Bundle identifiers (longest first so the extension suffix survives).
    ("Rarilabs.Rarime.NotificationBackgroundProcessor",
     "com.foundationnext.mobile.NotificationBackgroundProcessor"),
    ("Rarilabs.Rarime", "com.foundationnext.mobile"),
    # Signing team.
    ("DEVELOPMENT_TEAM = P7Z93A3C8U;", "DEVELOPMENT_TEAM = F9F26FQW95;"),
    # Display name.
    ("INFOPLIST_KEY_CFBundleDisplayName = Rarimo;",
     "INFOPLIST_KEY_CFBundleDisplayName = Foundation;"),
    # Directory / target / group names.
    ("RarimeTests", "FoundationTests"),
    ("RarimeApp.swift", "FoundationApp.swift"),
    ("Rarime.xcodeproj", "FoundationMobile.xcodeproj"),
    ("Rarime/", "FoundationMobile/"),
    ("= Rarime;", "= FoundationMobile;"),
    ('"Rarime"', '"FoundationMobile"'),
]
for a, b in subs:
    s = s.replace(a, b)

p.write_text(s)
print("rewritten")
PY
```

- [ ] **Step 4: Verify the rewrite landed and nothing dangles**

```bash
cd ios
grep -n 'PRODUCT_BUNDLE_IDENTIFIER\|INFOPLIST_KEY_CFBundleDisplayName\|DEVELOPMENT_TEAM' \
  FoundationMobile.xcodeproj/project.pbxproj | sort -u -t= -k2
grep -c 'Rarime' FoundationMobile.xcodeproj/project.pbxproj
```

Expected: bundle ids are `com.foundationnext.mobile` and
`com.foundationnext.mobile.NotificationBackgroundProcessor`; display name
`Foundation`; team `F9F26FQW95`; and the `Rarime` count is **0**.

- [ ] **Step 5: Rename the shared scheme**

```bash
cd ios
ls FoundationMobile.xcodeproj/xcshareddata/xcschemes/
git mv FoundationMobile.xcodeproj/xcshareddata/xcschemes/Rarime.xcscheme \
       FoundationMobile.xcodeproj/xcshareddata/xcschemes/FoundationMobile.xcscheme
python3 - <<'PY'
import pathlib
p = pathlib.Path("FoundationMobile.xcodeproj/xcshareddata/xcschemes/FoundationMobile.xcscheme")
p.write_text(p.read_text().replace("Rarime", "Foundation"))
print("scheme rewritten")
PY
```

- [ ] **Step 6: Change the URL scheme in Info.plist**

Edit `ios/Info.plist` — replace the `CFBundleURLSchemes` entry:

```xml
			<key>CFBundleURLSchemes</key>
			<array>
				<string>foundationmobile</string>
			</array>
```

Also set `CFBundleURLName` in the same dict to `com.foundationnext.mobile`.

- [ ] **Step 7: Rename the `@main` struct**

Edit `ios/FoundationMobile/Code/FoundationApp.swift`:

```swift
@main
struct FoundationApp: App {
```

(only the struct name changes; the body and every `.environmentObject` line stay as-is — the manager strip happens in Task B5.)

- [ ] **Step 8: Repoint Task B1's test at the renamed module**

`ios/FoundationTests/Tests/ConfigTests/FoundationConfigTests.swift` was written in
Task B1, before this rename, so it still says `@testable import Rarime`. The test
target will not compile until it is updated:

```bash
cd ios
grep -rn '@testable import Rarime' FoundationTests
sed -i '' 's/@testable import Rarime/@testable import FoundationMobile/' \
  FoundationTests/Tests/ConfigTests/FoundationConfigTests.swift
grep -rn '@testable import' FoundationTests
```

Expected after: `@testable import FoundationMobile`, and no remaining
`@testable import Rarime` anywhere.

- [ ] **Step 9: Build**

```bash
cd ios && xcodebuild build \
  -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

> If the build fails on a missing `Identity` module, re-run `./prebuild.sh`
> (Task A4) — the framework is a gitignored build output and does not survive
> a clean checkout.

- [ ] **Step 10: Commit**

```bash
git add -A ios
git commit -m "chore(ios): rename Rarime -> Foundation and repoint app identity

Bundle com.foundationnext.mobile, display name Foundation, team F9F26FQW95,
URL scheme foundationmobile://. Project, scheme, source dir and test dir all
renamed so no build setting still says Rarime.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B3: Visual rebrand — app icon, launch mark, colors, intro imagery

**Model tier:** Sonnet for the mechanics; the icon artwork itself is an asset-production step (see Open Decision OD-6 if no final artwork exists yet).

**Files:**
- Modify: `ios/FoundationMobile/Resources/Assets.xcassets/AppIcons/` (5 icon sets)
- Modify: `ios/FoundationMobile/Resources/Assets.xcassets/Colors/PrimaryMain.colorset/Contents.json` (+ the Primary/Secondary ramps)
- Modify: `ios/FoundationMobile/Resources/Assets.xcassets/GradientColors/` (green/purple ramps)
- Modify: `ios/FoundationMobile/Resources/Assets.xcassets/Images/Intro*.imageset/`
- Modify: `ios/FoundationMobile/Code/Modules/App/Views/AppView.swift:48` (the `Image(.rarime)` splash mark)
- Delete: `ios/FoundationMobile/Resources/Assets.xcassets/Icons/Rarime.imageset` (source of the `.rarime` symbol)
- Test: `ios/FoundationTests/Tests/BrandingTests/AssetBrandingTests.swift` (new)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: asset catalog symbol `.foundationMark` replacing `.rarime`, used by `AppView`.

> **Palette source of truth — do not invent colors.** The pre-fork shell already
> carried Foundation's agreed palette in
> `legacy-ios-shell/FoundationMobile/Theme.swift`, in the `foundation`
> `ThemePalette` (the one `Resources/profiles/foundation.json` selects, and the
> default profile for both Debug and Release):
>
> | Token | Hex | Role |
> |---|---|---|
> | `bg` | `#f6f9fc` | page background |
> | `surface` | `#ffffff` | cards, sheets |
> | `border` | `#e6ebf1` | hairlines |
> | `muted` | `#596171` | secondary text |
> | `brandGreen` | `#047857` | **primary accent** — CTAs, active states, text-safe |
> | `brandFill` | `#34d399` | decorative fill only — gradients, chip tints, never text |
> | `brandCyan` | `#22d3ee` | secondary accent |
> | `voice` | `#6366f1` | Your Voice pillar |
> | `share` | `#0d9488` | Your Share pillar |
> | `market` | `#0891b2` | Your Market pillar |
> | `text` | `#0a0e27` | primary text |
> | `onAccent` | `#ffffff` | text/glyph on a filled accent |
>
> `isDark: false` — this is a light palette, and Rarimo's app defaults to a dark
> scheme, so check contrast on every screen after remapping. Rarimo's primary
> accent is also a green ramp, so `PrimaryMain → brandGreen` is a direct swap;
> their purple secondary ramp has no Foundation counterpart and maps to
> `brandFill`.

- [ ] **Step 1: Write the failing test**

Create `ios/FoundationTests/Tests/BrandingTests/AssetBrandingTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Confirm the palette source, so the mapping table is grounded**

```bash
python3 -c "
import json, glob
for f in sorted(glob.glob('legacy-ios-shell/FoundationMobile/Resources/profiles/*.json')):
    d = json.load(open(f))
    print(f.split('/')[-1], '->', d.get('theme', {}).get('palette'))
"
grep -n 'static let foundation' -A 9 legacy-ios-shell/FoundationMobile/Theme.swift
```

Expected: `foundation.json -> foundation`, and the palette

```
bg #f6f9fc   surface #ffffff   border #e6ebf1   muted #596171
brandGreen #047857   brandFill #34d399   brandCyan #22d3ee
voice #6366f1   share #0d9488   market #0891b2
text #0a0e27   onAccent #ffffff   isDark false
```

These are the exact values Step 6's mapping table uses, and the same ones Task
C3 pins on Android.

- [ ] **Step 3: Run the test and watch it fail**

```bash
cd ios && xcodebuild test \
  -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/AssetBrandingTests 2>&1 | tail -20
```

Expected: FAIL on `testRarimeSplashMarkIsGone`, `testFoundationMarkExists`,
`testAlternateAppIconsAreFoundations`, and the color assertion.

- [ ] **Step 4: Replace the splash mark**

```bash
cd ios/FoundationMobile/Resources/Assets.xcassets/Icons
git mv Rarime.imageset FoundationMark.imageset
```

Edit `FoundationMark.imageset/Contents.json` so `filename` points at the
Foundation mark artwork, and drop in the artwork itself. The pre-fork shell has
a usable vector source at `legacy-ios-shell/FoundationMobile/foundation-appicon.svg`
and raster logo sets under
`legacy-ios-shell/FoundationMobile/Images.xcassets/LaunchLogo.imageset/` —
copy from there rather than commissioning new art.

Then update the call site, `ios/FoundationMobile/Code/Modules/App/Views/AppView.swift:48`:

```swift
                    Image(.foundationMark)
                        .square(96)
                        .foregroundStyle(Gradients.gradientFirst)
```

- [ ] **Step 5: Replace the app icons**

```bash
cd ios/FoundationMobile/Resources/Assets.xcassets/AppIcons
git rm -r CatIcon.appiconset
```

For each of `BlackIcon`, `WhiteIcon`, `GreenIcon`, `GradientIcon`: replace the
single PNG inside with a Foundation-branded 1024×1024 render. Source artwork:
`legacy-ios-shell/FoundationMobile/Images.xcassets/AppIcon.appiconset/`.

Then remove the CatIcon entry from `ios/Info.plist`'s
`CFBundleIcons` → `CFBundleAlternateIcons` dictionary, and from
`ios/FoundationMobile/Code/Enums/AppIcon.swift` (the enum case and its display name).

- [ ] **Step 6: Remap the color ramps**

For each colorset under
`ios/FoundationMobile/Resources/Assets.xcassets/Colors/`, edit `Contents.json`'s
sRGB components. The mapping (Rarimo → Foundation, values from the shell's
`ThemePalette`):

| Rarimo colorset | Foundation token |
|---|---|
| `PrimaryMain`, `PrimaryDark`, `PrimaryDarker`, `PrimaryLight`, `PrimaryLighter` | `brandGreen` ramp |
| `SecondaryMain` + ramp | `brandCyan` ramp |
| `BgPrimary`, `BgPure` | `bg` |
| `BgSurface1`, `BgSurface2`, `BgContainer` | `surface` |
| `TextPrimary` | `text` |
| `TextSecondary`, `TextPlaceholder`, `TextDisabled` | `muted` (at decreasing opacity) |
| `AdditionalPurple`, `BgPurple`, `Purple*` | `brandFill` — Rarimo's purple is their secondary brand color and must not survive |
| `GradientColors/PurpleBgGradient*`, `PurpleTextGradient*` | `brandFill` → `brandCyan` gradient |
| `GradientColors/GreenTextGradient*`, `LimeTextGradient*` | `brandGreen` → `brandFill` gradient |

Leave the semantic ramps (`Error*`, `Warning*`, `Success*`, `Informational*`)
untouched — they are not brand-carrying.

- [ ] **Step 7: Replace the intro imagery**

```bash
ls ios/FoundationMobile/Resources/Assets.xcassets/Images/ | grep -i intro
```

Expected: `IntroIdentity`, `IntroPrivacy`, `IntroWelcome`, `IntroWidgets`.
These are Rarimo-specific onboarding illustrations shown by
`ios/FoundationMobile/Code/Modules/Intro/Views/IntroView.swift`. Replace the PNGs with
Foundation artwork, or — if none exists — delete the imagesets and simplify
`IntroView` to a text-and-icon layout (see Open Decision OD-6).

- [ ] **Step 8: Re-run the test**

```bash
cd ios && xcodebuild test \
  -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/AssetBrandingTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add -A ios
git commit -m "feat(ios): Foundation visual identity - icons, splash mark, palette

Maps Rarimo's color ramps onto the Foundation palette already agreed in the
pre-fork shell's Theme.swift, replaces the app icon set (dropping Rarimo's
CatIcon), and swaps the splash mark. AssetBrandingTests fails if any of them
regresses on an upstream merge.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B4: Copy rebrand — every user-visible Rarimo string

**Model tier:** Sonnet.

**Files:**
- Modify: `ios/FoundationMobile/Resources/Localizable.xcstrings` (599 keys; 15 mention the brand, 8 carry it in a *value*)
- Modify: `ios/FoundationMobile/Code/Modules/Common/Views/MaintenanceView.swift`
- Modify: `ios/FoundationMobile/Code/Modules/Home/Views/HomeOnboardingView.swift`
- Modify: `ios/FoundationMobile/Code/Modules/Intro/Views/IntroView.swift`
- Modify: `ios/FoundationMobile/Code/Modules/ScanPassport/Views/PassportChipErrorView.swift`
- Modify: `ios/FoundationMobile/Code/Managers/ExternalRequestsManager.swift` (log/alert copy)
- Test: `scripts/brand-sweep.sh ios` — the primary gate.

**Interfaces:**
- Consumes: `scripts/brand-sweep.sh` from Task A1.
- Produces: no code interface; this is a copy-only task.

- [ ] **Step 1: Enumerate the exact keys to change (the red state)**

```bash
python3 - <<'PY'
import json, re
d = json.load(open("ios/FoundationMobile/Resources/Localizable.xcstrings"))
brand = re.compile(r'rari(me|mo)|\bRMO\b', re.I)
key_hits, val_hits = [], []
for k, v in d["strings"].items():
    if brand.search(k):
        key_hits.append(k)
    if brand.search(json.dumps(v)):
        val_hits.append(k)
print(f"{len(d['strings'])} total keys")
print(f"{len(key_hits)} keys with brand in the KEY:")
for k in key_hits: print("  K:", k[:120])
print(f"{len(val_hits)} keys with brand in a VALUE:")
for k in val_hits: print("  V:", k[:120])
PY
```

Expected (verified against upstream HEAD): 599 total keys, 15 with the brand in
the key, 8 with it in a translated value. The full key list includes:
`RariMe`, `RMO`, `Earn RMO`, `Invite to RariMe`, `Invite to Rarimo`,
`Join RariMe with my invite code: %@`, `Join Rarimo with my invite code: %@`,
`RariMe lets you prove your identity - without giving anything away`,
`Rarimo lets you prove your identity - without giving anything away`,
`Enable Face ID in Settings > RariMe.`, `Enable Face ID in Settings > Rarimo.`,
`Complete various tasks and get rewarded with Rarimo tokens` (×2 wrappings),
`I just set a personal AI-usage rule for my digital likeness in rariMe…`, and
the AI-likeness marketing paragraph.

- [ ] **Step 2: Run the sweep and confirm it fails on these files**

```bash
./scripts/brand-sweep.sh ios | grep -c 'Localizable.xcstrings'
```

Expected: a non-zero count.

- [ ] **Step 3: Apply the copy substitutions**

Because Xcode string catalogs key on the source string, a rename changes both
the key and the value. Apply this exact mapping:

| Upstream string | Foundation replacement |
|---|---|
| `RariMe` / `Rarimo` (standalone app name) | `Foundation` |
| `RariMe lets you prove your identity - without giving anything away` | `Foundation lets you prove your identity — without giving anything away` |
| `Rarimo lets you prove your identity - without giving anything away` | *(delete — duplicate of the above once both collapse to "Foundation")* |
| `Enable Face ID in Settings > RariMe.` / `… > Rarimo.` | `Enable Face ID in Settings > Foundation.` |
| `Invite to RariMe` / `Invite to Rarimo` | `Invite to Foundation` |
| `Join RariMe with my invite code: %@\n\n%@` | `Join Foundation with my invite code: %@\n\n%@` |
| `RMO`, `Earn RMO`, `Complete various tasks and get rewarded with Rarimo tokens` | *(delete — the Earn module is removed in Task B5)* |
| `I just set a personal AI-usage rule for my digital likeness in rariMe…` | *(delete — the Likeness module is removed in Task B5)* |
| `AI can now replicate your face, voice, and identity…` | *(delete — Likeness marketing copy)* |

Script the mechanical half:

```bash
python3 - <<'PY'
import json, pathlib, re

p = pathlib.Path("ios/FoundationMobile/Resources/Localizable.xcstrings")
d = json.loads(p.read_text())

# Keys deleted outright: they belong to modules stripped in Task B5.
DROP = {
    "RMO", "Earn RMO",
    "Complete various tasks and get rewarded with\nRarimo tokens",
    "Complete various tasks and get rewarded with Rarimo tokens",
    "Rarimo lets you prove your identity - without giving anything away",
}
RENAME = {
    "RariMe": "Foundation",
    "Enable Face ID in Settings > RariMe.": "Enable Face ID in Settings > Foundation.",
    "Enable Face ID in Settings > Rarimo.": "Enable Face ID in Settings > Foundation.",
    "Invite to RariMe": "Invite to Foundation",
    "Invite to Rarimo": "Invite to Foundation",
    "RariMe lets you prove your identity - without giving anything away":
        "Foundation lets you prove your identity — without giving anything away",
}

out = {}
for k, v in d["strings"].items():
    if k in DROP:
        continue
    nk = RENAME.get(k, k)
    # Also rewrite brand text inside translated values.
    blob = json.dumps(v)
    blob = blob.replace("RariMe", "Foundation").replace("rariMe", "Foundation")
    blob = blob.replace("Rarimo", "Foundation")
    out.setdefault(nk, json.loads(blob))

d["strings"] = out
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
print(f"{len(out)} keys remain")
PY
```

Then hand-review the remaining marketing paragraphs — the AI-likeness copy
mentions "your digital likeness" and belongs to a module being deleted; remove
those keys rather than rewriting them into Foundation's voice.

- [ ] **Step 4: Fix the hardcoded Swift strings the catalog does not cover**

```bash
grep -rn 'RariMe\|Rarimo\|rarime\|rarimo' ios/FoundationMobile/Code --include='*.swift'
```

Expected hits and their fixes:
- `ExternalRequestsManager.swift` — the literals `"Invalid RariMe app URL"`,
  `"Invalid RariMe URL host: …"` and the type name `RarimeUrlHosts`. Rename the
  enum to `FoundationUrlHosts` and change the copy to `"Invalid app link"`.
  (The scheme/host allowlist itself is rewritten in Task B8 — leave it for now.)
- `MaintenanceView.swift`, `VersionUpdateView.swift`, `ProfileView.swift`,
  `HomeOnboardingView.swift`, `IntroView.swift`, `PassportChipErrorView.swift`,
  `QRCodeView.swift`, `AuthMethodView.swift` — replace brand mentions with
  `Foundation`.
- `CircuitData.swift`, `ZKUtils.swift`, `CloudStorage.swift`,
  `NotificationManager.swift` — these reference Rarimo **infrastructure**
  (download URLs, GCS buckets, FCM topics), not branding. Leave the URLs; they
  are covered by Open Decision OD-5. Add an inline comment on each so the
  sweep's allowlist decision is legible:

```swift
// Rarimo-hosted circuit artifacts. Retained deliberately: our proofs are
// verified against Rarimo's L2 registration state. See Open Decision OD-5.
```

Then add those specific paths to the sweep's exemptions in
`scripts/brand-sweep.sh` (extend `EXCLUDES` with
`--exclude=CircuitData.swift --exclude=ZKUtils.swift --exclude=CloudStorage.swift`)
and record why in the script's header comment.

- [ ] **Step 5: Run the sweep**

```bash
./scripts/brand-sweep.sh ios
```

Expected at this point: still FAIL, but only on files owned by Task B5's module
strip (`Modules/Earn`, `Modules/HiddenKeys`, `Modules/Likeness`,
`Modules/PrizeScan`, `Modules/Polls`) and on `FoundationMobile.xcodeproj` group names
for those modules. Confirm nothing else remains:

```bash
./scripts/brand-sweep.sh ios | grep -v 'Modules/Earn\|Modules/HiddenKeys\|Modules/Likeness\|Modules/PrizeScan\|Modules/Polls'
```

Expected: only the `brand-sweep: FAIL` header line and the count line.

- [ ] **Step 6: Build and commit**

```bash
cd ios && xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

```bash
git add -A ios scripts/brand-sweep.sh
git commit -m "feat(ios): rebrand user-visible copy from RariMe to Foundation

Rewrites the string catalog (599 keys; 15 brand-bearing) and the hardcoded
Swift literals. Rarimo infrastructure URLs in CircuitData/ZKUtils/CloudStorage
are retained deliberately and exempted from the sweep with an inline rationale
(Open Decision OD-5).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B5: Strip Rarimo-ecosystem modules

**Model tier:** Opus — this is the task with real judgement in it (each removal cascades into `MainTabs`, `HomeWidget`, `FoundationApp`'s environment objects, and the asset catalog).

**Files:**
- Delete: `ios/FoundationMobile/Code/Modules/Earn/`, `Modules/HiddenKeys/`, `Modules/Likeness/`, `Modules/PrizeScan/`, `Modules/Polls/`, `Modules/Wallet/`
- Delete: `ios/FoundationMobile/Code/Managers/LikenessManager.swift`, `Managers/WalletManager.swift`, `Managers/TensorFlowManager.swift`
- Delete: `ios/FoundationMobile/Code/Models/Services/Points.swift`
- Modify: `ios/FoundationMobile/Code/Modules/Main/ViewModels/MainView+ViewModel.swift`
- Modify: `ios/FoundationMobile/Code/Modules/Main/Views/MainViewLayout.swift`
- Modify: `ios/FoundationMobile/Code/Enums/HomeWidget.swift`
- Modify: `ios/FoundationMobile/Code/Modules/Home/Views/HomeWidgetsView.swift`
- Modify: `ios/FoundationMobile/Code/FoundationApp.swift`
- Modify: `ios/FoundationMobile/Code/Modules/App/Views/AppView.swift` (drop AppsFlyer)
- Test: `ios/FoundationTests/Tests/NavigationTests/MainTabsTests.swift` (new)

**Interfaces:**
- Consumes: nothing.
- Produces: `enum MainTabs: Int, CaseIterable { case home, identity, scanQr, profile }` — Task B8 attaches the verification entry point to `.identity`.

**Keep / strip decision, one line of reasoning each:**

| Module | Decision | Reasoning |
|---|---|---|
| `ScanPassport` | **KEEP** | The passport NFC + MRZ pipeline. This is the whole point of the fork. |
| `Identity` | **KEEP** | Identity creation/recovery — the secret key the proofs are bound to. |
| `Recovery` | **KEEP** | Losing the identity key means losing the verified status; recovery is not optional. |
| `Intro` | **KEEP, restyled in B3/B4** | Onboarding is needed; the Rarimo-specific copy/art is already replaced. |
| `Home` | **KEEP, trimmed** | The shell for widgets; strip the widgets whose modules are removed. |
| `Main`, `App`, `Common` | **KEEP** | Navigation and shared views. |
| `Profile` | **KEEP, trimmed** | Settings, app icon, language, security — all still relevant. |
| `Notifications` | **KEEP** | FCM already targets our own topics after Task B1. |
| `MRZScan` | **KEEP** | Feeds `ScanPassport`. |
| `Earn` | **STRIP** | RMO token rewards + referrals against Rarimo's points service. No Foundation analogue; shipping it points users at Rarimo's economy. |
| `HiddenKeys` | **STRIP** | A Rarimo prize game (`GUESS_CELEBRITY_CONTRACT_ADDRESS`). Pure Rarimo-ecosystem marketing. |
| `PrizeScan` | **STRIP** | The celebrity face-matching game feeding HiddenKeys. |
| `Likeness` | **STRIP** | Rarimo's "digital likeness / AI-usage rule" product, backed by their `FACE_REGISTRY_CONTRACT_ADDRESS`. A separate product, not identity verification. |
| `Polls` | **STRIP** | Freedom Tool voting on Rarimo's L2. Foundation has its own governance on Solana (spec § 5), which is not this code. |
| `Wallet` | **STRIP** | An RMO token wallet. Foundation's Solana invariant is that the app holds no keypair; shipping an EVM token wallet contradicts the product. |

- [ ] **Step 1: Write the failing test**

Create `ios/FoundationTests/Tests/NavigationTests/MainTabsTests.swift`:

```swift
import XCTest
@testable import FoundationMobile

final class MainTabsTests: XCTestCase {
    func testTabSetIsFoundations() {
        // Wallet is removed: Foundation's mobile app never holds a keypair.
        XCTAssertEqual(MainTabs.allCases, [.home, .identity, .scanQr, .profile])
    }

    func testNoWalletTab() {
        XCTAssertFalse(MainTabs.allCases.contains { "\($0)" == "wallet" })
    }

    func testHomeWidgetsAreFoundations() {
        // Earn / HiddenKeys / Likeness / Freedomtool widgets are all stripped.
        let names = HomeWidget.allCases.map { "\($0)".lowercased() }
        for banned in ["earn", "hiddenkeys", "likeness", "freedomtool"] {
            XCTAssertFalse(names.contains(banned), "widget \(banned) should be stripped")
        }
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/MainTabsTests 2>&1 | tail -20
```

Expected: FAIL — `MainTabs.allCases` is currently
`[.home, .identity, .scanQr, .wallet, .profile]`
(`ios/FoundationMobile/Code/Modules/Main/ViewModels/MainView+ViewModel.swift:4`).

- [ ] **Step 3: Delete the module directories and their managers**

```bash
cd ios/FoundationMobile/Code
git rm -r Modules/Earn Modules/HiddenKeys Modules/Likeness Modules/PrizeScan Modules/Polls Modules/Wallet
git rm Managers/LikenessManager.swift Managers/WalletManager.swift Managers/TensorFlowManager.swift
git rm Models/Services/Points.swift
```

> `TensorFlowManager` goes with `Likeness`/`PrizeScan` — it loads the celebrity
> face-recognition model (`FACE_RECOGNITION_MODEL_URL`). If a build error shows
> `ScanPassport` also depends on it, **restore it** and note that in the commit;
> the passport pipeline's own face handling must not be collaterally removed.

- [ ] **Step 4: Trim the tab bar**

Edit `ios/FoundationMobile/Code/Modules/Main/ViewModels/MainView+ViewModel.swift`:

```swift
enum MainTabs: Int, CaseIterable {
    case home, identity, scanQr, profile

    var iconName: ImageResource {
        switch self {
        case .home: .homeLine
        case .identity: .passportLine
        case .scanQr: .qrScan2Line
        case .profile: .userLine
        }
    }

    var activeIconName: ImageResource {
        switch self {
        case .home: .homeFill
        case .identity: .passportFill
        case .scanQr: .qrScan2Line
        case .profile: .userFill
        }
    }
}
```

Then remove the `case .wallet:` branch from the `switch` in
`ios/FoundationMobile/Code/Modules/Main/Views/MainViewLayout.swift`.

- [ ] **Step 5: Trim the home widgets**

Edit `ios/FoundationMobile/Code/Enums/HomeWidget.swift`, removing the `earn`,
`hiddenKeys`, `likeness`, `freedomtool` and `recovery`-adjacent-Rarimo cases
(keep `recovery` itself — it is identity recovery, which we keep), plus their
branches in every `switch` in that file and in
`ios/FoundationMobile/Code/Modules/Home/Views/HomeWidgetsView.swift` and
`SnapCarouselView.swift`.

Delete the orphaned artwork:

```bash
cd ios/FoundationMobile/Resources/Assets.xcassets/Images
git rm -r EarnBg.imageset HiddenKeysBg.imageset HiddenKeysWidget.imageset \
          HiddenKeysSocialShare.imageset HiddenKeysWinnerShare.imageset \
          LikenessBg.imageset LikenessWidget.imageset \
          FreedomtoolBg.imageset FreedomtoolWidget.imageset
```

- [ ] **Step 6: Drop the removed environment objects and AppsFlyer**

Edit `ios/FoundationMobile/Code/FoundationApp.swift` — remove these two lines from the
`WindowGroup` chain:

```swift
                .environmentObject(LikenessManager.shared)
                .environmentObject(WalletManager.shared)
```

And in the same file's `AppDelegate`, remove the AppsFlyer wiring (three lines
in `didFinishLaunchingWithOptions`, the `application(_:continue:)` override, and
the whole `extension AppDelegate: DeepLinkDelegate` block), plus the
`import AppsFlyerLib`. Then remove the AppsFlyer package from the Xcode project's
Swift Package dependencies.

> Rationale: AppsFlyer is configured entirely from `APPSFLYER_DEV_KEY`, which
> Task B1 blanked. Leaving the SDK linked with an empty key means a third-party
> attribution SDK in the binary doing nothing — an App Store privacy-manifest
> liability for no benefit.

- [ ] **Step 7: Build, fix the cascade, re-run the test**

```bash
cd ios && xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep -E 'error:' | head -30
```

Expect a cascade of "cannot find X in scope" errors on first build — every one
is a reference into a deleted module. Resolve each by deleting the referencing
code, not by restoring the module. Repeat until:

```bash
cd ios && xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/MainTabsTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: The brand sweep should now pass for iOS**

```bash
./scripts/brand-sweep.sh ios
```

Expected: `brand-sweep: PASS`

- [ ] **Step 9: Commit**

```bash
git add -A ios
git commit -m "feat(ios): strip Rarimo-ecosystem modules

Removes Earn/RMO, HiddenKeys, PrizeScan, Likeness, Polls (Freedom Tool) and
Wallet, with their managers, widgets and artwork. Wallet in particular
contradicts Foundation's hard invariant that the mobile app holds no keypair.
Also removes AppsFlyer, whose key was blanked in B1 - an attribution SDK doing
nothing is a privacy-manifest liability. Keeps ScanPassport, Identity,
Recovery, Home, Main, Profile, Notifications, MRZScan.

brand-sweep now passes for ios/.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B6: Port Firebase Auth (OTP sign-in) into the fork

**Model tier:** Opus — this bolts a whole auth identity onto an app that has none.

**Files:**
- Create: `ios/FoundationMobile/Code/Foundation/FunctionsService.swift`
- Create: `ios/FoundationMobile/Code/Foundation/AuthService.swift`
- Create: `ios/FoundationMobile/Code/Foundation/Keychain.swift`
- Create: `ios/FoundationMobile/Code/Modules/FoundationAuth/Views/SignInView.swift`
- Modify: `ios/FoundationMobile/Code/Modules/App/Views/AppView.swift`
- Modify: `ios/FoundationMobile/Code/FoundationApp.swift`
- Test: `ios/FoundationTests/Tests/FoundationTests/AuthServiceTests.swift` (new)

**Interfaces:**
- Consumes: `legacy-ios-shell/FoundationMobile/{FunctionsService,AuthService,Keychain}.swift` as the port source; xcconfig key `FOUNDATION_FUNCTIONS_REGION` from Task B1.
- Produces:
  - `actor FunctionsService` with `static let shared`, and methods
    `requestSignInCode(email: String) async throws -> RequestSignInCodeResult`,
    `verifySignInCode(email: String, code: String) async throws -> VerifySignInCodeResult`,
    `issueAttestationNonce() async throws -> AttestationNonce`,
    `recordMobileAttestation(_:) async throws -> RecordAttestationResult`,
    `anchorCommitment(_:) async throws -> AnchorCommitmentResult`,
    `startL2Verification() async throws -> StartL2VerificationResult`,
    `getL2VerificationStatus() async throws -> L2VerificationStatusResult`.
  - `final class AuthService: ObservableObject` with `@Published var uid: String?`,
    `@Published var isSignedIn: Bool`, `func sendCode(to:) async throws`,
    `func submitCode(_:) async throws`, `func signOut()`.
  - `enum Keychain` with `setAttestedKeyId/getAttestedKeyId/clearAttestedKeyId`
    and `setPendingEmail/getPendingEmail/clearPendingEmail`.

> **Why this is a full task, not a footnote.** Rarimo's app has no Firebase Auth
> at all — its notion of a user is a locally-generated identity secret managed by
> `DecentralizedAuthManager`. Every Foundation callable this plan consumes runs
> `requireAuth`, and `anchorCommitment` additionally runs `requireVerifiedMember`.
> Without a Firebase user there is no uid, and without a uid `EnclaveSeal.seal`
> cannot bind the commitment. The two identity systems coexist: Rarimo's identity
> secret proves the passport; the Firebase uid names the Foundation member.

- [ ] **Step 1: Write the failing test**

Create `ios/FoundationTests/Tests/FoundationTests/AuthServiceTests.swift`:

```swift
import XCTest
@testable import FoundationMobile

final class AuthServiceTests: XCTestCase {
    func testKeychainRoundTripsPendingEmail() {
        Keychain.clearPendingEmail()
        XCTAssertNil(Keychain.getPendingEmail())
        Keychain.setPendingEmail("member@example.com")
        XCTAssertEqual(Keychain.getPendingEmail(), "member@example.com")
        Keychain.clearPendingEmail()
        XCTAssertNil(Keychain.getPendingEmail())
    }

    func testKeychainRoundTripsAttestedKeyId() {
        Keychain.clearAttestedKeyId()
        XCTAssertNil(Keychain.getAttestedKeyId())
        Keychain.setAttestedKeyId("key-abc-123")
        XCTAssertEqual(Keychain.getAttestedKeyId(), "key-abc-123")
        Keychain.clearAttestedKeyId()
    }

    func testKeychainServiceIsThisForksBundleId() {
        // Guards against porting the live app's keychain service identifier,
        // which would share the keychain group with live Foundation Mobile.
        XCTAssertEqual(Keychain.serviceIdentifier, "com.foundationnext.mobile")
    }

    func testSignedOutStateHasNoUid() {
        let auth = AuthService()
        auth.signOut()
        XCTAssertNil(auth.uid)
        XCTAssertFalse(auth.isSignedIn)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/AuthServiceTests 2>&1 | tail -20
```

Expected: compile failure — `cannot find 'Keychain' in scope`,
`cannot find 'AuthService' in scope`.

- [ ] **Step 3: Add the Firebase SPM dependencies**

The app already links `FirebaseCore` and `FirebaseMessaging` (see
`ios/FoundationMobile/Code/FoundationApp.swift`). Add `FirebaseAuth`,
`FirebaseFunctions` and `FirebaseAppCheck` to the `FoundationMobile` target's linked
libraries in `FoundationMobile.xcodeproj` (Xcode → target → Frameworks, or add the
product names to the existing `firebase-ios-sdk` package product dependencies in
`project.pbxproj`).

Verify:

```bash
grep -c 'FirebaseAuth\|FirebaseFunctions\|FirebaseAppCheck' ios/FoundationMobile.xcodeproj/project.pbxproj
```

Expected: at least `3`.

- [ ] **Step 4: Port Keychain**

```bash
mkdir -p ios/FoundationMobile/Code/Foundation
cp legacy-ios-shell/FoundationMobile/Keychain.swift ios/FoundationMobile/Code/Foundation/Keychain.swift
```

Edit the copied file — change the service constant and expose it for the test:

```swift
enum Keychain {
    /// Namespaces every item this app stores. MUST be this fork's bundle id:
    /// using the live app's identifier would share the keychain with live
    /// Foundation Mobile.
    static let serviceIdentifier = "com.foundationnext.mobile"
    private static var service: String { serviceIdentifier }
```

Leave the rest of the file byte-identical.

- [ ] **Step 5: Port the FunctionsService subset**

Create `ios/FoundationMobile/Code/Foundation/FunctionsService.swift` by copying
`legacy-ios-shell/FoundationMobile/FunctionsService.swift` and then:

1. Delete the wrappers for `resendInviteLink`, `claimPairingSession`,
   `heartbeatPairingSession`, `releasePairingSession`, `submitSupportTicket`,
   `mintWebSessionToken`, `recordBiometricConsent`, `checkBiometricConsent`,
   and their request/result structs.
2. Replace the `functions` computed property — the fork has no
   `DeploymentService`, and the region now comes from the xcconfig:

```swift
    private var functions: Functions {
        let region = Bundle.main.object(forInfoDictionaryKey: "FOUNDATION_FUNCTIONS_REGION") as? String ?? "us-east1"
        return Functions.functions(region: region)
    }
```

3. Delete `Self.injectAttestationTier(into:)` calls from `anchorCommitment`
   (that helper depended on shell-only state); keep `refreshIDTokenIfStale()`.
4. Add the two verification wrappers this plan needs:

```swift
struct StartL2VerificationResult: Decodable, Sendable {
    let status: String
    /// The universal link Foundation's backend builds for RariMe. The fork
    /// deliberately IGNORES this and uses getProofParamsUrl directly - see
    /// AD-2 in the fork plan. Decoded only so the shape stays honest.
    let deepLink: String?
    let getProofParamsUrl: String?
}

struct L2VerificationStatusResult: Decodable, Sendable {
    let status: String
    let memberNumber: Int?
}
```

```swift
    func startL2Verification() async throws -> StartL2VerificationResult {
        try await refreshIDTokenIfStale()
        let result = try await functions.httpsCallable("startL2Verification").call([:])
        return try decode(StartL2VerificationResult.self, from: result.data)
    }

    func getL2VerificationStatus() async throws -> L2VerificationStatusResult {
        let result = try await functions.httpsCallable("getL2VerificationStatus").call([:])
        return try decode(L2VerificationStatusResult.self, from: result.data)
    }
```

- [ ] **Step 6: Port AuthService**

```bash
cp legacy-ios-shell/FoundationMobile/AuthService.swift ios/FoundationMobile/Code/Foundation/AuthService.swift
```

Trim it to the OTP path only (the shell also carried an email-link path and
deployment switching). The required surface:

```swift
import FirebaseAuth
import Foundation

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var uid: String?
    @Published private(set) var isSignedIn: Bool = false

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.uid = user?.uid
            self?.isSignedIn = user != nil
        }
    }

    /// Ask the server to email a 6-digit code. Stores the email so the
    /// verify step can be resumed after a cold launch.
    func sendCode(to email: String) async throws {
        _ = try await FunctionsService.shared.requestSignInCode(email: email)
        Keychain.setPendingEmail(email)
    }

    /// Exchange the code for a Firebase custom token and sign in.
    func submitCode(_ code: String) async throws {
        guard let email = Keychain.getPendingEmail() else {
            throw AuthError.noPendingEmail
        }
        let result = try await FunctionsService.shared.verifySignInCode(email: email, code: code)
        try await Auth.auth().signIn(withCustomToken: result.customToken)
        Keychain.clearPendingEmail()
        // signIn produces a fresh ID token as a side effect; tell the
        // callable client so the next mutating call skips a round-trip.
        // (Method name is the ported one - see the shell's FunctionsService.)
        await FunctionsService.shared.markIDTokenJustRefreshed()
    }

    func signOut() {
        try? Auth.auth().signOut()
        uid = nil
        isSignedIn = false
        Keychain.clearPendingEmail()
        Task { await FunctionsService.shared.invalidateIDTokenCache() }
    }

    enum AuthError: Error { case noPendingEmail }
}
```

- [ ] **Step 7: Add the sign-in screen**

Create `ios/FoundationMobile/Code/Modules/FoundationAuth/Views/SignInView.swift`,
styling it with Rarimo's existing view vocabulary (`AppTextField`,
`AppButton`, `.bgPrimary`, `.textPrimary`) rather than porting the shell's
SwiftUI, so it matches the surrounding app:

```swift
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var alertManager: AlertManager

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Sign in to Foundation")
                .h5()
                .foregroundStyle(.textPrimary)

            if codeSent {
                Text("We emailed a 6-digit code to \(email).")
                    .body4()
                    .foregroundStyle(.textSecondary)
                AppTextField(text: $code, placeholder: "000000")
                    .keyboardType(.numberPad)
                AppButton(text: "Verify", action: verify)
                    .disabled(isBusy || code.count != 6)
            } else {
                AppTextField(text: $email, placeholder: "you@example.com")
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                AppButton(text: "Send code", action: sendCode)
                    .disabled(isBusy || !email.contains("@"))
            }
            Spacer()
        }
        .padding(20)
        .background(.bgPrimary)
    }

    private func sendCode() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await authService.sendCode(to: email)
                codeSent = true
            } catch {
                alertManager.emitError(.unknown("Couldn't send the code. Try again."))
            }
        }
    }

    private func verify() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await authService.submitCode(code)
            } catch {
                alertManager.emitError(.unknown("That code didn't work. Try again."))
            }
        }
    }
}
```

- [ ] **Step 8: Gate the app on sign-in**

Edit `ios/FoundationMobile/Code/FoundationApp.swift` — add the environment object:

```swift
                .environmentObject(AuthService.shared)
```

Edit `ios/FoundationMobile/Code/Modules/App/Views/AppView.swift` — add
`@EnvironmentObject private var authService: AuthService` and insert a branch
**before** the `MainView()` branch in the existing `if/else` chain:

```swift
                } else if !authService.isSignedIn {
                    SignInView().transition(.backslide)
                } else if
                    securityManager.passcodeState != .unset,
```

- [ ] **Step 9: Run the test**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/AuthServiceTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`, 4 tests passing.

- [ ] **Step 10: Commit**

```bash
git add -A ios
git commit -m "feat(ios): port Firebase Auth OTP sign-in into the Rarimo fork

Rarimo's app has no Firebase Auth - its user is a local identity secret. Every
Foundation callable requires requireAuth, and anchorCommitment also requires
requireVerifiedMember, so the fork needs a real Firebase uid. Ports
FunctionsService (trimmed to the callables this plan uses), AuthService (OTP
path only) and Keychain (service id repointed at com.foundationnext.mobile) from
the pre-fork shell, and gates AppView on sign-in.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B7: Port App Attest and enforce it before verification

**Model tier:** Sonnet.

**Files:**
- Create: `ios/FoundationMobile/Code/Foundation/AttestationService.swift`
- Create: `ios/FoundationMobile/Code/Foundation/AppCheckFactory.swift`
- Create: `ios/FoundationMobile/Code/Foundation/ProofArtifact.swift`
- Create: `ios/FoundationMobile/Code/Foundation/EnclaveSeal.swift`
- Modify: `ios/FoundationMobile/Code/FoundationApp.swift`
- Modify: `ios/FoundationMobile/FoundationMobile.entitlements` (create if the fork has none)
- Test: `ios/FoundationTests/Tests/FoundationTests/EnclaveSealTests.swift` (new)

**Interfaces:**
- Consumes: `FunctionsService.shared.issueAttestationNonce()` /
  `.recordMobileAttestation(_:)` from Task B6; `Keychain` from Task B6.
- Produces:
  - `actor AttestationService` with `static let shared`, `var isSupported: Bool`,
    `func attestDeviceEndToEnd() async throws -> RecordAttestationResult`,
    `func generateAssertion(keyId: String, payloadBase64: String) async throws -> String`.
  - `struct ProofArtifact` with `enum Kind: String { case appAttest, nfcZk }` and
    `func canonicalBytes() -> Data`.
  - `enum EnclaveSeal` with
    `static func seal(uid: String, artifacts: [ProofArtifact]) -> Commitment`.
  - `enum ProofArtifactBuilder` with
    `static func build(kind:payload:) async throws -> ProofArtifact`.

> **Contract-frozen files.** `ProofArtifact.canonicalBytes()` and
> `EnclaveSeal.seal` are mirrored byte-for-byte by the server's
> `canonicalSealBytes(uid, artifacts)` in `functions/index.js`. A cosmetic
> reformat here produces a different hash and every `anchorCommitment` call
> fails with `"anchorCommitment seal-mismatch"`. Port them verbatim.

- [ ] **Step 1: Write the failing test**

Create `ios/FoundationTests/Tests/FoundationTests/EnclaveSealTests.swift`:

```swift
import XCTest
@testable import FoundationMobile

final class EnclaveSealTests: XCTestCase {
    private func artifact(_ kind: ProofArtifact.Kind, at ms: Int64) -> ProofArtifact {
        ProofArtifact(
            kind: kind,
            producedAtMs: ms,
            payloadHashHex: String(repeating: "a", count: 64),
            signatureBase64: "c2ln"
        )
    }

    func testCanonicalBytesFormatIsFrozen() {
        let a = artifact(.appAttest, at: 1_700_000_000_000)
        let expected = "appAttest:1700000000000:\(String(repeating: "a", count: 64)):c2ln"
        XCTAssertEqual(String(data: a.canonicalBytes(), encoding: .utf8), expected)
    }

    func testSealBindsUidAndIsOrderIndependent() {
        let one = EnclaveSeal.seal(uid: "u1", artifacts: [
            artifact(.appAttest, at: 1), artifact(.nfcZk, at: 2),
        ])
        let two = EnclaveSeal.seal(uid: "u1", artifacts: [
            artifact(.nfcZk, at: 2), artifact(.appAttest, at: 1),
        ])
        XCTAssertEqual(one.commitmentHashHex, two.commitmentHashHex)

        let other = EnclaveSeal.seal(uid: "u2", artifacts: [
            artifact(.appAttest, at: 1), artifact(.nfcZk, at: 2),
        ])
        XCTAssertNotEqual(one.commitmentHashHex, other.commitmentHashHex,
                          "a commitment must not be replayable under another uid")
    }

    func testCommitmentHashIs64LowercaseHex() {
        let c = EnclaveSeal.seal(uid: "u1", artifacts: [artifact(.appAttest, at: 1)])
        XCTAssertEqual(c.commitmentHashHex.count, 64)
        XCTAssertEqual(c.commitmentHashHex, c.commitmentHashHex.lowercased())
    }

    func testOnlyServerAllowedKindsExist() {
        // Server: ALLOWED_ARTIFACT_KINDS = appAttest, liveness, nfcZk,
        // antiSpoof, faceMatch. The fork emits a subset.
        let allowed: Set<String> = ["appAttest", "liveness", "nfcZk", "antiSpoof", "faceMatch"]
        for k in ProofArtifact.Kind.allCases {
            XCTAssertTrue(allowed.contains(k.rawValue), "\(k.rawValue) is not server-allowed")
        }
    }

    /// Cross-platform golden vector. Task C8's Kotlin EnclaveSealTest asserts
    /// this exact constant, which is how the two implementations are pinned to
    /// each other. Independently verifiable:
    ///   python3 -c "import hashlib;a='appAttest:1000:'+'a'*64+':c2ln';
    ///   print(hashlib.sha256(b'uid:golden-uid\n'+a.encode()+b'\n').hexdigest())"
    func testGoldenVector() {
        let c = EnclaveSeal.seal(uid: "golden-uid", artifacts: [artifact(.appAttest, at: 1000)])
        XCTAssertEqual(
            c.commitmentHashHex,
            "498af846df74d0e173e1cee4c09cec1d932c14e65fc9e88d4862943a211922d7"
        )
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/EnclaveSealTests 2>&1 | tail -20
```

Expected: compile failure — `cannot find 'ProofArtifact' in scope`.

- [ ] **Step 3: Port the four files verbatim**

```bash
cp legacy-ios-shell/FoundationMobile/AttestationService.swift ios/FoundationMobile/Code/Foundation/
cp legacy-ios-shell/FoundationMobile/AppCheckFactory.swift    ios/FoundationMobile/Code/Foundation/
cp legacy-ios-shell/FoundationMobile/ProofArtifact.swift      ios/FoundationMobile/Code/Foundation/
cp legacy-ios-shell/FoundationMobile/EnclaveSeal.swift        ios/FoundationMobile/Code/Foundation/
```

- [ ] **Step 4: Trim the artifact kinds to what the fork can honestly produce**

Edit `ios/FoundationMobile/Code/Foundation/ProofArtifact.swift`:

```swift
    enum Kind: String, Codable, Sendable, CaseIterable {
        case appAttest      // DCAppAttestService attestation - the only kind
                            // anchorCommitment requires
                            // (ANCHOR_COMMITMENT_REQUIRED_KINDS = ["appAttest"])
        case nfcZk          // the Rarimo registration proof, once the passport
                            // is registered on L2
    }
```

> The dropped kinds (`liveness`, `antiSpoof`, `faceMatch`) were produced by the
> shell's own capture pipeline, which Task B5 deleted. Rarimo runs its own
> liveness internally and does not surface a signable artifact for it. Claiming
> those kinds without producing them would be exactly the "test double that is
> too optimistic" failure — the server would accept a commitment asserting
> checks the app never ran.

- [ ] **Step 5: Fix the AppCheckFactory doc comment**

Edit the header comment in `ios/FoundationMobile/Code/Foundation/AppCheckFactory.swift`
so its pre-flight instructions name this fork:

```swift
/// **Pre-flight**
///
/// Requires the iOS bundle ID `com.foundationnext.mobile` to be registered
/// with App Attest + DeviceCheck in the `foundation-next-app` Firebase
/// Console, and the simulator's debug token registered in the App Check
/// debug-tokens list.
```

Leave the implementation untouched.

- [ ] **Step 6: Install the provider factory and the entitlement**

Edit `ios/FoundationMobile/Code/FoundationApp.swift`'s `AppDelegate`, before
`FirebaseApp.configure()`:

```swift
        AppCheck.setAppCheckProviderFactory(AppCheckFactory())
        FirebaseApp.configure()
```

(and `import FirebaseAppCheck` at the top).

Then ensure the app target has the App Attest entitlement. Create
`ios/FoundationMobile/FoundationMobile.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.devicecheck.appattest-environment</key>
	<string>production</string>
</dict>
</plist>
```

Set `CODE_SIGN_ENTITLEMENTS = FoundationMobile/FoundationMobile.entitlements;` for the
`FoundationMobile` target in `project.pbxproj`.

> **Do not port the shell's entitlements files.** Both
> `legacy-ios-shell/FoundationMobile/FoundationMobile.entitlements` and
> `…-Release.entitlements` declare `associated-domains` `applinks:` entries for
> live production domains (`foundation-global.com` and its `voice.`/`share.`/
> `market.` subdomains, plus `solanavote-devnet.firebaseapp.com`) — one of the
> four known live-identity remnants recorded in this repo's `CLAUDE.md`. This
> fork does not own those domains' AASA files. Start clean, as above.

- [ ] **Step 7: Run the test**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/EnclaveSealTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`, 5 tests passing — including `testGoldenVector`,
which is what Task C8 Step 5 later checks the Kotlin implementation against.

- [ ] **Step 8: Commit**

```bash
git add -A ios
git commit -m "feat(ios): port App Attest, ProofArtifact and EnclaveSeal into the fork

Rarimo's apps ship no platform attestation (spec section 3). Ports the shell's
built-and-tested DCAppAttestService implementation, its App Check provider
factory, and the two contract-frozen files whose canonical bytes the server
re-derives. Artifact kinds trimmed to appAttest + nfcZk - the kinds the fork
can honestly produce now that the shell's capture pipeline is gone. Fresh
entitlements file: the shell's declared applinks for live domains we do not own.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B8: Wire Foundation verification in-process (AD-2)

**Model tier:** Opus — this is the integration seam the whole fork exists for.

**Files:**
- Create: `ios/FoundationMobile/Code/Foundation/FoundationVerificationManager.swift`
- Create: `ios/FoundationMobile/Code/Modules/Home/Views/FoundationVerifyCardView.swift`
- Modify: `ios/FoundationMobile/Code/Managers/ExternalRequestsManager.swift`
- Modify: `ios/FoundationMobile/Code/Modules/Main/Views/MainViewLayout.swift`
- Modify: `ios/FoundationMobile/Code/FoundationApp.swift`
- Test: `ios/FoundationTests/Tests/FoundationTests/VerificationManagerTests.swift` (new)

**Interfaces:**
- Consumes: `FunctionsService.shared.startL2Verification()` and
  `.getL2VerificationStatus()` (Task B6);
  `ExternalRequestsManager.shared.setRequest(_:)` (upstream, at
  `ios/FoundationMobile/Code/Managers/ExternalRequestsManager.swift:127`);
  `UserManager.shared.registerZkProof` (upstream, the registration precondition).
- Produces:
  - `@MainActor final class FoundationVerificationManager: ObservableObject`
    with `@Published private(set) var state: VerificationState`,
    `func beginVerification() async`, `func pollUntilVerified() async`.
  - `enum VerificationState: Equatable { case idle, notRegistered, starting, awaitingProof, polling, verified(memberNumber: Int?), failed(String) }`

- [ ] **Step 1: Write the failing test**

Create `ios/FoundationTests/Tests/FoundationTests/VerificationManagerTests.swift`:

```swift
import XCTest
@testable import FoundationMobile

final class VerificationManagerTests: XCTestCase {
    func testUrlAllowlistAcceptsFoundationSchemeOnly() {
        let m = ExternalRequestsManager.shared

        XCTAssertTrue(m.isValidExternalUrl(
            URL(string: "foundationmobile://external?type=proof-request")!))
        // Rarimo's own hosts must no longer be honoured: we do not own their
        // AASA files, and a universal link to app.rarime.com opens RariMe.
        XCTAssertFalse(m.isValidExternalUrl(
            URL(string: "rarime://external?type=proof-request")!))
        XCTAssertFalse(m.isValidExternalUrl(
            URL(string: "https://app.rarime.com/external?type=proof-request")!))
    }

    func testProofRequestCanBeSetFromABareParamsUrl() {
        // AD-2: the fork never parses a deep link on the primary path - it
        // feeds getProofParamsUrl straight into the existing proof flow.
        let m = ExternalRequestsManager.shared
        m.resetRequest()
        let url = URL(string: "https://verificator.example.run.app/integrations/verificator-svc/light/v2/public/proof-params/abc")!
        m.setProofRequest(proofParamsUrl: url)

        guard case .proofRequest(let got, _)? = m.request else {
            return XCTFail("expected a proofRequest")
        }
        XCTAssertEqual(got, url)
        m.resetRequest()
    }

    func testStateStartsIdle() {
        XCTAssertEqual(FoundationVerificationManager().state, .idle)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/VerificationManagerTests 2>&1 | tail -20
```

Expected: FAIL — `isValidExternalUrl` is `private` and still accepts
`rarime://`; `setProofRequest` and `FoundationVerificationManager` do not exist.

- [ ] **Step 3: Re-scope the external URL allowlist**

Edit `ios/FoundationMobile/Code/Managers/ExternalRequestsManager.swift`. Replace the
allowlist (currently at the `isValidExternalUrl` method) with:

```swift
    /// Only this fork's own scheme. Rarimo's `rarime://` scheme and their
    /// `app.rarime.com` universal-link hosts are deliberately NOT honoured:
    /// we do not control their AASA files, so an https link to those hosts
    /// opens RariMe (if installed) rather than this app.
    ///
    /// `internal` rather than `private` so VerificationManagerTests can assert
    /// the allowlist directly - it is the boundary between us and the outside.
    func isValidExternalUrl(_ url: URL) -> Bool {
        url.scheme == "foundationmobile" && url.host == "external"
    }
```

And rename the enum introduced in Task B4:

```swift
enum FoundationUrlHosts: String {
    case external
}
```

Then add the in-process entry point next to `setRequest`:

```swift
    /// AD-2: start a proof request from a bare proof-params URL, with no deep
    /// link involved. `startL2Verification` returns this URL alongside a
    /// RariMe deep link; we use the URL and ignore the link.
    func setProofRequest(proofParamsUrl: URL) {
        setRequest(.proofRequest(proofParamsUrl: proofParamsUrl, urlQueryParams: []))
    }
```

- [ ] **Step 4: Write the verification manager**

Create `ios/FoundationMobile/Code/Foundation/FoundationVerificationManager.swift`:

```swift
import Foundation
import SwiftUI

enum VerificationState: Equatable {
    case idle
    /// The passport is not registered on L2 yet - Rarimo's own scan flow must
    /// complete first, because a proof request needs a registration proof.
    case notRegistered
    case starting
    /// The proof sheet is up; Rarimo's ProofRequestView owns the UI from here.
    case awaitingProof
    case polling
    case verified(memberNumber: Int?)
    case failed(String)
}

/// Bridges Foundation's backend to Rarimo's proving flow, entirely in-process.
///
/// The flow:
///   1. `startL2Verification` (Foundation Cloud Function) creates a
///      verification request against this fork's own verificator-svc instance
///      and returns `getProofParamsUrl`.
///   2. That URL is handed straight to `ExternalRequestsManager`, which drives
///      Rarimo's existing `ProofRequestView` - the same code path an external
///      QR scan would take.
///   3. `ProofRequestView` posts the query proof to verificator-svc.
///   4. `getL2VerificationStatus` is polled until the member flips to l2.
///
/// No deep link is constructed or parsed, and no backend change is required.
/// See AD-2 in docs/superpowers/plans/2026-08-31-foundation-mobile-next-rarimo-fork-rebrand.md
@MainActor
final class FoundationVerificationManager: ObservableObject {
    static let shared = FoundationVerificationManager()

    @Published private(set) var state: VerificationState = .idle

    /// How long to keep polling before giving up. verificator-svc terminates
    /// the proof server-side, so the flip is usually seconds, not minutes.
    private let pollInterval: Duration = .seconds(3)
    private let pollLimit = 40

    func beginVerification() async {
        guard UserManager.shared.registerZkProof != nil else {
            state = .notRegistered
            return
        }
        state = .starting
        do {
            let result = try await FunctionsService.shared.startL2Verification()

            if result.status == "already_verified_l2" {
                state = .verified(memberNumber: nil)
                return
            }
            guard let raw = result.getProofParamsUrl, let url = URL(string: raw) else {
                state = .failed("The server didn't return proof parameters.")
                return
            }

            // AD-2: hand the params URL straight to Rarimo's proof flow.
            ExternalRequestsManager.shared.setProofRequest(proofParamsUrl: url)
            state = .awaitingProof
        } catch {
            LoggerUtil.common.error("startL2Verification failed: \(error.localizedDescription, privacy: .public)")
            state = .failed("We couldn't start the passport check. Please try again.")
        }
    }

    /// Call once ProofRequestView reports success.
    func pollUntilVerified() async {
        state = .polling
        for _ in 0 ..< pollLimit {
            do {
                let status = try await FunctionsService.shared.getL2VerificationStatus()
                if status.status == "verified" || status.status == "already_verified_l2" {
                    state = .verified(memberNumber: status.memberNumber)
                    return
                }
            } catch {
                LoggerUtil.common.error("getL2VerificationStatus failed: \(error.localizedDescription, privacy: .public)")
            }
            try? await Task.sleep(for: pollInterval)
        }
        state = .failed("The check is taking longer than expected. Please try again.")
    }
}
```

- [ ] **Step 5: Add the entry-point card**

Create `ios/FoundationMobile/Code/Modules/Home/Views/FoundationVerifyCardView.swift`:

```swift
import SwiftUI

/// The Home entry point into Foundation verification. Placed on Home rather
/// than behind the QR tab because, unlike Rarimo's flow, ours is not initiated
/// by scanning someone else's code - the app asks our own backend for it.
struct FoundationVerifyCardView: View {
    @EnvironmentObject private var verification: FoundationVerificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verify with Foundation")
                .subtitle5()
                .foregroundStyle(.textPrimary)
            Text(caption)
                .body4()
                .foregroundStyle(.textSecondary)
            AppButton(text: buttonTitle) {
                Task { await verification.beginVerification() }
            }
            .disabled(isBusy)
        }
        .padding(16)
        .background(.bgComponentPrimary)
        .cornerRadius(16)
    }

    private var caption: String {
        switch verification.state {
        case .notRegistered: "Scan your passport first, then come back here."
        case .verified: "You're a verified Foundation member."
        case .failed(let message): message
        default: "Prove you're a unique human, without revealing who you are."
        }
    }

    private var buttonTitle: String {
        switch verification.state {
        case .verified: "Verified"
        case .starting, .awaitingProof, .polling: "Working…"
        default: "Verify"
        }
    }

    private var isBusy: Bool {
        switch verification.state {
        case .starting, .awaitingProof, .polling, .verified: true
        default: false
        }
    }
}
```

Render it from `ios/FoundationMobile/Code/Modules/Home/Views/HomeView.swift` above the
widget carousel, and register the manager in
`ios/FoundationMobile/Code/FoundationApp.swift`:

```swift
                .environmentObject(FoundationVerificationManager.shared)
```

- [ ] **Step 6: Chain the proof sheet's success callback into polling**

`ProofRequestView` already takes `onSuccess: () -> Void`. Find where
`ExternalRequestsView` presents it
(`ios/FoundationMobile/Code/Modules/Main/Views/ExternalRequestsView.swift`) and extend
that closure:

```swift
                    onSuccess: {
                        externalRequestsManager.resetRequest()
                        Task { await FoundationVerificationManager.shared.pollUntilVerified() }
                    },
```

- [ ] **Step 7: Run the test**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/VerificationManagerTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`, 3 tests passing.

- [ ] **Step 8: Prove the test can fail (mutation check)**

Temporarily add `|| url.scheme == "rarime"` back into `isValidExternalUrl`, re-run
the test, and confirm `testUrlAllowlistAcceptsFoundationSchemeOnly` **fails**.
Then revert. A green allowlist test that cannot go red is worthless.

- [ ] **Step 9: Commit**

```bash
git add -A ios
git commit -m "feat(ios): wire Foundation L2 verification in-process (AD-2)

startL2Verification returns both a RariMe deep link and the raw
getProofParamsUrl. The fork ignores the deep link and feeds the params URL
straight into Rarimo's existing ExternalRequestsManager proof flow, so there is
no universal-link ownership problem, no app switch and no backend change. The
external-URL allowlist is narrowed to foundationmobile://external only.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B9: Solana commitment write-back, and delete the legacy shell

**Model tier:** Opus.

**Files:**
- Create: `ios/FoundationMobile/Code/Foundation/CommitmentAnchorService.swift`
- Modify: `ios/FoundationMobile/Code/Foundation/FoundationVerificationManager.swift`
- Delete: `legacy-ios-shell/`
- Test: `ios/FoundationTests/Tests/FoundationTests/CommitmentAnchorTests.swift` (new)

**Interfaces:**
- Consumes: `EnclaveSeal.seal(uid:artifacts:)`, `ProofArtifactBuilder.build(kind:payload:)`,
  `AttestationService.shared` (Task B7); `FunctionsService.shared.anchorCommitment(_:)`
  and `AuthService.shared.uid` (Task B6); `VerificationState.verified` (Task B8).
- Produces: `actor CommitmentAnchorService` with `static let shared` and
  `func anchorAfterVerification() async throws -> AnchorCommitmentResult`.

**Ordering constraint (from the server contract):** `anchorCommitment` runs
`requireVerifiedMember`, so it **must** be called after the L2 lane flips the
member to `verificationLevel: "l2"` — i.e. after `pollUntilVerified()` reaches
`.verified`, never before.

- [ ] **Step 1: Write the failing test**

Create `ios/FoundationTests/Tests/FoundationTests/CommitmentAnchorTests.swift`:

```swift
import XCTest
@testable import FoundationMobile

final class CommitmentAnchorTests: XCTestCase {
    func testRequestCarriesTheRequiredKind() throws {
        // Server: ANCHOR_COMMITMENT_REQUIRED_KINDS = ["appAttest"].
        let artifacts = [
            ProofArtifact(kind: .appAttest, producedAtMs: 1,
                          payloadHashHex: String(repeating: "b", count: 64),
                          signatureBase64: "c2ln"),
        ]
        let commitment = EnclaveSeal.seal(uid: "uid-1", artifacts: artifacts)
        let req = CommitmentAnchorService.makeRequest(commitment: commitment, artifacts: artifacts)

        XCTAssertTrue(req.commitment.kinds.contains("appAttest"))
        XCTAssertEqual(req.commitment.hashHex.count, 64)
        XCTAssertEqual(req.artifacts.count, 1)
    }

    func testKindsAreSortedLikeTheSeal() throws {
        // EnclaveSeal.seal sorts artifacts alphabetically by rawValue; the
        // request's `kinds` must be in that same order or the server's
        // re-derivation produces a different hash.
        let artifacts = [
            ProofArtifact(kind: .nfcZk, producedAtMs: 2,
                          payloadHashHex: String(repeating: "c", count: 64),
                          signatureBase64: "c2ln"),
            ProofArtifact(kind: .appAttest, producedAtMs: 1,
                          payloadHashHex: String(repeating: "b", count: 64),
                          signatureBase64: "c2ln"),
        ]
        let commitment = EnclaveSeal.seal(uid: "uid-1", artifacts: artifacts)
        let req = CommitmentAnchorService.makeRequest(commitment: commitment, artifacts: artifacts)
        XCTAssertEqual(req.commitment.kinds, ["appAttest", "nfcZk"])
    }

    func testAnchoringRequiresASignedInUid() async {
        AuthService.shared.signOut()
        do {
            _ = try await CommitmentAnchorService.shared.anchorAfterVerification()
            XCTFail("expected a missingUid error")
        } catch CommitmentAnchorService.Error.missingUid {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/CommitmentAnchorTests 2>&1 | tail -20
```

Expected: compile failure — `cannot find 'CommitmentAnchorService' in scope`.

- [ ] **Step 3: Write the service**

Create `ios/FoundationMobile/Code/Foundation/CommitmentAnchorService.swift`:

```swift
import CryptoKit
import Foundation

/// Writes a Foundation commitment to Solana devnet, via the backend.
///
/// The mobile app never holds a Solana keypair (hard invariant). It produces
/// the commitment locally, posts it to the `anchorCommitment` callable, and the
/// server re-derives the canonical bytes, verifies the hash and performs the
/// on-chain write through the shared Anchor client.
///
/// Rarimo's apps have no concept of Solana; this is new integration work
/// layered onto the fork (spec section 3).
actor CommitmentAnchorService {
    static let shared = CommitmentAnchorService()

    enum Error: Swift.Error {
        case missingUid
        case attestationUnsupported
    }

    /// Pure request assembly, factored out so it is unit-testable without a
    /// network round-trip or a Secure Enclave.
    nonisolated static func makeRequest(
        commitment: EnclaveSeal.Commitment,
        artifacts: [ProofArtifact]
    ) -> AnchorCommitmentRequest {
        AnchorCommitmentRequest(
            commitment: .init(
                hashHex: commitment.commitmentHashHex,
                producedAtMs: commitment.producedAtMs,
                kinds: commitment.artifactKinds.map(\.rawValue)
            ),
            artifacts: artifacts.map {
                .init(
                    kind: $0.kind.rawValue,
                    producedAtMs: $0.producedAtMs,
                    payloadHashHex: $0.payloadHashHex,
                    signatureBase64: $0.signatureBase64
                )
            },
            biometricSeal: nil,
            passportBiometricSeal: nil
        )
    }

    /// Call ONLY after the member has reached verificationLevel "l2" - the
    /// callable runs requireVerifiedMember and will reject otherwise.
    @discardableResult
    func anchorAfterVerification() async throws -> AnchorCommitmentResult {
        guard let uid = await AuthService.shared.uid else {
            throw Error.missingUid
        }
        guard await AttestationService.shared.isSupported else {
            throw Error.attestationUnsupported
        }

        // Ensure we hold an attested key before signing anything.
        if Keychain.getAttestedKeyId() == nil {
            _ = try await AttestationService.shared.attestDeviceEndToEnd()
        }

        var artifacts: [ProofArtifact] = []

        // appAttest - the only kind anchorCommitment requires. The payload is
        // the attested key id, so the artifact is bound to this device's key.
        let keyId = Keychain.getAttestedKeyId() ?? ""
        artifacts.append(try await ProofArtifactBuilder.build(
            kind: .appAttest,
            payload: Data(keyId.utf8)
        ))

        // nfcZk - the Rarimo registration proof, if the passport is registered.
        // Optional: the server allows the kind but does not require it.
        if let zkProof = await UserManager.shared.registerZkProof,
           let proofBytes = try? JSONEncoder().encode(zkProof) {
            artifacts.append(try await ProofArtifactBuilder.build(
                kind: .nfcZk,
                payload: proofBytes
            ))
        }

        let commitment = EnclaveSeal.seal(uid: uid, artifacts: artifacts)
        let request = Self.makeRequest(commitment: commitment, artifacts: artifacts)
        return try await FunctionsService.shared.anchorCommitment(request)
    }
}
```

- [ ] **Step 4: Trim the ported request struct**

`AnchorCommitmentRequest` was ported with `biometricSeal` and
`passportBiometricSeal` fields. The shell's `BiometricSealer` is not ported, so
they are always `nil`. Keep the fields (the server reads them when present, and
a future task may add the sealer) but delete the `BiometricSealPayload` struct's
now-unreachable construction sites. Verify:

```bash
grep -rn 'BiometricSealer' ios/FoundationMobile/Code
```

Expected: no hits.

- [ ] **Step 5: Chain anchoring onto successful verification**

Edit `FoundationVerificationManager.pollUntilVerified()` — inside the branch
that sets `.verified`:

```swift
                if status.status == "verified" || status.status == "already_verified_l2" {
                    state = .verified(memberNumber: status.memberNumber)
                    // Anchor only after the member is verified: the callable
                    // runs requireVerifiedMember.
                    do {
                        let anchored = try await CommitmentAnchorService.shared.anchorAfterVerification()
                        LoggerUtil.common.info("anchorCommitment status: \(anchored.status ?? "nil", privacy: .public)")
                    } catch {
                        // Anchoring is a follow-on write, not a gate on
                        // membership - surface it in logs, do not fail the
                        // user's verification.
                        LoggerUtil.common.error("anchorCommitment failed: \(error.localizedDescription, privacy: .public)")
                    }
                    return
                }
```

- [ ] **Step 6: Run the test**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FoundationTests/CommitmentAnchorTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`, 3 tests passing.

- [ ] **Step 7: Delete the legacy shell**

Every file named in AD-1's "port" column now exists under
`ios/FoundationMobile/Code/Foundation/`. Verify, then delete:

```bash
for f in AttestationService Keychain AppCheckFactory ProofArtifact EnclaveSeal FunctionsService AuthService; do
  test -f "ios/FoundationMobile/Code/Foundation/$f.swift" && echo "ported: $f" || echo "MISSING: $f"
done
```

Expected: seven `ported:` lines, no `MISSING:`.

```bash
git rm -r legacy-ios-shell
```

- [ ] **Step 8: Full test run and commit**

```bash
cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
./scripts/brand-sweep.sh ios
```

Expected: `** TEST SUCCEEDED **` and `brand-sweep: PASS`.

```bash
git add -A
git commit -m "feat(ios): Solana commitment write-back; remove the legacy shell

Adds CommitmentAnchorService, which seals an appAttest artifact (the only kind
anchorCommitment requires) plus the Rarimo registration proof as nfcZk, and
posts it to the callable. Called only after the member reaches l2, because the
callable runs requireVerifiedMember. Anchoring failures are logged, not fatal -
membership does not depend on the on-chain write landing.

legacy-ios-shell/ deleted: every file AD-1 marked for porting now lives under
ios/FoundationMobile/Code/Foundation/.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task B10: iOS release readiness — fastlane, CI gate, App Store metadata

**Model tier:** Sonnet.

**Files:**
- Create: `ios/fastlane/Fastfile`
- Create: `ios/fastlane/Appfile`
- Delete: the inherited `Gemfile`/`Gemfile.lock` fastlane config if it points at the live app (verify first)
- Create: `.github/workflows/brand-sweep.yml`
- Modify: `CLAUDE.md`
- Test: `.github/workflows/brand-sweep.yml` running green in CI.

**Interfaces:**
- Consumes: `scripts/brand-sweep.sh` (Task A1); the Xcode scheme `Foundation` (Task B2).
- Produces: fastlane lane `beta` targeting `com.foundationnext.mobile`; a CI job named `brand-sweep`.

> **This task closes the single most dangerous inherited remnant.** Item 1 of
> this repo's `CLAUDE.md` known-remnants list: the inherited
> `ios/fastlane/Fastfile` `beta` lane calls `update_code_signing_settings` with
> the LIVE bundle ID `com.foundationglobal.mobile` and then uploads to live
> Foundation Mobile's App Store Connect record. That file was carried into
> `legacy-ios-shell/` in Task A2 and deleted in Task B9 — this task writes the
> fork's own replacement rather than repairing theirs.

- [ ] **Step 1: Confirm the dangerous file is gone**

```bash
git log --oneline -- legacy-ios-shell/fastlane/Fastfile | head -3
ls ios/fastlane 2>&1
grep -rn 'com.foundationglobal.mobile' . --exclude-dir=.git 2>/dev/null | head
```

Expected: the legacy Fastfile is in history but not the worktree; `ios/fastlane`
does not exist; **no occurrence of `com.foundationglobal.mobile` anywhere in the
tree.** If that grep returns anything, fix it before continuing.

Also verify the other three remnants from `CLAUDE.md` are gone with the shell:

```bash
grep -rn 'foundation-global.com\|solanavote-devnet\|add-test-target.rb' . --exclude-dir=.git --exclude-dir=docs 2>/dev/null | head
```

Expected: no hits outside `docs/` (which may still cite them historically).

- [ ] **Step 2: Write the CI gate first (the failing test)**

Create `.github/workflows/brand-sweep.yml`:

```yaml
name: brand-sweep

on:
  push:
    branches: [main]
  pull_request:

jobs:
  brand-sweep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: No residual Rarimo branding
        run: ./scripts/brand-sweep.sh ios android
      - name: Licensing files present
        run: |
          test -f LICENSE
          test -f NOTICE
          test -f THIRD_PARTY_LICENSES.md
          grep -q "GNU GENERAL PUBLIC LICENSE" LICENSE
          grep -q "Rarimo Foundation" NOTICE
      - name: No inherited live-app identifiers
        run: |
          ! grep -rn "com.foundationglobal.mobile" \
              --exclude-dir=.git --exclude-dir=docs . || \
            { echo "live bundle id leaked into the fork"; exit 1; }
      - name: No third-party secrets republished
        run: |
          ! grep -rnE 'LIGHT_SIGNATURE_PRIVATE_KEY="[0-9a-f]{16,}"|JOIN_REWARDS_KEY="[0-9a-f]{16,}"' \
              --exclude-dir=.git . || \
            { echo "Rarimo private key present"; exit 1; }
```

- [ ] **Step 3: Run the gate locally**

```bash
./scripts/brand-sweep.sh ios
test -f LICENSE && test -f NOTICE && test -f THIRD_PARTY_LICENSES.md && echo "licensing OK"
! grep -rn "com.foundationglobal.mobile" --exclude-dir=.git --exclude-dir=docs . && echo "no live id"
```

Expected: `brand-sweep: PASS`, `licensing OK`, `no live id`. (The `android`
argument will fail until Phase C completes — that is correct and expected; land
this workflow after Task C9, or scope the CI step to `ios` and widen it in C9.)

- [ ] **Step 4: Write the fork's Appfile**

Create `ios/fastlane/Appfile`:

```ruby
app_identifier("com.foundationnext.mobile")
apple_id(ENV["FASTLANE_APPLE_ID"])
team_id("F9F26FQW95")
```

- [ ] **Step 5: Write the fork's Fastfile**

Create `ios/fastlane/Fastfile`:

```ruby
# Foundation Mobile (foundation-mobile-next) — fork of rarime-ios-app.
#
# This file replaces the one inherited from live foundation-mobile, whose beta
# lane rewrote the bundle id to com.foundationglobal.mobile and uploaded to the
# LIVE App Store Connect record. Never reintroduce a hardcoded bundle id here;
# it comes from Appfile.

default_platform(:ios)

APP_IDENTIFIER = "com.foundationnext.mobile".freeze
TEAM_ID = "F9F26FQW95".freeze

platform :ios do
  desc "Build the identity SDK framework (required before any build)"
  lane :prebuild do
    sh("cd .. && ./prebuild.sh")
  end

  desc "Fail if any Rarimo branding survives"
  lane :brand_sweep do
    sh("cd ../.. && ./scripts/brand-sweep.sh ios")
  end

  desc "Build and upload a TestFlight build"
  lane :beta do
    brand_sweep
    prebuild

    update_code_signing_settings(
      path: "FoundationMobile.xcodeproj",
      use_automatic_signing: false,
      team_id: TEAM_ID,
      bundle_identifier: APP_IDENTIFIER,
      code_sign_identity: "Apple Distribution"
    )

    increment_build_number(xcodeproj: "FoundationMobile.xcodeproj")

    build_app(
      project: "FoundationMobile.xcodeproj",
      scheme: "FoundationMobile",
      export_method: "app-store"
    )

    upload_to_testflight(
      app_identifier: APP_IDENTIFIER,
      skip_waiting_for_build_processing: true
    )
  end
end
```

> `brand_sweep` runs **before** the build, not after, so a leaked Rarimo string
> cannot reach TestFlight. That is the spec's named risk ("a leftover Rarimo
> string/logo before App Store submission is a real risk").

- [ ] **Step 6: Write the App Store review notes**

Create `docs/app-store-review-notes.md`:

```markdown
# App Store / Play Store review notes

## Open-source and licensing disclosure

Foundation Mobile is a fork of Rarimo's `rarime-ios-app` (MIT) that statically
links GPL-3.0 `witnesscalc` and LGPL-3.0 `rapidsnark` proving libraries. The
app is distributed free, and the complete corresponding source is public at
https://github.com/dagangilat/foundation-mobile-next.

Apple's App Store Review Guidelines do not prohibit GPL-licensed apps outright,
but the App Store's standard EULA conflicts with GPL-3.0's terms. Distributing
a GPL-3.0 app on the App Store therefore requires the copyright holder to grant
an additional permission, which we can grant because we are the copyright holder
of the combined work. This is recorded here so the point is not rediscovered at
submission time. **See Open Decision OD-2 — this needs a real legal read before
first submission, not a plan author's judgement.**

## Prior art to check before submitting

Spec § 3 names this as the cheapest next step, and it is still outstanding:
Rarimo's own Freedom Tool apps (Russia2024, Iranians Vote) are real App Store
and Play Store distributions carrying this identical proving stack. They have
solved shipping it at least once. Before the first submission, look at how those
listings are worded and licensed — that is higher-leverage than a cold legal
review.

## Review-sensitive capabilities to declare

| Capability | Why the app needs it |
|---|---|
| NFC (`NFCReaderUsageDescription`) | Reading the passport chip — the core function. |
| Camera | MRZ scan and liveness. |
| App Attest entitlement | Anti-spoofing: proves requests come from a genuine build. |
| Face ID | Local app lock only; no biometric data leaves the device. |

## Privacy positioning

All passport data is processed on-device; only a zero-knowledge proof leaves the
phone. The privacy manifest (`PrivacyInfo.xcprivacy`) must reflect that no
personal data is collected. Re-audit it after Task B5 removed AppsFlyer — the
inherited manifest may still declare tracking domains.
```

- [ ] **Step 7: Supersede the stale remnants list in CLAUDE.md**

Edit `CLAUDE.md` — replace the whole "Known live-identity remnants (deferred to
the Rarimo rebrand plan)" section with:

```markdown
## Live-identity remnants — RESOLVED by the Rarimo fork-and-rebrand plan

The four remnants this file previously listed (fastlane's live bundle ID and
TestFlight target, `add-test-target.rb`'s hardcoded test bundle ID,
`DeploymentConfig.swift`'s live `webUrl`, and the entitlements' `applinks:`
entries for live domains) all lived in the pre-fork SwiftUI shell. That shell
was quarantined as `legacy-ios-shell/` and deleted once its portable files were
carried into the fork.

- `ios/fastlane/Fastfile` is now the fork's own, targeting
  `com.foundationnext.mobile`, and runs `scripts/brand-sweep.sh` before any
  TestFlight upload.
- `add-test-target.rb` and `DeploymentConfig.swift` no longer exist.
- `ios/FoundationMobile/FoundationMobile.entitlements` was written fresh and declares only
  the App Attest environment — no `associated-domains`.

`.github/workflows/brand-sweep.yml` fails CI if `com.foundationglobal.mobile`
reappears anywhere in the tree.
```

- [ ] **Step 8: Commit**

```bash
git add ios/fastlane .github/workflows/brand-sweep.yml docs/app-store-review-notes.md CLAUDE.md
git commit -m "chore(ios): fork-owned fastlane, CI brand gate, review notes

Replaces the inherited Fastfile whose beta lane rewrote the bundle id to the
LIVE com.foundationglobal.mobile and uploaded to live Foundation Mobile's ASC
record - the most dangerous of the four remnants CLAUDE.md tracked. The new
beta lane runs brand-sweep BEFORE building, so a leaked Rarimo string cannot
reach TestFlight.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

# Phase C — Android track

Independent of Phase B from C1 onward; the two tracks share only the backend
contract (Global Constraints) and the licensing posture (Task A1).

## Task C1: Unblock the build — reconstruct `Keys.kt`, register the Firebase Android app

**Model tier:** Opus — the missing file must be reconstructed from its call sites.

**Files:**
- Create: `android/app/src/main/java/com/rarilabs/rarime/config/Keys.kt`
- Create: `android/app/google-services.json` (gitignored — generated, not committed)
- Modify: `android/.gitignore`
- Create: `docs/android-local-setup.md`
- Test: `./gradlew :app:assembleDebug` succeeds.

**Interfaces:**
- Consumes: the `android/` subtree from Task A3.
- Produces: `object Keys` in package `com.rarilabs.rarime.config`, supplying
  `APPSFLYER_DEV_KEY: String`, `APP_ID: String`, `GOOGLE_WEB_KEY: String`,
  `genesisReferralCode: String`, `lightVerificationSKHex: String`,
  `joinProgram: String`. Consumed by
  `android/app/src/main/java/com/rarilabs/rarime/BaseConfig.kt`,
  `.../manager/PointsManager.kt`, `.../data/tokens/PointsToken.kt`.

> **The known blocker from Task A3.** Upstream `.gitignore` excludes
> `/app/src/main/java/com/rarilabs/rarime/config/`, so `Keys.kt` is not in the
> repository, yet `BaseConfig.kt` imports it. **`rarime-android-app` does not
> compile as cloned.** This is not an import error — it is upstream's intended
> state, with the file supplied out of band.

- [ ] **Step 1: Confirm the failure**

```bash
cd android && ./gradlew :app:assembleDebug 2>&1 | grep -E 'error|Unresolved' | head -20
```

Expected: `Unresolved reference: config` / `Unresolved reference: Keys` in
`BaseConfig.kt`, `PointsManager.kt`, `PointsToken.kt`.

- [ ] **Step 2: Enumerate every member the codebase reads off `Keys`**

```bash
cd android && grep -rn 'Keys\.' app/src/main/java --include='*.kt' \
  | sed 's/.*Keys\./Keys./' | sed 's/[^A-Za-z0-9_.].*//' | sort -u
```

Expected (the `Keys.` prefixed ones — the `NavigationKeys`-style hits from
Compose navigation are a different symbol and can be ignored):
`Keys.APPSFLYER_DEV_KEY`, `Keys.APP_ID`, `Keys.GOOGLE_WEB_KEY`,
`Keys.genesisReferralCode`, `Keys.lightVerificationSKHex`, `Keys.joinProgram`.

- [ ] **Step 3: Write the reconstruction**

Create `android/app/src/main/java/com/rarilabs/rarime/config/Keys.kt`:

```kotlin
package com.rarilabs.rarime.config

/**
 * Reconstruction of the file upstream gitignores
 * (`/app/src/main/java/com/rarilabs/rarime/config/`), without which
 * `rarime-android-app` does not compile. Every member here is read somewhere in
 * BaseConfig.kt, PointsManager.kt or PointsToken.kt.
 *
 * Values are Foundation's, not Rarimo's. Three are deliberately empty because
 * the features that consume them are stripped in Task C5:
 *   - APPSFLYER_DEV_KEY  -> AppsFlyer removed; a non-empty value here would
 *                           attribute our installs to Rarimo's account.
 *   - genesisReferralCode-> the referral/Earn programme is removed.
 *   - joinProgram        -> the RMO rewards HMAC key; rewards are removed.
 *
 * NEVER paste Rarimo's values in from their iOS xcconfig. This repository is
 * public and those are their keys.
 */
object Keys {
    /** AppsFlyer attribution. Stripped in Task C5 - empty makes it a no-op. */
    const val APPSFLYER_DEV_KEY: String = ""

    /** Play Store application id, used for update checks and share links. */
    const val APP_ID: String = "com.foundationnext.mobile"

    /**
     * Google OAuth web client id, used by the Drive-backed identity backup in
     * the Recovery module. Read from google-services.json's oauth_client entry
     * of type 3. See docs/android-local-setup.md.
     */
    const val GOOGLE_WEB_KEY: String = BuildConfigKeys.GOOGLE_WEB_KEY

    /** Referral programme - stripped in Task C5. */
    const val genesisReferralCode: String = ""

    /**
     * Light-verification signing key. Foundation's L2 lane uses the full query
     * proof, not the light path, so this stays empty; LightProofHandler is
     * removed in Task C5.
     */
    const val lightVerificationSKHex: String = ""

    /** RMO rewards HMAC key - the rewards programme is stripped in Task C5. */
    const val joinProgram: String = ""
}
```

Add the `BuildConfigKeys` shim so the OAuth id comes from Gradle rather than
source. In `android/app/build.gradle.kts`, inside `defaultConfig`:

```kotlin
        buildConfigField(
            "String",
            "GOOGLE_WEB_KEY",
            "\"${project.findProperty("GOOGLE_WEB_KEY") ?: ""}\""
        )
```

and in `Keys.kt` replace the `BuildConfigKeys.GOOGLE_WEB_KEY` reference with
`com.rarilabs.rarime.BuildConfig.GOOGLE_WEB_KEY`.

- [ ] **Step 4: Register the Firebase Android app**

The bootstrap plan registered an **iOS** app only. Register the Android app
under the same project:

```bash
firebase apps:list --project foundation-next-app
firebase apps:create ANDROID "Foundation Mobile Android" \
  --package-name com.foundationnext.mobile --project foundation-next-app
firebase apps:sdkconfig ANDROID --project foundation-next-app \
  --out android/app/google-services.json
```

Verify:

```bash
python3 -c "import json;d=json.load(open('android/app/google-services.json'));print(d['project_info']['project_id'], [c['client_info']['android_client_info']['package_name'] for c in d['client']])"
```

Expected: `foundation-next-app ['com.foundationnext.mobile']`

> The package name Firebase keys on is the **applicationId**, not the Kotlin
> namespace — so this must be registered as `com.foundationnext.mobile` even
> though the source package stays `com.rarilabs.rarime` (Open Decision OD-3).
> Task C2 sets that applicationId; if C2 has not run yet, run it first.

- [ ] **Step 5: Confirm `google-services.json` stays untracked**

```bash
cd android && git check-ignore -v app/google-services.json
```

Expected: a match on the `.gitignore` line `/app/google-services.json`. If not,
stop — it must never be committed.

- [ ] **Step 6: Document local setup**

Create `docs/android-local-setup.md`:

```markdown
# Android local setup

`android/` is a fork of `rarime-android-app`, which **does not compile as
cloned**: upstream gitignores
`app/src/main/java/com/rarilabs/rarime/config/`, so `Keys.kt` — which
`BaseConfig.kt` imports — is absent from their repository. This fork commits its
own reconstruction of that file (Foundation's values, several deliberately
empty). You do not need to obtain anything from Rarimo.

## What you do need locally

1. **`app/google-services.json`** — gitignored. Generate it:

       firebase apps:sdkconfig ANDROID --project foundation-next-app \
         --out android/app/google-services.json

2. **`GOOGLE_WEB_KEY`** — the OAuth web client id used by the Drive-backed
   identity backup. Take the `client_id` whose `client_type` is `3` from the
   generated `google-services.json`, and put it in `~/.gradle/gradle.properties`:

       GOOGLE_WEB_KEY=<...>.apps.googleusercontent.com

3. **Android NDK** — the app builds `librarime.so` from
   `app/src/main/cpp/CMakeLists.txt`, linking the GPL-3.0 witnesscalc and
   LGPL-3.0 rapidsnark shared objects. ABI filter is `arm64-v8a` only, so an
   x86_64 emulator will not run it — use a physical arm64 device or an
   arm64 emulator image.

## Build

    cd android && ./gradlew :app:assembleDebug
```

- [ ] **Step 7: Build**

```bash
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit**

```bash
git add android/app/src/main/java/com/rarilabs/rarime/config/Keys.kt \
        android/app/build.gradle.kts docs/android-local-setup.md
git commit -m "fix(android): reconstruct the gitignored Keys.kt; register Firebase app

rarime-android-app does not compile as cloned: upstream gitignores
app/src/main/java/com/rarilabs/rarime/config/, but BaseConfig.kt imports
config.Keys from it. Reconstructed from every Keys.* call site, with
Foundation's values - AppsFlyer, referral and rewards keys deliberately empty
because Task C5 strips those features. GOOGLE_WEB_KEY comes from a Gradle
property, not source.

Also registers the Android app under foundation-next-app (the bootstrap plan
registered iOS only).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C2: Android app identity — applicationId, app name, theme, deep-link host

**Model tier:** Sonnet.

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/res/values/strings.xml` (the `app_name` key only)
- Modify: `android/app/src/main/res/values/themes.xml`
- Modify: `android/app/src/main/java/com/rarilabs/rarime/ui/theme/Theme.kt`
- Test: `android/app/src/test/java/com/rarilabs/rarime/foundation/AppIdentityTest.kt` (new)

**Interfaces:**
- Consumes: `Keys.APP_ID` from Task C1.
- Produces: `applicationId = "com.foundationnext.mobile"`; theme resource
  `@style/Theme.Foundation`; deep-link host `app.foundation-next.example` under
  scheme `foundationmobile`.

**Decision (OD-3, resolved here):** change the **applicationId only**. The Kotlin
package namespace stays `com.rarilabs.rarime`. Renaming 394 files / 54,463 LOC of
package declarations and imports produces zero user-visible change, guarantees
merge conflicts on every upstream pull, and risks silent breakage in Hilt's
generated components and Compose navigation route strings. Users never see a
package namespace; they see `applicationId` (Play Store listing, `adb` package
name) and `app_name` (launcher label). Both change.

- [ ] **Step 1: Write the failing test**

Create `android/app/src/test/java/com/rarilabs/rarime/foundation/AppIdentityTest.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import com.rarilabs.rarime.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AppIdentityTest {
    @Test
    fun applicationIdIsFoundations() {
        assertEquals("com.foundationnext.mobile", BuildConfig.APPLICATION_ID)
    }

    @Test
    fun applicationIdIsNotRarimos() {
        assertFalse(BuildConfig.APPLICATION_ID.contains("rarilabs"))
        assertFalse(BuildConfig.APPLICATION_ID.contains("rarime"))
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*AppIdentityTest*' 2>&1 | tail -20
```

Expected: FAIL — `expected:<com.foundationnext.mobile> but was:<com.rarilabs.rarime>`.

- [ ] **Step 3: Change the applicationId**

Edit `android/app/build.gradle.kts`, in `defaultConfig`:

```kotlin
        applicationId = "com.foundationnext.mobile"
```

Leave `namespace = "com.rarilabs.rarime"` unchanged (OD-3), and add a comment
above it:

```kotlin
    // Kotlin package namespace deliberately unchanged - see Open Decision OD-3
    // in docs/superpowers/plans/2026-08-31-foundation-mobile-next-rarimo-fork-rebrand.md.
    // Users see applicationId and app_name; the namespace is invisible, and
    // renaming it would conflict on every upstream merge.
    namespace = "com.rarilabs.rarime"
```

Also reset the version for a fresh Play listing:

```kotlin
        versionCode = 1
        versionName = "1.0.0"
```

- [ ] **Step 4: Change the launcher label and theme name**

Edit `android/app/src/main/res/values/strings.xml` line 2:

```xml
    <string name="app_name">Foundation</string>
```

Rename the theme in `android/app/src/main/res/values/themes.xml` and
`values-night/themes.xml`: `Theme.Rarime` → `Theme.Foundation`. Then update both
references in `android/app/src/main/AndroidManifest.xml`:

```xml
        android:theme="@style/Theme.Foundation"
```

(on both `<application>` and the `MainActivity` `<activity>`), and rename the
Compose theme function in
`android/app/src/main/java/com/rarilabs/rarime/ui/theme/Theme.kt`:

```kotlin
@Composable
fun FoundationTheme(
```

```bash
cd android && grep -rln 'RarimeTheme(' app/src/main/java | xargs sed -i '' 's/RarimeTheme(/FoundationTheme(/g'
```

- [ ] **Step 5: Re-scope the deep-link intent filter**

Edit `android/app/src/main/AndroidManifest.xml` — replace the
`app.rarime.com` `<intent-filter>` block on `MainActivity` with this fork's own
scheme (mirroring AD-2 / Task B8 on iOS):

```xml
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="foundationmobile" />
                <data android:host="external" />
            </intent-filter>
```

Remove the `android:autoVerify="true"` https filters for `app.rarime.com`
entirely: we do not own that domain's Digital Asset Links file, so those filters
can only ever fail verification.

- [ ] **Step 6: Rename the theme files for consistency**

```bash
cd android/app/src/main/java/com/rarilabs/rarime/ui/theme
git mv RarimeColors.kt FoundationColors.kt
git mv RarimeTheme.kt FoundationTheme.kt
git mv RarimeTypography.kt FoundationTypography.kt
cd ../../../../../../../..
grep -rln 'RarimeColors\|RarimeTypography' android/app/src/main/java \
  | xargs sed -i '' -e 's/RarimeColors/FoundationColors/g' -e 's/RarimeTypography/FoundationTypography/g'
```

- [ ] **Step 7: Build and run the test**

```bash
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -10
cd android && ./gradlew :app:testDebugUnitTest --tests '*AppIdentityTest*' 2>&1 | tail -10
```

Expected: `BUILD SUCCESSFUL` and the test passing.

- [ ] **Step 8: Commit**

```bash
git add -A android
git commit -m "chore(android): applicationId, launcher label, theme and deep-link host

applicationId com.foundationnext.mobile, label Foundation, Theme.Foundation,
scheme foundationmobile://external. Kotlin namespace stays com.rarilabs.rarime
(OD-3): renaming 394 files changes nothing a user sees and conflicts on every
upstream merge. Drops the autoVerify https filters for app.rarime.com - we do
not own that domain's assetlinks.json, so they could only ever fail.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C3: Android visual rebrand — launcher icon and color scheme

**Model tier:** Sonnet.

**Files:**
- Modify: `android/app/src/main/res/mipmap-*/ic_launcher*.png|webp`
- Modify: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml`
- Modify: `android/app/src/main/java/com/rarilabs/rarime/ui/theme/FoundationColors.kt`
- Modify: `android/app/src/main/res/values/colors.xml`, `values-night/colors.xml`
- Modify: `android/app/src/main/res/drawable/`, `drawable-night/` (brand marks)
- Test: `android/app/src/test/java/com/rarilabs/rarime/foundation/BrandColorsTest.kt` (new)

**Interfaces:**
- Consumes: the same Foundation palette Task B3 used (from the pre-fork shell's
  `Theme.swift` `ThemePalette`). **The two platforms must land on identical hex
  values** — that is the point of doing them from one source.
- Produces: `FoundationColors` with the Foundation primary/secondary ramps.

- [ ] **Step 1: Write the failing test**

Create `android/app/src/test/java/com/rarilabs/rarime/foundation/BrandColorsTest.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import com.rarilabs.rarime.ui.theme.FoundationColors
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Locks the Android palette to the same hex values the iOS fork uses, so the
 * two platforms cannot drift. Source of truth: the pre-fork shell's
 * Theme.swift ThemePalette, mapped in Task B3.
 */
class BrandColorsTest {
    // brandGreen #047857 from the `foundation` ThemePalette - the identical
    // value Task B3 pins on iOS. If these two ever disagree, one platform has
    // drifted.
    private val expectedPrimaryMain = 0xFF047857.toInt()

    @Test
    fun primaryMainMatchesIos() {
        assertEquals(expectedPrimaryMain, FoundationColors.primaryMain.value.toInt())
    }

    @Test
    fun noPurpleBrandRampSurvives() {
        // Rarimo's purple is their secondary brand colour and must not ship.
        val fields = FoundationColors::class.java.declaredFields.map { it.name.lowercase() }
        assert(fields.none { it.contains("purple") }) {
            "Rarimo purple ramp survived: ${fields.filter { it.contains("purple") }}"
        }
    }
}
```

- [ ] **Step 2: Cross-check the pinned value against iOS**

`0xFF047857` is `brandGreen` from the `foundation` `ThemePalette`. If Phase B
has already run, confirm iOS landed on the same value:

```bash
python3 -c "
import json
d = json.load(open('ios/FoundationMobile/Resources/Assets.xcassets/Colors/PrimaryMain.colorset/Contents.json'))
for c in d['colors']:
    print(c.get('appearances', 'any'), c['color']['components'])
"
```

Expected components: red `0x04`, green `0x78`, blue `0x57` (or the decimal
equivalents `0.016`, `0.471`, `0.341`). A mismatch means one platform drifted —
fix it here rather than relaxing the assertion.

- [ ] **Step 3: Run the test and watch it fail**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*BrandColorsTest*' 2>&1 | tail -20
```

Expected: FAIL on both — the palette is Rarimo's, and the purple ramp exists.

- [ ] **Step 4: Remap the palette**

Edit `android/app/src/main/java/com/rarilabs/rarime/ui/theme/FoundationColors.kt`,
applying the same Rarimo→Foundation mapping table Task B3 defined (primary ramp
→ `brandGreen`, secondary → `brandCyan`, backgrounds → `bg`/`surface`, text →
`text`/`muted`, **purple ramp → `brandFill`, with the `purple` names renamed**).
Mirror the changes into `values/colors.xml` and `values-night/colors.xml`.

- [ ] **Step 5: Replace the launcher icon**

```bash
cd android/app/src/main/res
ls mipmap-*/ic_launcher* mipmap-anydpi-v26/*
```

Replace each density bucket's `ic_launcher` / `ic_launcher_round` raster with a
Foundation render, and update the adaptive-icon foreground/background drawables
referenced from `mipmap-anydpi-v26/ic_launcher.xml`. Use the same source artwork
Task B3 used for iOS.

- [ ] **Step 6: Replace in-app brand marks**

```bash
cd android && grep -rl 'rarime\|rarimo' app/src/main/res/drawable app/src/main/res/drawable-night 2>/dev/null
ls app/src/main/res/drawable | grep -i 'rarime\|logo\|brand'
```

Rename and replace any brand-mark vector/raster found, and update the `R.drawable.*`
references that name them.

- [ ] **Step 7: Run the test and build**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*BrandColorsTest*' 2>&1 | tail -10
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -5
```

Expected: test passes, `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit**

```bash
git add -A android
git commit -m "feat(android): Foundation palette and launcher icon

Maps Rarimo's ramps onto the same Foundation palette the iOS fork uses, with a
test that locks the two platforms to identical hex values so they cannot drift.
Rarimo's purple secondary ramp is renamed and remapped, not kept.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C4: Android copy rebrand

**Model tier:** Sonnet.

**Files:**
- Modify: `android/app/src/main/res/values/strings.xml` (16 brand-bearing entries)
- Modify: `android/app/src/main/java/com/rarilabs/rarime/util/Constants.kt`
- Modify: `android/app/src/main/java/com/rarilabs/rarime/BaseConfig.kt`
- Test: `scripts/brand-sweep.sh android`

**Interfaces:**
- Consumes: `scripts/brand-sweep.sh` (Task A1).
- Produces: no code interface.

- [ ] **Step 1: Enumerate the red state**

```bash
cd android && grep -n 'RariMe\|Rarimo\|rarime\|rarimo\|RMO' app/src/main/res/values/strings.xml
```

Expected (verified against upstream HEAD): 16 lines, including
`app_name` (done in C2), `intro_step_1_title`, `intro_step_2_text`,
`what_is_rarimo_title`, `what_is_rarimo_text_item_1/2/3`,
`rarimo_general_terms_conditions`, `rarimo_privacy_notice`,
`rarimo_airdrop_program_terms_conditions`, `airdrop_intro_text`,
`claim_tokens_title`, `reserve_tokens_title`, `you_re_entitled_of_x_rmo`,
`rmo`, `welcome_card3_description`, `earn_collapsed_widget_caption`,
`earn_expanded_widget_caption`, `hidden_prize_on_social_share_description`.

- [ ] **Step 2: Apply the mapping**

| Upstream key | Action |
|---|---|
| `intro_step_1_title`, `intro_step_2_text` | Rewrite with `Foundation` |
| `what_is_rarimo_title` → rename to `what_is_foundation_title` | `What is Foundation?` |
| `what_is_rarimo_text_item_1/2/3` → `what_is_foundation_text_item_*` | Rewrite with `Foundation` |
| `rarimo_general_terms_conditions`, `rarimo_privacy_notice` → `foundation_*` | Point at Foundation's legal pages |
| `welcome_card3_description` | `Foundation lets you prove your identity — without giving anything away` |
| `rarimo_airdrop_program_terms_conditions`, `airdrop_intro_text`, `claim_tokens_title`, `reserve_tokens_title`, `you_re_entitled_of_x_rmo`, `rmo`, `earn_*_widget_caption`, `hidden_prize_*` | **Delete** — Task C5 removes the modules that use them |

Rename the resource ids at every `R.string.*` call site:

```bash
cd android
grep -rln 'R.string.what_is_rarimo\|R.string.rarimo_' app/src/main/java \
  | xargs sed -i '' \
      -e 's/R\.string\.what_is_rarimo/R.string.what_is_foundation/g' \
      -e 's/R\.string\.rarimo_general_terms_conditions/R.string.foundation_general_terms_conditions/g' \
      -e 's/R\.string\.rarimo_privacy_notice/R.string.foundation_privacy_notice/g'
```

- [ ] **Step 3: Handle the infrastructure references in Kotlin**

```bash
cd android && grep -rn 'rarime.com\|rarimo.com\|freedomtool' app/src/main/java --include='*.kt' | head -20
```

`BaseConfig.kt` and `util/Constants.kt` carry RPC/relayer/explorer URLs. Same
call as iOS Task B4: **retain the registration relayer, RPC and contract
addresses** (Open Decision OD-5), blank the Freedom Tool, points-service and
AppsFlyer entries, and repoint `FEEDBACK_EMAIL`, `INVITATION_BASE_URL`,
`GLOBAL_NOTIFICATION_TOPIC` and `REWARD_NOTIFICATION_TOPIC` at Foundation's
values (matching Task B1's xcconfig exactly — the two platforms subscribe to the
same FCM topics).

Add the same inline rationale comment used on iOS above each retained URL, and
extend `scripts/brand-sweep.sh`'s exemptions with
`--exclude=BaseConfig.kt --exclude=Constants.kt`.

- [ ] **Step 4: Run the sweep**

```bash
./scripts/brand-sweep.sh android
```

Expected: still FAIL, but only under `modules/earn`, `modules/hiddenPrize`,
`modules/digitalLikeness`, `modules/votes`, `modules/wallet` — Task C5's
territory. Verify nothing else remains:

```bash
./scripts/brand-sweep.sh android | grep -v 'modules/earn\|modules/hiddenPrize\|modules/digitalLikeness\|modules/votes\|modules/wallet'
```

Expected: only the header and count lines.

- [ ] **Step 5: Build and commit**

```bash
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -5
git add -A android scripts/brand-sweep.sh
git commit -m "feat(android): rebrand user-visible copy to Foundation

Rewrites the brand-bearing strings.xml entries and their R.string call sites;
deletes the RMO/airdrop/earn/hidden-prize copy belonging to modules Task C5
removes. Rarimo relayer and RPC URLs retained deliberately with inline
rationale (OD-5).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C5: Strip Rarimo-ecosystem modules (Android)

**Model tier:** Opus.

**Files:**
- Delete: `android/app/src/main/java/com/rarilabs/rarime/modules/{earn,hiddenPrize,digitalLikeness,votes,wallet}/`
- Delete: `android/app/src/main/java/com/rarilabs/rarime/manager/PointsManager.kt`
- Delete: `android/app/src/main/java/com/rarilabs/rarime/data/tokens/PointsToken.kt`
- Delete: `android/app/src/main/java/com/rarilabs/rarime/api/voting/`
- Delete: `android/app/src/main/java/com/rarilabs/rarime/api/ext_integrator/.../light_proof_handler/`
- Modify: `android/app/src/main/java/com/rarilabs/rarime/modules/main/` (bottom nav)
- Modify: `android/app/src/main/java/com/rarilabs/rarime/modules/home/` (widgets)
- Modify: `android/app/src/main/java/com/rarilabs/rarime/di/` (Hilt bindings for deleted managers)
- Test: `scripts/brand-sweep.sh android` must PASS; `./gradlew :app:assembleDebug`.

**Interfaces:**
- Consumes: nothing.
- Produces: a bottom-nav destination set mirroring iOS's `MainTabs`
  (home, identity/passport, scan, profile).

**Keep / strip — mirrors Task B5's decisions module-for-module:**

| Module | Decision | Reasoning |
|---|---|---|
| `passportScan`, `passportVerify`, `register` | **KEEP** | The NFC + registration + proving pipeline. |
| `home`, `main`, `intro`, `profile`, `you`, `security`, `recoveryMethod`, `notifications`, `qr`, `appUpdate`, `maintenance`, `manageWidgets` | **KEEP** | Shell, navigation, identity recovery, settings. |
| `earn` | **STRIP** | RMO rewards + referrals against Rarimo's points service. |
| `hiddenPrize` | **STRIP** | Rarimo's celebrity prize game. |
| `digitalLikeness` | **STRIP** | Rarimo's separate AI-likeness product. |
| `votes` | **STRIP** | Freedom Tool voting on Rarimo's L2; Foundation governs on Solana. |
| `wallet` | **STRIP** | EVM token wallet — contradicts the no-keypair invariant. |

- [ ] **Step 1: Confirm the red state**

```bash
./scripts/brand-sweep.sh android | tail -3
cd android && ls app/src/main/java/com/rarilabs/rarime/modules
```

Expected: sweep FAILs; the five modules to strip are present.

- [ ] **Step 2: Delete the modules and their support code**

```bash
cd android/app/src/main/java/com/rarilabs/rarime
git rm -r modules/earn modules/hiddenPrize modules/digitalLikeness modules/votes modules/wallet
git rm -r api/voting
git rm manager/PointsManager.kt data/tokens/PointsToken.kt
git rm -r api/ext_integrator/ext_int_action_preview/handlers/light_proof_handler
```

- [ ] **Step 3: Remove the Hilt bindings for the deleted managers**

```bash
cd android && grep -rn 'PointsManager\|WalletManager\|LikenessManager\|VotingApiManager' app/src/main/java/com/rarilabs/rarime/di
```

Delete each `@Provides` / `@Binds` function that returns a deleted type. Missing
this is the most common cause of a Hilt build failure in this task — the error
will name the module and the missing symbol.

- [ ] **Step 4: Trim the bottom navigation and home widgets**

```bash
cd android && grep -rn 'Wallet\|Earn\|Likeness\|Freedomtool\|HiddenPrize' \
  app/src/main/java/com/rarilabs/rarime/modules/main \
  app/src/main/java/com/rarilabs/rarime/modules/home | head -30
```

Remove each navigation destination, route constant, and widget entry that names
a deleted module. Also delete the orphaned widget composables under
`modules/home/v3/ui/expanded/` and `.../collapsed/`
(`FreedomtoolExpandedWidget.kt`, `FreedomtoolCollapsedWidget.kt`, and the
Earn/Likeness/HiddenPrize equivalents).

- [ ] **Step 5: Delete the orphaned drawables and strings**

```bash
cd android/app/src/main/res
grep -rn 'freedomtool\|earn_bg\|likeness\|hidden_prize' drawable/ drawable-night/ values/strings.xml 2>/dev/null | head -20
```

Delete every drawable and string only reachable from a removed module.

- [ ] **Step 6: Build, fixing the cascade**

```bash
cd android && ./gradlew :app:assembleDebug 2>&1 | grep -E 'e: |error:' | head -30
```

Resolve every unresolved reference by deleting the referencing code, not by
restoring a module. Repeat until:

```bash
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 7: The sweep should now pass for Android**

```bash
./scripts/brand-sweep.sh android
./scripts/brand-sweep.sh
```

Expected: `brand-sweep: PASS` for both (the second covers `ios` and `android`
together, and requires Phase B to have completed).

- [ ] **Step 8: Commit**

```bash
git add -A android
git commit -m "feat(android): strip Rarimo-ecosystem modules

Removes earn (RMO rewards), hiddenPrize, digitalLikeness, votes (Freedom Tool)
and wallet, with their Hilt bindings, nav destinations, home widgets, drawables
and strings. Mirrors the iOS strip decisions module-for-module so the two
platforms ship the same product.

brand-sweep now passes for android/.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C6: Firebase Auth (OTP sign-in) on Android

**Model tier:** Opus.

**Files:**
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationFunctionsService.kt`
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationAuthManager.kt`
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/ui/SignInScreen.kt`
- Modify: `android/app/build.gradle.kts` (Firebase BOM, auth, functions)
- Modify: `android/app/src/main/java/com/rarilabs/rarime/di/AppModule.kt`
- Modify: `android/app/src/main/java/com/rarilabs/rarime/modules/main/MainScreen.kt`
- Test: `android/app/src/test/java/com/rarilabs/rarime/foundation/FoundationAuthManagerTest.kt` (new)

**Interfaces:**
- Consumes: `google-services.json` from Task C1.
- Produces:
  - `class FoundationFunctionsService @Inject constructor(private val functions: FirebaseFunctions)` with
    `suspend fun requestSignInCode(email: String): SignInCodeResult`,
    `suspend fun verifySignInCode(email: String, code: String): VerifyCodeResult`,
    `suspend fun issueAttestationNonce(): AttestationNonce`,
    `suspend fun recordMobileAttestation(nonce: String, token: String): RecordAttestationResult`,
    `suspend fun startL2Verification(): StartL2VerificationResult`,
    `suspend fun getL2VerificationStatus(): L2VerificationStatusResult`.
    (`anchorCommitment` is **added to this same class in Task C8**, together with
    its request/result types — it needs `ProofArtifact`, which C8 defines.)
  - `class FoundationAuthManager @Inject constructor(...)` with
    `val uid: StateFlow<String?>`, `val isSignedIn: StateFlow<Boolean>`,
    `suspend fun sendCode(email: String)`, `suspend fun submitCode(code: String)`,
    `fun signOut()`.

- [ ] **Step 1: Write the failing test**

Create `android/app/src/test/java/com/rarilabs/rarime/foundation/FoundationAuthManagerTest.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FoundationAuthManagerTest {
    @Test
    fun callableNamesMatchTheBackend() {
        // Guards against a typo silently producing NOT_FOUND at runtime.
        assertEquals("requestSignInCode", FoundationCallables.REQUEST_SIGN_IN_CODE)
        assertEquals("verifySignInCode", FoundationCallables.VERIFY_SIGN_IN_CODE)
        assertEquals("issueAttestationNonce", FoundationCallables.ISSUE_ATTESTATION_NONCE)
        assertEquals("recordMobileAttestation", FoundationCallables.RECORD_MOBILE_ATTESTATION)
        assertEquals("startL2Verification", FoundationCallables.START_L2_VERIFICATION)
        assertEquals("getL2VerificationStatus", FoundationCallables.GET_L2_VERIFICATION_STATUS)
        assertEquals("anchorCommitment", FoundationCallables.ANCHOR_COMMITMENT)
    }

    @Test
    fun functionsRegionMatchesDeployment() {
        // Every Foundation callable is deployed to us-east1. A default-region
        // client silently hits us-central1 and 404s.
        assertEquals("us-east1", FoundationCallables.REGION)
    }

    @Test
    fun signedOutStateHasNoUid() = runTest {
        val manager = FoundationAuthManager.forTesting()
        manager.signOut()
        assertNull(manager.uid.value)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*FoundationAuthManagerTest*' 2>&1 | tail -20
```

Expected: compile failure — `Unresolved reference: FoundationCallables`.

- [ ] **Step 3: Add the Firebase dependencies**

Edit `android/app/build.gradle.kts`'s `dependencies` block:

```kotlin
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-functions-ktx")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    implementation("com.google.android.play:integrity:1.4.0")
```

(The `com.google.gms.google-services` plugin is already applied at the top of
the file, and `firebase-messaging` is already present.)

- [ ] **Step 4: Write the callables client**

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationFunctionsService.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Names and region of Foundation's Cloud Functions. Kept as constants so a
 * unit test can assert them without a network call - a typo here surfaces as
 * a runtime NOT_FOUND, which is expensive to diagnose on device.
 */
object FoundationCallables {
    const val REGION = "us-east1"
    const val REQUEST_SIGN_IN_CODE = "requestSignInCode"
    const val VERIFY_SIGN_IN_CODE = "verifySignInCode"
    const val ISSUE_ATTESTATION_NONCE = "issueAttestationNonce"
    const val RECORD_MOBILE_ATTESTATION = "recordMobileAttestation"
    const val START_L2_VERIFICATION = "startL2Verification"
    const val GET_L2_VERIFICATION_STATUS = "getL2VerificationStatus"
    const val ANCHOR_COMMITMENT = "anchorCommitment"
}

data class SignInCodeResult(val status: String, val sent: Boolean)
data class VerifyCodeResult(val customToken: String, val uid: String)
data class AttestationNonce(val nonce: String, val expiresAtMs: Long)
data class RecordAttestationResult(val accepted: Boolean, val credentialId: String?)
data class StartL2VerificationResult(
    val status: String,
    /** Ignored on purpose - see AD-2. Decoded so the shape stays honest. */
    val deepLink: String?,
    val getProofParamsUrl: String?,
)
data class L2VerificationStatusResult(val status: String, val memberNumber: Int?)

@Singleton
class FoundationFunctionsService @Inject constructor() {

    private val functions: FirebaseFunctions
        get() = FirebaseFunctions.getInstance(FoundationCallables.REGION)

    private suspend fun call(name: String, data: Map<String, Any?>): Map<*, *> {
        val result = functions.getHttpsCallable(name).call(data).await()
        return result.data as? Map<*, *> ?: emptyMap<String, Any?>()
    }

    suspend fun requestSignInCode(email: String): SignInCodeResult {
        val d = call(FoundationCallables.REQUEST_SIGN_IN_CODE, mapOf("email" to email))
        return SignInCodeResult(
            status = d["status"] as? String ?: "",
            sent = d["sent"] as? Boolean ?: false,
        )
    }

    suspend fun verifySignInCode(email: String, code: String): VerifyCodeResult {
        val d = call(
            FoundationCallables.VERIFY_SIGN_IN_CODE,
            mapOf("email" to email, "code" to code),
        )
        return VerifyCodeResult(
            customToken = d["customToken"] as? String
                ?: error("verifySignInCode returned no customToken"),
            uid = d["uid"] as? String ?: "",
        )
    }

    suspend fun issueAttestationNonce(): AttestationNonce {
        val d = call(FoundationCallables.ISSUE_ATTESTATION_NONCE, emptyMap())
        return AttestationNonce(
            nonce = d["nonce"] as? String ?: error("no nonce"),
            expiresAtMs = (d["expiresAtMs"] as? Number)?.toLong() ?: 0L,
        )
    }

    /**
     * Android attestation wire shape, per @plantagoai/attestation's
     * RecordAttestationRequest: { platform: 'android', token }.
     */
    suspend fun recordMobileAttestation(nonce: String, token: String): RecordAttestationResult {
        val d = call(
            FoundationCallables.RECORD_MOBILE_ATTESTATION,
            mapOf(
                "nonce" to nonce,
                "attestation" to mapOf("platform" to "android", "token" to token),
            ),
        )
        return RecordAttestationResult(
            accepted = d["accepted"] as? Boolean ?: false,
            credentialId = d["credentialId"] as? String,
        )
    }

    suspend fun startL2Verification(): StartL2VerificationResult {
        val d = call(FoundationCallables.START_L2_VERIFICATION, emptyMap())
        return StartL2VerificationResult(
            status = d["status"] as? String ?: "",
            deepLink = d["deepLink"] as? String,
            getProofParamsUrl = d["getProofParamsUrl"] as? String,
        )
    }

    suspend fun getL2VerificationStatus(): L2VerificationStatusResult {
        val d = call(FoundationCallables.GET_L2_VERIFICATION_STATUS, emptyMap())
        return L2VerificationStatusResult(
            status = d["status"] as? String ?: "",
            memberNumber = (d["memberNumber"] as? Number)?.toInt(),
        )
    }
}
```

- [ ] **Step 5: Write the auth manager**

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationAuthManager.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Foundation's Firebase identity, layered on top of Rarimo's local identity
 * secret. Rarimo's app has no server-side account at all; every Foundation
 * callable runs requireAuth, so a Firebase uid is a hard prerequisite.
 */
@Singleton
class FoundationAuthManager @Inject constructor(
    private val functionsService: FoundationFunctionsService,
) {
    private val auth: FirebaseAuth get() = FirebaseAuth.getInstance()

    private val _uid = MutableStateFlow(auth.currentUser?.uid)
    val uid: StateFlow<String?> = _uid.asStateFlow()

    private val _isSignedIn = MutableStateFlow(auth.currentUser != null)
    val isSignedIn: StateFlow<Boolean> = _isSignedIn.asStateFlow()

    private var pendingEmail: String? = null

    init {
        auth.addAuthStateListener { a ->
            _uid.value = a.currentUser?.uid
            _isSignedIn.value = a.currentUser != null
        }
    }

    suspend fun sendCode(email: String) {
        functionsService.requestSignInCode(email)
        pendingEmail = email
    }

    suspend fun submitCode(code: String) {
        val email = pendingEmail ?: error("no pending email; call sendCode first")
        val result = functionsService.verifySignInCode(email, code)
        auth.signInWithCustomToken(result.customToken).await()
        pendingEmail = null
    }

    fun signOut() {
        auth.signOut()
        _uid.value = null
        _isSignedIn.value = false
        pendingEmail = null
    }

    companion object {
        /** Constructs an instance without Hilt, for unit tests. */
        fun forTesting(): FoundationAuthManager =
            FoundationAuthManager(FoundationFunctionsService())
    }
}
```

- [ ] **Step 6: Gate the app on sign-in**

Add a `@Provides` for `FoundationFunctionsService` and `FoundationAuthManager`
in `android/app/src/main/java/com/rarilabs/rarime/di/AppModule.kt` (or let
`@Singleton class … @Inject constructor` be discovered — check the module's
existing convention and follow it).

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/ui/SignInScreen.kt`
mirroring iOS's `SignInView` (email field → send code → 6-digit field → verify),
composed with the app's existing `PrimaryTextField`/`PrimaryButton` components.

Then, in `modules/main/MainScreen.kt`, collect `authManager.isSignedIn` and show
`SignInScreen()` when it is `false`, before the existing passcode/intro gate.

- [ ] **Step 7: Run the test and build**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*FoundationAuthManagerTest*' 2>&1 | tail -10
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -5
```

Expected: 3 tests pass; `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit**

```bash
git add -A android
git commit -m "feat(android): Firebase Auth OTP sign-in

Rarimo's Android app has no server-side account. Adds a callables client
(pinned to us-east1, with the callable names asserted in a unit test so a typo
fails at build time rather than as a runtime NOT_FOUND) and an auth manager,
and gates MainScreen on sign-in.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C7: Play Integrity attestation

**Model tier:** Sonnet.

**Files:**
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/PlayIntegrityService.kt`
- Modify: `android/app/src/main/java/com/rarilabs/rarime/App.kt`
- Modify: `android/app/build.gradle.kts`
- Test: `android/app/src/test/java/com/rarilabs/rarime/foundation/PlayIntegrityServiceTest.kt` (new)

**Interfaces:**
- Consumes: `FoundationFunctionsService.issueAttestationNonce()` /
  `.recordMobileAttestation(nonce, token)` (Task C6).
- Produces: `class PlayIntegrityService @Inject constructor(...)` with
  `suspend fun attestDeviceEndToEnd(): RecordAttestationResult` and
  `suspend fun requestToken(nonce: String): String`.

> **The backend is already ready.** `@plantagoai/attestation` implements
> `verifyPlayIntegrity` (`src/server.ts:121`) and `recordMobileAttestation`
> accepts `platform: "android"` (`functions/index.js:2770`). This task is
> client-side only — no backend work, no coordination with `foundation-next`.

- [ ] **Step 1: Write the failing test**

Create `android/app/src/test/java/com/rarilabs/rarime/foundation/PlayIntegrityServiceTest.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlayIntegrityServiceTest {
    @Test
    fun nonceIsUrlSafeBase64AsPlayIntegrityRequires() {
        // Play Integrity requires the requestHash/nonce to be URL-safe base64,
        // 16..500 bytes. The server emits base64url nonces already; this
        // asserts we do not re-encode and break that.
        val nonce = "abcDEF-123_xyz456789"
        val prepared = PlayIntegrityService.prepareNonce(nonce)
        assertEquals(nonce, prepared)
        assertTrue(prepared.all { it.isLetterOrDigit() || it == '-' || it == '_' || it == '=' })
        assertTrue(prepared.length in 16..500)
    }

    @Test
    fun rejectsAnEmptyNonce() {
        try {
            PlayIntegrityService.prepareNonce("")
            throw AssertionError("expected an IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*PlayIntegrityServiceTest*' 2>&1 | tail -20
```

Expected: `Unresolved reference: PlayIntegrityService`.

- [ ] **Step 3: Write the service**

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/PlayIntegrityService.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Android's counterpart to iOS App Attest. Rarimo's apps ship no platform
 * attestation (spec section 3); this is added work, not inherited.
 *
 * The server side already exists: @plantagoai/attestation's
 * verifyPlayIntegrity, reached through recordMobileAttestation with
 * { platform: "android", token }.
 */
@Singleton
class PlayIntegrityService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val functionsService: FoundationFunctionsService,
) {
    /**
     * Requests an integrity verdict bound to the server-issued nonce, then
     * posts it. The nonce binds the verdict to this one request, which is what
     * stops a captured verdict being replayed.
     */
    suspend fun attestDeviceEndToEnd(): RecordAttestationResult {
        val nonce = functionsService.issueAttestationNonce()
        val token = requestToken(nonce.nonce)
        return functionsService.recordMobileAttestation(nonce.nonce, token)
    }

    suspend fun requestToken(nonce: String): String {
        val prepared = prepareNonce(nonce)
        val manager = IntegrityManagerFactory.create(context)
        val response = manager
            .requestIntegrityToken(
                IntegrityTokenRequest.builder().setNonce(prepared).build()
            )
            .await()
        return response.token()
    }

    companion object {
        /**
         * The server emits base64url-encoded nonces already, so we pass them
         * through unchanged - re-encoding would break the binding the server
         * checks. Validation only.
         */
        fun prepareNonce(nonce: String): String {
            require(nonce.isNotEmpty()) { "nonce must not be empty" }
            require(nonce.length in 16..500) {
                "Play Integrity requires a 16..500 character nonce, got ${nonce.length}"
            }
            require(nonce.all { it.isLetterOrDigit() || it == '-' || it == '_' || it == '=' }) {
                "nonce must be URL-safe base64"
            }
            return nonce
        }
    }
}
```

- [ ] **Step 4: Install App Check with the Play Integrity provider**

Edit `android/app/src/main/java/com/rarilabs/rarime/App.kt`'s `onCreate`, before
any Firebase call:

```kotlin
        FirebaseApp.initializeApp(this)
        FirebaseAppCheck.getInstance().installAppCheckProviderFactory(
            PlayIntegrityAppCheckProviderFactory.getInstance()
        )
```

- [ ] **Step 5: Attest once after sign-in**

In `FoundationAuthManager.submitCode`, after `signInWithCustomToken` succeeds,
kick off attestation without blocking the UI — failures are logged, not fatal
(the device may be a non-Play build or offline; verification itself is what
gates membership).

- [ ] **Step 6: Run the test and build**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*PlayIntegrityServiceTest*' 2>&1 | tail -10
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -5
```

Expected: 2 tests pass; `BUILD SUCCESSFUL`.

- [ ] **Step 7: Commit**

```bash
git add -A android
git commit -m "feat(android): Play Integrity attestation

Rarimo ships no platform attestation. Adds the client half; the server half
already exists (@plantagoai/attestation verifyPlayIntegrity, and
recordMobileAttestation already accepts platform: android), so no backend
change is needed. Nonce is passed through unchanged - the server emits
base64url already and re-encoding would break the binding it checks.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C8: Android verification wiring and commitment write-back

**Model tier:** Opus.

**Files:**
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationVerificationManager.kt`
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/CommitmentAnchorService.kt`
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/ProofArtifact.kt`
- Create: `android/app/src/main/java/com/rarilabs/rarime/foundation/ui/FoundationVerifyCard.kt`
- Modify: `android/app/src/main/java/com/rarilabs/rarime/api/ext_integrator/ext_int_action_preview/handlers/ext_int_query_proof_handler/ExtIntQueryProofHandler.kt`
- Test: `android/app/src/test/java/com/rarilabs/rarime/foundation/EnclaveSealTest.kt` (new)

**Interfaces:**
- Consumes: `FoundationFunctionsService.startL2Verification()` and
  `.getL2VerificationStatus()` (Task C6);
  `PlayIntegrityService.requestToken(nonce)` (Task C7);
  `FoundationAuthManager.uid` (Task C6);
  Rarimo's `ExtIntQueryProofHandler` (upstream) for the proof flow.
- Produces:
  - `data class ProofArtifact(val kind: String, val producedAtMs: Long, val payloadHashHex: String, val signatureBase64: String)`
    with `fun canonicalBytes(): ByteArray`, and companion constants
    `KIND_APP_ATTEST = "appAttest"`, `KIND_NFC_ZK = "nfcZk"`.
  - `object EnclaveSeal` with
    `fun seal(uid: String, artifacts: List<ProofArtifact>): EnclaveSeal.Commitment`,
    where `Commitment(commitmentHashHex: String, artifactKinds: List<String>, producedAtMs: Long)`.
  - **Added to `FoundationFunctionsService` (Task C6's class):**
    `suspend fun anchorCommitment(commitment: EnclaveSeal.Commitment, artifacts: List<ProofArtifact>): AnchorCommitmentResult`,
    plus `data class AnchorCommitmentResult(val accepted: Boolean, val status: String?, val txSignature: String?, val commitmentDocPath: String?, val reason: String?)`
    — matching the Swift `AnchorCommitmentResult` field-for-field.
  - `class FoundationVerificationManager` with `val state: StateFlow<VerificationState>`,
    `suspend fun beginVerification()`, `suspend fun pollUntilVerified()`.

> **The canonical-bytes format is a cross-platform contract.** The server
> re-derives exactly `"{kind}:{producedAtMs}:{payloadHashHex}:{signatureBase64}"`
> per artifact, sorted by kind, prefixed with `"uid:{uid}\n"` and newline-joined.
> The Kotlin implementation must produce byte-identical output to the Swift one
> in `ios/FoundationMobile/Code/Foundation/EnclaveSeal.swift`, or Android commitments
> fail with `"anchorCommitment seal-mismatch"` while iOS ones succeed.

- [ ] **Step 1: Write the failing test**

Create `android/app/src/test/java/com/rarilabs/rarime/foundation/EnclaveSealTest.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class EnclaveSealTest {
    private fun artifact(kind: String, ms: Long, h: Char) = ProofArtifact(
        kind = kind,
        producedAtMs = ms,
        payloadHashHex = h.toString().repeat(64),
        signatureBase64 = "c2ln",
    )

    @Test
    fun canonicalBytesMatchTheSwiftFormat() {
        val a = artifact("appAttest", 1_700_000_000_000L, 'a')
        assertEquals(
            "appAttest:1700000000000:${"a".repeat(64)}:c2ln",
            String(a.canonicalBytes(), Charsets.UTF_8),
        )
    }

    @Test
    fun sealIsOrderIndependentAndUidBound() {
        val one = EnclaveSeal.seal("u1", listOf(artifact("appAttest", 1, 'b'), artifact("nfcZk", 2, 'c')))
        val two = EnclaveSeal.seal("u1", listOf(artifact("nfcZk", 2, 'c'), artifact("appAttest", 1, 'b')))
        assertEquals(one.commitmentHashHex, two.commitmentHashHex)

        val other = EnclaveSeal.seal("u2", listOf(artifact("appAttest", 1, 'b'), artifact("nfcZk", 2, 'c')))
        assertNotEquals(one.commitmentHashHex, other.commitmentHashHex)
    }

    @Test
    fun hashIs64LowercaseHex() {
        val c = EnclaveSeal.seal("u1", listOf(artifact("appAttest", 1, 'b')))
        assertEquals(64, c.commitmentHashHex.length)
        assertEquals(c.commitmentHashHex.lowercase(), c.commitmentHashHex)
    }

    /**
     * Cross-platform golden vector. The same inputs must produce the same hash
     * on iOS. Generate it once by running the equivalent Swift computation and
     * paste it here; after that this test pins the two platforms together.
     */
    @Test
    fun matchesTheIosGoldenVector() {
        val c = EnclaveSeal.seal("golden-uid", listOf(artifact("appAttest", 1000, 'a')))
        assertEquals(IOS_GOLDEN_HASH, c.commitmentHashHex)
    }

    companion object {
        // SHA-256 of:
        //   "uid:golden-uid\n" + "appAttest:1000:" + "a"*64 + ":c2ln" + "\n"
        // Verify independently with:
        //   python3 -c "import hashlib;a='appAttest:1000:'+'a'*64+':c2ln';\
        //   print(hashlib.sha256(b'uid:golden-uid\n'+a.encode()+b'\n').hexdigest())"
        const val IOS_GOLDEN_HASH =
            "498af846df74d0e173e1cee4c09cec1d932c14e65fc9e88d4862943a211922d7"
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*EnclaveSealTest*' 2>&1 | tail -20
```

Expected: `Unresolved reference: ProofArtifact`.

- [ ] **Step 3: Port the seal to Kotlin**

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/ProofArtifact.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import java.security.MessageDigest

/**
 * Cross-platform contract. The server re-derives these exact bytes; iOS's
 * ios/FoundationMobile/Code/Foundation/ProofArtifact.swift must stay byte-identical.
 * Do not reformat.
 */
data class ProofArtifact(
    val kind: String,
    val producedAtMs: Long,
    val payloadHashHex: String,
    val signatureBase64: String,
) {
    fun canonicalBytes(): ByteArray =
        "$kind:$producedAtMs:$payloadHashHex:$signatureBase64".toByteArray(Charsets.UTF_8)

    companion object {
        const val KIND_APP_ATTEST = "appAttest"
        const val KIND_NFC_ZK = "nfcZk"
    }
}

object EnclaveSeal {
    data class Commitment(
        val commitmentHashHex: String,
        val artifactKinds: List<String>,
        val producedAtMs: Long,
    )

    /**
     * Binds the uid into the hash so a captured payload cannot be replayed
     * under another account. Mirrors canonicalSealBytes(uid, artifacts) in
     * foundation-next's functions/index.js.
     */
    fun seal(uid: String, artifacts: List<ProofArtifact>): Commitment {
        val sorted = artifacts.sortedBy { it.kind }
        val buffer = java.io.ByteArrayOutputStream()
        buffer.write("uid:$uid\n".toByteArray(Charsets.UTF_8))
        for (a in sorted) {
            buffer.write(a.canonicalBytes())
            buffer.write('\n'.code)
        }
        val digest = MessageDigest.getInstance("SHA-256").digest(buffer.toByteArray())
        return Commitment(
            commitmentHashHex = digest.joinToString("") { "%02x".format(it) },
            artifactKinds = sorted.map { it.kind },
            producedAtMs = System.currentTimeMillis(),
        )
    }
}
```

- [ ] **Step 4: Write the verification manager**

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationVerificationManager.kt`,
mirroring iOS's Task B8 exactly: call `startL2Verification()`, take
`getProofParamsUrl` (**never** `deepLink`), and drive Rarimo's existing
`ExtIntQueryProofHandler` with that URL directly. Expose
`state: StateFlow<VerificationState>` with the same case set as iOS
(`Idle`, `NotRegistered`, `Starting`, `AwaitingProof`, `Polling`,
`Verified(memberNumber)`, `Failed(message)`).

Modify `ExtIntQueryProofHandler.kt` to accept a `proofParamsUrl` supplied
directly, not only one parsed out of `queryParams["proof_params_url"]`
(line 209) — extract the existing body into a function taking the URL, and have
the query-param path call it.

- [ ] **Step 5: Confirm iOS asserts the identical golden vector**

`IOS_GOLDEN_HASH` above is not copied from a run — it is the independently
computed SHA-256 of the canonical bytes, and Task B7's `EnclaveSealTests`
asserts the same constant on the Swift side. Confirm both are present and equal:

```bash
grep -rn '498af846df74d0e173e1cee4c09cec1d932c14e65fc9e88d4862943a211922d7' \
  ios/FoundationTests android/app/src/test
```

Expected: exactly two hits — one Swift, one Kotlin. If iOS does not have it,
Task B7's test was written without the golden case; add it before continuing,
because nothing else proves the two implementations agree byte-for-byte.

- [ ] **Step 6: Add `anchorCommitment` to the callables client**

Append to `android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationFunctionsService.kt`:

```kotlin
data class AnchorCommitmentResult(
    val accepted: Boolean,
    val status: String?,
    val txSignature: String?,
    val commitmentDocPath: String?,
    val reason: String?,
)
```

and, inside `FoundationFunctionsService`:

```kotlin
    /**
     * Posts a sealed commitment for on-chain anchoring. The server re-derives
     * the canonical bytes from `artifacts` and rejects a hash mismatch, so the
     * payload shape here must match EnclaveSeal.seal exactly.
     *
     * MUST be called only after the member reaches verificationLevel "l2" -
     * the callable runs requireVerifiedMember.
     */
    suspend fun anchorCommitment(
        commitment: EnclaveSeal.Commitment,
        artifacts: List<ProofArtifact>,
    ): AnchorCommitmentResult {
        val d = call(
            FoundationCallables.ANCHOR_COMMITMENT,
            mapOf(
                "commitment" to mapOf(
                    "hashHex" to commitment.commitmentHashHex,
                    "producedAtMs" to commitment.producedAtMs,
                    "kinds" to commitment.artifactKinds,
                ),
                "artifacts" to artifacts.map {
                    mapOf(
                        "kind" to it.kind,
                        "producedAtMs" to it.producedAtMs,
                        "payloadHashHex" to it.payloadHashHex,
                        "signatureBase64" to it.signatureBase64,
                    )
                },
            ),
        )
        return AnchorCommitmentResult(
            accepted = d["accepted"] as? Boolean ?: false,
            status = d["status"] as? String,
            txSignature = d["txSignature"] as? String,
            commitmentDocPath = d["commitmentDocPath"] as? String,
            reason = d["reason"] as? String,
        )
    }
```

- [ ] **Step 7: Write the anchor service**

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/CommitmentAnchorService.kt`:

```kotlin
package com.rarilabs.rarime.foundation

import android.util.Base64
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Android counterpart of iOS's CommitmentAnchorService (Task B9). The app never
 * holds a Solana keypair; it seals a commitment locally and the server performs
 * the on-chain write.
 */
@Singleton
class CommitmentAnchorService @Inject constructor(
    private val functionsService: FoundationFunctionsService,
    private val playIntegrity: PlayIntegrityService,
    private val authManager: FoundationAuthManager,
) {
    class MissingUidException : IllegalStateException("not signed in")

    /**
     * Call ONLY after the member reaches l2 - the callable runs
     * requireVerifiedMember and rejects otherwise.
     */
    suspend fun anchorAfterVerification(): AnchorCommitmentResult {
        val uid = authManager.uid.value ?: throw MissingUidException()

        // appAttest is the only kind anchorCommitment requires
        // (ANCHOR_COMMITMENT_REQUIRED_KINDS = ["appAttest"]). On Android the
        // "attestation" is a Play Integrity verdict token.
        val nonce = functionsService.issueAttestationNonce()
        val token = playIntegrity.requestToken(nonce.nonce)
        val tokenBytes = token.toByteArray(Charsets.UTF_8)
        val hashHex = MessageDigest.getInstance("SHA-256")
            .digest(tokenBytes)
            .joinToString("") { "%02x".format(it) }

        val artifacts = listOf(
            ProofArtifact(
                kind = ProofArtifact.KIND_APP_ATTEST,
                producedAtMs = System.currentTimeMillis(),
                payloadHashHex = hashHex,
                signatureBase64 = Base64.encodeToString(tokenBytes, Base64.NO_WRAP),
            )
        )

        val commitment = EnclaveSeal.seal(uid, artifacts)
        return functionsService.anchorCommitment(commitment, artifacts)
    }
}
```

Then call it from `FoundationVerificationManager.pollUntilVerified()` at the
moment the state becomes `Verified`, catching and logging any failure — as on
iOS, anchoring is a follow-on write and must never fail the user's verification.

- [ ] **Step 8: Add the entry-point card**

Create `android/app/src/main/java/com/rarilabs/rarime/foundation/ui/FoundationVerifyCard.kt`,
a Compose card mirroring iOS's `FoundationVerifyCardView`, and render it from
the home screen above the widget list.

- [ ] **Step 9: Run the tests and build**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*EnclaveSealTest*' 2>&1 | tail -10
cd android && ./gradlew :app:assembleDebug 2>&1 | tail -5
```

Expected: 4 tests pass (including the golden vector); `BUILD SUCCESSFUL`.

- [ ] **Step 10: Prove the golden test can fail (mutation check)**

Temporarily change `"uid:$uid\n"` to `"uid:$uid"` (drop the newline), re-run, and
confirm `matchesTheIosGoldenVector` **fails**. Revert. A cross-platform contract
test that cannot detect a one-byte difference is not testing the contract.

- [ ] **Step 11: Commit**

```bash
git add -A android
git commit -m "feat(android): verification wiring and Solana commitment write-back

Mirrors iOS AD-2: startL2Verification's getProofParamsUrl is fed straight into
Rarimo's ExtIntQueryProofHandler, ignoring the RariMe deep link. Ports
ProofArtifact/EnclaveSeal to Kotlin with a golden-vector test pinning it
byte-for-byte to the Swift implementation - the server re-derives these bytes,
so a one-character divergence would break Android commitments only.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task C9: Android release readiness and the full two-platform gate

**Model tier:** Sonnet.

**Files:**
- Create: `android/fastlane/Fastfile`, `android/fastlane/Appfile`
- Modify: `.github/workflows/brand-sweep.yml`
- Modify: `docs/app-store-review-notes.md`
- Modify: `README.md`
- Test: the full `scripts/brand-sweep.sh` (both platforms) and both builds.

**Interfaces:**
- Consumes: everything from Phases A–C.
- Produces: a green two-platform CI gate.

- [ ] **Step 1: Run the full gate and see where it stands**

```bash
./scripts/brand-sweep.sh
cd ios && xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
cd android && ./gradlew :app:assembleRelease 2>&1 | tail -3
```

Expected: `brand-sweep: PASS`, `** BUILD SUCCEEDED **`, `BUILD SUCCESSFUL`.

- [ ] **Step 2: Widen the CI workflow to both platforms**

Edit `.github/workflows/brand-sweep.yml` — the sweep step already passes
`ios android`; confirm it is not scoped down to `ios`, and add a licensing check
specific to Android's native libraries:

```yaml
      - name: Copyleft inventory is accurate
        run: |
          test -f android/app/src/main/cpp/CMakeLists.txt
          grep -q "librapidsnark.so" android/app/src/main/cpp/CMakeLists.txt
          grep -q "librapidsnark" THIRD_PARTY_LICENSES.md
          grep -q "witnesscalc" THIRD_PARTY_LICENSES.md
```

> This step exists so that if an upstream merge ever *removes* the copyleft
> libraries, the inventory is revisited deliberately rather than silently
> becoming wrong in the other direction.

- [ ] **Step 3: Write the Android fastlane config**

Create `android/fastlane/Appfile`:

```ruby
json_key_file(ENV["PLAY_STORE_JSON_KEY"])
package_name("com.foundationnext.mobile")
```

Create `android/fastlane/Fastfile`:

```ruby
default_platform(:android)

platform :android do
  desc "Fail if any Rarimo branding survives"
  lane :brand_sweep do
    sh("cd ../.. && ./scripts/brand-sweep.sh android")
  end

  desc "Build and upload an internal-testing release"
  lane :internal do
    brand_sweep
    gradle(task: "clean")
    gradle(task: "bundle", build_type: "Release")
    upload_to_play_store(track: "internal")
  end
end
```

- [ ] **Step 4: Extend the review notes for Play**

Append to `docs/app-store-review-notes.md`:

```markdown
## Google Play specifics

- **Target API level:** 35 (`targetSdk`), meeting Play's current requirement.
- **ABI:** `arm64-v8a` only. Declared deliberately — the proving libraries are
  shipped for that ABI alone. Play will restrict device availability
  accordingly; this is expected, not a packaging error.
- **Native debug symbols:** `debugSymbolLevel = "SYMBOL_TABLE"` is already set,
  so the bundle carries symbols for the native crash reports Play expects.
- **Data safety form:** all passport processing is on-device; only a
  zero-knowledge proof leaves the phone. AppsFlyer was removed in Task C5, so
  no advertising or attribution SDK is present — the form must say so.
- **GPL and the Play Store:** unlike the App Store, Google Play's Developer
  Distribution Agreement does not impose EULA terms that conflict with the GPL,
  so Android carries materially less licensing friction than iOS. See Open
  Decision OD-2 — the iOS side is where the legal read is actually needed.
```

- [ ] **Step 5: Finish the README's build section**

Append to `README.md`:

```markdown
## Build

### iOS

    cd ios && ./prebuild.sh          # builds Identity.xcframework (Go + gomobile)
    open FoundationMobile.xcodeproj

Requires `ios/FoundationMobile/GoogleService-Info.plist` (gitignored) — generate with
`firebase apps:sdkconfig IOS --project foundation-next-app`.

### Android

    cd android && ./gradlew :app:assembleDebug

See docs/android-local-setup.md — `app/google-services.json` and a
`GOOGLE_WEB_KEY` Gradle property are required, and the app builds for
`arm64-v8a` only.

### Before any store upload

    ./scripts/brand-sweep.sh

Both fastlane lanes run this first. A leftover Rarimo string or logo reaching a
store listing is the failure mode this guards.
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: two-platform release gate, Android fastlane, build docs

CI now runs brand-sweep across ios/ and android/, checks the licensing files,
and asserts the copyleft inventory still matches CMakeLists so an upstream
removal is noticed deliberately. Both fastlane lanes run the sweep before
building, so a residual Rarimo string cannot reach a store listing.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Open decisions — resolved here provisionally, for controller/user confirmation before execution

Each was made because the spec does not settle it and the plan could not proceed
without a call. Every one is reversible before execution begins; several are
expensive to reverse after.

**OD-1 — LICENSE choice: GPL-3.0 for the combined work.**
*Resolved as:* `LICENSE` = GPL-3.0; Rarimo's MIT notice preserved verbatim in
`NOTICE`; component inventory in `THIRD_PARTY_LICENSES.md`.
*Reasoning:* both platforms statically link GPL-3.0 `witnesscalc`, so the
combined work's distribution terms are GPL-3.0 regardless of what the top-level
file says. The alternative (MIT top-level + a third-party notice file) describes
only our own contributions and misstates the terms recipients actually get.
*Needs confirmation because:* it also licenses Foundation's own new integration
code (attestation, verification wiring, commitment write-back) under GPL-3.0,
which constrains any future proprietary reuse. Also unresolved: `libfq.a`,
`libfr.a` and `libbionet.a` in `ios/Frameworks/` have no stated license — they
are currently treated as part of Rarimo's MIT distribution, which may be wrong.

**OD-2 — App Store distribution of a GPL-3.0 app.**
*Resolved as:* proceed, documenting in `docs/app-store-review-notes.md` that we
hold the copyright in the combined work and can therefore grant the additional
permission the App Store EULA requires.
*Reasoning:* this is the standard resolution, and Rarimo's own Freedom Tool apps
demonstrably ship this identical stack on the App Store today.
*Needs confirmation because:* this is a legal judgement made by a plan author,
not a lawyer. Spec § 3 names the cheap first step and it is still outstanding —
**look at how Rarimo's Russia2024 / Iranians Vote listings handle it before the
first submission.** Google Play carries materially less friction here than the
App Store.

**OD-3 — Android Kotlin namespace stays `com.rarilabs.rarime`.**
*Resolved as:* change `applicationId` only.
*Reasoning:* 394 files / 54,463 LOC of package renames produce no user-visible
change, guarantee conflicts on every upstream merge, and risk silent breakage in
Hilt's generated components and Compose route strings. Users see `applicationId`
and `app_name`; both change.
**CONFIRMED 2026-08-31 (user decision):** keep `com.rarilabs.rarime`, matching
this plan's default. Task C2 proceeds as written, no change needed.

**OD-4 — Module strip list.**
*Resolved as:* strip Earn/RMO, HiddenKeys, PrizeScan, Likeness, Polls/Freedom
Tool, Wallet on iOS and their Android equivalents. Keep passport scan, identity,
recovery, home, main, profile, notifications, MRZ scan.
*Reasoning:* each stripped module is a Rarimo-ecosystem product (their token,
their games, their voting, their likeness product), not identity verification.
Wallet additionally contradicts Foundation's hard no-keypair invariant.
*Needs confirmation because:* **Polls is the debatable one.** Spec § 5 describes
Freedom-Tool-style public polls as a Foundation feature — but on Solana, not on
Rarimo's L2. Stripping the module discards a working polls UI that a later
Solana-backed implementation might otherwise adapt. The call here is that
retargeting it is a rewrite, not a port, so keeping dead Rarimo-L2 voting code
in the tree costs more than it saves.

**OD-5 — Keep depending on Rarimo's hosted registration relayer and L2 contracts.**
*Resolved as:* retain `APP_API_URL`, `EVM_RPC_URL`, the registration/SMT/state-
keeper contract addresses, the circuit-artifact download URLs and the IPFS node.
Strip only the Freedom Tool, points-service, referral and AppsFlyer endpoints.
*Reasoning:* passport registration is anchored on Rarimo's L2, and this fork's
own `verificator-svc` validates proofs against that same registration state.
Repointing means running our own relayer, SMT contracts and certificate
registry — a separate project, not a task in this plan.
**CONFIRMED 2026-08-31 (user decision): accept indefinitely.** No
self-hosting trigger being tracked — this dependency is accepted the same
way the fork-and-rebrand posture already accepted trusting Rarimo's client
code. Revisit only if it becomes an actual operational problem, not on a
predefined schedule.

**OD-6 — Brand artwork.**
*Resolved as:* reuse the pre-fork shell's existing assets
(`foundation-appicon.svg`, `LaunchLogo.imageset`, `AppIcon.appiconset`) for the
app icon and splash mark; where no Foundation equivalent exists for Rarimo's
onboarding illustrations (`IntroIdentity`, `IntroPrivacy`, `IntroWelcome`,
`IntroWidgets`), delete the imagesets and simplify the intro to a text-and-icon
layout rather than shipping Rarimo's art.
*Reasoning:* shipping Rarimo's illustrations is the exact leak the spec warns
about, and a placeholder-free simplification is better than a half-rebranded
onboarding.
*Needs confirmation because:* it visibly downgrades onboarding. If commissioned
artwork exists or is planned, Task B3 Step 7 and Task C3 should use it instead.

**OD-7 — Repo weight and LFS posture.**
*Resolved as:* commit the binaries plainly; do **not** adopt Git LFS.
*Reasoning:* the iOS `Frameworks/*.a` set is roughly 40 MB and Android's `.so`
set roughly 15 MB — large but well inside GitHub's normal limits. LFS on a
public repo consumes bandwidth quota against every clone, and GPL-3.0 requires
these binaries' corresponding source to be genuinely available.
*Needs confirmation because:* upstream Android ships a `.gitattributes` with
`*.aar filter=lfs`. If any `.aar` arrives in a future upstream merge, LFS becomes
active whether or not we chose it. Decide now whether to strip that
`.gitattributes` line at import time.

**OD-8 — Repo visibility timing.**
*Resolved as:* flip to public in Task A1, **before** the Rarimo code is imported
in Task A2, with an explicit pre-flight secret scan.
*Reasoning:* the spec's posture is "public repo from day one," and flipping
before the import means no window in which GPL code sits in a private repo.
*Needs confirmation because:* it makes the fork publicly visible before any
rebranding has happened — for a period, `dagangilat/foundation-mobile-next` will
publicly contain visibly-Rarimo-branded code. That is legally fine and arguably
the most honest sequence, but it is a public-communications choice. Flipping
after Task B5 / C5 instead is a defensible alternative.

---

## Execution notes

- **Phase ordering:** A1 → A2 → A3 → A4, then B1–B10 and C1–C9 may proceed in
  parallel, except that **Task C8 Step 5 (the golden vector) depends on Task B9**
  having produced a working Swift `EnclaveSeal`, and **Task B10 Step 3's CI gate
  covers both platforms**, so scope it to `ios` until C9 lands.
- **Do not run any fastlane lane before Task B10 / C9.**
- **`Identity.xcframework` is a build output.** Any fresh checkout must run
  `ios/prebuild.sh` before the first Xcode build.
- **Android needs an arm64 device or emulator image** — the app ships
  `arm64-v8a` only.
