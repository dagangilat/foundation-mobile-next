# Backend Security & Compliance Audit — 2026-04-26

Reviewer: senior cloud/backend security expert (audit pass).
Repo: `/Users/dagan/dev/foundation/foundation-global/`.
Scope: Firestore rules, Storage rules, Cloud Functions (auth/authz, App Check, Solana, account deletion, demo, voting, admin), DoS surface, secrets, PII in logs.
Project: `solanavote-devnet` (devnet — pre-pilot). Hard invariant carried in from mobile: **nothing identifying leaves the device** (mobile only emits enclave-signed attestation blob + Solana commitment hash; the server stores only hashes / categorical disclosures).

This is a *security* audit — not a correctness audit. Some findings call out functionality that works fine but is brittle under adversarial inputs.

---

## Scope

| Surface | Files reviewed |
|---|---|
| Firestore rules | `firestore.rules` (332 lines) |
| Storage rules | `storage.rules` (31 lines) |
| Hosting / headers | `firebase.json` |
| Callables / triggers | `functions/index.js` (3696 lines), `functions/proposal-voting.js`, `functions/account-deletion.js`, `functions/admin-status.js`, `functions/chain-dlq.js`, `functions/demo-access.js`, `functions/demo-cleanup.js`, `functions/legal.js`, `functions/cleanup.js`, `functions/user-management.js`, `functions/on-chain-tasks.js` |
| Lib | `functions/lib/app-check.js`, `functions/lib/identity-onchain.js`, `functions/lib/on-chain-queue.js`, `functions/lib/pairing.js`, `functions/lib/solana.js`, `functions/lib/tier.js`, `functions/lib/user-wallet.js`, `functions/lib/voting-onchain.js` |
| Scripts | `scripts/promote-admin.mjs`, `scripts/seed-admin-invite.mjs`, `functions/tmp-promote.mjs`, `functions/phase2-integration-test.mjs` |
| Env | `functions/.env`, `.gitignore`, `.firebaserc` |

ENFORCE_APP_CHECK=true is set globally. Every callable is wrapped in `lib/app-check.js::callable`, with explicit `enforceAppCheck: false` carve-outs on individual mobile callables.

Ring model (per `@plantagoai/auth/middleware`): `0 = PLATFORM_OWNER`, `1 = TENANT_ADMIN`, `2 = PRIVILEGED`, `3 = USER`, `4 = RESTRICTED`. `isAdmin()` in firestore.rules = ring ≤ 1.

---

## Firestore rules — per-collection findings

| Collection | Read | Write | App Check on writes | Issue |
|---|---|---|---|---|
| `proposals/{id}` | public | any authed | n/a (rule layer) | **HIGH**: any authed user can `update`/`delete` ANY proposal — no `request.auth.uid == resource.data.proposer_uid` check. Means a legitimately authed (or demo) user can edit titles, options, status, vote counts on someone else's proposal. Comment marks it Phase 0 hotfix; the migration to CFs (`createProposalDraft`, `castProposalVote`) has shipped, but the rule was never tightened. |
| `voters/{id}` | public | any authed | — | **HIGH**: any authed user can create/update/delete any voter doc. `voters/{uid}` is the on-chain-pubkey mirror created by `createVoterAccount` CF. A user can stomp another user's `voterAccountAddress`/`signerPubkey`/`tenant_id` mapping. Not a humanity bypass, but a cleanly exploitable vandalism path (deletion locks the legitimate user out of their voter doc until a CF rebuilds it). |
| `votes/{id}` | public | any authed `create`; `update`/`delete: false` | — | **HIGH**: client-direct vote create is still allowed even though `castProposalVote` CF is the canonical writer. A direct client write can spoof `voter_uid`/`anonymous_hash`/`tenant_id` and inflate counters via separate `proposals` updates (which are also wide open). |
| `supporter_signatures/{id}` | public | any authed | — | **HIGH**: same shape as votes — direct client create allows forged supporter rows that bypass `castProposalSupport`'s server-derived `anonymous_hash` dedup (the dedup is keyed on the same field, but a client write with a different hash bypasses the gate). |
| `webauthn_credentials/{id}` | denied | denied | — | OK. Server-only. |
| `user_wallets/{uid}` | denied | denied | — | OK. KMS-encrypted secret keys. |
| `identity_proofs/{nullifier}` | self-only or admin | denied | — | OK. Mediated through `verifyPassportProof` HTTP function (Admin SDK). |
| `voting_rounds/{id}` | public | any authed | — | **MED**: any authed user can create/update/delete arbitrary voting rounds. Round windows decide whether votes are accepted — an adversary can shift the window. Comment labels Phase 2 work pending. |
| `funds/{id}`, `distributions/{id}`, `product_requests/{id}`, `savings_summary/{id}` | public | any authed | — | **MED**: same pattern as proposals — any authed user can create or alter any document. Pillar-2 / Pillar-3 data integrity is unprotected. |
| `mail/{id}` | denied | denied | — | OK. Trigger-only. |
| `manual_review_requests/{id}` | public | any authed `create`; update/delete denied | — | **MED-LOW**: public read on the manual-review queue exposes `voterId` (Firebase uid) plus `status`/`reviewedAt`/`rejectionReason`. A scraper can map uid → "submitted manual review at T" + did-they-pass. Rule comment says reads stay open. Storage objects under `manual-review/{voterId}/` are admin-read so the photos themselves stay private. |
| `anonymous_votes/{proposalId}/nullifiers/{n}` | public | denied | — | OK. Server-write only via `verifyAnonymousVote`. |
| `semaphore_groups/{tier}` | public | denied | — | OK. Trigger-rebuilt only. |
| `action_items/{id}` | public | any authed | — | **LOW**: comment promises Ring ≤ 1 gating in Phase 2; today any authed user. Low impact (admin todo list). |
| `populations/{id}` | public | denied | — | OK. |
| `tenants/{id}` | public | any authed `create`/`update`; delete denied | — | **HIGH**: any authed user can create a tenant or rewrite an existing tenant doc. `tenant_memberships`/`votes`/`proposals` rules trust `tenant_id` as a sharding scope, but the tenant doc itself is wide open. A user could change `Foundation 0.0.1` (the demo tenant) config — branding, governance defaults — or create a parallel tenant they then "admin". Demo cleanup uses `where("demo","==",true)` filters but the `demo` flag itself is forgeable. |
| `tenant_memberships/{id}` | public | any authed `create`/`update`; delete denied | — | **HIGH**: any authed user can create a membership doc claiming `voter_id: <other-uid>` in any tenant, with `role: "owner"`. The application uses memberships for UI gating, but they are NOT the source of truth for ring claims (those are auth custom claims). Still, a hostile membership write distorts member counts and could trip downstream tenant-admin queries (e.g. listing members shows fake entries). |
| `access_requests/{email}` | admin-read; denied write | — | — | OK — `requestSelfAccess` CF mediates writes. |
| `access_request_rate{,_ip}/{key}` | denied | denied | — | OK. |
| `abuse_registry/{voterId}` | admin-read; denied write | — | — | OK. |
| `invites/{email}` | admin OR own-email read; admin write | — | — | OK. |
| `settings/{key}` | public | admin-only | — | OK. Note `allowSelfRequest` flag is gated by isAdmin. |
| `users/{uid}` | self or admin read; denied write | — | — | OK. Server-only writes. |
| `users/{uid}/legal_consent/{docId}` | self read+write | self read+write | — | **LOW**: a user can write any `documentType_version` consent doc with any contentHash. A legal trail under that doc is therefore self-reportable. Phase-correct (compliance shipped via `recordTosAcceptance` CF, but the React hook still writes here client-side per the comment). The risk is low because the *server-trusted* attestation should come from the `legal_consents/{userId}` collection used by `@plantagoai/legal/recordConsent`. |
| `flow_snapshots/{snapId}` | self read/write (instanceId == uid) | same | — | OK. |
| `pairing_sessions/{sessionId}` | desktopUid OR mobileUid match; denied write | — | — | OK. CF-only writes. |
| `support/{ticketId}` | denied | denied | — | OK. CF-mediated. |
| `support_usage/{uid}` | denied | denied | — | OK. |
| `identity_commitments/{uid}/commitments/{hashHex}` | self read; denied write | — | — | OK. CF-mediated. |

