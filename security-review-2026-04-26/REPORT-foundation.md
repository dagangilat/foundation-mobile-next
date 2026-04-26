# Foundation (foundation-global) — Security & Compliance Report (2026-04-26)

**Scope:** Firebase backend at `/Users/dagan/dev/foundation/foundation-global/` — Firestore rules (332 lines), Storage rules (31 lines), Cloud Functions (`functions/index.js` 3696 lines + lib/* + per-feature files), Solana commitment writes, App Attest verifier wiring, account deletion, demo paths, scripts.
**Frame:** mobile invariant is "nothing identifying leaves the device"; the server's contract is to receive only enclave-signed attestation blobs (hashes) + Solana commitment hashes, and to never re-introduce identity onto the wire.
**Method:** five expert agents (privacy-invariant, app-security, cryptography, privacy-compliance, backend security/compliance). This document re-buckets findings by repo; raw per-domain reports are in the same directory (`01-` … `05-`).

---

## Executive summary

App Attest plumbing is sound: the nonce contract is correctly UTF-8 + per-uid + 15-min TTL + transactional consume; the Apple CBOR verifier walks all seven required checks against Apple's root CA. Solana keypair handling is appropriate (Secret Manager in prod, gated emulator fallback, KMS-encrypted per-user keys). The hard-invariant story is largely respected on the receive side.

**The serious problems are concentrated in three buckets:**

1. **Stale Firestore rules** that never tightened after Phase 0 — vote/proposal/tenant/voter writes are wide open to any authed user, bypassing every Cloud-Function-side dedup, anonymous-hash, and tenant gate.
2. **Public/under-gated callables and HTTP endpoints** — `sendNotification` (CRITICAL: no auth at all), `evaluateProposal` (CRITICAL: no auth, burns LLM tokens), `verifyPassportProof` / `verifyAnonymousVote` / `tryDemo` / `adminStatus` / `listChainDlq` (HIGH: public HTTP, no App Check, expensive work or shared static admin key).
3. **Cryptographic seam between mobile commitment and Solana anchor** — server doesn't bind `uid` into the canonical-bytes hash and doesn't re-verify per-artifact App Attest assertions, enabling a cross-uid replay that flips another user's `humanityVerified` flag (CRITICAL).

Plus systemic compliance gaps: account deletion misses several uid-keyed collections, breaking GDPR Art. 17; the privacy policy contradicts what the system actually logs (email + IP retained 30-90d); no DPIA, no DPO, no in-app data export, manual-review path uploads raw face/ID images server-side which contradicts the public "nothing leaves the device" claim.

---

## CRITICAL

### F-CRIT-1 — `sendNotification` has no `requireAuth`
**File:** `functions/index.js:1769`.
**What:** Any caller (with App Check) can write a notification doc for any `userId` with arbitrary title/body. Phishing/spam channel against the entire user base. App Check stops bots without a Foundation token but a real installed app can blast notifications at any user.
**Fix:** add `await requireAuth(request)`; validate `userId == auth.uid` (self-only). Today no legitimate cross-user use case appears in call sites.

### F-CRIT-2 — `evaluateProposal` has no `requireAuth`
**File:** `functions/index.js:696`.
**What:** Public callable runs Anthropic Claude / Gemini per call. App Check stops bots without a valid Foundation token, but any real user can hammer it indefinitely; no per-callable rate limit. The rate-limit path lives only in `generateProposalDraft`.
**Fix:** `requireAuth` + share the `checkGenerateProposalRateLimit` budget between the two AI callables.

### F-CRIT-3 — Cross-uid commitment replay flips another user's `humanityVerified`
**Files:** `functions/index.js:2645-2738` (anchorCommitment), `functions/on-chain-tasks.js:410-452` (task handler), `functions/lib/identity-onchain.js:30, 64-67` (PDA seed).

**What:** `canonicalSealBytes(artifacts)` mirrors the client's `canonicalBytes()` — neither includes `uid`. The on-chain PDA seed is `[b"commitment", hash]` (no uid). On replay from user B with B's auth token + A's captured payload:
1. `requireAuth` returns `uid = B`.
2. Re-derived bytes hash to the same `hashHex`. Seal-mismatch passes.
3. Server stamps `identity_commitments/B/commitments/{hash}` and enqueues the task.
4. Task handler's on-chain anchor throws `OnChainAlreadyAnchored` (PDA exists from A's earlier anchor).
5. Handler at `on-chain-tasks.js:410-420` **adopts** the existing PDA address.
6. `users/B.humanityVerified = true` set against A's record. Only telltale is `txSignature: null`.

Per-artifact App Attest `signatureBase64` is captured but **not verified server-side at this callable** (the comment promises a "Layer 3" check but no `verifyAssertion` call exists in the code path).

**Why CRITICAL:** humanity-verification bypass — defeats the core product claim.

**Fix (single change closes M-CRIT-1 mobile + F-CRIT-3 backend):** include `uid` in `canonicalSealBytes()` so the byte sequence is uid-bound; mirror in `EnclaveSeal.canonicalBytes()` on the client. Reject submissions whose re-derived hash doesn't match. Optional belt-and-suspenders: in the task handler, before adopting an existing PDA, look up the prior `identity_commitments/*/commitments/{hash}` doc; if it exists for a different uid, refuse to adopt and error.

### F-CRIT-4 — GDPR Art. 17 deletion incomplete (on-chain re-identification persists post-erasure)
**File:** `functions/account-deletion.js:26-51` (`foundationDataMap`).

**What:** The data map does not include `identity_commitments/{uid}/commitments/*`, `mobile_credentials/{uid}`, `users/{uid}` (per-user mirror doc), `flow_snapshots`, `sessions`, `support_usage`, `pairing_sessions`, `tenant_memberships`, or `chain_dlq` payloads referencing the user's uid. Most importantly, `identity_commitments/{uid}/commitments/{hashHex}` encodes uid in the path — even if the doc body were anonymized, doc-existence-by-uid re-identifies the user post-deletion. CNIL's blockchain guidance: a hash on-chain IS personal data when the controller (or any party with reasonable means) can re-identify; Foundation holds the mapping until it deletes it.

**Fix:** extend `deleteMyAccount` (before `deleteAccount` runs) to explicitly delete:
```js
// identity_commitments
const commitmentsCol = admin.firestore()
  .collection("identity_commitments").doc(auth.uid).collection("commitments");
const snap = await commitmentsCol.get();
await Promise.all(snap.docs.map(d => d.ref.delete()));
await admin.firestore().collection("identity_commitments").doc(auth.uid).delete();
// also: mobile_credentials/{uid}, flow_snapshots where instanceId==uid,
// sessions where uid==uid, support_usage/{uid}, pairing_sessions where
// desktopUid|mobileUid == uid, tenant_memberships where voter_id==uid
```
Update privacy policy to state explicitly: *"After your deletion request the on-chain hash remains, but Foundation no longer holds any data that can re-identify you from it."* Reconcile the 30-day-vs-90-day grace contradiction (privacy policy line 70 says 30d; `account-deletion.js:110` enforces 90d).

---

## HIGH

### F-H-1 — Firestore rules: `proposals` / `votes` / `supporter_signatures` / `voters` / `tenants` / `tenant_memberships` are wide open
**File:** `firestore.rules:19-200` (multiple sections).

**What:** Any authed user can `create`/`update` (and in some cases `delete`) on these collections directly via the Firestore client SDK, bypassing the Cloud Functions that are now the canonical writers (`castProposalVote`, `castProposalSupport`, `createProposalDraft`, `createVoterAccount`). The "Phase 0 hotfix" comments promised Phase 2 tightening — never happened. Compounding effects:
- A user can vote multiple times on a proposal by direct Firestore writes (CF dedup is bypassed).
- A user can create a tenant membership claiming `voter_id: <other-uid>, role: "owner"` — distorts member counts and trips downstream tenant-admin queries.
- A user can rewrite the demo tenant's branding/governance defaults.
- A user can write `demo: true` onto a real proposal, then trick (or wait for) an admin to run `cleanupDemoData{mode:"all"}` — collateral data destruction.

**Fix:** flip writes to `if false` for those collections after auditing the frontend for any remaining client-direct writes and migrating them to CFs first. Same treatment for `voting_rounds`, `funds`, `distributions`, `product_requests`.

### F-H-2 — Mobile callables all opt out of App Check; per-artifact assertions never verified
**Files:** `functions/index.js:2401, 2411, 2584, 3072, 3443, 3506, 3560, 3621, 3641, 3670` (each `enforceAppCheck: false`); `functions/index.js:2566-2582` (anchorCommitment "Layer 3" comment).

**What:** `ENFORCE_APP_CHECK=true` globally, but every active mobile callable opts out with comments saying this is "temporary, drop once mobile reliably attaches `app:VALID`". Combined: the mobile surface has effectively zero App Check enforcement today. The custom CBOR verifier in `recordMobileAttestation` is the gate, but the per-artifact App Attest assertions in `anchorCommitment` payloads are captured-but-not-validated server-side (no `verifyAssertion` call). A device whose App Attest is one-off compromised can submit forever.

**Fix:** wire per-artifact assertion verification in `anchorCommitment` against the stored credential at `mobile_credentials/{uid}` (or `identity_proofs/{uid}/mobile_attestations/`). Schedule pulling each carve-out as iOS App Attest gets fully wired (the in-code TODO comments enumerate them).

### F-H-3 — Public HTTP endpoints with no auth and no App Check
**Files:** `functions/index.js:1164` (`verifyPassportProof`, 60s × 512 MiB, CORS `*`), `functions/index.js:1533` (`verifyAnonymousVote`, ~100ms Semaphore proof verify per call), `functions/index.js:1460` (`getSemaphoreGroup`, cache-miss triggers full identity-proofs scan).

**What:** Three unauthenticated, no-App-Check HTTP endpoints, each doing real work (Self proof verifier, Semaphore proof verifier, group rebuild). Spam-amplifies cost; no per-IP rate limit beyond Firebase platform default.
**Fix:** require App Check (`onRequest` doesn't enforce natively but the headers can be checked manually) OR add per-IP sliding-window throttle + concurrency cap. For `getSemaphoreGroup`, dispatch cache-miss rebuilds to a queue rather than running synchronously inside the request.

### F-H-4 — `tryDemo` has no rate limit
**File:** `functions/demo-access.js:28`.

**What:** Public, App-Check-OFF, no rate limit. Each call mints a Firebase custom token for the shared `DEMO_UID`. Bot-grindable. Each call also performs Firestore writes on idempotent paths.
**Fix:** per-IP sliding-window throttle (reuse `checkAndRecordRate`); reCAPTCHA Enterprise score gate. Schedule `cleanupDemoData{mode:"all"}` nightly via `onSchedule` (today only on-demand — demo state accumulates indefinitely).

### F-H-5 — Privacy policy contradicts what the backend actually logs
**File:** `functions/legal.js:51-55`.

**What:** Privacy policy declares `dataCollected = [document_hash, votes, wallet_address, anonymous_hash]` and `dataNotCollected = [name, date_of_birth, biometric_raw_data]`. Actual collection includes:
- Email (Firebase Auth, `mail` collection, sessions, Resend logs)
- IP address (`sessions` 90d, `request_logs` 30d)
- userAgent (`sessions` 90d)

Plus `sendMail` logs full recipient email (`functions/index.js:287`). Misalignment is the kind of gap regulators latch onto — "the controller represented one thing and did another."

**Fix:** either drop email/IP/userAgent fields from `sessions`/`request_logs` (preferred — better trust story) or update the privacy policy to disclose them honestly. Update `dataCollected` array. Reduce `sessions` retention from 90 days to 7 if you keep the IP. Add a `Resend.com` sub-processor disclosure with ~30d email-metadata retention.

### F-H-6 — Manual-review Storage path uploads raw face + ID images
**Files:** `storage.rules:16-24`, `functions/index.js:1648-1731`.

**What:** Manual-review fallback bypasses the entire on-device-only architecture. Users upload `front.jpg`, `back.jpg`, `selfie.jpg` to Firebase Storage; admins (ring ≤ 1) read. Privacy policy says the DG2 photo is NOT collected — but `selfie.jpg` IS, on this path. Plus the Storage `contentType` regex allows `image/svg+xml` (SVG = arbitrary HTML/JS for any UI that ever inlines).

**Fix:**
1. Disclose the manual-review path in the privacy policy with separate consent.
2. Add Storage lifecycle rule: delete `manual-review/**` after 30 days (no lifecycle in `firebase.json` today).
3. Tighten `contentType` regex to `image/(jpeg|png|heic|webp)` — drop SVG.
4. Encrypt-at-rest with CMEK so a Foundation compromise alone doesn't expose images.
5. Server-side: delete the source images immediately after the admin's review decision is recorded.
6. iOS UI must show a separate Art. 9 consent screen before the manual-review submit.

### F-H-7 — Tenant admin can self-promote to platform owner
**File:** `functions/user-management.js:116`.

**What:** `setUserAccess` lets any ring-1 admin call `setUserAccess({ ring: 0 })` on themselves or anyone. No "cannot elevate above your own ring" guard. One compromised TENANT_ADMIN = root over the project.
**Fix:**
```js
if (Number.isInteger(ring) && ring < callerRing)
  throw new HttpsError("permission-denied", "cannot elevate above your own ring");
```
Apply to `role` if certain roles imply elevated capability.

### F-H-8 — `getMyWallet` auto-funds API wallet drain
**Files:** `functions/index.js:2354`, `functions/lib/user-wallet.js:128`.

**What:** First call per uid airdrops 0.1 SOL from the API wallet. A scripted attacker can spin up Firebase users to drain. Currently devnet-free; **flips to real money on mainnet — promote to CRITICAL the moment mainnet goes live**.
**Fix:** rate-limit per-IP; require an explicit "I want a wallet" UX action; defer wallet creation to first write op rather than first read.

---

## MEDIUM

### F-M-1 — No anchorCommitment freshness gate
**File:** `functions/index.js:2602-2603`.
No `producedAtMs` window check. A signed payload from a months-old session can be re-anchored if prior status was `anchor-failed`. Reject if `commitment.producedAtMs < now - 24h`.

### F-M-2 — `signatureBase64` lacks server-side shape validation
**File:** `functions/index.js:2639-2641`.
Only emptiness is checked. Add `^[A-Za-z0-9+/=]+$` and ≤ 1024 byte cap. Defense in depth against malformed canonical-bytes inputs.

### F-M-3 — `OnChainAlreadyAnchored` adoption loses tx signature
**Files:** `functions/on-chain-tasks.js:410-420, 437`.
Adopted records get `txSignature: null`. Future audit can't retrieve the on-chain anchoring tx for that record. Backfill via `getSignaturesForAddress` at adoption time.

### F-M-4 — `signedAtMs` (biometric seal) not bounds-checked
**File:** `functions/index.js:2515-2524`.
Once seal verification ships, reject seals outside `now ± 24h` skew so pre-signed seals can't be banked.

### F-M-5 — `ADMIN_API_KEY` is `defineString`, not `defineSecret`
**Files:** `functions/admin-status.js:11`, `functions/chain-dlq.js:30`, `functions/.env`.
Static API key in env config (`ADMIN_API_KEY=4402964dac8cc1...`). Switch to `defineSecret`, store in Secret Manager, document rotation procedure. Both `adminStatus` and `listChainDlq` share this key — a leak gives full DLQ visibility (raw payloads with uid + commitment hash + raw artifacts) and the pending-deletion roster.

### F-M-6 — `adminStatus` returns full `deletion_requests` body
**File:** `functions/admin-status.js:28`.
Returns `userId`, `requestedAt`, `scheduledAt` for every pending deletion. CORS `*`. If `ADMIN_API_KEY` leaks, the entire pending-deletion roster is exfil. Lock CORS to known admin-tool origins; consider returning counts rather than rows.

### F-M-7 — Demo path: shared UID + open features
**File:** `functions/demo-access.js`.
Demo users share one UID. Anything one demo user does is attributed to all. Plus rate-limit calls from each new visitor share the same `support_usage/{uid}` counter. Also: demo tenant has `pillar1/2/3: true`, and the open `tenants.update` rule (F-H-1) lets a demo user write proposals to non-demo tenants by direct Firestore write.
**Fix:** part of F-H-1 (lock the rules); add a per-uid-from-demo-token guard that refuses non-demo-tenant writes.

### F-M-8 — `cleanupDemoData` is on-demand only
**File:** `functions/demo-cleanup.js:113`.
No scheduler. Demo state accumulates. Add `onSchedule` wrapper running nightly against the demo tenant.

### F-M-9 — `request_logs` / `sessions` retain `voter_id + IP` pairs
**File:** `functions/cleanup.js:42, 54`.
30 / 90-day retention on a re-identification pair. Either reduce retention (7 days) or drop the IP field entirely. Compounds with F-H-5.

### F-M-10 — `resendInviteLink` has no per-IP rate limit
**File:** `functions/index.js:3064`.
Per-email yes (3/h std, 300/d privileged), per-IP no. Email-amplification surface — costs Resend send-budget. Add IP throttle the same way `requestSelfAccess` does.

### F-M-11 — Per-user Storage object count unbounded
**File:** `storage.rules:16`.
5 MB cap per file but no per-user file-count limit. App-side cleanup exists in `approveManualReview` and `deleteManualReviewStorage`; add a hard ceiling check via a CF that watches Storage events.

### F-M-12 — Legacy on-chain callables lack PoH gate
**Files:** `functions/index.js:2077` (`createProposal`), `:2174` (`castVote`), `:2233` (`submitSupport`).
Pre-Phase-0 paths still wired; do not check `voterAccount`/`identity_proofs` before signing on-chain. Anchor program may enforce voter-account existence, but server-side has no PoH check. Either delete (canonical writers are now `createProposalDraft` / `castProposalVote` / `castProposalSupport`) or add the PoH gate.

### F-M-13 — `verifyPassportProof` logs `result.isValidDetails`
**File:** `functions/index.js:1212-1215`.
Self's `isValidDetails` may include nationality/age fields. Cloud Logging retains 30d default; PII residue. Audit the upstream `isValidDetails` shape and de-PII the log line.

### F-M-14 — No DPIA, no DPO designated
**Files:** repo-wide; expected at `docs/legal/dpia.md` (absent); `functions/legal.js:43-46` lists only `privacy@plantagoai.com`.
GDPR Art. 35(3)(b) makes DPIA mandatory for large-scale special-category processing; Art. 37(1)(c) makes DPO mandatory when biometric verification is core activity. Both are pre-EU-launch blockers.
**Fix:** write the DPIA (data-flow diagram, lawful-basis analysis, necessity/proportionality, risks, mitigations, residual risk, sign-off). Designate a fractional / external DPO; publish contact in privacy policy. Include in Records of Processing Activities (Art. 30).

### F-M-15 — `exportMyData` not surfaced in iOS UI
**File:** `functions/account-deletion.js:95-102`.
Backend implements Art. 15 right-of-access via callable; iOS app has no Settings entry-point. Email-only fulfillment is acceptable but slow; in-app export is the modern bar (Apple, Google, Meta).

### F-M-16 — App Attest nonce has no per-uid issuance throttle
**File:** `functions/index.js:2400-2408`.
Authenticated user can fill `attestation_nonces` between 5-min sweeps. Sweeper handles it; a per-uid throttle (≤ 5 unconsumed, ≤ 20/hr) bounds noise.

### F-M-17 — `attestationTier` is client-asserted
**Files:** `functions/index.js` (multiple callables read `attestationTier` from request); `ios/FoundationMobile/FunctionsService.swift:225-229`.
Server has no way to verify client's self-reported tier without cross-checking `mobile_credentials/{uid}`. A client claiming `standard` while having skipped attestation gets the longer 30-min freshness window. Server should derive tier from stored attestation record, not trust the client.

---

## LOW

| ID | File:line | Issue / fix |
|---|---|---|
| F-L-1 | `functions/.env` | Stale `JWT_SECRET=0e17f93cb3...` left from deleted Rocket service — drop |
| F-L-2 | `functions/phase2-integration-test.mjs` | Embeds web API key + admin email; web API keys are public-by-design but pair with a CI-only marker |
| F-L-3 | `firestore.rules:204` | `isAdmin()` defined after first use — cosmetic |
| F-L-4 | `functions/index.js:507` | Wikidata population lookup logs candidate labels — public data only |
| F-L-5 | `functions/cleanup.js:68` | `cleanupAttestationNonces` deletes regardless of `consumed` flag — single-use enforcement lives in `@plantagoai/attestation`; verify out-of-band |
| F-L-6 | `firestore.rules` | `users/{uid}/legal_consent/{docId}` self-write — legal trail under that doc is self-reportable; the server-trusted record should be `legal_consents/{userId}` |
| F-L-7 | `functions/index.js:2442` | `recordMobileAttestation` logs `msg` from verifier including nonce values; nonces are non-PII but worth confirming |
| F-L-8 | `functions/manual_review_requests` (firestore.rules) | Public read on the moderation queue exposes `voterId` + `status` + `reviewedAt` — a scraper can map uid → "submitted manual review at T" |
| F-L-9 | `functions/lib/pairing.js:21-24` | Comment claims 36^6 code space; actual alphabet is 32 chars (1.07B codes). Fix comment, or extend to 8 chars if scale demands |
| F-L-10 | `functions/index.js:3656-3666` | Release-pairing path bypasses `ensureFreshPairingAuth`. Document the DoS-tradeoff is intentional; re-check when App Attest enforcement flips |
| F-L-11 | `functions/index.js:2718-2738` | On-chain `record_address` derivable from `(programId, uid, hashHex)` — observer who once saw the Firestore mapping can verify post-erasure record still exists. Document; possibly randomize seed in Phase 2 |
| F-L-12 | Storage `manual-review/{voterId}/{requestId}/{file}` | `requestId` and `file` segments are caller-controlled; one user × N files is unbounded count (5 MB each) — add a per-user file-count ceiling via CF watcher |
| F-L-13 | `functions/legal.js` (privacy policy) | `[to be filled in]` placeholder for registered business address — fill before EU launch |
| F-L-14 | `firebase.json` | No Storage lifecycle config — see F-H-6 |
| F-L-15 | CCPA/CPRA | No "Do Not Sell or Share" or "Limit Use of SPI" links — even when you don't sell, the assertion link is required |

---

## Privilege escalation paths (worst-case ladders)

From a vanilla authed user (ring 3 / "USER"):
1. **U → tenant rewrite** via direct Firestore `tenants/{id}.update` (F-H-1).
2. **U → forged voter doc** for any uid via direct `voters/{uid}.create` (F-H-1).
3. **U → forged proposal/vote/support** via direct Firestore writes that bypass CF dedup (F-H-1).
4. **U → demo cleanup of real data** via writing `demo: true` onto a real proposal then awaiting admin run of `cleanupDemoData` (F-H-1 + F-M-7).
5. **U → spam any user** via `sendNotification` (F-CRIT-1).
6. **U → drain API wallet** via `getMyWallet` + many uids (F-H-8 — devnet free, mainnet real).
7. **U → flip another user's `humanityVerified`** via captured-payload replay (F-CRIT-3).

From a TENANT_ADMIN (ring 1):
8. **TA → PLATFORM_OWNER** via `setUserAccess({ring: 0})` on self (F-H-7). System's blast radius today = the set of TENANT_ADMINs (currently `[feedmyinfo@gmail.com, dagan.gilat@gmail.com]` per `tmp-promote.mjs`).

---

## DoS / abuse surface (ranked by attacker-side cost-amplification)

| Attack | Surface | Severity |
|---|---|---|
| Spoof system notifications via `sendNotification` | public-with-auth, NO `requireAuth` | **CRITICAL** |
| LLM cost burn via `evaluateProposal` | public, NO auth | **CRITICAL** |
| Self proof verifier cycles via `verifyPassportProof` | public HTTP, no auth, 60s × 512 MiB | HIGH |
| Drain API wallet via `getMyWallet` | authed, App Check on, per-uid idempotent — but N uids | HIGH (mainnet) |
| Spam custom-token mints via `tryDemo` | public, App Check OFF, no rate limit | HIGH |
| Spam-amplify Resend send budget via `resendInviteLink` | public, App-Check-OFF, per-email rate limit only | MEDIUM |
| Anonymous-vote verifier cycles via `verifyAnonymousVote` | public HTTP, no auth | MEDIUM |
| Force-rebuild Semaphore groups via `getSemaphoreGroup` cache miss | public HTTP | LOW |
| Spam access-request emails via `requestSelfAccess` | per-email + per-IP throttle in place | LOW |

Default Cloud Functions concurrency is 1; functions like `evaluateProposal` (30s timeout) and `verifyPassportProof` (60s/512MiB) saturate cheaply.

---

## Verifications worth surfacing (no finding)

- **App Attest CBOR verifier is correct.** `verify-apple.ts` walks all seven required Apple checks (cert chain to Apple WWDR, validity windows, OID 1.2.840.113635.100.8.2 nonce extension matching `SHA-256(authData || SHA-256(utf8(req.nonce)))`, AAGUID, RP ID hash, etc.).
- **Solana keypair handling is sound.** Secret Manager in prod (`defineSecret("SOLANA_DEVNET_KEYPAIR")`); local-file fallback gated on `FUNCTIONS_EMULATOR=true`. Per-user keypairs encrypted with GCP KMS (`projects/solanavote-devnet/locations/global/keyRings/foundation/cryptoKeys/user-wallets`); Firestore `user_wallets/{uid}` rule denies all reads/writes.
- **Mobile holds no Solana keypair.** Confirmed by `SolanaRPC.swift:6` and the absence of any signing path on iOS.
- **Idempotency on commitment writes is correct** — re-submit returns the stored receipt; PDA collision is detected; DLQ for failures. (The cross-uid replay in F-CRIT-3 exploits this idempotency, not breaks it.)
- **`anchorCommitment` server-derives the canonical hash** and rejects on mismatch (`functions/index.js:2645-2656`). The client can't claim a hash it can't reproduce. The gap is that the canonical bytes don't include `uid`.

---

## Cross-references

- **Mobile counterparts** of F-CRIT-3, F-H-2, F-M-17 live in `REPORT-foundation-mobile.md`. The cross-uid replay's full fix needs both client and server updates.
- **Manual-review path (F-H-6)** is triggered by an iOS UI flow — the iOS report has the consent-screen requirement; this report has the server-side hardening (lifecycle, CMEK, contentType regex, per-flow Art. 9 consent record).
- **Raw per-domain reports** (more depth):
  - `03-backend.md` — full per-collection Firestore rule analysis, 50+ callable table with auth/AppCheck/claims/validation, GDPR Art. 17 tracker
  - `04-crypto-attestation.md` — App Attest verifier walk, PDA seeding, replay walk-throughs (Walk-through A is F-CRIT-3 step-by-step)
  - `05-privacy-compliance.md` — GDPR/CCPA/BIPA analyses, on-chain immutability vs erasure, DPIA gap, manual-review path classification

---

## Recommended remediation order

**Pre-public launch (ship-blockers):**
1. F-CRIT-1, F-CRIT-2 — add `requireAuth` to `sendNotification` and `evaluateProposal`. Per-uid rate-limit for `evaluateProposal`.
2. F-CRIT-3 — bind `uid` into `canonicalSealBytes()` on both server + client; close cross-uid replay.
3. F-CRIT-4 — extend `foundationDataMap` with `identity_commitments`, `mobile_credentials`, `users`, `flow_snapshots`, `sessions`, `support_usage`, `pairing_sessions`, `tenant_memberships`. Reconcile the 30/90-day grace contradiction.
4. F-H-1 — lock the open Firestore rules to `if false` for `proposals` / `votes` / `supporter_signatures` / `voters` / `tenants` / `tenant_memberships` / `voting_rounds` / `funds` / `distributions` / `product_requests` after migrating frontend to CFs.
5. F-H-3, F-H-4 — add per-IP rate limit + concurrency cap to `verifyPassportProof`, `verifyAnonymousVote`, `tryDemo`. Schedule `cleanupDemoData` nightly.
6. F-H-5 — drop email/IP/userAgent from `sessions`/`request_logs` OR update privacy policy to disclose them.
7. F-H-7 — add ring-elevation guard in `setUserAccess`.

**Pre-EU-launch (in addition):**
8. F-M-14 — write the DPIA, designate the DPO.
9. F-H-2 — wire per-artifact App Attest verification in `anchorCommitment`; schedule App Check carve-out removal as iOS clients flip on enforcement.
10. F-H-6 — manual-review path: lifecycle deletion (30d), CMEK, drop SVG, separate Art. 9 consent flow.
11. F-M-5 — switch `ADMIN_API_KEY` to `defineSecret`.

**Pre-mainnet:**
12. F-H-8 — `getMyWallet` rate-limit; defer wallet creation to first write.

**Post-launch (90-day window):**
13. F-M-1, F-M-2, F-M-3, F-M-4, F-M-8, F-M-9, F-M-10, F-M-11, F-M-15, F-M-16
14. LOW-tier hygiene
