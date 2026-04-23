# foundation-mobile

Native iOS + Android app for Foundation (Pillar 1 — *Your Voice*). Persona-smooth identity + humanity verification, with zero server-side retention.

> **Canonical plan:** `foundation-global/docs/architecture_identity-humanity-mobile-app-2026-04-23.md`

## Stack decisions (2026-04-23)

- **React Native 0.85 + TypeScript**, `react-native-paper` (MD3 theme) — iOS and Android share one codebase, thin native modules per capability.
- **Consume `@selfxyz/*` SDK + Circom circuits under MIT / ISC.** The BSL-licensed `app/` directory in `selfxyz/self` is **not** forked or vendored.
- **App Attest + Play Integrity is Phase 1**, before NFC+ZK — deepfake camera injection is the dominant 2025–2026 attack class and platform attestation is the only thing that stops it.
- **Standalone repo**, sibling to `foundation-global` (not a subdirectory).
- RN Community CLI, not Expo — full control over every native module.
- Minimum iOS 16 (App Attest prereq), minimum Android 10 / API 29 (Play Integrity prereq).

## Hard invariant

Nothing identifying leaves the device. The only outbound payloads are:

1. The enclave / keystore-signed attestation blob (hashes only — no raw images, no MRZ, no DG2).
2. The Solana commitment hash.

Any code path that uploads DG2 photos, selfie frames, MRZ strings, or raw biometrics is a regression on the core claim and requires explicit sign-off.

## Phase status

| Phase | Summary | Status |
|---|---|---|
| 0 | Scaffolding, RN + MD3, Firebase sign-in, ring-tier display | In progress |
| 1 | App Attest + Play Integrity (first real integration) | Pending |
| 2 | Solana Groth16 verifier (backend Anchor program) | Pending |
| 3 | Integrate Self SDK + circuits (NFC + ZK) | Pending |
| 4 | Active liveness + nonce binding | Pending |
| 5 | Passive anti-spoof | Pending |
| 6 | Face match DG2 ↔ selfie | Pending |
| 7 | Enclave / Keystore seal | Pending |
| 8 | Ring-tier uplift + UX polish | Pending |
| 9 | YC demo recording | Pending |
| 10 | Store submission + production hardening | Pending |
| 11 | Threshold tuning + telemetry | Pending |

Phase detail lives in the canonical architecture doc.

## Getting started

```sh
# First time only
bundle install

# Install JS deps
npm install

# iOS native deps
cd ios && bundle exec pod install && cd ..

# Run (Metro auto-starts)
npm run ios
npm run android
```

## Next up (Phase 0 remainder)

1. Drop `GoogleService-Info.plist` (iOS) and `google-services.json` (Android) from the `solanavote-devnet` Firebase project.
2. Implement email-link sign-in mirroring `evoting-frontend`'s flow.
3. Render ring tier from Firebase custom claims (empty-app demo gate).
