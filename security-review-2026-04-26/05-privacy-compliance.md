# Privacy & Compliance Audit — 2026-04-26

Auditor: senior privacy / data-protection compliance review against Foundation
mobile (iOS) + foundation-global (Firebase backend).

Scope target: pre-TestFlight / pre-EU launch posture. Findings calibrated to
"would a regulator (EDPB, ICO, CPPA, AG-IL) find this defensible," not just
"would the App Store accept it."

---

## Scope (regulations covered)

- **GDPR / UK GDPR** — Arts. 4, 5, 6, 7, 9, 12-22, 25, 30, 32, 35, 44.
- **CCPA / CPRA** — §§1798.100-1798.150 (notice at collection, right to know,
  right to delete, sensitive personal information).
- **BIPA (740 ILCS 14)** — written consent, retention schedule, destruction
  within 3 yrs, prohibition on profiting from biometric identifiers.
- **COPPA (16 CFR 312)** — under-13 age gate, verifiable parental consent.
- **Apple Privacy Manifest (PrivacyInfo.xcprivacy)** + ATT (App Tracking
  Transparency).
- **eIDAS / ICAO 9303** sensitivity (passport DG1/DG2, biometric template).

Out of scope (flagged but not analyzed): Brazilian LGPD, Indian DPDP Act,
Quebec Law 25, NYC Local Law 3 (employment), Texas CUBI, Washington My Health
My Data Act — Foundation will inherit risk in each as it expands.

---

## Data classification table

Source of truth for "where it lives": `ios/FoundationMobile/*.swift` for
device-side; `functions/index.js`, `functions/account-deletion.js`, and
`firestore.rules` for server-side.

| # | Datum | GDPR class | BIPA-relevant? | Where it lives | Retention | Legal basis (claimed) |
|---|---|---|---|---|---|---|
| D1 | Email address | Personal data (Art. 4(1)) | No | Firebase Auth; mirrored to `users/{uid}` & `invites/{email}`; Resend.com (transactional email) | While account active; 30d after deletion (per privacy policy); Resend logs ~30d | Contract + legitimate interest (Art. 6(1)(b)/(f)) |
| D2 | Firebase `uid` | Pseudonymous personal data | No | Firebase Auth; embedded in `users/{uid}`, `votes`, `voters`, `manual_review_requests`, `pairing_sessions`, `identity_commitments/{uid}/...` | Linked to D1; deleted/anonymized by `account-deletion.js` foundationDataMap | Contract |
| D3 | Ring tier (custom claim + `users/{uid}.ring`) | Personal data | No | Firebase Auth custom claims + Firestore `users/{uid}` | Account lifetime | Legitimate interest |
| D4 | App Attest `keyId` (32-byte random) | Personal data (device-bound identifier) | No | iOS Keychain (`Keychain.swift`); server stores attestation record in `mobile_credentials/{uid}` | Account lifetime | Legitimate interest (anti-fraud) |
| D5 | App Attest CBOR attestation blob | Personal data (device-attestation) | No | Server-side `mobile_credentials/{uid}` (via `@plantagoai/attestation`) | Account lifetime | Legitimate interest (Art. 6(1)(f)) |
| D6 | Per-artifact App Attest assertion (`signatureBase64` in `ProofArtifact`) | Personal data (device-bound) | No | `identity_commitments/{uid}/commitments/{hashHex}.artifacts[*].signatureBase64` | Indefinite | Legitimate interest |
| D7 | Selfie JPEG frames (3-5, ~50KB each) | **Special category — Art. 9 biometric** | **YES** — face geometry processed | iOS RAM only (`CaptureCoordinator.capturedJpegs`); dropped after seal | Drop within ~30s of capture | "Hash of hash never leaves device" — but **see F-3** |
| D8 | DG1 (MRZ raw bytes) | Personal data (passport number, DoB, expiry, sex, nationality, name) | No | iOS RAM only (`PassportNFCReader`); used to compute SHA-256 then dropped | Drop within ~5s | Consent (implicit) |
| D9 | DG2 raw bytes (JPEG2000 face from ePassport chip) | **Special category — Art. 9 biometric** | **YES** | iOS RAM only; SHA-256 then dropped | Drop within ~5s | Consent (implicit) — but **see F-3** |
| D10 | DG2 face `UIImage` (decoded for face match) | **Special category — Art. 9 biometric** | **YES** | iOS RAM during `verify()`; **DEBUG build also writes JPEG to app Documents** (see F-1) | Verify session in release; **persistent in DEBUG** | Consent (implicit) |
| D11 | Document-photo capture (back-camera face crop) | **Special category — Art. 9 biometric** | **YES** | iOS RAM (`DocumentPhotoCapture.faceCropJpeg`) | Drop after seal | Consent (implicit) |
| D12 | Face embedding (Core ML, 128/512-D float vector) | **Special category — Art. 9 biometric** (per EDPB guidance — embeddings are biometric data) | **YES** | iOS RAM during face-match producer | Drop after seal | Consent (implicit) |
| D13 | Liveness pose telemetry (yaw/pitch radians) | Personal data (behavioral biometric) | Arguably yes | iOS RAM | Drop after capture | Consent (implicit) |
| D14 | Solana commitment hash (32-byte hex) | Pseudonymous personal data (GDPR Recital 26) | No | Firestore `identity_commitments/{uid}/commitments/{hashHex}` + Solana devnet/mainnet program account | **Indefinite on-chain** (irreversible) | Legitimate interest — **see F-2** |
| D15 | Server-side per-user Solana keypair | Personal data (identifier) | No | Firestore `user_wallets/{uid}` (KMS-encrypted) | Account lifetime | Contract |
| D16 | Biometric seal public key + ECDSA signature | Personal data (device-bound) | Arguable — derived from a biometric-gated key | `users/{uid}.biometricPublicKeyB64`; per-commitment `biometricSeal` sidecar | Account lifetime | Legitimate interest |
| D17 | IP address (during sign-in / callable invocation) | Personal data | No | Cloud Functions logs (Cloud Logging, default 30d); `requestSelfAccess` hashes the IP into a rate-limit counter | 30d (Cloud Logging default) — see F-7 | Legitimate interest |
| D18 | ToS / privacy consent record | Personal data | No | `users/{uid}/legal_consent/{documentType}_{version}` | Account lifetime; `legalConsents` map mode = `retain` (deliberately not deleted) | Legal obligation (Art. 7(1) — must be able to demonstrate consent) |
| D19 | Manual-review submitted images (front/back/selfie of ID) | **Special category** — biometric + government ID | **YES** | Firebase Storage `manual-review/{uid}/{requestId}/{file}.jpg` | Until ticket resolved or account deletion (server-side cleanup is wired); **5MB cap; admin-readable** | Consent — **see F-9** |
| D20 | Support ticket diagnostics | Pseudonymous (no identifiers per `SupportSheet.swift`) | No | Firestore `/support/{ticketId}` | Indefinite (no TTL set) | Legitimate interest |
| D21 | Pairing session (desktopUid, mobileUid, sessionId) | Personal data | No | `pairing_sessions/{sessionId}` | Lifetime of pairing + grace window | Contract |
| D22 | Identity proof artifacts (Self/Semaphore PoH path) | Personal data + nullifier (linkability) | Indirect | `identity_proofs/{nullifier}` | Account lifetime; deleted on Art. 17 (per foundationDataMap) | Consent |

