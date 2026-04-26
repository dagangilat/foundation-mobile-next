# iOS Privacy Invariant Audit — 2026-04-26

## Scope

Full read of every `.swift` file under `ios/FoundationMobile/` plus
`Info.plist`, `FoundationMobile.entitlements`, `PrivacyInfo.xcprivacy`, and
`Podfile`/`Podfile.lock`. Goal: verify the hard invariant — *nothing
identifying leaves the device. Outbound payloads are limited to (1) an
enclave-signed attestation blob containing only hashes, and (2) a Solana
commitment hash.*

Out of scope (not verified here): server-side handling of received payloads
(Cloud Functions in `foundation-global`), Solana program invocation, the
embedded WebView's behavior at `https://foundation-global.com/` (a different
codebase rendered inside `WKWebView`).

## Network egress inventory (every host + payload shape)

The app talks to four hosts:

1. **Firebase Auth (Google) — `*.googleapis.com`** via `FirebaseAuth` SDK
   - `Auth.auth().signIn(withEmail:link:)` (`AuthService.swift:90`) — sends
     the user's email + email-link continuation URL. Email is necessarily PII
     but is not in scope of the "raw biometric / DG2 / MRZ" invariant.
   - `Auth.auth().addStateDidChangeListener` (`AuthService.swift:28`) — token
     refresh round-trips. ID token claims contain `uid`, `email`, `ring`,
     `role`. Email is sent as part of the ID token's normal lifecycle.
2. **Firebase Functions (us-east1) — `us-east1-…cloudfunctions.net`**, all
   invocations in `FunctionsService.swift`:
   - `issueAttestationNonce` (`:163`) — empty payload `[:]`.
   - `recordMobileAttestation` (`:169`) — `{ nonce, attestation: { platform,
     keyId, attestation: <base64 CBOR> } }`. The attestation CBOR is Apple's
     App Attest blob (cert chain, authData, attStmt). No app payload bytes.
   - `resendInviteLink` (`:174`) — `{ email, platform: "ios" }`. Email PII
     (necessary for invite gating).
   - `anchorCommitment` (`:184`) — `{ commitment: { hashHex, producedAtMs,
     kinds[] }, artifacts: [{ kind, producedAtMs, payloadHashHex,
     signatureBase64 }], biometricSeal: nil, attestationTier }`. Hashes only;
     each `signatureBase64` is the App Attest assertion over the per-artifact
     payload hash. **Currently `biometricSeal` is unconditionally `nil`
     (`CaptureCoordinator.swift:594`).**
   - `claimPairingSession` (`:190`) — `{ code, attestationTier }`.
   - `heartbeatPairingSession` (`:198`) — `{ sessionId }`.
   - `releasePairingSession` (`:204`) — `{ sessionId, attestationTier }`.
   - `submitSupportTicket` (`:210`) — `{ appAttest, moproStatus,
     humanityState, latestCommitment, anchorStatus, profileId, appVersion,
     buildVersion, iosVersion, deviceModel }`. Strings are diagnostic
     state — see SupportSheet finding below for caveats.
   - `mintWebSessionToken` (`:216`) — `{ attestationTier }`.
3. **Solana devnet RPC — `https://api.devnet.solana.com`**
   (`SolanaRPC.swift:7`). Read-only `getAccountInfo` JSON-RPC; `[pubkey,
   { encoding: "base64" }]` body. **No write / signing path; mobile holds
   no Solana keypair.** This actor is exposed but I could find no call
   site under `ios/FoundationMobile/*.swift` that uses it (it appears to
   be reserved for a future UI surface).
4. **Apple App Attest — `*.apple-cloudkit.com`** via `DCAppAttestService`
   (`AttestationService.swift:20`). `generateKey` and `attestKey` round-trip
   to Apple. Payload to Apple: device key + `clientDataHash` =
   `SHA-256(utf8(nonce))`. Apple holds nothing identifying about the user.
5. **Foundation web app (WKWebView only) —
   `https://foundation-global.com/`** loaded by `WebHomeView.swift:38`. This
   is a `WKWebView`, not native HTTP, so what flows depends on the loaded JS
   bundle (out of scope here). One JS injection: a Firebase custom token
   passed via `view.evaluateJavaScript` (`WebHomeView.swift:297`); token
   itself is server-minted by `mintWebSessionToken`.
6. **NFCPassportReader → passport chip directly** (Phase 3a). This is
   APDU-over-NFC, not network, but worth noting: only DG1, DG2, SOD are
   read; DG3 (fingerprints), DG4 (iris), DG7 (signature image), DG11/12
   (personal details) are explicitly skipped (`PassportNFCReader.swift:129`,
   `PassportNFCReader.swift:123`).