### Other observations on rules

- `isAdmin()` is defined *after* it's used (line 204; first ref line 220). Firestore evaluates rules statically so order doesn't matter for correctness, but it's confusing.
- No collection has a `request.app != null` predicate. App Check enforcement is entirely at the Cloud Functions layer; clients writing directly to Firestore from the web bypass App Check on those direct paths. Given how many write paths above are wide open to "any authed user", that means App Check provides ZERO mitigation against authenticated abuse for those collections.
- TTL fields exist (`expireAt` on rate-limit counters) but I did not verify the Firestore TTL policy is actually configured in the project — that's an out-of-band gcloud/console setting; misconfig means counters live forever. (See `firestore.indexes.json` — only indexes there, no TTL config visible in repo.)

---

## Storage rules — per-bucket-path findings

`storage.rules`:
- `manual-review/{voterId}/{requestId}/{file}`: write requires `request.auth.uid == voterId`, size ≤ 5 MB, contentType matches `image/.*`. Read = ring ≤ 1.
  - **MED**: contentType check is client-declared. A malicious client can set `Content-Type: image/png` on an arbitrary blob. Storage rules don't run real magic-byte sniffing. The 5 MB cap and the admin-only read scope mitigate damage (no public-served XSS), but admins viewing in the moderation UI may load attacker-supplied files as "images" and hit issues if the UI uses `<img src>` with a JS payload (no real risk for `<img>` but real for `<embed>`/`<object>`/SVG payloads).
  - **LOW**: image-content-type allows `image/svg+xml`. SVG = arbitrary HTML/JS. If the moderator UI ever renders these inline (vs. as `<img>`), it's stored XSS in the admin panel. Recommend: tighten to `image/(jpeg|png|heic|webp)`.
  - **LOW**: `requestId` and `file` are caller-controlled path segments. Not a path traversal in the GCS sense (rules treat them as opaque), but a single user can create unbounded objects under their own prefix (no per-user file-count limit). One user × N MB × many files = storage cost amplification. The 5 MB per file is bounded but per-user object count is not.
  - The `voterId` segment must match `request.auth.uid`, so cross-user upload is blocked. Good.
- Default `match /{allPaths=**}: read, write: if false`. Good.

---

## Callables — table

(✓ = correct/safe; ✗ = issue; — = N/A)

