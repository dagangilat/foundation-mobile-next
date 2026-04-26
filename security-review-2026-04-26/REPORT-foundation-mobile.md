# Foundation Mobile — Security & Compliance Report (2026-04-26)

**Scope:** iOS app at `/Users/dagan/dev/foundation/foundation-mobile-claude/` (313 Swift files, Podfile, entitlements, Info.plist, PrivacyInfo.xcprivacy).
**Frame:** the hard invariant — *nothing identifying leaves the device; outbound is hashes-only attestation + Solana commitment hash*.
**Method:** five expert agents (privacy-invariant, app-security, cryptography, privacy-compliance, plus the backend-side analysis where it constrains the client). This document re-buckets findings by repo; raw per-domain reports are in the same directory (`01-` … `05-`).

---

## Executive summary

The hard invariant *holds in production code paths* — no agent found a release-build branch that ships raw biometrics, raw MRZ, raw DG1/DG2, raw selfie JPEGs, or face embeddings off-device. Sensor producers reduce raw bytes to SHA-256 (or canonical decision strings) before the network call, and `capturedJpegs.removeAll()` runs immediately after hashing. No third-party telemetry SDKs are linked. The App Attest nonce contract (`SHA-256(utf8(nonce))`) is implemented correctly.

**However, four CRITICAL issues block a real launch:**

1. **Cross-uid replay** flips one user's `humanityVerified` flag using another user's captured anchor payload (`EnclaveSeal.canonicalBytes` does not bind `uid`).
2. **DEBUG-only paths write raw DG2 face JPEG + CBOR attestation to `Documents/`** — one mis-configured archive defeats the entire device-only-processing claim.
3. **Empty `NSPrivacyCollectedDataTypes`** in the Privacy Manifest will get the next App Store submission rejected.
4. **No granular biometric consent screen** before the `Verify humanity` button — fails GDPR Art. 9(2)(a) and BIPA §15(b)(3).

**Fastest single mitigation that closes the most ground:** bind `uid` into `EnclaveSeal.canonicalBytes()` (and the matching server `canonicalSealBytes`). One change closes the cross-uid replay primitive at the cryptographic layer.

---

## CRITICAL

### M-CRIT-1 — Cross-uid commitment replay flips `humanityVerified`
**Files:** `ios/FoundationMobile/EnclaveSeal.swift:21-34`, `ios/FoundationMobile/ProofArtifact.swift:25-28`, `ios/FoundationMobile/CaptureCoordinator.swift:594` (paired server-side fix in `functions/index.js:2645-2738`, `functions/on-chain-tasks.js:410-420`).

**What:** `canonicalBytes()` hashes only artifact contents; the on-chain PDA seed is `[b"commitment", hash]`; nothing in either encoding binds the user. A captured `(commitment, artifacts)` payload from user A, replayed by user B with B's auth token, lands in `identity_commitments/B/commitments/{hash}`, the on-chain attempt hits `OnChainAlreadyAnchored`, the task handler **adopts** the existing PDA, and stamps `users/B.humanityVerified = true` against A's on-chain record. The seal-mismatch check passes deterministically because the bytes hash to the same value regardless of who submits them. Per-artifact App Attest assertions are captured but not server-verified at `anchorCommitment` time, so they don't gate.

**Why it's CRITICAL (not HIGH as the cryptography agent originally rated):** this is a humanity-verification bypass — the entire point of the product. Anyone who can capture one anchor payload (rooted device, debugger, exfil from device backups, MITM with a hostile profile) hands free humanity verification to anyone with a Firebase account.

**Fix:** include `uid` in `canonicalBytes()` on both sides, e.g.
```swift
let line = "\(uid):\(kind.rawValue):\(producedAtMs):\(payloadHashHex):\(signatureBase64)"
```
and mirror in `canonicalSealBytes()` server-side. Reject seals where `producedAtMs < now - 24h` to bound the legitimate-retry window. Alternative: seed the PDA with `[uid_bytes, hash]` (loses global hash uniqueness but eliminates the class of attack).

### M-CRIT-2 — DEBUG dumps put raw DG2 + CBOR attestation in `Documents/`
**Files:** `ios/FoundationMobile/CaptureCoordinator.swift:344-376`, `ios/FoundationMobile/AttestationService.swift:138-184`.