No third-party telemetry / analytics SDKs are linked. No Sentry / Crashlytics
/ Firebase Analytics / Datadog / Mixpanel pods in `Podfile`; grep for
`Sentry`/`Crashlytics`/`Analytics`/`recordError`/`setUserID`/`setUserProperty`
returns nothing in the source tree.

## Persistence inventory (Keychain, files, UserDefaults, photo lib)

### Keychain (`Keychain.swift`)

Two slots, both `kSecAttrAccessibleAfterFirstUnlock`, service
`com.foundationglobal.mobile`:
- `pendingSignInEmail` (`Keychain.swift:6`) — the email entered on
  SignInView, stashed until the email-link callback consumes it. Cleared on
  `completeSignIn` success (`AuthService.swift:91`).
- `appAttestKeyId` (`Keychain.swift:7`) — Apple-issued opaque key id
  (random; not a user identifier). Persisted across launches.

`BiometricSealer.swift` additionally stores a Secure-Enclave-bound P-256
private key under `kSecAttrApplicationTag = com.foundation.biometric-seal-
key.v1` with `kSecAttrAccessControl = .biometryCurrentSet`
(`BiometricSealer.swift:51`, `:177`). Private key never leaves the Secure
Enclave by construction.

### UserDefaults

No direct app code reads/writes `UserDefaults`. Firebase (and GoogleUtilities)
declare `NSPrivacyAccessedAPICategoryUserDefaults` in
`PrivacyInfo.xcprivacy:17` for their own internal use; this is normal SDK
behavior (auth-state caching).

### Files (Documents / Caches)

- **DEBUG-only dumps** to `Documents/`:
  - `AttestationService.swift:138-184` writes attestation CBOR + meta
    (`attestation-<keyIdPrefix>-<timestamp>.cbor`,`.b64`,`-meta.txt`).
    Wrapped in `#if DEBUG`.
  - `CaptureCoordinator.swift:344-376` writes DG2 face JPEG + meta
    (`passport-<ISR>-<masked-suffix>-<timestamp>-dg2.jpg`,`-meta.txt`).
    Wrapped in `#if DEBUG`.
  - **Note:** these are explicitly debug-only and the comment treats it as
    a hard invariant. They are still on a developer's device and accessible
    via Xcode → Window → Devices → Download Container; that's intended for
    offline forensic / verification work. No release code path writes them.
- **Caches/MLModelCache** (release builds): `AntiSpoofProducer.swift:228`
  and `CoreMLFaceEmbedder.swift:57` cache compiled `.mlmodelc` bundles.
  These are model weights, not user data.

### Photo library

No call to `UIImageWriteToSavedPhotosAlbum`, `PHPhotoLibrary`, or any
PhotoKit API. Camera frames stay in process memory (CVPixelBuffer →
JPEG-encode in `LivenessFrameProducer.swift` → drop after the
`verify()` flow consumes them — `CaptureCoordinator.swift:449` calls
`self.capturedJpegs.removeAll()` immediately after they are read into the
sealing closure).

### Pasteboard

One write: `SupportSheet.swift:182` copies the server-returned ticket id
into `UIPasteboard.general` on user tap. Ticket id is server-generated,
non-PII.

## Logging audit (print/NSLog/os_log)

Every `print` call I found:

- `AttestationService.swift:158`, `:182` — DEBUG-only, log filename of the
  on-disk dump (no payload bytes).
- `AuthService.swift:108`, `:111`, `:117`, `:139` — pair-release retry
  status. Logs include `error.localizedDescription` (server error message)
  and `state` (which stringifies a `sessionId`). **`sessionId` is a
  server-generated random; not PII per se but does tie a session to a
  user.** This is intentional debugging instrumentation per the inline
  comment.
- `CoreMLFaceEmbedder.swift:52` — model-compile failure message; no user
  data.
- `CaptureCoordinator.swift:357`, `:374` — DEBUG-only, dump filenames.
- `PassportNFCReader.swift:152` — issuing-authority string on chain-check
  failure (e.g. `"ISR"`, country-level, no individual data).
- `HomeView.swift:784` — biometric-gate skip error message.
- `WebHomeView.swift:299`, `:306`, `:310` — sign-in bridge debug.
  `:306` logs `uid` (`"sign-in bridge ok uid=\(dict["uid"] ?? "nil")"`)
  on success — see HIGH finding.

No `NSLog`. No `os_log`. No `Logger`. No `OSLog` subsystem. So everything is
`print` — which goes to stdout (Xcode console) but is also captured by the
unified logging system and visible to anyone with USB+Console.app access in
release builds.

## Findings

### CRITICAL — invariant violation

