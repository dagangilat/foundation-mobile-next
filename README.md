# foundation-mobile

Native iOS Swift app for Foundation (Pillar 1 — *Your Voice*). Persona-smooth identity + humanity verification, with zero server-side retention.

> **Canonical plan:** `foundation-global/docs/architecture_identity-humanity-mobile-app-2026-04-23.md`

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
| 0 | SwiftUI app shell, Firebase sign-in, ring-tier display | ✅ Done (2026-04-24) — email-link sign-in + Ring 0 render verified on device |
| 1 | App Attest (first real integration) | Mobile client complete (service + coordinator + UI); backend verifier + portal/console config pending |
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

## Phase 0 — done (2026-04-24)

Verified on device:
- Email-link sign-in (Firebase Auth) round-trips: request link → Gmail receipt → tap → app reopens signed in.
- Universal Links / Associated Domains (`applinks:foundation-global.com` → `/mobile-signin`) handing back to the app.
- Ring tier renders from Firebase custom claims ("Ring 0 — Operator") on the signed-in home screen.
- App Check debug provider wired on simulator; real App Attest wiring for device lands in Phase 1.

Open Phase 0 housekeeping (not blocking Phase 1):
- Finalize `GoogleService-Info.plist` policy (commit vs. `.gitignore` + CI-injected).

(`PRODUCT_BUNDLE_IDENTIFIER = com.foundationglobal.mobile` is already set in both Debug and Release configurations.)

## Phase 1 — Platform attestation (Swift)

`DCAppAttestService` is exposed via a plain Swift `AttestationService` (`ios/FoundationMobile/Services/AttestationService.swift` after Phase A lands). No RN bridge.

Two layers — don't conflate them:

- **Coarse request gating: Firebase App Check** (delegates App Attest to Firebase, which verifies against Apple public keys). Wired via `AppCheck.setAppCheckProviderFactory(...)` *before* `FirebaseApp.configure()` in `AppDelegate`. Backend enforcement already plumbed in `foundation-global/functions/lib/app-check.js` — flip `ENFORCE_APP_CHECK=true` in the functions env to reject unattested requests.
- **Fine-grained attestation payload** (for the Phase 7 enclave-seal hash): `AttestationService` exposes `attestDeviceEndToEnd()` which runs `issueAttestationNonce` → `DCAppAttestService.generateKey` / `attestKey(clientDataHash:)` → `recordMobileAttestation`. App Check's opaque token isn't suitable for that payload.

Phase 1 mobile client (in-repo):
- `AppCheckFactory` picks `AppCheckDebugProvider` on simulator and `AppAttestProvider` on device, wired from `AppDelegate` before `FirebaseApp.configure()`.
- `AttestationService.attestDeviceEndToEnd()` runs `issueAttestationNonce` → `generateKey` → `attestKey(clientDataHash:)` → `recordMobileAttestation`, and persists the attested keyId in Keychain on success for reuse via `generateAssertion`.
- `AttestationCoordinator` kicks off once per session after sign-in, short-circuits on simulator (App Attest unsupported) and on devices with a persisted keyId, and publishes state for the UI.
- `HomeView` surfaces the coordinator's state as a small status row in the ring card so device attestation is visible during the demo and debugging.
- Entitlements (`com.apple.developer.devicecheck.appattest-environment = development`) and bundle id (`com.foundationglobal.mobile`) are in place.

Phase 1 remainder (out-of-repo deployment + config):
1. Apple Developer portal: enable "App Attest" on the bundle id.
2. Firebase console → App Check: register the iOS app (App Attest provider); generate a debug token for the simulator.
3. `foundation-global/functions/`: `recordMobileAttestation` callable accepts `{ platform: 'ios', keyId, attestation }`, verifies the CBOR attestation against Apple roots, and writes to the user's `identity_proofs` doc — feeds the Phase 7 enclave seal.
4. Functions env: set `ENFORCE_APP_CHECK=true` once the Swift client reliably attaches tokens and the verifier is live.
5. On-device verification: clean install → email-link sign-in → attestation row transitions to "device attested".

## Parallel execution plan (Phases 2–11)

The phases fan out behind a frozen artifact contract so mobile sensor tracks, the backend verifier track, and the Solana on-chain track can progress independently and merge in Phase 7.

**Contract (frozen):** `ProofArtifact { kind, producedAtMs, payloadHashHex, signatureBase64 }` — defined in `ios/FoundationMobile/ProofArtifact.swift`. Every sensor phase emits exactly this shape; Phase 7 (`EnclaveSeal.swift`) sorts by kind, concatenates canonical bytes, SHA-256s, and submits to the Phase 2 Solana callable. Changing this shape invalidates every signed artifact — treat as load-bearing.

**Feature flags:** `SensorFeatureFlags.swift` — each sensor phase has a compile-time bool. Disabled phases emit deterministic mocks so Phase 7 + Phase 2 always see a complete fan-in during development. Flip to `true` once the real sensor ships.

**Sprint 0 — de-risk + contract (all in parallel):**
1. Contract freeze — done (`ProofArtifact.swift`, `EnclaveSeal.swift`, `SensorFeatureFlags.swift` landed).
2. MOPRO toolchain smoke test: trivial UniFFI `.xcframework` into the app on Xcode Cloud. Decide fall-back (WASM in JavaScriptCore) if the toolchain fights us. Highest-risk item in the plan.
3. Core ML smoke test: load Silent-Face-Anti-Spoofing + ArcFace in a throwaway Playground on iOS 16 and confirm they compile.
4. Phase 1 backend verifier (out of this repo): `recordMobileAttestation` CBOR verify + Apple portal + Firebase console config.

**Sprints 1–3 — three parallel tracks, all behind feature flags:**
- **Track A — Backend:** Phase 2 Anchor Groth16 verifier, developing against a mock commitment hash.
- **Track B — NFC + ZK (Phase 3):** gated on Sprint 0 step 2 going green. Real NFC passport read → DG1/DG2 → Self circuit via MOPRO → `ProofArtifact(kind: .nfcZk)`.
- **Track C — Camera sensors (Phases 4, 5, 6):** all three consume `CameraSession.shared.frames()` (one `AVCaptureSession`, many `AsyncStream` subscribers). Each phase emits its own `ProofArtifact` kind. Building them together avoids three competing capture sessions and shared-state rework later.

**Sprint 4 — integration:** Phase 7 enclave seal becomes trivially small — collect available artifacts, hash, sign with Secure Enclave key, submit to the Phase 2 callable. Phase 8 ring uplift wires off the on-chain confirmation. If a sensor track slipped, Phase 7 still seals with the subset — the demo can ship partial.

**Sprint 5 — ship:** Phase 9 (demo record) and Phase 10 (TestFlight) run in parallel; Phase 11 (threshold tuning) pulls from Phase 9 rehearsal telemetry.

**Anti-rework rules:**
- Nothing bypasses the `ProofArtifact` contract.
- One camera session for Phases 4/5/6 — don't ship three.
- Both sides of every integration develop against mocks; real wire-up happens in Sprint 4.
- Sign-in / home path never blocks on an in-progress sensor — feature flag it off.
- If MOPRO's toolchain fights back in Sprint 0 step 2, fall back to WASM-in-JavaScriptCore rather than letting Track B slip.