| Name | File:line | Auth | App Check | Custom-claims source | Input validation | Finding |
|---|---|---|---|---|---|---|
| sendMail (trigger) | index.js:228 | n/a (Firestore trigger) | n/a | — | reads `to` from doc | OK — `mail` writes are denied to clients. |
| lookupPopulation (trigger) | index.js:573 | n/a | n/a | — | — | OK — best-effort enrichment. |
| evaluateProposal | index.js:696 | NONE | env-default (TRUE) | — | strict (title/desc/principles) | **HIGH**: missing `requireAuth`. Anyone with App Check tokens can call Anthropic Claude / Gemini at our cost via the function. AI rate limit lives only in `generateProposalDraft`. Each call uses an LLM provider key (`ANTHROPIC_API_KEY`, `GEMINI_API_KEY`). 30s timeout, no per-caller throttle. |
| generateProposalDraft | index.js:985 | requireAuth | env (TRUE) | — | strict | OK. Per-uid rate limit (20/h, 60/d). |
| verifyPassportProof | index.js:1164 | NONE (HTTP) | NONE | — | strict shape | **HIGH**: HTTP endpoint, no auth gate, no App Check, CORS `*`. Any caller from any origin can submit a Self proof bundle. Self's verifier prevents forging proofs without a real passport, but a Self-MITM attacker who's harvested someone else's proof bundle can replay it (attestation already enforces nullifier uniqueness, so an existing nullifier rejects). The bigger surface is unbounded compute from spam — Self verifier + 60s timeout + 512 MiB. |
| attachSemaphoreCommitment | index.js:1333 | requireAuth | env (TRUE) | — | regex 0x-hex ≤ 64 | OK. Idempotent on commitment match. |
| getSemaphoreGroup (HTTP) | index.js:1460 | NONE | NONE | — | tier validated | LOW: public read endpoint. By design (anonymous-vote frontend builds a local Group). Cache-miss path triggers an inline `buildAndCacheSemaphoreGroups` that scans `identity_proofs` — DoS-amplifier if attackers force cache miss repeatedly. |
| rebuildSemaphoreGroups (trigger) | index.js:1511 | n/a | n/a | — | — | OK — Firestore trigger. |
| verifyAnonymousVote (HTTP) | index.js:1533 | NONE | NONE | — | shape only | **MED**: HTTP endpoint, no auth, CORS open. Semaphore proof verification on every call (CPU-heavy). DoS surface: Semaphore proof verify (~100ms wall) × spam = real cost. Rate-limited only by Firebase platform default (regional). Also tier-gating uses cached root which is built from public commitments — the root is technically the only authority gate. |
| approveManualReview | index.js:1672 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | OK. |
| sendNotification | index.js:1769 | NONE | env (TRUE) | — | requires userId/title/body | **CRITICAL**: NO `requireAuth`. Any caller (with App Check) can create an in-app notification for ANY userId with arbitrary title/body. Spoofable system notifications, phishing surface, abuse vector. App Check stops bots without a valid app token but does not stop a legitimately installed app from blasting notifications at any user. |
| solanaClientSmokeTest | index.js:1914 | requirePlatformOwner | env (TRUE) | from token | — | OK. |
| createVoterAccount | index.js:1987 | requireAuth | env (TRUE) | — | population string ≤ 32 | OK. Reads identity_proofs by uid first. |
| createProposal | index.js:2077 | requireAuth | env (TRUE) | — | strict | OK. **NB**: This is the *legacy* on-chain-only path; no humanity gate (does not check `voterAccount`/identity_proofs before creating proposal). Any authed user can mint a proposal. (`createProposalDraft` is the Firestore-authoritative replacement.) |
| castVote | index.js:2174 | requireAuth | env (TRUE) | — | proposalAddress + optionIndex | **MED**: legacy on-chain-only path. Like createProposal, doesn't gate on humanity. The Anchor program may enforce voter_account exists, but server-side no PoH check. (The `castProposalVote` CF likewise has no PoH gate — it relies solely on Firestore rules.) |
| submitSupport | index.js:2233 | requireAuth | env (TRUE) | — | proposalAddress | **MED**: legacy on-chain-only path; no PoH gate before signing on-chain. |
| activateProposal | index.js:2294 | requireAuth | env (TRUE) | — | proposalAddress | OK. On-chain program enforces threshold. |
| getMyWallet | index.js:2354 | requireAuth | env (TRUE) | — | — | OK. Returns own pubkey only. **MED**: side-effect — calling this auto-creates a per-user keypair AND auto-funds it from the API wallet (0.1 SOL on devnet). A scripted attacker who can spin up Firebase users can drain the API wallet by calling `getMyWallet` once per fresh uid. Devnet airdrop = free, but mainnet would burn real SOL; this becomes a CRITICAL finding once mainnet flips. |
| issueAttestationNonce | index.js:2400 | requireAuth | **OFF** (carve-out) | — | — | OK — by-design carve-out (chicken-and-egg with App Attest). |
| recordMobileAttestation | index.js:2410 | requireAuth | **OFF** (carve-out) | — | shape only | OK — by-design. CBOR verifier in `@plantagoai/attestation` handles real validation. |
| anchorCommitment | index.js:2583 | requireAuth | **OFF** (carve-out) | — | strict + seal-hash re-derivation | OK. Strong validation; per-artifact App Attest assertion verification is documented but actually deferred (comment says "Full App Attest re-verification of each assertion is Phase 7 / later"). See HIGH below. |
| sendInviteEmail (trigger) | index.js:2795 | n/a | n/a | — | — | OK. |
| checkInviteOnSignup (trigger) | index.js:2809 | n/a | n/a | — | — | OK. |
| backfillTenantClaim (trigger) | index.js:2838 | n/a | n/a | — | — | OK. |
| approveAccessRequest | index.js:2857 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | OK. |
| rejectAccessRequest | index.js:2876 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | OK. |
| inviteDirect | index.js:2893 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | OK. |
| setAllowSelfRequest | index.js:2912 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | bool check | OK. |
| requestSelfAccess | index.js:2973 | NONE (public) | env (TRUE) | — | email format | OK — App Check + per-email + per-IP sliding window throttle. **LOW**: IP comes from `x-forwarded-for` which Cloud Run/Functions sets correctly, but spoofable if the function is ever fronted by a non-GCP proxy. |
| resendInviteLink | index.js:3064 | NONE (public) | **OFF** (carve-out) | from queried user | email | **MED**: carved-out from App Check AND public. Email-amplification surface — privileged tier allows 300/day per email. Per-email rate limit, but per-IP not enforced on this path. An attacker can pick an unprivileged email and trigger 3/h sign-in emails to that mailbox; combined with many email targets, that's a spam vector that costs you Resend send-budget. Anti-enum logic returns ok-but-not-sent on unknown addresses. |
| getOpsSummary | index.js:3214 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | bounded | OK. |
| flagUserAbuse | index.js:3323 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | OK. |
| unflagUserAbuse | index.js:3353 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | OK. |
| submitSupportTicket | index.js:3442 | requireAuth | **OFF** (carve-out) | — | strict (length-capped) | OK — explicit no-PII contract enforced inline. Per-uid throttle. |
| mintWebSessionToken | index.js:3496 | requireAuth + auth_time fresh | **OFF** (carve-out) | from token | — | OK. Stale-auth defense documented. |
| requestPairingCode | index.js:3551 | requireAuth | **OFF** (carve-out) | — | — | OK. |
| claimPairingSession | index.js:3618 | requireAuth + auth_time fresh | **OFF** (carve-out) | from token | code shape | OK. |
| heartbeatPairingSession | index.js:3638 | requireAuth | **OFF** (carve-out) | — | sessionId | OK. owner-mismatch guard inside helper. |
| releasePairingSession | index.js:3667 | requireAuth | **OFF** (carve-out) | — | sessionId | OK. (intentionally not freshness-gated — see comment.) |
| cleanupStalePairings (sched) | index.js:3688 | n/a | n/a | — | — | OK. |
| listChainDlq (HTTP) | chain-dlq.js:37 | X-Admin-Key | n/a | — | bounded | **MED**: shared admin key in `.env`. If `ADMIN_API_KEY` ever leaks (env file checked into a screenshot, CI artifact, etc.) it gives full DLQ visibility. Static key — no rotation. Same key used by `adminStatus`. |
| listChainDlqAdmin | chain-dlq.js:106 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | bounded | OK. |
| retryChainDlq | chain-dlq.js:162 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | dlqId | OK. |
| deleteChainDlq | chain-dlq.js:228 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | dlqId | OK. |
| adminStatus (HTTP) | admin-status.js:28 | X-Admin-Key | n/a | — | — | **MED**: same shared static admin key. CORS `*`. Returns collection counts + first-5 proposals + the *contents of `deletion_requests`* including `userId`, `requestedAt`, `scheduledAt` for every pending deletion. If the API key leaks, that's the full pending-deletion roster. |
| tryDemo | demo-access.js:28 | NONE | **OFF** (`enforceAppCheck: false`) | n/a | n/a | **MED**: unauthenticated, unprotected. Mints a Firebase custom token for a fixed shared demo UID. Anyone can hit it from anywhere — by design — but it has NO rate-limit. A bot can call `tryDemo` to mint custom tokens infinitely (each call also performs Firestore reads + writes on idempotent paths, but those are O(1) reads). Real cost = invocation count × Firestore read price. |
| cleanupDemoData | demo-cleanup.js:113 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | mode strict | OK. Tenant-scoped from token claim. **NB**: relies on `demo: true` boolean flag on docs; Firestore rule allows any authed user to write `demo: true` on `tenants` and others, so an attacker could mark a real proposal as demo and then trick an admin into "cleaning" it. (This compounds with the open `proposals.update` rule.) |
| getPrivacyPolicy / getTermsOfService | legal.js:129/137 | NONE | env (TRUE) | n/a | n/a | OK — static content. |
| recordTosAcceptance / checkTosAcceptance | legal.js:145/160 | requireAuth | env (TRUE) | — | — | OK. |
| deleteMyAccount | account-deletion.js:72 | requireAuth | env (TRUE) | — | n/a | OK — see GDPR section below. |
| exportMyData | account-deletion.js:95 | requireAuth | env (TRUE) | — | n/a | OK. |
| requestAccountDeletion | account-deletion.js:105 | requireAuth | env (TRUE) | — | reason optional | OK. |
| cancelAccountDeletion | account-deletion.js:119 | requireAuth | env (TRUE) | — | n/a | OK. |
| castProposalVote | proposal-voting.js:267 | requireAuth | env (TRUE) | from token (tenantId) | strict (256 chars) | OK at the CF layer. **HIGH externally** because direct Firestore `votes.create` is still allowed (see rules HIGH above). |
| castProposalSupport | proposal-voting.js:435 | requireAuth | env (TRUE) | from token (tenantId) | strict | Same posture. |
| createProposalDraft | proposal-voting.js:898 | requireAuth | env (TRUE) | from token (tenantId) | very strict (allow-list) | OK at CF; same Firestore rule caveat. **NB**: no humanity gate either — any authed user can create a proposal. |
| listUsers | user-management.js:53 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | bounded | OK. |
| setUserAccess | user-management.js:116 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | **MED**: a TENANT_ADMIN (ring 1) can set ANY user's `ring` to 0 (PLATFORM_OWNER). No "cannot promote above your own ring" guard. So a single tenant admin compromise = root over the project. |
| inviteUserWithAccess | user-management.js:314 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | strict | OK. |
| logSession | user-management.js:389 | requireAuth | env (TRUE) | — | site whitelist | **LOW**: stores `ip` and `userAgent` on the `sessions` doc keyed by uid. Combined with `email` from the auth token, this is PII (IP + email) sitting in Firestore. Justified for "last login" diagnostics + 90-day retention via `cleanupOldSessions`, but worth noting under GDPR — the privacy policy at legal.js:51 lists `dataCollected` as `[document_hash, votes, wallet_address, anonymous_hash]` and explicitly NOT email/etc. The session collection contradicts that listing. |
| adminResetUserHumanity | user-management.js:189 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | uid | OK. |
| adminLockoutUser | user-management.js:270 | requireRing(TENANT_ADMIN) | env (TRUE) | from token | uid | OK. |
| mintProposalOnChainTask (Cloud Task) | on-chain-tasks.js:108 | task-queue auth | n/a | — | from queue payload | OK. |
| mirrorVoteOnChainTask | on-chain-tasks.js:179 | task-queue auth | n/a | — | from payload | OK. |
| mirrorSupportOnChainTask | on-chain-tasks.js:264 | task-queue auth | n/a | — | from payload | OK. |
| anchorIdentityCommitmentTask | on-chain-tasks.js:364 | task-queue auth | n/a | — | regex'd | OK. |
| cleanupOldSessions/RequestLogs/AttestationNonces/Mail (sched) | cleanup.js | n/a | n/a | — | — | OK. |

