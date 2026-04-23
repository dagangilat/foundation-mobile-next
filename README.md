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
| 0 | Scaffolding, RN + MD3, Firebase sign-in, ring-tier display | In progress (creds pending) |
| 1 | App Attest + Play Integrity (first real integration) | Scaffold landed (backend verifier pending) |
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

1. **Register Firebase apps** in the `solanavote-devnet` Firebase project and standardize bundle IDs to `com.foundationglobal.mobile`:
   - iOS: change `PRODUCT_BUNDLE_IDENTIFIER` in `ios/FoundationMobile.xcodeproj/project.pbxproj` (2 occurrences).
   - Android: change `namespace` + `applicationId` in `android/app/build.gradle` and move Kotlin files from `android/app/src/main/java/com/foundationmobile/**` to `.../com/foundationglobal/mobile/**` (update `package` headers in both `MainActivity.kt` and `MainApplication.kt`).
   - Update `ACTION_CODE_SETTINGS` in `src/lib/auth.ts` once the rename lands.
2. Drop `GoogleService-Info.plist` (iOS, into `ios/FoundationMobile/`) and `google-services.json` (Android, into `android/app/`) from the Firebase project.
3. Configure Universal Links (iOS associated domains) + App Links (Android asset links) for `foundation-global.com/mobile-signin` so the email-link reopens the app.
4. **Demo gate:** empty app on both platforms, signed in via email-link, renders ring tier from Firebase custom claims.

Already wired:
- `ios/FoundationMobile/AppDelegate.swift` calls `FirebaseApp.configure()` at startup.
- `ios/Podfile` has `use_modular_headers!` for the Firebase Swift pods; 92 pods integrated.
- `android/build.gradle` classpaths `com.google.gms:google-services:4.4.2`; `android/app/build.gradle` applies the plugin.
- `AsyncStorage` persists the pending email across the send-link / deep-link-return boundary; `completeSignInFromDeepLink(url)` runs on cold start and `Linking` events.

## Phase 1 — Platform attestation (scaffold)

iOS `DCAppAttestService` and Android Play Integrity are both wrapped behind a single TS surface (`src/lib/attestation.ts`):

```ts
const attestation = await attestDevice(challengeB64);
// iOS:     { platform: 'ios', keyId, attestation }
// Android: { platform: 'android', token }
```

Native module inventory:
- iOS: `ios/FoundationMobile/AppAttestModule.swift` + `AppAttestModule.m` (registered with the `FoundationMobile` target via `ios/scripts/add-phase1-sources.rb` — idempotent, rerun after `pod install` if needed).
- Android: `android/app/src/main/java/com/foundationmobile/attestation/{PlayIntegrityModule,AttestationPackage}.kt`, package registered in `MainApplication.kt`; `com.google.android.play:integrity:1.4.0` dep added.
- Entitlements: `ios/FoundationMobile/FoundationMobile.entitlements` (`com.apple.developer.devicecheck.appattest-environment = development`); wired via `CODE_SIGN_ENTITLEMENTS` in both Debug + Release pbxproj build configs.

Phase 1 remainder (backend + integration):
1. Cloud Functions: add `issueAttestationNonce` (server-issued random nonce, 15-minute TTL, stored in Firestore or memory cache) + `verifyAppAttestation` + `verifyPlayIntegrity` in `foundation-global/functions/`.
2. Implement Apple App Attest verification (parse CBOR attestation, verify against Apple's App Attest root + key id + nonce binding); prior art: `node-app-attest` / roll our own against Apple's published format.
3. Implement Google Play Integrity verification (Play Integrity JWS decode, verify against Google public keys, check nonce + app verdict `MEETS_DEVICE_INTEGRITY`).
4. Persist attested key id (iOS) or verdict (Android) on the user's Firestore doc so subsequent assertions can be re-verified.
5. Gate all ring-uplift-adjacent callables on a valid attestation token via middleware.
6. Apple Developer portal: enable "App Attest" capability on the app identifier (requires standardized bundle id from the Phase 0 remainder above).
7. Play Console: enable Play Integrity, fetch the decryption key (if using classic verdict) or the public key (if using standard verdict).