Notes:

- The `dataNotCollected` array in `functions/legal.js:51-55` lists `name`,
  `date_of_birth`, `biometric_raw_data`. The first two are technically true at
  rest but **transit through device RAM** (DG1 contains them). Whether that
  counts as "collected" under GDPR Art. 4(2) is contested — see Finding F-3.
- The privacy policy at `docs/legal/privacy-foundation-mobile.md` is well
  written for the device-only-processing claim; the app does **not** link to
  it. See Finding F-4.

---

## Per-regulation findings

### GDPR (EU + UK + Ireland — claimed jurisdiction is `Ireland` in
`functions/legal.js:43`)

**Article 5 — principles:**
- ✅ **Lawfulness/fairness/transparency:** privacy policy exists; ToS records
  consent versioned. **Gap:** the app never displays the privacy policy or
  links to it before any data is captured. The user clicks `Verify humanity`
  without ever seeing the privacy notice in-app. NSCameraUsageDescription /
  NFCReaderUsageDescription strings are the only in-flow disclosures and they
  are too short to satisfy Art. 13.
- ⚠️ **Purpose limitation:** the disclosed purpose is "verify humanity." But
  `mobile_credentials` and `identity_commitments` are also retained for
  replay-defense, audit, and ring-tier gating. Multiple purposes; not all of
  them are clearly disclosed to the user.
- ⚠️ **Data minimization:** see F-3 below — the device does process raw DG2
  + selfie + face embedding even though only hashes leave. EDPB has been
  consistent that "processing on-device" is still processing; the controller
  must justify the necessity.
- ⚠️ **Storage limitation:** `users/{uid}/legal_consent/*` is explicitly mode
  `retain` (`legalConsents` in `account-deletion.js:50`). This is correct for
  Art. 7(1) (must demonstrate consent) but should be time-boxed (e.g. 6 yrs to
  match contractual statute of limitations in IE/UK).
- ⚠️ **Accuracy:** no rectification flow for ring tier disputes. If a user is
  flagged in `abuse_registry` they have no in-app appeal surface.
- ⚠️ **Integrity/confidentiality:** acceptable — App Attest, biometric seal,
  Firebase TLS, KMS-encrypted Solana keypair.
- ⚠️ **Accountability:** no DPIA artifact. Foundation processes Art. 9
  biometric data → DPIA is **mandatory** under Art. 35(3)(b). See F-8.

**Article 6 lawful basis:**
- The privacy policy implies consent for biometric processing but never
  explicitly captures it. Tapping `Verify humanity` is positioned as a
  product action, not a consent moment. Under Art. 7, consent must be
  "freely given, specific, informed, unambiguous." A button labeled `Verify
  humanity` is **specific** and **unambiguous** for a verification purpose
  but it is **not informed** unless paired with the privacy notice text. See
  F-4.

**Article 9 — special category (biometric):**
- Foundation **does** process biometric data within the meaning of Art. 4(14)
  even though raw bytes never leave the device. Recital 51 + EDPB Guidelines
  3/2019 are clear: face-match embeddings, liveness pose data, and DG2 face
  images are all biometric data when used to identify a natural person.
- Legal basis under Art. 9(2)(a) (explicit consent) is the only viable
  pathway for Foundation. (9)(g) "substantial public interest" requires Member
  State law authorization which Foundation does not have.
- **Gap:** explicit consent under Art. 9 must be **separate** from generic
  ToS/Privacy consent. Foundation's `recordTosAcceptance` records a single
  blob hash; there is no granular "I consent to processing my biometric data
  on this device for humanity verification" toggle. See Finding F-5.