None. After tracing every sensor capture → hash → submit path, no release-
code branch sends raw biometrics, raw MRZ, raw DG1/DG2 bytes, raw selfie
JPEG, or face embeddings off the device. The shape `anchorCommitment`
posts is `{ payloadHashHex, signatureBase64 }` per artifact; payload bytes
are SHA-256'd and dropped before the network call.

Specifically verified:
- `CaptureCoordinator.swift:459-460` — selfie JPEGs are mapped to per-frame
  SHA-256, concatenated, and the raw `jpegs` are released
  (`capturedJpegs.removeAll()` at `:449` ran before this).
- `PassportNfcProducer.swift:29` — only `passportData.dg1Hash` (already a
  32-byte SHA-256) feeds the artifact builder. DG1 raw bytes never escape
  `PassportNFCReader.readPassport` (`PassportNFCReader.swift:165` is the
  only place they live, and the local goes out of scope on return).
- `PassportNFCReader.swift:179` — same for DG2 raw bytes.
- `AntiSpoofProducer.swift:81-87` — only the canonical decision string
  (accepted / score×10000 / threshold×10000 / frame count / model hash)
  is hashed and submitted; per-frame inference outputs and 80×80 crops
  stay local.
- `FaceMatchProducer.swift:99-110` — same for face match: payload is
  `accepted | distance10000 | reference-hash | selfie-hash | source |
  threshold10000`. The reference image, the selfie JPEG, and both
  embeddings stay local.

### HIGH — likely violation under specific conditions

**HIGH-1.** **`WebHomeView.swift:306`** prints `uid` to the console on the
sign-in-bridge happy path:
```
print("[WebHome] sign-in bridge ok uid=\(dict["uid"] ?? "nil")")
```
`uid` is the Firebase user identifier — it ties this device session to a
specific human across the entire Foundation backend. This goes to the
unified logging system in release builds; anyone with physical USB access
(e.g. customs, lost-phone finder, repair shop) can read it via
Console.app. **Fix:** remove the `uid` interpolation or wrap in
`#if DEBUG`. The success case doesn't need to log anything.

**HIGH-2.** **`AppCheckFactory.swift:12-16`** uses
`AppCheckDebugProvider` on simulator. The debug provider issues a token
the Firebase backend trusts only when its random-generated debug secret
is registered in the Firebase console. Standard practice, but the
SupportSheet (`HomeView.swift:837`, `SupportSheet.swift:276`) advertises
`"simulator (debug provider)"` to the user. If a `submitSupportTicket`
ticket is sent from a simulator run, the server sees `appAttest:
"simulator (debug provider)"` and stores it. The server presumably
filters / weights, but I cannot verify from the iOS code that the
unattested simulator branch is server-rejected — flagging as HIGH because
this depends on the server contract. (Same path applies to a user who
taps "Continue without attestation" at the 10s mark —
`AttestationCoordinator.swift:168`.)