---

## Privilege escalation paths

Worst-case ladders from a vanilla authed user (ring 3 / "USER") today:

1. **U → tenant rewrite**: open `tenants/{id}` `update` rule lets any authed user rewrite any tenant's config. Doesn't grant ring elevation but tampers with tenant-wide settings (governance defaults, branding, member counts).
2. **U → forged voter doc**: open `voters/{uid}` create/update lets any authed user write to ANY voter id, including impersonating someone else's `voterAccountAddress`. Doesn't grant ring elevation.
3. **U → forged proposal/vote/support**: direct Firestore writes to `proposals`/`votes`/`supporter_signatures` bypass the CF dedup. A user can vote multiple times on a proposal as long as they vary the doc fields enough to avoid the (server-generated, but client-writable) `anonymous_hash`. Inflates totals; doesn't elevate ring.
4. **U → demo cleanup of real data**: write `demo: true` onto a real proposal, then trick (or wait for) an admin to run `cleanupDemoData`/mode=all. Cross-collection: open `proposals.update` × demo-cleanup's `where("demo","==",true)` filter.
5. **U → spam any user via `sendNotification`**: direct call. CRITICAL.
6. **U → drain API wallet via `getMyWallet`**: spin up many users, call `getMyWallet`. Each first-time call airdrops 0.1 SOL from the API wallet. Cost-amplification on devnet (free SOL); becomes real money on mainnet.
7. **Tenant admin (ring 1) → PLATFORM_OWNER (ring 0)**: `setUserAccess` lets any ring-1 admin promote themselves or any other user to ring 0. There is NO "no-cross-ring-elevation" check. One compromised TENANT_ADMIN = full root.

No path I found from "vanilla authed user" to ring elevation directly. But path #7 means the system's blast radius is the largest set of TENANT_ADMINs, which today is `[feedmyinfo@gmail.com, dagan.gilat@gmail.com]` per `functions/tmp-promote.mjs` (not committed).