**Articles 13/14 — information at collection:**
- Privacy policy covers most points. Missing or weak:
  - Identity of the controller (says "Foundation / PlantagoAI Ltd" — address
    is `*[to be filled in]*` at line 82). **CRITICAL** for an EU-launched app.
  - DPO contact — none designated. Required if Art. 9 processing is core
    activity (Art. 37(1)(c)). Foundation's core activity is biometric
    identity verification → **DPO is mandatory**. See F-6.
  - Recipient categories — Apple, Google, Solana RPC nodes are listed but
    not named (e.g. which RPC node provider, where).
  - Cross-border transfer mechanism — privacy policy says Firebase region
    `us-east1` but does not cite a transfer mechanism (SCCs, adequacy, DPF).
    Google's CDPA covers this; should be referenced.
  - Retention periods are stated for some data classes, not all. D20, D21,
    D5, D6 are unbounded.
  - Right to lodge a complaint with a supervisory authority — missing
    entirely.
  - Existence of automated decision-making — humanity verification IS
    automated decision-making with legal/significant effects (gates platform
    access, ring tier). Art. 22(1) prohibits this absent (a) contract
    necessity, (b) Member State law, or (c) explicit consent. Foundation's
    posture should default to (c) and the user should be told they can
    request human review (the `manual_review_requests` flow exists; should
    be surfaced).

**Article 17 — right to erasure:**
- See dedicated section below.

**Article 22 — automated decision making:**
- Verification outcome (humanity verified yes/no, ring tier) is fully
  automated. **F-10 below.**

**Article 25 — Privacy by design:**
- The "nothing identifying leaves the device" architecture is genuinely
  privacy-by-design and **stronger than anything Persona / Onfido / Veriff
  ship.** This is the single biggest defensible thing in the audit and
  should be foregrounded in any DPIA + regulator engagement.

**Articles 44-49 — international transfers:**
- Firebase Auth, Firestore, Functions, Storage all execute in
  `us-east1` (per `functions/legal.js`, `firebase.json`, every callable's
  region). EU data → US transfer.
- Apple App Attest verification: server-side via `@plantagoai/attestation`
  reaches Apple's CRL endpoint. EU → US.
- Solana RPC: `https://api.devnet.solana.com` (per CSP allowlist in
  `firebase.json`). Run by Solana Labs in the US. Mainnet RPC TBD.
- **No SCCs or DPA referenced in privacy policy.** Google's standard CDPA +
  SCCs apply automatically when you accept the Firebase ToS but the privacy
  policy must still cite the mechanism for Art. 13(1)(f). See F-11.

### CCPA / CPRA (California)

- "Do Not Sell or Share My Personal Information" link — **not present**.
  Required even when you don't sell, to assert that fact.
- Notice at collection (CCPA §1798.100(b)) — same gap as GDPR Art. 13;
  in-app linkage to privacy policy missing.
- **Sensitive Personal Information** (CPRA §1798.140(ae)) explicitly includes
  biometric information for identification. Right to limit use of SPI is
  triggered; "Limit Use of My Sensitive Personal Information" link required.
- Children under 16 — opt-in to sale (none here, but the affirmative-consent
  posture should be documented).
- Consumer rights mechanism: privacy policy says "email us"; CCPA requires
  at least two methods (toll-free phone, web form, email). One method only.

### BIPA (Illinois)

BIPA's threshold question for Foundation: **is the entity "in possession of"
biometric identifiers?** (740 ILCS 14/15(a))

- The Rosenbach v. Six Flags + Cothron line of cases establishes that
  collecting (capturing on the device the entity controls) counts as
  "possession" even if no server-side copy exists. The relevant question for
  Foundation is whether the on-device processing is by Foundation (the
  controller) or by the user. Because Foundation's binary collects, processes,
  and biometrically gates a Secure Enclave key on biometric data, **Foundation
  is the controller**, and BIPA likely applies if any user is in Illinois.
- BIPA §15(b) requires:
  1. Written notice that biometric data is collected/stored — **provided in
     privacy policy, not in-app at collection.** Gap.
  2. Written notice of purpose and length of term — purpose yes, term no.
  3. **Written release** signed by the subject. Tap-through of `Verify
     humanity` arguably qualifies post-Rogers but a separate, granular
     biometric consent screen is the only way to be safe.
- BIPA §15(a) requires a **publicly available retention schedule** with
  destruction within 3 yrs of last interaction or when the purpose has been
  satisfied. Privacy policy does not contain this schedule. Gap.
- BIPA §15(c) prohibits **profiting from biometric identifiers**. Foundation
  doesn't sell biometrics — but the ring tier + governance access could be
  argued as "value derived from biometric verification." Defensible but
  document the analysis.
- BIPA statutory damages: $1,000/$5,000 per violation, per person, per
  scan. **Cothron held each scan is a separate violation.** A multi-pose
  liveness capture is multiple scans. Existential risk if Illinois users
  onboard without proper consent.
- **Mitigation: geo-block Illinois at the email-link sign-in callable until
  in-app BIPA consent is wired.** Cheap; do this before any public launch.

### COPPA (Children's Online Privacy Protection Act)

- App Store age rating not visible in this audit, but no in-app age gate
  exists.
- Email-link sign-in does not enforce age. A 12-year-old with an email and
  an invite can complete the flow.
- COPPA applies to operators of "commercial websites or online services
  directed to children under 13" OR who have actual knowledge of collecting
  from under-13s. Foundation is positioned as a governance / civic platform
  → not "directed to children" — but BIPA-like proactive defense is wise.
- **Recommendation:** add a date-of-birth confirmation step at sign-up, and
  if `age < 13`, hard-block. Privacy policy already says "not directed at
  under 13" — operationalize it.
- DG1 contains DoB. The app could derive an age check at NFC time without
  storing the DoB. (This intersects with the known DG1-expiry gap;
  see `project_passport_expiry_gap.md` in user memory.)

### Apple Privacy Manifest / ATT

`ios/FoundationMobile/PrivacyInfo.xcprivacy` review (lines 1-39):

