# Foundation — Security & Compliance Review (2026-04-26)

Multi-agent deep audit covering both repos. Five expert agents (privacy invariant, iOS security, backend security, cryptography, regulatory compliance) ran in parallel; this index points to the two consolidated reports — one per repo — and to the raw per-domain reports underneath.

## Consolidated reports (read these)

- **[REPORT-foundation-mobile.md](REPORT-foundation-mobile.md)** — iOS app (`/foundation-mobile-claude/`).
- **[REPORT-foundation.md](REPORT-foundation.md)** — backend (`/foundation-global/`).

A copy of the backend report lives at `/foundation-global/security-review-2026-04-26-backend.md` for that repo's working tree.

## Top-line verdict

| Layer | Verdict |
|---|---|
| Hard invariant — "nothing identifying leaves the device" | **Holds in production code paths.** No release-build branch ships raw biometrics, MRZ, DG1/DG2, selfies, or face embeddings. Sensor pipelines reduce to SHA-256 before egress. No third-party telemetry SDKs. App Attest nonce contract correctly implemented. |
| iOS app | 4 CRITICAL, 6 HIGH, 12 MEDIUM, 9 LOW. Largest issue: `EnclaveSeal.canonicalBytes()` doesn't bind `uid` → cross-uid replay primitive. |
| Backend | 4 CRITICAL, 8 HIGH, 17 MEDIUM, 15 LOW. Largest cluster: stale Phase-0 Firestore rules + several public-no-auth callables/HTTP endpoints + GDPR Art. 17 deletion gaps. |

## Critical findings (cross-repo)

| # | Repo | What | Files |
|---|---|---|---|
| 1 | **both** | **Cross-uid commitment replay flips another user's `humanityVerified` flag** — the central humanity-verification claim is bypassable. Single fix: bind `uid` into `EnclaveSeal.canonicalBytes()` (client) + `canonicalSealBytes()` (server). | `EnclaveSeal.swift:21-34`, `functions/index.js:2645-2738`, `functions/on-chain-tasks.js:410-420` |
| 2 | foundation-mobile | DEBUG-only paths write raw DG2 face JPEG + CBOR attestation to `Documents/`. One mis-configured archive defeats the entire on-device-only claim. | `CaptureCoordinator.swift:344-376`, `AttestationService.swift:138-184` |
| 3 | foundation-mobile | `NSPrivacyCollectedDataTypes` empty — App Store will reject the next submission. | `PrivacyInfo.xcprivacy:34-35` |
| 4 | foundation-mobile | No granular biometric consent before `Verify humanity` — fails GDPR Art. 9(2)(a) + BIPA §15(b)(3). | `HomeView.swift:670-693`, `CaptureView.swift`, `SignInView.swift` |
| 5 | foundation | `sendNotification` has no `requireAuth` — phishing/spam channel against any user. | `functions/index.js:1769` |
| 6 | foundation | `evaluateProposal` has no `requireAuth` — burns LLM tokens at attacker speed. | `functions/index.js:696` |
| 7 | foundation | GDPR Art. 17 deletion misses `identity_commitments/{uid}/...`, `mobile_credentials/{uid}`, several uid-keyed collections; on-chain re-identification persists. Privacy policy says 30-day deletion; code enforces 90-day grace. | `functions/account-deletion.js:26-51, :110` |

## Single highest-leverage fix

Bind `uid` into the canonical bytes hashed by `EnclaveSeal`. One change closes the humanity-verification bypass at the cryptographic layer.

```swift
// ProofArtifact.swift:25-28
let line = "\(uid):\(kind.rawValue):\(producedAtMs):\(payloadHashHex):\(signatureBase64)"
```
mirrored in the server's `canonicalSealBytes` in `functions/index.js`.

## Raw per-domain reports

- [01-ios-privacy-invariant.md](01-ios-privacy-invariant.md) — full network egress + persistence inventory; verdict: invariant holds in production.
- [02-ios-security.md](02-ios-security.md) — 12-area iOS security audit (auth, App Attest, Keychain, Secure Enclave, WebKit, deeplinks, TLS, QR, permissions, DoS, secrets, dependencies).
- [03-backend.md](03-backend.md) — Firestore rules per-collection table, Storage rules, 50+ callable matrix, privilege-escalation paths, App Check enforcement state, Solana commitment integrity, Art. 17 audit, demo isolation, DoS surface.
- [04-crypto-attestation.md](04-crypto-attestation.md) — App Attest verifier walk, EnclaveSeal/BiometricSealer review, MOPRO smoke, ProofArtifact contract verification, replay walk-throughs.
- [05-privacy-compliance.md](05-privacy-compliance.md) — GDPR/CCPA/BIPA/COPPA/Apple Privacy Manifest analysis, on-chain immutability vs right-to-erasure, DPIA gap, recommendations roadmap.

## Recommended remediation order

**Pre-TestFlight ship-blockers:** finding 2, 3, the iOS App Attest production entitlement, release-path log leaks (`uid`/country-code prints), finding 4 + privacy-policy linking.

**Pre-public launch:** findings 1, 5, 6, 7; lock the stale Phase-0 Firestore rules; rate-limit the public-no-auth HTTP endpoints; refuse unattested tier on mutating callables; ring-elevation guard in `setUserAccess`; reconcile privacy-policy logging contradiction.

**Pre-EU launch:** DPIA, DPO designation, manual-review path tightening (Art. 9 consent, lifecycle, CMEK, drop SVG), wire per-artifact App Attest verification at `anchorCommitment`.

**Pre-mainnet:** `getMyWallet` rate-limit and deferred wallet creation.

Detailed ordered remediation lists at the bottom of each consolidated report.
