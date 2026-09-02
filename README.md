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

## Stack decisions (2026-04-23 PM — amended from AM RN decision)

- **Native iOS Swift + SwiftUI.** Minimum iOS 16 (App Attest prereq). No React Native, no JS runtime, no RN bridge.
- **Android deferred post-YC-demo.** When picked up, Android will be a separate Kotlin / native track, not a revived RN codebase. Pre-pivot RN scaffold preserved at git tag `archive/rn-scaffold`.
- **Firebase via Swift Package Manager** — `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFunctions`, `FirebaseAppCheck`.
- **Solana writes stay server-side** via `foundation-global/functions/lib/solana.js` (`anchorCommitment` callable). Mobile never holds a Solana keypair. Optional read-only `SolanaRPC` actor for on-chain status display.
- **NFC + ZK path:** Self Protocol's Circom circuits consumed via **MOPRO** (`zkmopro/mopro`) → UniFFI-generated Swift `.xcframework`. The BSL-licensed `selfxyz/self` `app/` directory is **not** forked or vendored.
- **App Attest is Phase 1** before NFC+ZK — deepfake camera injection is the dominant 2025–2026 attack class and platform attestation is the only thing that stops it. Play Integrity deferred to the Android track.

## Hard invariant

Nothing identifying leaves the device. The only outbound payloads are:

1. The enclave-signed attestation blob (hashes only — no raw images, no MRZ, no DG2).
2. The Solana commitment hash.

Any code path that uploads DG2 photos, selfie frames, MRZ strings, or raw biometrics is a regression on the core claim and requires explicit sign-off.

## Phase status

| Phase | Summary | Status |
|---|---|---|
| 0 | SwiftUI app shell, Firebase sign-in, ring-tier display | In progress (Swift pivot 2026-04-23 PM) |
| 1 | App Attest (first real integration) | Swift `AttestationService` landed; backend verifier pending |
| 2 | Solana Groth16 verifier (backend Anchor program) | Pending |
| 3 | NFC + ZK via MOPRO-bound Self circuits | Pending |
| 4 | Active liveness + nonce binding (MediaPipe via XCFramework) | Pending |
| 5 | Passive anti-spoof (Silent-Face-Anti-Spoofing, Core ML) | Pending |
| 6 | Face match DG2 ↔ selfie (ArcFace, Core ML) | Pending |
| 7 | Secure Enclave seal (biometric-gated) | Pending |
| 8 | Ring-tier uplift + UX polish | Pending |
| 9 | YC demo recording | Pending |
| 10 | TestFlight → App Store submission | Pending |
| 11 | Threshold tuning + telemetry | Pending |

Phase detail lives in the canonical architecture doc. Android track will be planned after the iOS demo lands.

## Getting started

```sh
# First time only — install CocoaPods deps
(cd ios && pod install)

# Open the workspace in Xcode (not .xcodeproj — CocoaPods requires .xcworkspace)
open ios/FoundationMobile.xcworkspace

# Minimum iOS target: 16.0. Signing team: F9F26FQW95.
# Simulator uses Firebase App Check debug provider; device uses real App Attest.
```

CI/CD: Xcode Cloud, running `ios/ci_scripts/ci_post_clone.sh` (`pod install`) before each build. See memory `project_xcode_cloud.md` and `project_spm_migration.md` for why we're on CocoaPods (SPM was tried + reverted due to Xcode Cloud's per-org GitHub App install requirement).

## Phase 0 remainder

1. **Standardize bundle id to `com.foundationglobal.mobile`** — change `PRODUCT_BUNDLE_IDENTIFIER` in `ios/FoundationMobile.xcodeproj/project.pbxproj` (Debug + Release).
2. **Apple Developer portal:** enable "App Attest" + "Associated Domains" capabilities on the app identifier.
3. **Associated Domains:** configure `applinks:foundation-global.com` for Universal Links so the email sign-in link reopens the app (`/mobile-signin` path).
4. `GoogleService-Info.plist` is already in `ios/FoundationMobile/` (untracked — add to repo or ignore per release policy).
5. **Demo gate:** empty app, signed in via email-link, renders ring tier from Firebase custom claims.

## Phase 1 — Platform attestation (Swift)

`DCAppAttestService` is exposed via a plain Swift `AttestationService` (`ios/FoundationMobile/Services/AttestationService.swift` after Phase A lands). No RN bridge.

Two layers — don't conflate them:

- **Coarse request gating: Firebase App Check** (delegates App Attest to Firebase, which verifies against Apple public keys). Wired via `AppCheck.setAppCheckProviderFactory(...)` *before* `FirebaseApp.configure()` in `AppDelegate`. Backend enforcement already plumbed in `foundation-global/functions/lib/app-check.js` — flip `ENFORCE_APP_CHECK=true` in the functions env to reject unattested requests.
- **Fine-grained attestation payload** (for the Phase 7 enclave-seal hash): `AttestationService` exposes `attestDeviceEndToEnd()` which runs `issueAttestationNonce` → `DCAppAttestService.generateKey` / `attestKey(clientDataHash:)` → `recordMobileAttestation`. App Check's opaque token isn't suitable for that payload.

Phase 1 remainder (deployment + config):
1. Apple Developer portal: enable "App Attest" on the standardized bundle id.
2. Firebase console → App Check: register the iOS app (App Attest provider); generate a debug token for the simulator.
3. Functions env: set `ENFORCE_APP_CHECK=true` once the Swift client reliably attaches tokens.
4. `recordMobileAttestation` callable in `foundation-global/functions/` accepts `{ platform: 'ios', keyId, attestation }` and writes to the user's `identity_proofs` doc — feeds the Phase 7 enclave seal.