- ✅ `NSPrivacyTracking = false` — correct, no IDFA / cross-app tracking.
- ✅ FileTimestamp (C617.1), UserDefaults (CA92.1, 1C8F.1, C56D.1),
  SystemBootTime (35F9.1) declared — these are the typical reasons used by
  the Firebase pods.
- ❌ **`NSPrivacyCollectedDataTypes` is empty** (line 35: `<array/>`). This
  is the App Store Connect Privacy Nutrition Label backing data. The app
  collects (at minimum, server-side):
  - Email address (`NSPrivacyCollectedDataTypeEmailAddress`)
  - User ID (`NSPrivacyCollectedDataTypeUserID`) — the Firebase uid
  - Device ID (`NSPrivacyCollectedDataTypeDeviceID`) — App Attest keyId is
    arguably a device identifier
  - Sensitive Info (`NSPrivacyCollectedDataTypeSensitiveInfo`) — biometric
    data, even though processed on-device, must be declared if any
    derivative leaves the device. The signed assertion is a derivative.
  - Crash Data / Performance Data — none today (no Crashlytics linked,
    confirmed: Podfile.lock has no Firebase/Crashlytics).
  - Diagnostic data — `submitSupportTicket` payload is technically
    diagnostic data; declare under Other Diagnostic Data.

  **App Store Review will reject the next submission with the manifest in
  this state.** F-12.
- ❌ Disk Space (`NSPrivacyAccessedAPICategoryDiskSpace`) — Firebase
  Firestore uses `NSFileManager.fileSystemRepresentation` and disk space
  APIs internally. Should be declared. (Apple has been increasingly strict
  here since iOS 17.)
- ⚠️ ATT not requested → fine because the app doesn't track. But if
  `FirebaseAnalytics` is ever added, ATT prompt becomes mandatory and the
  manifest must flip `NSPrivacyTracking = true` + add tracking domains.
- ✅ No analytics SDK linked (Podfile.lock confirmed: only Firebase Auth,
  Firestore, Functions, AppCheck, NFCPassportReader, OpenSSL).

### App Tracking Transparency

- IDFA is not requested anywhere in the codebase (verified by absence of
  `ATTrackingManager`). Posture is correct.

### Children's data (additional COPPA notes)

- Privacy policy section "Children's privacy" (lines 64-66) says "Foundation
  is not directed at users under 13" — boilerplate; survives COPPA's narrow
  test only because the app is genuinely civic-tech.

### Biometric-specific compliance summary

Even with the strong on-device-only architecture, Foundation should treat
itself as a biometric data controller and meet the stricter regime:

- **GDPR Art. 9** explicit consent (separate from generic ToS).
- **BIPA** §15(a)/(b) written notice + retention schedule.
- **CCPA SPI** opt-in framing.
- **DPIA** under Art. 35(3)(b).

The hash-of-hash-only architecture **mitigates breach risk to zero** for raw
biometrics — that is genuinely defensible — but it does **not** exempt
Foundation from the consent and notice obligations.

---

## Account-deletion completeness (Art. 17 / CCPA right-to-delete)

`functions/account-deletion.js` audited end-to-end. Map:

