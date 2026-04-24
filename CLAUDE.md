# CLAUDE.md — foundation-mobile

Auto-loaded by Claude Code at session start. Keep it under ~200 lines.

## What this repo is

Native iOS Swift app for Foundation (Pillar 1 — *Your Voice*). Persona-smooth identity + humanity verification with zero server-side retention. The canonical architecture doc lives in `foundation-global/docs/architecture_identity-humanity-mobile-app-2026-04-23.md`.

## Hard invariant — do not regress

Nothing identifying leaves the device. The only outbound payloads are:
1. An enclave-signed attestation blob (hashes only — no raw images, no MRZ, no DG2).
2. A Solana commitment hash.

Any code path that uploads DG2 photos, selfie frames, MRZ strings, or raw biometrics is a regression on the core claim. Flag it immediately; don't ship it.

## Current branch state (as of 2026-04-24)

- **Phase 0 — done.** Email-link sign-in + Universal Links + Ring 0 render verified on device.
- **Phase 1 — mobile-side done.** `AttestationService`, `AttestationCoordinator`, `AppCheckFactory` wired. Apple CBOR verifier landed in `@plantagoai/attestation/server` (2026-04-23 PM, 11 tests green). Still needs: Apple portal "App Attest" capability + Firebase console App Attest provider registration, and an eventual `ENFORCE_APP_CHECK=true` flip on the mobile callables once the client reliably attaches App Check tokens.
- **Sprint 0 — scaffolded.** `ProofArtifact` contract frozen, `CameraSession` shared pipeline written, `EnclaveSeal` skeleton in place, `mopro-smoke/` toolchain smoke test ready to run on macOS.

## Frozen contract — `ProofArtifact` is load-bearing

`ios/FoundationMobile/ProofArtifact.swift`:

```swift
struct ProofArtifact {
    enum Kind { case appAttest, nfcZk, liveness, antiSpoof, faceMatch }
    let kind: Kind
    let producedAtMs: Int64
    let payloadHashHex: String     // lowercase hex SHA-256
    let signatureBase64: String    // App Attest assertion
}
```

Every sensor phase (1, 3, 4, 5, 6) emits exactly this shape. `EnclaveSeal` sorts by kind, concatenates `canonicalBytes()`, SHA-256s, submits to Phase 2 Solana callable. Changing the shape invalidates every previously-signed artifact — treat as frozen.

## Feature flags — `SensorFeatureFlags.swift`

Each sensor phase has a compile-time bool. Disabled phases emit deterministic mocks so Phase 7 + Phase 2 can integrate against the full fan-in from day one. Never block sign-in/home on an in-progress sensor — gate it off.

## Parallel execution plan

- **Sprint 0:** contract freeze (done), MOPRO smoke (scaffolded, awaits macOS), Core ML smoke (TODO), Phase 1 backend verifier (foundation-global repo).
- **Sprints 1–3, three parallel tracks:**
  - **Track A — Backend:** Phase 2 Anchor Groth16 verifier. Develops against a mock commitment hash.
  - **Track B — NFC+ZK (Phase 3):** gated on MOPRO smoke going green. Self circuit via `mopro-ffi` if green; WASM-in-JavaScriptCore fallback if red.
  - **Track C — Camera sensors (Phases 4/5/6):** all three consume `CameraSession.shared.frames()` — one `AVCaptureSession`, many `AsyncStream` subscribers. Do **not** ship three competing capture sessions.
- **Sprint 4:** Phase 7 (concat artifacts → SHA-256 → Secure-Enclave-sign → submit) + Phase 8 (ring uplift from on-chain confirmation).
- **Sprint 5:** Phase 9 (demo record) + Phase 10 (TestFlight) in parallel; Phase 11 (threshold tuning) from Phase 9 telemetry.

## Anti-rework rules — enforce these

- Nothing bypasses the `ProofArtifact` contract.
- One camera session for Phases 4/5/6.
- Both sides of every integration develop against mocks; real wire-up is Sprint 4 only.
- Sign-in / home path never blocks on an in-progress sensor — feature-flag off.
- If MOPRO's toolchain fights back, fall back to WASM-in-JavaScriptCore; don't let Track B slip chasing the toolchain.
- Persist App Attest `keyId` in Keychain; attest once per install and reuse via `generateAssertion`.