---

## App Attest enforcement state

Server config: `ENFORCE_APP_CHECK=true` in `functions/.env`. Helper at `functions/lib/app-check.js` reads this once and applies it to every callable wrapped via `callable()` unless overridden.

Per-callable carve-outs (`enforceAppCheck: false`):
- `tryDemo` (demo-access.js:31) — by design.
- `issueAttestationNonce`, `recordMobileAttestation` (index.js:2401, 2411) — chicken-and-egg with App Attest itself; legitimate carve-out.
- `anchorCommitment` (index.js:2584) — replaced with custom seal verification + per-artifact App Attest assertion.
- `mintWebSessionToken`, `claimPairingSession`, `heartbeatPairingSession`, `releasePairingSession`, `requestPairingCode` (index.js:3506, 3621, 3641, 3670, 3560) — temporary, tracking iOS App Attest provider readiness; comment says "drop this override once mobile reliably attaches `app:VALID` tokens".
- `submitSupportTicket` (index.js:3443) — by design (need Support reachable when App Check is broken).
- `resendInviteLink` (index.js:3072) — pre-sign-in path.

**HIGH (carve-out drift)**: 5 of the 6 mobile callables have App Check disabled with a comment that this is "temporary". Combined with the carve-outs being how iOS bootstraps, this means the mobile surface has effectively NO App Check enforcement today. The custom `recordMobileAttestation` verifier is the actual gate, but per the comment in `anchorCommitment` "Full App Attest re-verification of each assertion is Phase 7 / later" — the per-artifact assertion is *carried in the payload* but not actually re-verified on the server today. So today: a mobile-bound caller proves App Attest *once* via `recordMobileAttestation`, then can call `anchorCommitment` from anywhere.

App Attest nonce contract:
- `_issueAttestationNonce` writes a doc to `attestation_nonces` with `expiresAtMs`, `consumed: false`, `uid` binding. Client receives `{ nonce, expiresAtMs }`.
- `_recordMobileAttestation` (verifier in `@plantagoai/attestation`) hashes `SHA-256(utf8(nonce_string))` per the memory note and verifies the App Attest x5c chain.
- Sweeper `cleanupAttestationNonces` runs every 5 min, deletes past expiry. **MED**: nonces are uid-bound and expire, but the consumed-flag enforcement lives inside `@plantagoai/attestation` (not in this repo) — verify out-of-band that single-use is enforced. The nonce sweeper deletes regardless of consumption status, which is fine but means a slow attacker has a window between consumption and sweep where the doc still exists with `consumed: true`.

---

## Solana commitment integrity

Mobile invariant: mobile holds NO Solana keypair. Confirmed: every Solana write in `functions/lib/voting-onchain.js`, `functions/lib/identity-onchain.js`, and `functions/index.js::activateProposal` signs with either `getProgramKeypair()` (shared API wallet) or `getUserKeypair(uid)` (server-custodied per-user wallet from `lib/user-wallet.js`).

Keypair sources:
- `SOLANA_DEVNET_KEYPAIR` Secret Manager secret. Fallback: local file via `SOLANA_KEYPAIR_PATH` env var, but **only when `FUNCTIONS_EMULATOR=true`** — well-gated.
- Per-user keypairs encrypted via GCP KMS (`projects/solanavote-devnet/locations/global/keyRings/foundation/cryptoKeys/user-wallets`), ciphertext stored in Firestore `user_wallets/{uid}` with rule `allow read, write: if false`. Good.

Commitment write path (Phase 2 humanity seal):
1. Mobile calls `anchorCommitment` (Auth-only, App-Check-off). Server re-derives canonical bytes from artifacts, SHA-256s, compares to client-claimed hash. Any mismatch → reject.
2. Server writes Firestore `identity_commitments/{uid}/commitments/{hashHex}` with `status: "queued"`.
3. Server enqueues `anchorIdentityCommitmentTask` via Cloud Tasks.
4. Task handler calls `anchorIdentityCommitmentOnChain` which signs with API wallet. Idempotent: pre-flight PDA-existence check returns `OnChainAlreadyAnchored` with `recordAddress` so a retried task can stamp Firestore without re-minting.
5. On success: stamp `identity_commitments/.../commitments/{hashHex}` AND `users/{uid}.humanityVerified=true` in one batch.

Integrity verdict:
- ✓ Server, not client, computes the on-chain hash.
- ✓ Idempotency on PDA existence — no double-write.
- ✓ DLQ on failure.
- ✗ **MED**: server does NOT re-verify per-artifact App Attest assertions before anchoring (acknowledged in comment). Means a compromised mobile install (App Attest defeated) can submit any artifact set as long as the seal hash matches the artifact bytes. The artifact `signatureBase64` is captured but not validated server-side until "Phase 7 / later". This weakens the chain "device proves it produced these proofs" → "device proves it can compute SHA-256 of these proofs".
- ✗ **LOW**: chain DLQ collection (`chain_dlq`) stores raw payloads, including `payload.uid`. If an admin's HTTP `listChainDlq` token leaks, a snooper sees full per-user task contents. Mitigation: rule already denies client read; HTTP endpoint is admin-key-gated.

---

## Account deletion completeness (GDPR Art. 17)

`account-deletion.js`'s `deleteMyAccount` flow:

1. `deleteUserWallet(uid)` — wipes Firestore `user_wallets/{uid}` and the in-memory cache. **On-chain accounts created by this user remain orphaned** (Solana has no un-deploy). The KMS-encrypted secret key is gone, so nobody can sign for them. ✓ documented in code comments.
2. `deleteUserStorage(uid)` — drops every Storage object under `manual-review/{uid}/`. ✓
3. `deleteAccount(uid, foundationDataMap)` from `@plantagoai/auth`:
   - `voters` (delete by uid)
   - `votes` (anonymize voter_uid)
   - `supporter_signatures` (anonymize voter_uid)
   - `identity_proofs` (delete by voter_id)
   - `manual_review_requests` (delete by voterId)
   - `voting_rounds` (retain)
   - notifications (delete)
   - legal_consents (retain)