**What:** Both blocks are wrapped in `#if DEBUG` today, but a single mis-configured Archive scheme would silently ship the dump path to TestFlight or App Store. The Documents container is iCloud-backed (when iCloud Drive is on), Xcode-extractable, and visible in Files.app. One bad build breaks the entire "nothing identifying leaves the device" claim.

**Fix:**
1. Replace `#if DEBUG` with `#if DEBUG && FOUNDATION_DEBUG_DUMPS_ENABLED` and only set the latter via the dev scheme's xcconfig.
2. Mark the dump directory `URLResourceValues.isExcludedFromBackup = true`.
3. Add a CI/Xcode Cloud check that fails the archive if `DEBUG` is set on a Release configuration.
4. **Strongly preferred:** delete the dump path entirely. If a developer needs the bytes, an LLDB breakpoint produces them on demand without persistence.

### M-CRIT-3 — `NSPrivacyCollectedDataTypes` is empty
**File:** `ios/FoundationMobile/PrivacyInfo.xcprivacy:34-35`.

**What:** Manifest declares no collected data types. The app collects (server-side after device-side processing) email, Firebase uid, App Attest keyId (device identifier), and ships an enclave-signed assertion derived from biometric data. App Store Review (since iOS 17) rejects manifests provably inconsistent with the linked SDKs.

**Fix:** Populate with `EmailAddress`, `UserID`, `DeviceID`, `SensitiveInfo` (biometric-derived assertion), `OtherDiagnosticData` (support-ticket payload). Linked = true, Tracking = false, Purpose = AppFunctionality. (Full XML in `05-privacy-compliance.md` finding F-8.)

### M-CRIT-4 — No granular biometric consent before `Verify humanity`
**Files:** `ios/FoundationMobile/HomeView.swift:670-693` (verifyHumanityButton), `ios/FoundationMobile/CaptureView.swift` (capture flow), `ios/FoundationMobile/SignInView.swift` (no privacy-policy link).

**What:** Tapping `Verify humanity` triggers Art. 9 biometric processing (selfie, NFC DG2, face embedding, biometric-gated enclave key) without a separate explicit consent screen. Generic ToS acceptance via `recordTosAcceptance` doesn't satisfy GDPR Art. 9(2)(a) (explicit consent for special category data) or BIPA §15(b)(3) (written release for biometric identifiers). The privacy policy is also never linked or displayed in-app.

**Fix:**
1. Insert a full-screen biometric-consent disclosure before the `Verify humanity` button: what's captured, what's processed on-device, what leaves (only hashes), retention, how to revoke, link to full policy.
2. Two distinct accept buttons (or two checkboxes): general ToS, biometric processing. Record both consents separately as `legal_consent/biometric-processing_v1`.
3. Surface "Withdraw biometric consent" in Settings — Art. 7(3) requires withdrawal to be as easy as giving consent.
4. Link the privacy policy on `SignInView` ("By continuing you agree…") and add a Settings tab with Privacy Policy / ToS / Manage my data.
5. **Geo-block Illinois at sign-in until this ships** — BIPA statutory damages are $1,000-$5,000 per violation per scan (`Cothron`).

---

## HIGH

### M-H-1 — Email-link sign-in: `pendingEmail` has no TTL; `onOpenURL` accepts any host
**Files:** `ios/FoundationMobile/AuthService.swift:71-93`, `ios/FoundationMobile/Keychain.swift:18-20`, `ios/FoundationMobile/FoundationMobileApp.swift:13-22`.

**What:** `sendSignInLink` stashes the typed email in Keychain with no expiry; a stale entry sits indefinitely. `onOpenURL` hands every URL to Firebase without a host check (Universal Links + AASA bound the practical exposure, but defense-in-depth is missing). The email link itself has no second factor — anyone who reads the link before the user opens it on the same device is signed in as that user.

**Fix:**
- Stamp `pendingEmailIssuedAtMs` next to `pendingEmail`; reject in `completeSignIn` if older than 30 min.
- Guard `onOpenURL` with `host ∈ {foundation-global.com, solanavote-devnet.firebaseapp.com}`.
- Document the cross-device email-link caveat. For production verifiable identity, plan to pair email-link with biometric or WebAuthn.

### M-H-2 — App Attest entitlement still `development`
**File:** `ios/FoundationMobile/FoundationMobile.entitlements:11`.

**What:** A Release archive submitted with `appattest-environment = development` will validate against Apple's sandbox, and the production CBOR verifier will reject the assertions.