| Asset | Deleted? | Path | Notes |
|---|---|---|---|
| Firebase Auth user | ✅ | `deleteAccount(uid, ...)` (via `@plantagoai/auth`) | Standard |
| `users/{uid}` doc | Indirect (via map's notifications/etc.) | foundationDataMap | Need to verify the underlying `@plantagoai/auth` impl — if it doesn't delete the user doc itself the auth user is orphaned from its mirror |
| `voters/{uid}` | ✅ delete | foundationDataMap line 28 | |
| `votes` (where voter_uid==uid) | ✅ anonymize | line 30-34 | Correct — vote history must persist for tally integrity |
| `supporter_signatures` | ✅ anonymize | line 36-40 | |
| `identity_proofs` (where voter_id==uid) | ✅ delete | line 41 | |
| `manual_review_requests` (where voterId==uid) | ✅ delete | line 46 | |
| `voting_rounds` | retain | line 47 | Non-personal aggregate — fine |
| `notifications` (where userId==uid) | ✅ delete | line 49 | |
| `legal_consents` | retain | line 50 | Correct (Art. 7(1)) |
| Storage `manual-review/{uid}/` | ✅ delete | `deleteUserStorage(uid)` line 56-65 | Best-effort, swallows errors — risk of residual blobs |
| Solana per-user keypair | ✅ delete | `deleteUserWallet(uid)` line 80 | KMS-encrypted secret bytes purged from `user_wallets/{uid}` |
| Custom claims (admin/ring/tier) | Implicit via Auth user delete | | If `@plantagoai/auth.deleteAccount` calls `admin.auth().deleteUser(uid)` claims go with it |
| `identity_commitments/{uid}/commitments/*` | ❌ **NOT DELETED** | Not in foundationDataMap | **CRITICAL gap — F-13** |
| `mobile_credentials/{uid}` (App Attest record) | ❌ **NOT DELETED** | Not in foundationDataMap | **HIGH — F-14** |
| `pairing_sessions` (desktopUid==uid OR mobileUid==uid) | ❌ NOT DELETED | Not in map | Medium — sessions self-stale but the doc lingers |
| `flow_snapshots/*_{uid}` | ❌ NOT DELETED | Not in map | Low — XState snapshots, but contains the user's instance state |
| `abuse_registry/{voterId}` | ❌ NOT DELETED | Not in map | Arguable — moderation data has retention rationale; document it |
| `tenant_memberships` | ❌ NOT DELETED | Not in map | Medium |
| `support/{ticketId}` (uid only in body) | Anonymize? | Not in map | Tickets contain no PII per `SupportSheet` design but uid is in `support_usage`/`uid` keying — F-15 |
| `support_usage/{uid}` | ❌ NOT DELETED | Not in map | Low — doc keyed by uid |
| `access_request_rate/{sha256(email)}` | ❌ NOT DELETED | Not in map | Low — keyed by hash, but with TTL |
| `invites/{email}` | Indirect via auth notifications config | foundationDataMap line 49 says notifications keyed `userId`; `invites` doc id IS the email; needs verification | Medium |
| Solana on-chain commitment | **CANNOT BE DELETED** (immutable ledger) | by design | See on-chain section below |
| Cloud Functions logs | ❌ NOT DELETED | Cloud Logging default 30d retention | Residual — disclose in privacy policy (currently silent) |
| Firebase Auth logs | ❌ NOT DELETED | Google retention | Residual — disclose |
| Resend (email) logs | ❌ NOT DELETED | Resend retention ~30d, not configurable on free tier | Residual — disclose |

**Privacy policy claim "we delete within 30 days of request"** —
`requestAccountDeletion` callable enforces a **90-day grace period** (line
110 of `account-deletion.js`). This is a contradiction: privacy policy says
30 days, code says 90. F-16.

`exportMyData` callable (line 95-102) exists — good for Art. 15 right of
access. **Not exposed in the iOS app UI.** Need a Settings screen with
"Export my data" + "Delete my account" buttons. F-17.

---

## On-chain immutability vs. right-to-erasure analysis

The Solana commitment hash is irreversible by design. The question is
whether it's personal data, and if so how to satisfy Art. 17.

**Is the on-chain hash personal data?**

- Standing alone: a 32-byte hash on a public ledger is not directly
  identifiable. EU regulators have been inconsistent on hash-as-personal-data
  but the safer assumption is **yes, it's pseudonymous personal data** under
  Recital 26 because Foundation holds the server-side mapping
  (`identity_commitments/{uid}/commitments/{hashHex}`) that re-identifies it.
- French CNIL's 2018 blockchain guidance: hashes on-chain ARE personal data
  if the controller (or anyone with reasonable means) can re-identify.
- EDPB has not issued a definitive blockchain guideline; CNIL's stance is
  the most authoritative.

**Implication:** when a user requests erasure, Foundation must delete the
*server-side mapping* that links the hash to the uid — i.e. the
`identity_commitments/{uid}/commitments/{hashHex}` Firestore docs. Once
that's gone the on-chain hash is no longer reasonably re-identifiable by
Foundation, and the data subject's right is satisfied as far as
Foundation's accountability extends.

**This deletion is not currently happening.** F-13 above. CRITICAL.

**Disclosure requirement:** the privacy policy and ToS both state the
on-chain commitment is irreversible (good). They should add: "After your
deletion request, the on-chain hash remains but Foundation no longer holds
any data that can re-identify you from it." — to make the erasure
satisfaction explicit.

**Architectural option for the future:** publish a *one-way*-derived
identity commitment that bakes a deletion-revocation token into the hash
input, so that future regulators / verifiers can't re-derive the link even
if Foundation's database is compelled. This is a major design change;
flag it for post-launch.

---

## Severity-ordered findings

Each finding gets: severity, brief, affected file/line, concrete fix.

### CRITICAL

#### F-1 — Debug build writes DG2 face image + passport metadata to Documents directory
**File:** `ios/FoundationMobile/CaptureCoordinator.swift:344-376` and
`ios/FoundationMobile/AttestationService.swift:138-184`
**Risk:** A `#if DEBUG` guard is the only thing keeping raw passport face
photos and CBOR attestation blobs out of the persistent Documents container.
Any developer running a TestFlight or App Store-uploaded build with the
`DEBUG` flag accidentally set will exfiltrate raw biometrics to the device's
Files app. App backups, iCloud Drive sync of Documents (if enabled), and Xcode
device-container downloads all then leak the data. The hard-invariant comment
acknowledges this risk explicitly but a single misconfigured build setting
defeats the whole architecture.
**Fix:**
1. Replace `#if DEBUG` with a runtime check that BOTH `DEBUG` is set AND
   `Bundle.main.isDevBuild` (an env-supplied flag set only by the dev
   scheme). Ship-time builds should be impossible to flip into debug-dump
   mode.
2. Mark the Documents subdirectory used for these dumps with
   `URLResourceValues.isExcludedFromBackup = true` so even local dumps don't
   land in iCloud/iTunes backups.
3. Add a CI/Xcode Cloud check that fails the archive if `DEBUG` flag is set.
4. Strongly preferred: remove the debug-dump path entirely. If devs need a
   DG2 image for testing they should reproduce it from an LLDB breakpoint,
   not a persistent file.

#### F-2 — On-chain commitment is GDPR personal data and Foundation has no documented erasure-of-mapping path
**File:** `functions/account-deletion.js:26-51`,
`functions/index.js:2666-2738`, `firestore.rules:317-330`
**Risk:** The `foundationDataMap` does not list `identity_commitments` for
deletion or anonymization. Cothron-style multi-collection queries by uid
will keep finding the data. A regulator-compelled re-identification
(subpoena to Foundation's DB) re-links the on-chain hash to the data
subject. Erasure obligation under Art. 17 is unfulfilled.
**Fix:**
1. Add `{ name: "identity_commitments/{uid}/commitments", userField: "uid",
   mode: "delete" }` to the foundationDataMap. Or, since the path is
   nested, add an explicit deletion in `deleteMyAccount` before
   `deleteAccount` runs:
   ```js
   const commitmentsCol = admin.firestore()
     .collection("identity_commitments").doc(auth.uid)
     .collection("commitments");
   const snap = await commitmentsCol.get();
   await Promise.all(snap.docs.map(d => d.ref.delete()));
   await admin.firestore().collection("identity_commitments")
     .doc(auth.uid).delete();
   ```
2. Update privacy policy to disclose that the on-chain hash persists but
   the server-side mapping is destroyed on erasure request.

#### F-3 — Biometric processing (Art. 9 / BIPA) lacks explicit, granular, in-app consent
**File:** `ios/FoundationMobile/CaptureView.swift` (entire flow);
`ios/FoundationMobile/HomeView.swift:670-693` (verifyHumanityButton);
`functions/legal.js`
**Risk:** Tapping `Verify humanity` triggers selfie capture, NFC DG2 read,
face embedding, and biometric-gated Secure Enclave key creation — all Art. 9
biometric processing — without a separate, granular consent screen. ToS
acceptance (`recordTosAcceptance`) is generic; it doesn't satisfy GDPR
Art. 9(2)(a) explicit-consent requirement nor BIPA §15(b)(3) written
release.
**Fix:**
1. Insert a full-screen consent disclosure before the `Verify humanity`
   button can be tapped. Bullet list of: what's captured, what's processed
   on-device, what leaves (only the hashes), how long it's retained, how to
   request erasure, link to full privacy policy.
2. Two checkboxes (or two distinct accept buttons) — one for general ToS
   and one for **biometric data processing**. Record both consents
   separately (`legal_consent/biometric-processing_v1` doc).
3. Surface a "Withdraw consent" button in Settings; revocation must be as
   easy as giving consent (Art. 7(3)).

### HIGH

#### F-4 — App never displays privacy policy in-flow
**File:** No file — privacy policy at
`/Users/dagan/dev/foundation/foundation-global/docs/legal/privacy-foundation-mobile.md`
exists but is not linked from any iOS view.
**Risk:** Art. 12-13 require information at the time of collection. CCPA
§1798.100(b) requires notice at collection. Apple App Store review since
Apr 2024 requires a privacy policy URL accessible from within the app.
**Fix:**
1. Add a Settings tab to the iOS app with "Privacy Policy", "Terms of
   Service", "Manage my data" rows.
2. Privacy Policy view fetches from `getPrivacyPolicy` callable (already
   exists in `functions/legal.js:128-134`).
3. Link to the privacy policy on the `SignInView` ("By signing in you
   agree…") and on the consent screen from F-3.

#### F-5 — No DPIA / Records of Processing Activities artifact
**File:** Repo-wide; expected at
`/Users/dagan/dev/foundation/foundation-global/docs/legal/dpia.md` —
absent.
**Risk:** GDPR Art. 35(3)(b) makes DPIA mandatory for "processing on a
large scale of special categories of data." Any pre-launch regulator audit
or due-diligence question (investor, partner) hits this gap immediately.
**Fix:** write a DPIA. Structure: data flows diagram, lawful basis
analysis, necessity/proportionality, risks identified, mitigations applied,
residual risk, DPO sign-off (see F-6).

#### F-6 — No Data Protection Officer designated
**File:** `functions/legal.js:43-46`. Privacy policy lists `privacy@plantagoai.com`
contact only.
**Risk:** Art. 37(1)(c) makes DPO designation mandatory when core
activities consist of large-scale processing of special category data —
which is exactly what Foundation does. Even if Foundation argues current
scale doesn't qualify as "large," at the post-launch user trajectory it
will, and pre-emptive designation is cheap.
**Fix:** Designate a DPO (can be external / fractional). Publish contact
in privacy policy. Include in Records of Processing Activities (Art. 30).

#### F-7 — Cloud Functions logs likely contain PII; logging discipline not enforced
**File:** `functions/index.js` — `console.log/error` calls scattered
throughout. e.g. `index.js:287` logs recipient email; `index.js:2754` logs
`uid` + commitment hash slice; `account-deletion.js:63` logs error
messages that may include uid.
**Risk:** Cloud Logging retains for 30 days by default; longer with
sinks. Logs containing email + uid become discoverable in subpoenas and
expand the breach surface beyond the documented data inventory.
**Fix:**
1. Adopt a structured logger that classifies log lines as
   PII/no-PII and refuses to log PII in production. (e.g. a thin wrapper
   over `pino`.)
2. Audit existing `console.log` calls: replace email-containing logs with
   `sha256(email)` or remove. Replace uid logs with a zero-knowledge
   "request id" generated per invocation.
3. Configure Cloud Logging exclusion filter to drop Firebase Auth
   request logs after 7 days; configure a retention bucket policy.

#### F-8 — Privacy Manifest `NSPrivacyCollectedDataTypes` is empty
**File:** `ios/FoundationMobile/PrivacyInfo.xcprivacy:34-35`
**Risk:** App Store review since iOS 17 enforces accuracy of the manifest
against the SDKs linked in. Firebase Auth/Firestore/Functions/AppCheck all
collect at least one declared data type each. The manifest's empty array
is provably wrong and **App Store Connect submission will be rejected**
(or accepted then flagged in privacy nutrition label).
**Fix:** populate with at minimum:
```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeEmailAddress</string>
    <key>NSPrivacyCollectedDataTypeLinked</key><true/>
    <key>NSPrivacyCollectedDataTypeTracking</key><false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
  </dict>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeUserID</string>
    <key>NSPrivacyCollectedDataTypeLinked</key><true/>
    <key>NSPrivacyCollectedDataTypeTracking</key><false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
  </dict>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeDeviceID</string>
    <key>NSPrivacyCollectedDataTypeLinked</key><true/>
    <key>NSPrivacyCollectedDataTypeTracking</key><false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
  </dict>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeSensitiveInfo</string>
    <key>NSPrivacyCollectedDataTypeLinked</key><true/>
    <key>NSPrivacyCollectedDataTypeTracking</key><false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
  </dict>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeOtherDiagnosticData</string>
    <key>NSPrivacyCollectedDataTypeLinked</key><false/>
    <key>NSPrivacyCollectedDataTypeTracking</key><false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
  </dict>
</array>
```

#### F-9 — Manual-review Storage path stores raw face + ID images server-side
**File:** `storage.rules:16-24`, `functions/index.js:1648-1731`
**Risk:** The manual-review fallback path bypasses the entire
"nothing-leaves-the-device" architecture. The user uploads `front.jpg`,
`back.jpg`, `selfie.jpg` directly to Firebase Storage. Admins (ring ≤ 1)
can read. This is essentially the Persona/Onfido architecture Foundation
positions itself against. Privacy policy at line 27-34 explicitly says
"DG2 photo extracted from your passport or national ID chip" is NOT
collected — but `selfie.jpg` IS collected on this path, contradicting
the public claim.
**Fix:**
1. Update privacy policy to disclose the manual-review path and the data
   it collects (separately from the standard flow).
2. Time-limit manual-review storage objects: add a Cloud Storage lifecycle
   rule deleting `manual-review/**` objects after 30 days. (`firebase.json`
   has no Storage lifecycle config today.)
3. Encrypt-at-rest with a customer-managed key (CMEK) so a Foundation
   compromise alone doesn't expose the images.
4. Server-side process: delete the source images immediately after the
   admin's review decision is recorded, regardless of outcome. Keep only
   a non-reversible trust signal.
5. Add a separate Art. 9 consent flow for the manual-review path —
   different lawful basis than the on-device flow.

#### F-10 — Article 22 automated-decision rights not surfaced
**File:** `functions/index.js:2583-2777` (`anchorCommitment`),
`functions/index.js:1683-1740+` (manual-review enrollment)
**Risk:** Humanity verification result has legal/significant effects (gates
ring tier, governance access, Pillar 2 fund participation). Art. 22
prohibits solely automated decisions absent (a) contract, (b) law, (c)
consent. The manual-review fallback exists (good — establishes the human
review pathway) but the user must be told about it and offered it
post-rejection.
**Fix:**
1. After a `verify` failure, surface in the UI: "Need a human to review?
   Submit for manual review." Already half-built (`manual_review_requests`
   collection); needs the entry-point in `CaptureView.swift` failed-state
   panel.
2. Privacy policy add Art. 22 paragraph: "Humanity verification is
   automated. You may request human review by emailing privacy@... or
   submitting a manual-review request."

### MEDIUM

#### F-11 — International transfer mechanism not cited
**File:** `docs/legal/privacy-foundation-mobile.md:48-49`
**Risk:** EU users' data goes to `us-east1`. Privacy policy must cite the
specific Art. 46 mechanism (SCCs) or Art. 45 adequacy decision (EU-US Data
Privacy Framework, in effect since Jul 2023, contingent on Google being
self-certified — Google IS self-certified as of writing).
**Fix:** Update privacy policy paragraph to cite "EU-US Data Privacy
Framework (Art. 45) and Standard Contractual Clauses (Art. 46) per
Google Cloud's Data Processing Addendum which we have entered into."

#### F-12 — `identity_commitments` schema makes user erasure observable on-chain
**File:** `functions/index.js:2718-2738`, `functions/lib/identity-onchain.js`
**Risk:** Even after server-side erasure (F-2 fix), the on-chain account
has a `record_address` derivable from `(programId, uid, hashHex)`. A
diligent observer who once observed the Firestore mapping (e.g.
exfiltrated DB) can later check whether the on-chain account still exists
to confirm the erasure occurred — which is a side-channel disclosure of
the erasure event. Not a hard breach, but worth noting.
**Fix:** Document in privacy policy that the on-chain commitment persists
post-erasure. Possibly randomize the seed so re-derivability is harder
post-hoc.

#### F-13 — `mobile_credentials` not deleted on account deletion
**File:** `functions/account-deletion.js`,
`@plantagoai/attestation` package (server-side)
**Risk:** App Attest CBOR blob and keyId are personal data (device-bound
identifier). Stays after Auth user deletion → orphaned record, fails
Art. 17.
**Fix:** Add to foundationDataMap or add explicit deletion in
`deleteMyAccount` for `mobile_credentials/{uid}`.

#### F-14 — 30-day vs 90-day deletion grace contradiction
**File:** `docs/legal/privacy-foundation-mobile.md:70`
("within 30 days") vs `account-deletion.js:110`
(`gracePeriodDays: 90`)
**Risk:** Privacy policy is the public-facing commitment; code is the
implementation. Privacy policy wins in any regulator dispute. Foundation
either delivers in 30d (immediate path is `deleteMyAccount`, which IS
immediate) or admits to 90d (update policy). Right now the policy is
under-promising relative to the immediate path AND over-promising relative
to the request-with-grace path.
**Fix:** Clarify privacy policy: "Immediate deletion: completes within
72h. Scheduled deletion (with 90-day grace period for cancellation):
completes 90 days after request, with a confirmation email."

#### F-15 — `exportMyData` callable not exposed in UI
**File:** `functions/account-deletion.js:95-102`; no iOS view calls it.
**Risk:** Art. 15 right of access fulfillment requires a usable channel.
Email-based fulfillment is acceptable but slow; in-app export is the
modern bar (Apple, Google, Meta all ship it).
**Fix:** Settings → "Download my data" button that calls `exportMyData`,
serializes the JSON, presents a share sheet (`UIActivityViewController`).

#### F-16 — Children's age gate absent
**File:** `ios/FoundationMobile/SignInView.swift`
**Risk:** COPPA / Art. 8 GDPR. A 13-year-old (16 in some EU member states)
cannot give valid consent. The email-link flow has zero age gating.
**Fix:** Add a date-of-birth confirmation step at sign-up, before email-
link send. If under 16 (default; configurable per Member State residency),
hard-block with "we'll be ready for you when you're 16" copy.

#### F-17 — No CCPA-mandated "Do Not Sell or Share" + "Limit Use of SPI" links
**File:** Web property; site-level not iOS-level. But iOS Settings page
should also link out per CPRA's mobile-app guidance.
**Fix:** Add link to `https://foundation-global.com/do-not-sell` page (can
be a one-liner page asserting "Foundation does not sell or share personal
information"). Same for SPI limit page.

#### F-18 — `support/{ticketId}` retention undefined
**File:** `functions/index.js` (submitSupportTicket — not shown above);
`firestore.rules:309-311`
**Risk:** Support tickets accumulate without TTL. Even though
`SupportSheet` design is PII-free in the payload, the doc creation still
writes uid into `support_usage/{uid}` for rate limiting. If an attacker
(or compelled disclosure) reads `support_usage`, they learn that a
particular uid has interacted with support.
**Fix:** Set TTL on `support` (180d after creation) and `support_usage`
(30d after last write). Configure via Firestore TTL policy.

### LOW

#### F-19 — Privacy policy "[to be filled in]" address placeholder
**File:** `docs/legal/privacy-foundation-mobile.md:82`
**Fix:** Fill in the registered business address (PlantagoAI Ltd, Ireland).

#### F-20 — `pairing_sessions` retain after sign-out
**File:** `functions/account-deletion.js`
**Fix:** Add to data map; or rely on lease-expiry sweeper. Sweeper is
documented in `docs/architecture_sweepers-2026-04-26_22-27.md`; verify it
runs on deletion.

#### F-21 — `flow_snapshots/*` not deleted on account deletion
**File:** `firestore.rules:278-289`, `functions/account-deletion.js`
**Fix:** Add to foundationDataMap with a query on `instanceId == uid`.

#### F-22 — Resend email logs (PII outside Foundation's control)
**File:** Sign-in email send via `resendInviteLink`
**Fix:** Disclose Resend.com as a sub-processor in privacy policy.
Acknowledge ~30d retention of email metadata at Resend.

#### F-23 — Privacy policy footer URL redirects to a path that does not exist
**File:** `docs/legal/privacy-foundation-mobile.md:77` references
`https://foundation-global.com/privacy` — verify this URL serves the
current policy. If not yet wired, do so before launch.

#### F-24 — Pasteboard usage in `SupportSheet.swift:182-187` (UIPasteboard)
**File:** `ios/FoundationMobile/SupportSheet.swift:182`
**Risk:** `UIPasteboard.general.string = ticketId` triggers iOS 16+ paste
toast. Not a privacy violation but Apple's manifest reasoning has
expanded to include UserDefaults-style observability of UIPasteboard.
Currently no `NSPrivacyAccessedAPICategoryActiveKeyboards` reason
declared (which can apply to pasteboard). Verify Apple's current rules
and add if needed.

---

## Recommendations roadmap

### Pre-launch (must-ship before any public TestFlight beyond invited
internal testers)

1. **F-1**: harden the debug-dump path. Either remove or runtime-gate
   beyond `#if DEBUG`.
2. **F-2** + **F-13**: extend `foundationDataMap` to cover
   `identity_commitments` and `mobile_credentials`. Verify deletion
   propagates.
3. **F-3**: Insert biometric-specific consent screen ahead of the
   `Verify humanity` button. Record consent doc separately.
4. **F-4**: Add Settings → Privacy Policy + ToS links. Surface privacy-
   policy URL on `SignInView` ("By continuing you accept …").
5. **F-8**: Populate `PrivacyInfo.xcprivacy` `NSPrivacyCollectedDataTypes`
   correctly. App Store will reject otherwise.
6. **F-14**: Reconcile 30/90 day deletion language between privacy policy
   and code.
7. **F-16**: Add age gate at sign-up. Block under-16 (or member-state
   minimum) until parental-consent flow shipped.
8. **Geo-block Illinois at sign-in callable until BIPA consent screen
   ships.** Cheap insurance against statutory damages.

### Pre-EU-launch (in addition to the above)

9. **F-5**: Write the DPIA. Pre-condition for any EU regulator
   conversation.
10. **F-6**: Designate the DPO. Even if fractional/external.
11. **F-9**: Manual-review path tightening — encryption at rest, lifecycle
    deletion, separate consent flow.
12. **F-11**: Cite the transfer mechanism in privacy policy.
13. **F-7**: Audit and de-PII Cloud Functions logs.

### Post-launch (within first 90 days)

14. **F-15**: Ship in-app data export.
15. **F-10**: Wire up the manual-review escalation pathway in the failed-
    verification UI.
16. **F-17**: CCPA-mandated link page.
17. **F-18**: Set TTLs on `support`, `support_usage`, and similar
    diagnostic collections.
18. **F-12**: Document the on-chain post-erasure observability. Consider
    architectural mitigation in the Phase 2 program design (random seed,
    or unlinkable commitment scheme).
19. **F-20** / **F-21**: Tidy account-deletion to also wipe
    `pairing_sessions` and `flow_snapshots`.

### Architectural / strategic (no fixed timeline)

20. **Build a model where the on-chain commitment is unlinkable to the
    server-side mapping** — e.g. encrypt the uid mapping with a key the
    user controls and that the server destroys on erasure. Removes F-12
    permanently.
21. **Adopt verifiable credentials issuance** (W3C VC) so partners can
    consume Foundation's "humanity proof" without ever touching
    Foundation's database.
22. **Document the "biometric data never leaves the device" claim with a
    third-party security audit** (e.g. Trail of Bits, NCC). Privacy
    policy says "this is not a legal fiction"; back it with auditor
    sign-off.