**Missing** from the user-data map (residual after a delete-account call):
- **HIGH**: `identity_commitments/{uid}/...` (Phase 2 sealed-artifact docs, including the SHA-256 hashes anchored on-chain). Not in the map. Wipes never happen.
- **HIGH**: `users/{uid}` mirror doc (humanityVerified, biometricPublicKeyB64, biometricKeyRotatedAt). Not in the map.
- **MED**: `flow_snapshots/*` keyed on instanceId == uid. Not in the map.
- **MED**: `support/*` tickets — per design no uid is on the ticket itself, so unrecoverable. ✓ But `support_usage/{uid}` IS keyed on uid and contains a timestamps array. Not in the map.
- **MED**: `sessions` audit collection (uid + email + ip + userAgent). Not in the map.
- **MED**: `pairing_sessions/*` where mobileUid or desktopUid == uid. Not in the map; will be swept eventually by `cleanupStalePairings` only via heartbeat staleness.
- **LOW**: `attestation_nonces` for the uid (auto-swept).
- **LOW**: `tenant_memberships` where `voter_id == uid`. Not in the map.
- **LOW**: `abuse_registry/{voterId}` if previously flagged — by design retained for ban enforcement; would need an explicit GDPR carve-out justification.
- **LOW**: `ai_generation_usage/{uid}` (rate-limit history) and `support_usage/{uid}`. Not in map.
- **CRITICAL/CONCEPT**: `chain_dlq` task payloads referencing `uid`. If an anchor task DLQ'd, the failed payload sits there indefinitely with the user's uid + commitment hash + raw artifacts. Not wiped on account deletion. GDPR-impacting. (No `userField` in the data map can capture this because the DLQ doc id encodes hash, not uid.)
- **NB**: Firebase Auth user record itself — assumed `deleteAccount` from `@plantagoai/auth` handles `admin.auth().deleteUser(uid)`. Not visible in this repo; verify out of band.

Net: account deletion leaks identity-commitment state. Article 17 says "without undue delay" — a sealed humanity verification anchored on-chain is technically a hash, not PII, but `identity_commitments/{uid}/commitments/{hashHex}` is INDEXED BY UID in the Firestore path, so the doc-existence-by-uid alone re-identifies the user post-deletion.

---

## Demo path isolation

`tryDemo` (demo-access.js):
- Mints custom token for shared `DEMO_UID = "demo-user-foundation"`.
- Stamps shared `tenant_id: "foundation-0-0-1"`.
- Pre-creates voter, identity_proofs, tenant_memberships docs.
- Custom claims: `{ ring: 4, role: "voter", demo: true, tenant_id: ... }`.