**HIGH-3.** **`PassportNFCReader.swift:152`** prints
`passport.issuingAuthority` (e.g. `"ISR"`) on chain-to-CSCA verification
failure. Country code is borderline: not strictly identifying at the
individual level, but combined with the ticket flow (which stamps device
model + iOS version + timestamp) it narrows to "Israeli passport holder
on iPhone 13 at this minute". The chain-failure path is rarely hit in
practice (only when a CSCA masterlist is bundled and doesn't cover the
chip's CSCA) but the `print` happens for every read of an uncovered
country. **Fix:** drop or `#if DEBUG`-gate.

### MEDIUM — risk to hardening

**MED-1.** **DEBUG dumps to Documents.** `AttestationService.swift:138-184`
and `CaptureCoordinator.swift:344-376` write attestation CBOR + DG2 face
JPEG to `Documents/`. The `#if DEBUG` guard works only as long as Xcode
schemes don't accidentally ship a DEBUG-configured build to TestFlight or
the App Store. Apple's archive flow defaults to `RELEASE`, but a
misconfigured `Build Configuration` on the Archive scheme would silently
ship the dump path. **Suggested hardening:** add a `precondition(false,
…)` or compile-time error on `RELEASE && !DEBUG_DUMP_ENABLED`, or pin
the Archive scheme's build configuration in CI.

**MED-2.** **`BiometricSealPayload.publicKeyB64`** is wired into the
`AnchorCommitmentRequest` schema (`FunctionsService.swift:67-79`) but
never sent today (`CaptureCoordinator.swift:594` always passes `nil`).
The doc-comment says "Sent every call so the server can lazily build a
per-uid public key registry." If/when this is enabled, the Secure-Enclave
public key is per-device and stable across sessions — which is fine for
attestation but means the server can correlate every commitment from the
same device even if the user signs in under a different email. Not a
hard-invariant violation, but a change-management risk: any future
"hashing" claim that skips this fact would be misleading.

**MED-3.** **Verbose error stringification.** Several places interpolate
`String(describing: error)` into UI / logs:
`CaptureCoordinator.swift:191`, `:329`, `:558`, `:603`;
`AttestationCoordinator.swift:150`. Errors from CoreNFC / NFCPassportReader
sometimes embed APDU response bytes. I could not verify whether
`NFCPassportReader.error.localizedDescription` ever contains DG bytes; the
upstream library's error enum (`PassportReaderError`) doesn't appear to,
but a future SDK update could leak bytes through `.readFailed(error)`'s
inner error. **Suggested hardening:** map the inner error to a coarse
enum string before user-facing surfaces / Firestore writes.

**MED-4.** **`SupportSessionTracker` is in-memory only** but
`maxPerSession` is not server-enforced from the iOS code's perspective —
the rate limit is purely client-side. A modified client could spam
`submitSupportTicket`, and the only thing in those tickets that is
sensitive is `latestCommitment` (12-char prefix + 4-char suffix of the
hash; not directly identifying). Low risk but worth surfacing as a
hardening item.

**MED-5.** **`SolanaRPC` is dead code** as far as I can see. It's set up
to call `getAccountInfo` against `api.devnet.solana.com` but nothing
under `ios/FoundationMobile/*.swift` invokes it. Dead code is a
hardening risk: if a future change wires it up incorrectly (e.g. passing
the user's `uid` as a "memo" or similar), it ships without UI review.
**Suggested:** delete or guard with a TODO + test.

### LOW — hygiene

**LOW-1.** `print` in production code — `AuthService.signOut`'s four
release-path prints (`AuthService.swift:108-117`, `:139`) go to the
unified log. They contain `sessionId` and `error.localizedDescription`.
Move to `os_log(.debug)` or wrap in `#if DEBUG`.

**LOW-2.** `WebHomeView.swift:299` and `:310` print bridge errors. Same
hygiene concern as LOW-1.

**LOW-3.** `Info.plist` text mentions "front camera ... only to verify
you're a live human" but `DocumentPhotoView` and `QRScannerView` use the
**back** camera. Apple typically accepts a single camera-usage string,
but the user's mental model doesn't match what the back camera will do
when a user is in the standardsec or pair-desktop flow. Cosmetic; tighten
copy.

**LOW-4.** **Bundle ID in Info.plist comments leaks the team identifier**
indirectly — `FoundationMobile.entitlements` declares the App Attest
environment as `development`. If a release archive ever goes to TestFlight
or App Store with `development` here, App Attest assertions are validated
against the wrong Apple endpoint and the server's CBOR verifier will
reject them — that's a stronger fail-closed posture than I expected,
worth confirming. Not a leak per se; flagging for release-build hygiene.

**LOW-5.** The privacy manifest (`PrivacyInfo.xcprivacy`) declares
`NSPrivacyTracking = false` and `NSPrivacyCollectedDataTypes = []`. That
is consistent with the audit findings: the app collects nothing in
Apple's enumeration. Good.

**LOW-6.** `AttestationService.swift:41` correctly hashes
`SHA-256(utf8(nonce))` matching the documented contract. Verified against
the doc comment and against
`reference_app_attest_challenge.md` in the user's memory: both client and
server hash `Buffer.from(req.nonce)` (UTF-8). The nonce is base64url and is
**not** base64-decoded on iOS — the code uses `Data(nonce.utf8)`
directly, which is correct.

## Hard-invariant verdict

**The current code substantively satisfies the hard invariant in
production paths.** Every sensor producer (`PassportNfcProducer`,
`AntiSpoofProducer`, `FaceMatchProducer`, the inline
liveness-frame-hashing in `CaptureCoordinator.verify`) reduces raw bytes
to a SHA-256 (or a canonical decision string that contains only hashes
and decimal-quantized scores) before any network call. The
`anchorCommitment` payload contains exactly `{ payloadHashHex,
signatureBase64 }` per artifact plus the commitment hash. Selfie JPEGs
and DG1/DG2 raw bytes are dropped from memory immediately after hashing.
No third-party telemetry SDKs are linked. The Keychain holds only an
email (signed-in already PII) and an Apple-issued App Attest key id; no
DG / MRZ data is persisted.

**Two small leaks need fixing before TestFlight:** the `uid` print at
`WebHomeView.swift:306` and the country-code print at
`PassportNFCReader.swift:152`, plus the four signOut release-path prints
that include `sessionId`. The DEBUG-only Documents-directory dumps in
`AttestationService` and `CaptureCoordinator` are correctly gated today
but depend on Xcode scheme discipline; pin the Archive scheme's build
configuration in CI to keep them gated. The `BiometricSealPayload` field
is dormant and benign today but should be revisited for correlation
risk before being turned on.