## Stack decisions (don't reopen without reason)

- **Native iOS Swift + SwiftUI**, min iOS 16. No React Native, no JS runtime except the WASM fallback carve-out above.
- **CocoaPods, not SPM.** Xcode Cloud requires per-org GitHub App installs that we don't control for public SDKs. Memory: `project_spm_migration.md`.
- **Android deferred post-YC-demo.** Pre-pivot RN scaffold is at git tag `archive/rn-scaffold`.
- **Firebase via CocoaPods** — FirebaseAuth, FirebaseFirestore, FirebaseFunctions, FirebaseAppCheck.
- **Solana writes stay server-side** via `foundation-global/functions/lib/solana.js`. Mobile never holds a Solana keypair.

## Key file map

```
ios/FoundationMobile/
  AppDelegate.swift            # wires AppCheck before FirebaseApp.configure()
  AppCheckFactory.swift        # DebugProvider on sim, AppAttestProvider on device
  AttestationService.swift     # DCAppAttestService actor; persists keyId
  AttestationCoordinator.swift # @MainActor, drives attestation once per session
  FunctionsService.swift       # issueAttestationNonce + recordMobileAttestation
  AuthService.swift            # email-link sign-in, custom claims
  Keychain.swift               # pendingEmail + appAttestKeyId slots
  CameraSession.swift          # shared AVCaptureSession, AsyncStream<FrameBuffer>
  ProofArtifact.swift          # FROZEN contract — don't mutate shape
  EnclaveSeal.swift            # Phase 7 commitment builder
  SensorFeatureFlags.swift     # compile-time per-phase toggles
  MoproSmokeBridge.swift       # gated on -D MOPRO_LINKED

mopro-smoke/                   # Sprint-0 toolchain smoke (Rust + UniFFI)
  Cargo.toml src/lib.rs src/bin/uniffi-bindgen.rs uniffi.toml
  build-xcframework.sh         # macOS-only; produces ios/Frameworks/MoproSmoke.xcframework
  README.md                    # how to run + integrate into Xcode
```

## Build / run

```sh
(cd ios && pod install)
open ios/FoundationMobile.xcworkspace
# Min iOS 16. Signing team: F9F26FQW95.
# Simulator uses App Check debug provider; device uses real App Attest.
```

MOPRO smoke (macOS only, first time):
```sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
./mopro-smoke/build-xcframework.sh
# Then in Xcode: drag MoproSmoke.xcframework + generated MoproSmoke.swift into target,
# add -D MOPRO_LINKED to Other Swift Flags.
```

## Conventions

- No comments for what code does — well-named identifiers already do that.
- No comments that reference PR context / callers / issue numbers — they rot.
- Only comment non-obvious WHY (hidden constraint, workaround, subtle invariant).
- No emojis in source files unless explicitly requested.
- No backwards-compat shims or feature flags for migrations that can just be done.
- `pbxproj` edits: new files need PBXBuildFile + PBXFileReference + group child + Sources phase entry. Four places.

## Immediate next actions (in priority order)

1. **macOS:** run `./mopro-smoke/build-xcframework.sh`, integrate the xcframework + binding, add `-D MOPRO_LINKED`, verify HomeView's MOPRO row shows the version string on device. If green → swap `uniffi` for `mopro-ffi` in `mopro-smoke/Cargo.toml`. If red → implement WASM-in-JavaScriptCore Phase 3 producer instead.
2. **foundation-global repo (separate):** Apple portal "App Attest" capability on `com.foundationglobal.mobile`, Firebase console App Attest provider registration. Apple CBOR verifier already shipped in `@plantagoai/attestation/server`. Play Integrity verifier still stubbed (Phase 1c, Android — not demo-critical).
3. **Parallel:** implement mock `ProofProducer`s for kinds 3/4/5/6 so Phase 7 integration can start now behind feature flags.
4. **Parallel:** Core ML smoke — load Silent-Face-Anti-Spoofing + ArcFace in a throwaway Playground; confirm iOS 16 compatibility.