Isolation status:
- ✓ Demo writes go into the demo tenant (`foundation-0-0-1`).
- ✓ Real proposals are rejected from `cleanupDemoData` even by an admin clicking accidentally (refuses if `demo !== true`).
- ✗ **HIGH**: NO RATE LIMIT on `tryDemo`. Open enumerable callable that issues custom tokens. Per-IP limit zero, App Check disabled. Bot-grindable.
- ✗ **MED**: All demo users share one UID. Anything one demo user does (post a vote, propose anything, leave abusive content) is attributed to all. Plus they can call `submitSupportTicket` with that uid hammering rate limits for the next visitor.
- ✗ **MED**: Demo tenant has full `pillar1: true, pillar2: true, pillar3: true` features. A demo user can hit `castProposalVote` / `createProposalDraft` for non-demo proposals if `tenant_id` happens to overlap (it doesn't today, but the rule allowing free `tenant_id` writes via direct Firestore would let a demo user write proposals into the *default* tenant by direct doc write, bypassing the CF tenant-claim gate).
- ✗ **LOW**: Demo cleanup is documented as "scheduled" but I found no scheduler — only the on-demand `cleanupDemoData` callable. The user's question lists demo-cleanup as something to verify is scheduled. It's NOT scheduled in `cleanup.js` or via `onSchedule` anywhere I can see. Demo state accumulates indefinitely.

---

## DoS / abuse surface

Ranked by attacker-side cost-amplification (highest first):

| Attack | Surface | Gating | Severity |
|---|---|---|---|
| Spam-amplify Resend send budget via `resendInviteLink` | public, App-Check-OFF, rate-limit per email only (3/h std) | sufficient for one email; hostile attacker with many target emails can still spam | MED |
| LLM cost burn via `evaluateProposal` | public, NO auth, App Check on | App Check stops bots without a Foundation app token; a real user can call from inside the app indefinitely (no rate limit on this specific callable) | **HIGH** |
| Drain API wallet via `getMyWallet` | authed, App Check on | per-user idempotent, but per-uid; create N users → drain N × 0.1 SOL | MED (devnet free) → CRITICAL on mainnet |
| Force-rebuild Semaphore groups via `getSemaphoreGroup` cache miss | public HTTP, no auth | rebuild is O(N) over identity_proofs, runs synchronously inside the request; while N small (1 row per verified user) this stays cheap | LOW |
| Spam custom-token mints via `tryDemo` | public, App Check OFF, no rate limit | infinite | MED |
| Spam-mint notifications via `sendNotification` | public-with-auth, no `requireAuth` | NONE | CRITICAL — see callable table |
| Self-proof verifier cycles via `verifyPassportProof` | public HTTP, no auth, no App Check, 60s × 512 MiB | nothing | HIGH |
| Anonymous-vote verifier cycles via `verifyAnonymousVote` | public HTTP, no auth | proof verify ≈ 100ms; nullifier collision check is a Firestore read | MED |
| Spam access-request emails | `requestSelfAccess` | per-email + per-IP throttle (5/h email, 20/h IP) | LOW |

Default Cloud Functions concurrency is 1. Functions like `evaluateProposal` (30s timeout) and `verifyPassportProof` (60s/512MiB) can be saturated cheaply.

---

## Secrets / logging / PII-in-logs

Secrets:
- ✓ `.env` is in `.gitignore`.
- ✓ Solana keypair via `defineSecret("SOLANA_DEVNET_KEYPAIR")` → Secret Manager.
- ✓ `RESEND_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `GMAIL_USER`, `GMAIL_APP_PASSWORD` via `defineSecret`.
- ✗ **MED**: `ADMIN_API_KEY` is `defineString(...)`, not a secret. Currently set in `.env` (`ADMIN_API_KEY=4402964dac8cc1b3e5723b5ae4e81855b453fe6d3987dc85`). It's gitignored, but moving to `defineSecret` puts it under Secret Manager + IAM gating instead of the runtime config bag.
- ✗ **LOW**: `phase2-integration-test.mjs` (committed to repo) embeds the Firebase web API key (`AIzaSyCn4HuYiyW1N6O3FfM9f30hia_saHike5U`). Web API keys are public-by-design in Firebase, but committing one with Admin-SDK code that mints custom tokens for arbitrary uids creates a misleading file: if the test ever ran outside dev, it would mint a custom token for `dagan.gilat@gmail.com`. Not exploitable as-is (needs admin SDK creds) but a confusing artifact.
- ✗ **LOW**: `JWT_SECRET=0e17f93cb3...` in `.env`. Comment says "Must match JWT_SECRET in evoting-rocket-server (deleted in migration Phase 4)". If Rocket is gone, JWT_SECRET is dead config — leftover surface that no longer needs to be a shared secret.

PII in logs:
- `sendMail` logs `Email sent to ${to}` — full target email address (index.js:287). Cloud Logging retains 30d default.
- `mintWebSessionToken` logs uid on failure (index.js:3520).
- `verifyPassportProof` logs the full `result.isValidDetails` on rejection (index.js:1212–1215). Self's `isValidDetails` may include nationality/age fields. Worth verifying upstream.
- `recordMobileAttestation` logs `msg` from verifier including nonce values (index.js:2442). Nonces are intentionally non-PII but worth confirming.
- All other console calls log only ids/codes, no PII.

`request_logs` collection (per `cleanupOldRequestLogs`) holds `{ status, method, path, duration_ms, source_ip, voter_id, timestamp }` with 30-day retention. **MED**: `voter_id` + `source_ip` is a re-identification pair stored in cleartext.

`sessions` collection has `{ uid, email, site, userAgent, ip, ts }` retained 90 days. **MED**: also re-identification pair stored.

These contradict the privacy policy at `legal.js:51–55` which lists `dataNotCollected` as `[name, date_of_birth, biometric_raw_data]` and elsewhere claims `dataCollected = [document_hash, votes, wallet_address, anonymous_hash]`. Neither IP nor email appears in the disclosed-collection list. **HIGH (compliance)**: privacy notice misalignment with actual logging.

---

## Severity-ordered findings

### CRITICAL

1. **`sendNotification` has NO `requireAuth` gate** — `functions/index.js:1769`. Any caller (with App Check) can write a notification doc for ANY userId with arbitrary title/body. Phishing + spam channel.
   *Fix*: Add `await requireAuth(request)` at top, validate `userId == auth.uid` (self-only) OR gate creator on a ring/role permission for cross-user notifications. Today there is no legitimate cross-user use case visible in the call sites.

2. **`evaluateProposal` has NO `requireAuth` gate** — `functions/index.js:696`. Callable burns Anthropic Claude / Gemini tokens. App Check stops bots without a valid Foundation token, but any installed-app user can hammer it indefinitely. No rate-limit on this specific callable (the rate-limit lives only in `generateProposalDraft`).
   *Fix*: Add `requireAuth` and reuse the `checkGenerateProposalRateLimit` pattern (or share one budget across the two AI callables).

### HIGH

3. **Firestore rules: `proposals` / `votes` / `supporter_signatures` / `voters` / `tenants` / `tenant_memberships` allow any authed user to write** — `firestore.rules:19–125`, `185–200`. CFs (`castProposalVote`, `castProposalSupport`, `createProposalDraft`, `createVoterAccount`) are now the canonical writers, but the rules never tightened, so direct client writes still bypass dedup, anonymous-hash derivation, and tenant gating. The "Phase 0 hotfix" comment promises Phase 2 tightening; that has not happened.
   *Fix*: Flip writes to `if false` for those collections. Audit the frontend for any remaining client-direct writes and migrate them to the CFs first, then deploy the rules.

4. **App Check carve-outs cover the entire mobile surface** — `index.js:2401, 2411, 2584, 3072, 3443, 3506, 3560, 3621, 3641, 3670`. With ENFORCE_APP_CHECK=true at the global level, every active mobile callable opts out. Effectively no App Check defense for mobile today. The custom CBOR verifier is sound, but per-artifact App Attest assertions in `anchorCommitment` are NOT re-verified server-side ("Phase 7 / later"). A mobile install that defeats App Attest once can submit forever.
   *Fix*: Wire per-artifact App Attest assertion verification in `anchorCommitment` (compare each artifact's `signatureBase64` against the stored `mobile_credentials/{uid}` keyId). Then schedule pulling the App Check carve-outs once iOS App Attest is fully wired (per the in-code comments).

5. **`verifyPassportProof` is an unauthenticated public HTTP endpoint** — `functions/index.js:1164`. CORS `*`, no auth, no App Check, 60s × 512 MiB. Spam-amplifies cost.
   *Fix*: Add an App Check gate (Self mobile app already attests; if Self mobile can't carry App Check, add per-IP rate limit + 1-RPS cap).

6. **`verifyAnonymousVote` is an unauthenticated public HTTP endpoint** with Semaphore proof verification per call — `functions/index.js:1533`. CPU-heavy (~100ms/call). Same fix.

7. **`tryDemo` has NO rate limit** — `functions/demo-access.js:28`. Public + App-Check-OFF + custom-token mint per call. Bot-grindable.
   *Fix*: Add per-IP sliding-window throttle (reuse `checkAndRecordRate` pattern) and possibly captcha / reCAPTCHA Enterprise score gate.

8. **GDPR Art. 17 data-deletion is incomplete** — `functions/account-deletion.js`. `foundationDataMap` does not cover `identity_commitments/{uid}`, `users/{uid}`, `flow_snapshots`, `sessions`, `support_usage`, `pairing_sessions`, `tenant_memberships`, `chain_dlq` payloads. The hash-uid binding under `identity_commitments/{uid}/commitments/{hash}` is the most important: that path encodes the user identity even after the doc body is rewritten/anonymized.
   *Fix*: Extend `foundationDataMap` with all of the above (or add explicit subcollection cleanups in `deleteMyAccount` like `deleteUserStorage`).

9. **Privacy policy misalignment** — `functions/legal.js:51–55` declares only `[document_hash, votes, wallet_address, anonymous_hash]` collected and explicitly NOT `[name, date_of_birth, biometric_raw_data]`. Actual collection includes email (sessions, mail), IP (sessions, request_logs), userAgent (sessions). Compliance gap.
   *Fix*: Update privacy policy to list email/IP/userAgent OR drop them from `sessions`/`request_logs` (likely better for the trust story). Note that the mobile app's `Submit Support Ticket` already correctly enforces no-PII — the desktop session logging breaks the same invariant.

### MEDIUM

10. **Tenant admin → platform owner via `setUserAccess`** — `functions/user-management.js:116`. Ring-1 admin can call `setUserAccess({ ring: 0 })` on themselves or anyone. No "cannot elevate above your own ring" guard.
    *Fix*: `if (Number.isInteger(ring) && ring < callerRing) throw permission-denied`. Also apply to `role` if certain roles imply elevated capability.

11. **App Attest per-artifact assertion not verified at anchor time** — `functions/index.js:2583`. The seal hash check is sound, but the per-artifact App Attest `signatureBase64` is captured-but-not-validated. A device whose App Attest is one-off compromised can keep submitting forever.

12. **Open `tenants` / `tenant_memberships` rules** — listed under HIGH-3 but split out because the impact differs: tenant config tampering vs vote spoofing.

13. **Demo path: shared UID + open features** — `demo-access.js`. Combined with open `tenants.update` rule (HIGH-3), demo users can corrupt the demo tenant or use direct Firestore writes to spill into the default tenant. *Fix*: tighten via HIGH-3 + add per-IP throttle on `tryDemo`.

14. **Demo cleanup is not scheduled** — `cleanupDemoData` is on-demand only. State accumulates. *Fix*: add `onSchedule` wrapper that runs `cleanupDemoData({mode:"all"})` against the demo tenant nightly.

15. **`getMyWallet` auto-funds API wallet drain** — `functions/index.js:2354` + `lib/user-wallet.js:128`. Per-user 0.1 SOL airdrop. Currently devnet-free; flips to real-money on mainnet. *Fix*: rate-limit per-IP / require an explicit "I want a wallet" UX action; defer wallet creation to first write op rather than first read.

16. **`request_logs` / `sessions` retain `voter_id + IP` pairs** — `cleanup.js:42, 54`. 30 / 90-day retention. Compliance alignment per HIGH-9. Either reduce retention (e.g. 7 days) or drop the IP field entirely.

17. **`ADMIN_API_KEY` is `defineString` not `defineSecret`** — `functions/admin-status.js:11`, `chain-dlq.js:30`. Static API key in env config.
    *Fix*: switch to `defineSecret`, store in Secret Manager, rotate.

18. **`adminStatus` HTTP CORS `*`** — `functions/admin-status.js:31`. The endpoint is admin-key-gated, but a leaked key from any origin works. *Fix*: lock CORS to known admin-tool origins.

19. **`resendInviteLink` no per-IP rate limit** — `functions/index.js:3064`. Per-email yes, per-IP no. *Fix*: add IP throttle the same way `requestSelfAccess` does.

20. **Storage rule allows `image/svg+xml`** — `storage.rules:23`. SVG = arbitrary HTML/JS for any UI that ever inlines. *Fix*: tighten regex to `image/(jpeg|png|heic|webp)`.

21. **Per-user Storage object count unbounded** — `storage.rules:16`. 5 MB cap per file but no per-user file-count limit. *Fix*: app-side cleanup of prior submissions (already done in `approveManualReview` and `deleteManualReviewStorage`); add a hard ceiling check on count via a CF that watches Storage events.

22. **`identity_commitments/.../commitments` doc uid in path = re-identification under deletion** — Already covered under HIGH-8.

23. **Demo tenant cross-write via direct Firestore** — direct `tenants.update` lets a demo user rewrite the demo tenant. Subset of HIGH-3 but worth flagging the demo-path-specific blast radius.

### LOW

24. **`logSession` stores email + uid + IP** — see HIGH-9.
25. **`users/{uid}/legal_consent/{docId}` self-write** — see Firestore findings table. Legal trail under that doc is self-reportable.
26. **Phase2 integration test embeds web API key + admin email** — `functions/phase2-integration-test.mjs`. Web API keys are public; the file is fine to commit as a test, but pair it with a CI-only marker so it can't be confused for a prod helper.
27. **Stale `JWT_SECRET` in `functions/.env`** — Rocket is gone; the secret is dead config.
28. **`isAdmin()` defined after first use in firestore.rules** — cosmetic, no security impact.
29. **Wikidata population lookup logs candidate labels** — `functions/index.js:507`. Public-data only; mentioned for completeness.
30. **No HTTP `enforceAppCheck` available on `onRequest`** — that's a Firebase-platform constraint, but worth noting `verifyPassportProof`, `verifyAnonymousVote`, `getSemaphoreGroup`, `adminStatus`, `listChainDlq` all run unprotected at the App Check layer.
31. **`cleanupAttestationNonces` deletes regardless of `consumed`** — `cleanup.js:68`. Consumption check lives in the verifier package; the sweeper just GC's expired docs. Verify single-use enforcement is in `@plantagoai/attestation`.

---

## Concrete remediation list (priority order)

1. Add `requireAuth` to `sendNotification` and `evaluateProposal`. Add per-uid budget to `evaluateProposal`. (CRITICAL)
2. Lock the open Firestore rules — `proposals`, `votes`, `supporter_signatures`, `voters`, `tenants`, `tenant_memberships`, `voting_rounds`, `funds`, `distributions`, `product_requests` — to `if false` after verifying frontend has migrated to CFs. (HIGH-3)
3. Add `requireAuth` / App Check to `verifyPassportProof` and `verifyAnonymousVote`, OR add per-IP rate-limit + cap concurrency. (HIGH-5/6)
4. Add per-IP rate limit to `tryDemo`. (HIGH-7)
5. Extend `foundationDataMap` (or add explicit subcollection cleanups) to cover `identity_commitments`, `users`, `flow_snapshots`, `sessions`, `support_usage`, `pairing_sessions`, `tenant_memberships`. (HIGH-8)
6. Update privacy policy or drop email/IP/userAgent fields from `sessions`/`request_logs`. (HIGH-9)
7. Wire per-artifact App Attest assertion verification in `anchorCommitment`. (MED-11)
8. Add "cannot elevate above your own ring" guard in `setUserAccess`. (MED-10)
9. Schedule `cleanupDemoData` nightly. (MED-14)
10. Switch `ADMIN_API_KEY` to `defineSecret`. (MED-17)
11. Tighten Storage `contentType` regex to exclude SVG. (MED-20)
12. Drop the App Check carve-outs on mobile callables once iOS App Attest is fully wired (already tracked in code comments). (HIGH-4)
13. Remove dead `JWT_SECRET` from `functions/.env`. (LOW-27)