**Fix:** ship a Release entitlements file with `<string>production</string>`, gated via xcconfig. Tracked in CLAUDE.md as next-action 2.

### M-H-3 — Unattested tier reaches mutating callables
**Files:** `ios/FoundationMobile/FunctionsService.swift:225-230`, `ios/FoundationMobile/AttestationCoordinator.swift:168` (skipAttestation).

**What:** The 10-second "Continue without attestation" path drops the tier to `.unattested`, but the client always injects the tier on every callable. Server is the only gatekeeper, and the support-ticket payload explicitly logs `appAttest: "simulator (debug provider)"` in its diagnostic state. If hisec-global ever accepts `.unattested` for mutating callables, App Attest is cosmetic.

**Fix:** belt-and-suspenders — refuse to send `.unattested` tier for mutating callables (`anchorCommitment`, `claimPairingSession`) on hisec-global; let server-side enforcement do the rest.

### M-H-4 — `BiometricSealer` is wired but always sends `nil`
**Files:** `ios/FoundationMobile/CaptureCoordinator.swift:570-595`, `ios/FoundationMobile/BiometricSealer.swift:25-28`.

**What:** `submitAnchor` always passes `biometricSeal: nil`. The Phase 7 "Secure-Enclave-sign + submit" promise from CLAUDE.md and the BiometricSealer doc-comment is currently delivered as "SHA-256 + submit". Face-ID-as-consent property is therefore not cryptographically verifiable. (Compounds with M-CRIT-1 — even if the seal were sent, today's design signs `commitment.hashHex` only, not `uid + hashHex`.)

**Fix:** Either wire the seal — `BiometricSealer.shared.sign(payload: Data(commitment.commitmentHashHex.utf8), prompt: …)` at the submit site — or update the BiometricSealer doc comment + architecture doc to "wired in a future iteration." Once you re-enable, sign over `(uid || serverNonce || commitmentHashHex)` to bind both attacks (cross-uid + replay) at once.

### M-H-5 — WKWebView has no navigation policy + shared `WKWebsiteDataStore.default()`
**Files:** `ios/FoundationMobile/WebHomeView.swift:186-323`.

**What:** The WKWebView at `WebHomeView.swift:238` (Coordinator: WKNavigationDelegate) does not implement `webView(_:decidePolicyFor:decisionHandler:)`. Any link the loaded `foundation-global.com` page navigates to is allowed; the injected `__foundationMobileWebView = true` and `__foundationSignInWithCustomToken` markers re-run on every navigation (`forMainFrameOnly: true`, `injectionTime: .atDocumentStart`). The default data store persists cookies and localStorage across users on the same device after sign-out.

**Fix:**
1. Implement `decidePolicyFor` with a host allowlist `{foundation-global.com, www.foundation-global.com}`; out-of-app links to `UIApplication.shared.open` (Safari).
2. Validate the custom-token shape `^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$` before injecting via `evaluateJavaScript`.
3. Stop logging `error.localizedDescription` from the token-injection JS path (`WebHomeView.swift:298-310`).
4. In `AuthService.signOut`, clear `WKWebsiteDataStore.default()`:
```swift
await WKWebsiteDataStore.default().removeData(
    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
    modifiedSince: .distantPast)
```

### M-H-6 — Release-path log leaks of identifying data
**Files:** `ios/FoundationMobile/WebHomeView.swift:306` (`uid`), `ios/FoundationMobile/PassportNFCReader.swift:152` (issuing-authority country code), `ios/FoundationMobile/AuthService.swift:108-117, :139` (`sessionId`).

**What:** All `print` calls go to the unified logging system in release builds — readable via Console.app with a USB cable. `uid` is the cross-device identity tying this device to the Foundation backend; country-code combined with device-model + iOS-version + timestamp narrows to "Israeli passport holder on iPhone 13 at this minute."

**Fix:** wrap each in `#if DEBUG`, or remove the success-case `print` at `:306` entirely.

---

## MEDIUM

### M-M-1 — No server-issued nonce in `EnclaveSeal`
**File:** `ios/FoundationMobile/EnclaveSeal.swift:21-34`.
The seal hashes only client-controlled content; freshness depends entirely on the server's `producedAtMs` window check, which today doesn't exist (see backend report). Fold a server-issued `commitmentNonce` into canonical bytes; have the server consume it single-use ≤60s. Closes anchor-commitment replay end-to-end, complementing M-CRIT-1.

### M-M-2 — Custom claims read without forced refresh
**File:** `ios/FoundationMobile/AuthService.swift:41-58`.
`apply(user:)` reads `ring`/`role` from the cached ID token. A server-side revoke isn't observed for ~60 min. Force a refresh every ~5 min when ring/role gates load-bearing UI.

### M-M-3 — Keychain ACL allows backup migration of `pendingEmail`
**File:** `ios/FoundationMobile/Keychain.swift:50`.
Change `kSecAttrAccessibleAfterFirstUnlock` → `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. `appAttestKeyId` self-heals; `pendingEmail` should not migrate to a restored device.

### M-M-4 — `SolanaRPC` is dead code
**File:** `ios/FoundationMobile/SolanaRPC.swift`.
No call site under `ios/FoundationMobile/*.swift` invokes it. Delete or guard with a TODO + tests; dead code ships without UI review.

### M-M-5 — DG2 image decompression bomb
**File:** `ios/FoundationMobile/PassportNFCReader.swift:184-189`.
`UIImage(data: Data(dg2Concrete.imageData))` decodes whatever the chip returns. Real DG2 photos are 15-25 KB. Guard `dg2Concrete.imageData.count < 200_000` before decode.

### M-M-6 — Server-controlled Firestore path subscribed without prefix check
**File:** `ios/FoundationMobile/CaptureCoordinator.swift:613`.
`commitmentDocPath` from `anchorCommitment` is fed directly to `db.document(path)`. If the server returns an unexpected path, the client subscribes wherever it points. Guard `commitmentDocPath.hasPrefix("commitments/")`.

### M-M-7 — `BiometricSealer.lookupKey` force-cast
**File:** `ios/FoundationMobile/BiometricSealer.swift:157`.
`result as! SecKey` is correct today by `kSecReturnRef`, but a future refactor that adds `kSecReturnAttributes` would crash. Use `as?` and treat nil as "regenerate."

### M-M-8 — `LAContext.localizedReason` set but never used
**File:** `ios/FoundationMobile/BiometricSealer.swift:96-99`.
The Face ID prompt the user sees is the system default, not the `prompt:` string. Either wire `kSecUseAuthenticationContext: context` in the SecItem query or delete the misleading lines.

### M-M-9 — Pairing-code charset/length not pre-validated client-side
**File:** `ios/FoundationMobile/PairingCoordinator.swift:184-190`.
`extractCode` accepts any string up to whatever the server rejects. Add `code.count <= 64` and alphanumeric-plus-dashes before the network call.

### M-M-10 — Privacy policy never displayed in-flow
**Files:** `ios/FoundationMobile/SignInView.swift`, no Settings view exists.
Add Settings tab with Privacy Policy / ToS / Manage My Data; fetch via `getPrivacyPolicy` callable (already deployed).

### M-M-11 — `UIPasteboard` write without manifest reason
**File:** `ios/FoundationMobile/SupportSheet.swift:182-187`.
`UIPasteboard.general.string = ticketId` triggers iOS 16+ paste toast. Verify Apple's current Privacy Manifest reason rules and add if needed.

### M-M-12 — Children's age gate absent
**File:** `ios/FoundationMobile/SignInView.swift`.
Email-link sign-in has zero age gating. Add a date-of-birth confirmation step at sign-up; if under 16 (or member-state minimum), hard-block.

---

## LOW

| ID | File:line | Issue / fix |
|---|---|---|
| M-L-1 | `ios/Podfile:14` | Pin `NFCPassportReader` to `~> 2.3.0` (currently `~> 2.0`); subscribe to OpenSSL advisory list |
| M-L-2 | `ios/FoundationMobile/AppCheckFactory.swift` | Verify Release archive doesn't ship `AppCheckDebugProvider` symbols (`nm -gU FoundationMobile \| grep -i debugprovider`) |
| M-L-3 | `ios/FoundationMobile/Info.plist` | `NSCameraUsageDescription` mentions "front camera" but back camera is also used (DocumentPhoto, QRScanner) — tighten copy |
| M-L-4 | `ios/FoundationMobile/MockProofProducers.swift:60-70` | Document in CLAUDE.md that mocks emit `signatureBase64: "mock:<tag>"` (non-base64 sentinel) — readers might assume base64-shaped placeholders |
| M-L-5 | `ios/FoundationMobile/AppConfig.swift:115` | `fatalError` on missing profile JSON is intentional fail-loud — keep |
| M-L-6 | GCP console (out-of-repo) | Verify Firebase API-key application + API restrictions for iOS bundle id `com.foundationglobal.mobile` |
| M-L-7 | `ios/FoundationMobile/MoproSmokeBridge.swift:60-69` | When the real circuit replaces `multiplier2`, type-wrap circuit inputs and add `catch_unwind` at FFI boundary |
| M-L-8 | `ios/FoundationMobile/AttestationCoordinator.swift:204-220` | Local nonce-expiry check before consuming nonce — defense in depth (server check is the real gate) |
| M-L-9 | TLS pinning | None today (ATS chains-to-public-CA only). Optional production hardening for Firebase + Apple endpoints |

---

## Verifications worth surfacing (no finding, but worth recording)

- **App Attest nonce contract is correct.** `AttestationService.swift:41` computes `Data(SHA256.hash(data: Data(nonce.utf8)))`; matches the server-side hashing in `@plantagoai/attestation/server` (`Buffer.from(req.nonce)` → SHA-256). No base64-decode on iOS.
- **No third-party telemetry.** Podfile has Firebase Auth, Firestore, Functions, AppCheck, NFCPassportReader, OpenSSL only — no Sentry, Crashlytics, FirebaseAnalytics, Datadog, Mixpanel.
- **Sensor pipelines drop raw bytes after hashing.** `PassportNfcProducer:29` (DG1), `:179` (DG2 raw), `AntiSpoofProducer:81-87` (frames + crops), `FaceMatchProducer:99-110` (embeddings), `CaptureCoordinator:449,459-460` (selfie JPEGs).
- **Secure Enclave key parameters are appropriate.** `BiometricSealer.swift:160-193` uses `kSecAttrTokenIDSecureEnclave`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, ACL `[.privateKeyUsage, .biometryCurrentSet]` — invalidates on biometric re-enrollment, the right flag for the stolen-then-re-enrolled threat model.
- **Permissions are minimum-needed.** No background modes; NFC `iso7816.select-identifiers` scoped to ICAO MRTD AID `A0000002471001`; no App Groups; no push.

---

## Cross-references

- **Server-side counterparts** of M-CRIT-1, M-H-3, M-H-4 live in `REPORT-foundation.md`. The cross-uid replay's *complete* fix needs both: client `canonicalBytes()` includes `uid` AND server `canonicalSealBytes()` mirrors it AND task handler refuses to adopt `OnChainAlreadyAnchored` for a different uid.
- **Manual-review path** (`functions/index.js:1648-1731`) uploads raw front/back/selfie images to Firebase Storage. This is a *backend* path the iOS app can trigger. It contradicts the "nothing leaves the device" public claim. Findings live in `REPORT-foundation.md`; iOS UI should disclose the privacy delta to users who fall back to manual review.
- **Raw per-domain reports** (more depth than this consolidation):
  - `01-ios-privacy-invariant.md` — full network egress + persistence inventory
  - `02-ios-security.md` — 12-area iOS security audit, severity table at the bottom
  - `04-crypto-attestation.md` — App Attest verifier walk, BiometricSealer review, replay walk-throughs
  - `05-privacy-compliance.md` — full GDPR/CCPA/BIPA/COPPA analysis, DPIA gap, Privacy Manifest fix XML

---

## Recommended remediation order

**Pre-TestFlight (ship-blockers):**
1. M-CRIT-2 (DEBUG dump hardening / removal)
2. M-CRIT-3 (Privacy Manifest)
3. M-H-2 (App Attest production entitlement)
4. M-H-6 (release-path log leaks)
5. M-CRIT-4 / M-M-10 (privacy policy linked + biometric consent)

**Pre-public launch:**
6. M-CRIT-1 + backend mirror — bind `uid` into `canonicalBytes()` end-to-end
7. M-H-1 (TTL on `pendingEmail`, `onOpenURL` host check)
8. M-H-4 (wire `BiometricSealer` for real, signing `(uid \|\| serverNonce \|\| hash)`)
9. M-H-3 + backend mirror (refuse unattested tier on mutating callables)
10. M-H-5 (WKWebView nav policy + data-store cleanup on signOut)
11. M-M-1 / M-M-12 / M-M-3 / M-M-5 / M-M-6

**Post-launch (90-day window):**
12. M-M-2 / M-M-7 / M-M-8 / M-M-9 / M-M-11
13. LOW-tier hygiene
