# Cryptography & Attestation Audit — 2026-04-26

## Scope

Audit covers cryptographic plumbing on the Phase 1 (App Attest) → Phase 2 (anchor commitment) → Phase 7 (enclave seal) → Solana anchor pipeline, plus desktop pairing and the MOPRO smoke test. Repos audited:

- `foundation-mobile-claude/ios/FoundationMobile/` — Swift client
- `foundation-global/functions/` — Cloud Functions
- `shared/packages/attestation/src/` — `@plantagoai/attestation` (Apple verifier + nonce store)
- `foundation-mobile-claude/mopro-smoke/` — Sprint-0 MOPRO/Circom smoke

Out of scope: Solana program internals (the Anchor program source itself), Self circuit (Phase 3b), the embedded WebView session bridge (mintWebSessionToken called out where it touches pairing freshness).

---

## Per-question analysis

### 1. App Attest nonce/challenge contract

**Memory line is correct, code matches.**

Client side, `AttestationService.swift:41` computes:
```swift
let clientDataHash = Data(SHA256.hash(data: Data(nonce.utf8)))
```
The string is treated as opaque UTF-8, fed straight into SHA-256. No base64-decode attempted. The comment block at lines 35–39 explicitly captures the rationale.

Server side, `shared/packages/attestation/src/server.ts:164`:
```ts
challenge: Buffer.from(req.nonce),
```
`Buffer.from(<string>)` defaults to UTF-8. Then in `verify-apple.ts:118`:
```ts
const clientDataHash = createHash('sha256').update(input.challenge).digest();
```
Same SHA-256 over UTF-8 bytes of the base64url nonce. Apple's expected nonce is then `SHA-256(authData || clientDataHash)` (`verify-apple.ts:119–122`), which is what gets compared against the OID 1.2.840.113635.100.8.2 extension on the credCert. **This is correct and matches the documented contract.**

**Nonce shape, TTL, replay properties:**

- `issueNonce` (`server.ts:52–68`): 32 bytes from `randomBytes`, base64url-encoded → 43 char string. Per-uid Firestore doc at `attestation_nonces/{nonce}` with `{ uid, issuedAtMs, expiresAtMs, consumed }`. **TTL is 15 minutes** (`index.ts:28`, `NONCE_TTL_MS = 15 * 60 * 1000`).
- `consumeNonce` (`server.ts:74–96`): atomic Firestore transaction — `nonce/not-found`, `nonce/uid-mismatch`, `nonce/already-consumed`, `nonce/expired` are all distinct errors. Sets `consumed: true` inside the transaction before returning. **One-shot consumption is correctly enforced.**
- Cleanup runs every 5 min with a 1-min grace (`functions/cleanup.js:68–78`).

**Reuse / replay analysis:**

- *Same-user replay of a captured nonce+attestation:* the `consumed: true` flag inside the transaction blocks this — second attempt throws `nonce/already-consumed`.
- *Cross-user replay:* `consumeNonce` checks `data.uid !== uid` → `nonce/uid-mismatch`. A nonce issued for user A cannot be consumed by user B.
- *Pre-issued bulk nonces:* not exploitable beyond the 15-minute TTL window; the App Attest CBOR also embeds the nonce in the credCert extension at attest time, so a pre-fetched nonce that is then consumed for a fresh attest is by definition the legitimate use case.
- *DoS via nonce exhaustion:* there is **no rate limit** on `issueAttestationNonce` — an authenticated user could fill `attestation_nonces` collection between cleanup sweeps. Severity is low (nonces are 43-byte doc IDs, sweep every 5 min, requires a valid Firebase Auth uid). Worth tracking but not exploitable.

**Issue 1.A (LOW):** No rate limit on `issueAttestationNonce`. Add a per-uid throttle (e.g. ≤ 5 outstanding unconsumed nonces, or ≤ 20/hour) to bound abuse.

---

### 2. EnclaveSeal commitment

**Determinism:**

`EnclaveSeal.seal` (`EnclaveSeal.swift:21–34`):
```swift
let sorted = artifacts.sorted { $0.kind.rawValue < $1.kind.rawValue }
var buffer = Data()
for artifact in sorted {
    buffer.append(artifact.canonicalBytes())
    buffer.append(0x0a)
}
let hash = Data(SHA256.hash(data: buffer))
```

`ProofArtifact.canonicalBytes()` (`ProofArtifact.swift:25–28`):
```swift
let line = "\(kind.rawValue):\(producedAtMs):\(payloadHashHex):\(signatureBase64)"
return Data(line.utf8)
```

This is deterministic provided three things hold — and they do, with one caveat:

1. Sort by `kind.rawValue` (lex-asc on Swift's String comparison) is stable. The five rawValues are `appAttest, antiSpoof, faceMatch, liveness, nfcZk`, all ASCII-only, so Swift String < and JS string < (`functions/index.js:2499`) agree byte-for-byte. **Confirmed matching server logic at `functions/index.js:2494–2507`.**
2. **Not Codable JSON** — the contract uses a custom textual line format, not `JSONEncoder`. This is the right call: Swift `JSONEncoder.OutputFormatting.sortedKeys` is iOS 11+ but the contract avoids the question entirely by hand-rolling the encoding. **Good.**
3. The format is **non-self-delimiting in the presence of a `:` inside a field**. `kind.rawValue` is enum-bounded so safe; `producedAtMs` is integer; `payloadHashHex` is `[0-9a-f]{64}` (server enforces this at `index.js:2491`); `signatureBase64` is base64-encoded App Attest assertion — **standard base64 contains no `:` either, so this is safe**. *However*, server-side validation (`index.js:2639–2641`) only checks `signatureBase64` is a non-empty string with no character-set or length cap. A producer that emitted a base64 string containing `:` would not be rejected, would canonicalize ambiguously, and the canonical-bytes check would still pass since both sides use the same emitter. So no exploit here, just a minor robustness gap.

**Issue 2.A (LOW):** Server should validate `signatureBase64` matches `^[A-Za-z0-9+/=]+$` and length-cap (e.g. ≤ 1024). Today only emptiness is checked (`index.js:2639–2641`). Defense in depth.

**Sort order matches client/server.** Client sorts by `kind.rawValue` (`EnclaveSeal.swift:22`); server sorts by the same string field (`index.js:2499`). Lowercase ASCII so byte-identical compare.

**SHA-256 binding:**

The server **re-derives** canonical bytes from the submitted `artifacts` array and rejects on mismatch (`index.js:2645–2656`):
```js
const derivedHashHex = crypto.createHash("sha256").update(canonical).digest("hex");
if (derivedHashHex !== commitment.hashHex) { throw "seal-mismatch"; }
```
This is the right shape: client commits to a hash, server recomputes and refuses to anchor a hash it can't reproduce. Good.

**Secure-Enclave signature binding:**

CRITICAL FINDING. The **Phase 7 Secure Enclave signature is not actually used for the anchor submission today.** Re-reading `CaptureCoordinator.submitAnchor` (`CaptureCoordinator.swift:567–606`):

```swift
let req = AnchorCommitmentRequest(
    commitment: ...,
    artifacts: artifacts.map { ... },
    biometricSeal: nil   // <-- always nil, see comment at line 570
)
```

The `biometricSeal` sidecar — the only field that would carry the Secure-Enclave-bound ECDSA signature over `commitment.hashHex` — is hardcoded to `nil` in this call site. The comment at lines 570–579 explains that the per-session entry-gate Face ID prompt was deemed sufficient and per-artifact biometric seals are deferred. Server-side `index.js:2715–2724` accepts a missing seal as a soft signal:
```js
const sealSidecar = sanitizeBiometricSeal(biometricSeal);
// commitment itself is still cryptographically protected by the seal
// hash and per-artifact App Attest assertions, so a missing biometric
// seal is a soft trust signal, not a precondition.
```

**What binds the user to the commitment today, then?**

1. `requireAuth(request)` at `index.js:2586` — Firebase Auth uid is the only binding to identity.
2. The per-artifact App Attest assertion (`signatureBase64`). Each artifact carries an assertion produced by `DCAppAttestService.generateAssertion` over `SHA-256(payloadHashHex bytes)` (`ProofArtifact.swift:50–55`). However, this is signed using the *device-bound* App Attest key, not a user-bound key. **The same physical phone re-signed in as a different uid would produce identical-looking assertions** — they bind device authenticity to uid only via the Firebase Auth context the request was made in.
3. The commitment hash itself contains no uid. The Solana PDA seed is just `["commitment", hash_bytes]` (`identity-onchain.js:30, 64–67`) — **identical commitments from two different uids would collide on-chain, and the second would fail with `OnChainAlreadyAnchored`.**

**Issue 2.B (HIGH — design gap):** "Secure-Enclave signature binds the user and the commitment" is **false** as currently shipped. `submitAnchor` always sends `biometricSeal: nil`. The Phase 7 EnclaveSeal step is not signed by any Secure-Enclave-bound key today; the only cryptographic per-request gate is the Firebase Auth ID token. The intent in `BiometricSealer.swift:25–28` ("CaptureCoordinator.submitAnchor signs commitment.hashHex … signature + public key flow as sidecar fields") is documented but not wired. Decide: either (a) flip the call site to actually sign and ship the seal, or (b) update `BiometricSealer.swift` doc comment + the architecture doc to say the seal is gated on a future iteration.

**Issue 2.C (HIGH — uid binding):** Even if the biometric seal were sent, neither the canonical bytes nor the on-chain PDA encode the uid. Two uids can produce the same commitment hash (e.g. both running mocks; both hitting the same time-step somehow); first one wins, second is `OnChainAlreadyAnchored`. Mitigation: include `uid` (or a salted derivative) in `canonicalBytes()`, OR seed the PDA with `[uid, hash]`, OR accept the current trust model and document that the on-chain record is uid-anonymous by design. The Firestore audit trail (`identity_commitments/{uid}/commitments/{hash}`) stores uid, but the chain does not — by design, per `identity-onchain.js:6–7` ("no user identifier on-chain"). Worth surfacing as an explicit threat-model note.

---

### 3. Solana commitment write

**Server-side derivation:** `index.js:2645–2656` re-derives canonical bytes from submitted artifacts and rejects on hash mismatch. The hash that goes on-chain (`identity-onchain.js:84` → `program.methods.anchorCommitment(Array.from(hashBytes))`) is the client-claimed hash, but only after the server has verified it is reproducible from the artifact array. **OK.**

**Idempotency / replay:**

- Per-uid Firestore doc keyed by hash (`index.js:2666–2698`). On re-submit:
  - `status === "anchored"` → return stored receipt (idempotent success).
  - `status === "queued"` → return queued status without re-enqueue.
  - `status === "anchor-failed"` or legacy `"anchor-not-wired"` / `"pending"` → fall through, overwrite, re-enqueue. **Note:** this allows a client to retry by re-submitting the same artifact array. That's the intended UX (recover from a DLQ failure). Safe because the seal-mismatch check still gates.
- On-chain idempotency: PDA seeded by `["commitment", hash]` (`identity-onchain.js:30, 64–67`) means the **second** anchor of the same hash from any uid throws `OnChainAlreadyAnchored`. The task handler at `on-chain-tasks.js:410–420` adopts the existing PDA address and stamps Firestore. **Cross-uid replay caveat is what 2.C noted.**

**Signer separation:**

Signer is `getProgramKeypair()` (`solana.js:94–117`), loaded from Secret Manager in prod, with a fallback to a local file path that is **gated on `FUNCTIONS_EMULATOR === "true"`** (`solana.js:105`). **Good.** Mobile holds no keypair — confirmed by `SolanaRPC.swift:6` ("Mobile never signs or submits on-chain transactions").

**Issue 3.A (MEDIUM — observability):** When `OnChainAlreadyAnchored` fires with a non-null `recordAddress` but null tx signature, the doc gets stamped with `txSignature: null` (`on-chain-tasks.js:410–416, 437`). This is a legitimate adoption path but it loses the original tx signature — a future audit can't retrieve the on-chain anchoring tx for that record. Minor; consider RPC `getSignaturesForAddress` lookup at adoption time to backfill.

---

### 4. BiometricSealer — Secure Enclave seal

**Key generation (`BiometricSealer.swift:160–193`):**
- ECC P-256, `kSecAttrTokenIDSecureEnclave` — key is hardware-bound. **Good.**
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — does not migrate to a new device on backup restore. **Good.**
- Access control flags: `[.privateKeyUsage, .biometryCurrentSet]` — **the right choice for the threat model.** `.biometryCurrentSet` (vs `.biometryAny` or `.userPresence`) means:
  - The key is **invalidated by the OS** when the user enrolls a new face / touches in a new fingerprint. A thief who unlocks the phone via screen passcode and adds their own face cannot use this key — `SecKeyCreateSignature` returns `errSecAuthFailed`.
  - `.userPresence` would have allowed passcode fallback (worse), `.biometryAny` would have allowed any current biometric set (not durable to re-enrollment).

**What it seals:** today, in CaptureCoordinator, **nothing** (always sends `biometricSeal: nil` per Issue 2.B). When wired, it signs `commitment.hashHex` UTF-8 bytes via `.ecdsaSignatureMessageX962SHA256` (`BiometricSealer.swift:107–112`), which hashes the payload internally. Public key is shipped per-request as SEC1 X9.63 uncompressed (`BiometricSealer.swift:70–80`) and lazily registered server-side at `index.js:2533–2558`.

**Re-enrollment behaviour:**
- Key is invalidated by the OS → `SecKeyCreateSignature` returns `errSecAuthFailed` (-25293) → mapped to `BiometricSealError.keyInvalidated` (`BiometricSealer.swift:202–211`). Caller is expected to call `resetKey()` and prompt the user to re-enroll on the next sealing attempt.
- **Server side**, `maybeRegisterBiometricKey` (`index.js:2533–2558`) does NOT replace the registered key on rotation. It records `biometricKeyRotatedAt` + `biometricKeyRotationCandidate` for ops to triage. The comment at lines 2528–2532 explicitly calls out the "stolen-then-re-enrolled device" attacker. **Good design.**

**Issue 4.A (MEDIUM — documentation drift):** `BiometricSealer.swift:25–28` documents that this is wired into `CaptureCoordinator.submitAnchor`, but it is not (Issue 2.B). Two action items:
- Either fix the call site to send the seal (recommended; the BiometricSealer code is correct and the Face ID prompt at the entry gate is documented as the "humanity commitment" UX moment in `HomeView.beginVerifyHumanity`).
- Or update the doc comment to "wired in a future iteration".

**Issue 4.B (LOW):** `signedAtMs` in `BiometricSealPayload` is wall-clock `Date()` from the client; server-side `sanitizeBiometricSeal` accepts it without bounds-checking (`index.js:2515–2524`). Server should reject seals with `signedAtMs > now + skew` or `signedAtMs < now - 24h` once the seal becomes verification-bearing, to prevent pre-signed seals being banked.

---

### 5. Replay protection on `recordMobileAttestation` and `anchorCommitment`

**`recordMobileAttestation`:** strong replay protection.
- Server-issued nonce embedded in the Apple App Attest CBOR via the credCert nonce extension (`verify-apple.ts:106–125`). The nonce is `SHA-256(authData || SHA-256(utf8(req.nonce)))` per Apple's spec.
- Server consumes the nonce in a transaction (`server.ts:74–96`) — second use throws `nonce/already-consumed`.
- 15-minute TTL bounds replay window even if a nonce escapes.
- Per-uid binding (`nonce/uid-mismatch`).

**Verdict: solid, multi-layer.**

**`anchorCommitment`:** **weak replay protection — there is no per-call nonce.**
- The callable is gated only on `requireAuth` and the seal-mismatch check.
- There is **no server-issued nonce embedded in the request payload**. There is no timestamp check on `commitment.producedAtMs` or any of the artifact `producedAtMs` fields beyond `Number.isFinite`.
- The per-artifact App Attest `signatureBase64` is signed over `SHA-256(payload)` — i.e. over the artifact contents, not over a server-issued challenge for *this* anchor call. Today these assertions are **not actually verified server-side at this callable** (`index.js:2566–2582` calls them "Layer 3" but the verification is only stub-described — there is no call into `@plantagoai/attestation` to verify each assertion against the stored credential).

**Walkthrough of a replayable failure mode:**

Step 1. Attacker MITMs (or extracts from a rooted device, or from device backups, etc.) one legitimate anchorCommitment payload from Alice — `{commitment, artifacts}` — at time T.

Step 2. Attacker re-submits the exact same payload to anchorCommitment with Alice's still-valid Firebase Auth ID token at time T+5min (say, user is still signed in). Server flow:
- `requireAuth` passes.
- Shape validation passes.
- Re-derived canonical bytes match `commitment.hashHex` (deterministic).
- Firestore lookup at `identity_commitments/{uid}/commitments/{hashHex}` finds the existing doc with `status === "anchored"`. Returns the stored receipt.
- **Result: idempotent success, no side effect. NOT exploitable.**

Step 3. What if Alice's commitment had `status === "anchor-failed"`? Then the replay falls through to overwrite + re-enqueue. The replay reuses the same artifact array (which is what was sealed), produces the same hash, re-attempts the on-chain anchor. Since the commitment hash is uid-keyed in Firestore but PDA-keyed by hash on-chain, a successful retry simply lands the previously-failed commitment. **Net effect: legitimate retry. NOT exploitable.**

Step 4. What about replaying Alice's payload **from a different uid B**? Server stamps the doc under `identity_commitments/{B}/commitments/{hash}` (uid taken from `requireAuth`, not from the payload). The on-chain anchor attempt fails with `OnChainAlreadyAnchored` (PDA already exists from Alice's prior anchor). Task handler stamps B's Firestore doc with the existing record_address and `txSignature: null` (`on-chain-tasks.js:410–420`). **Result: B is now flagged `humanityVerified: true` on-chain via Alice's commitment.** The user-doc fast-path flag (`on-chain-tasks.js:444–450`) is set on B without B ever performing the verification flow.

**Issue 5.A (HIGH — replay of commitment across uids):** A captured `(commitment, artifacts)` payload from user A can be replayed by user B (with B's own auth token) to gain `humanityVerified: true` on B's user doc. The replay is detected on-chain (`OnChainAlreadyAnchored`) but the handler currently **adopts** the existing PDA and stamps B's Firestore record as success. The PDA owner (`authority`) is the program signer keypair, so on-chain ownership is uniform; only the *Firestore mapping* is per-uid, and the task handler builds that mapping from the second submitter's uid.

**Mitigations:**
1. The strongest fix: include `uid` in `canonicalBytes()` so a payload sealed by A has hash H_A which a B-replay would re-derive to a different hash H_B (failing seal-mismatch). This requires updating the Phase 7 spec — `canonicalBytes()` becomes uid-bound and the artifact format gains a uid line. *This is the recommended fix and matches the architectural framing.*
2. Alternatively, in the task handler when adopting an existing PDA: refuse to stamp a new uid as anchored if the existing on-chain record was anchored on behalf of a different uid (look up the prior `identity_commitments/*/commitments/{hash}` doc; if it exists for a different uid, error out instead of adopting).
3. Alternatively, seed the PDA with `[uid_bytes, hash]` so two uids producing the same hash get distinct on-chain records. Loses the global hash-uniqueness property but eliminates this attack outright.

**Issue 5.B (MEDIUM — commitment-bound assertion missing):** The per-artifact `signatureBase64` is described as "binds every artifact to the specific Foundation Mobile install" (`index.js:2575–2576`), but **the server does not actually verify these assertions** at `anchorCommitment` time (no call into `verifyAssertion`/`@plantagoai/attestation` for the per-artifact signatures). The comment is aspirational — the layer it describes is not active. Either wire the verification (using the stored credential at `identity_proofs/{uid}/mobile_attestations/`) or update the comment to match reality.

**Issue 5.C (MEDIUM — no anchorCommitment freshness gate):** `anchorCommitment` does **not** call `ensureFreshPairingAuth(request)` and has no `producedAtMs` freshness check. A signed payload from a months-old session can be re-anchored if the prior status was `anchor-failed`. Recommend adding: reject if `commitment.producedAtMs < now - 24h` (the seal has a short legitimate lifetime — the user verified moments ago).

---

### 6. MOPRO smoke / Track B

**Files reviewed:** `mopro-smoke/Cargo.toml`, `mopro-smoke/src/lib.rs`, `mopro-smoke/src/circom.rs`, `MoproSmokeBridge.swift`.

- The smoke test exposes exactly two surfaces: `mopro_smoke_hello() -> String` and `generate_circom_proof(zkey_path, circuit_inputs, proof_lib) -> CircomProofResult`. Both are stock mopro-ffi exports for the `multiplier2` circuit (a*b=c). The bridge `MoproSmokeBridge.swift:46–74` is gated on `#if MOPRO_LINKED` — if the xcframework isn't built, the call returns `.skipped`. **Good.**
- Inputs are passed as a JSON string (`"{\"a\":\"3\",\"b\":\"4\"}"`). Errors are surfaced via `do/catch` on the throwing FFI; panics on the Rust side (e.g. malformed zkey) propagate as UniFFI errors. There is no `panic = abort` configuration for the iOS staticlib, so a Rust panic should unwind into Swift as a generic error, not crash the host. UniFFI does not bake in panic-safety at the boundary by default; **when the real circuit lands, audit the panic-handling story** (UniFFI's `convert_unwind_safe` or explicit `catch_unwind` wrappers).
- The zkey is bundled in the app (loaded via `Bundle.main.url(forResource: "multiplier2_final", ...)`). The bundled zkey is the **proving key** — confidential is moot for Groth16 proving; verifying keys + tau-trusted-setup are public. **No leak risk.**
- The `circom.rs` module is sourced from `mopro-cli init --adapter circom` (per the comment) — no Foundation-custom code. Risk surface is bounded by upstream `mopro-ffi 0.3.5` + `circom-prover 0.1` + `rust-witness 0.1`. **Worth re-auditing once the real circuit replaces multiplier2 — circuit constraints are where Phase 3 security actually lives.**
- The bridge does not log or persist proof inputs/outputs — `result.inputs` is just bubbled up to the UI (`HomeView`'s MOPRO row). **OK.**

**Issue 6.A (LOW — track B forward):** When swapping to the real NFC-bound circuit, ensure the circuit-input JSON is generated server-side or from sanitized inputs. A user-controlled JSON string passed to a future zk circuit is not exploitable in itself (proofs are still sound) but it is a frequent source of integrator bugs (off-by-one in input ordering, missing a public input, etc.). Add a typed Swift wrapper rather than the raw string used by the smoke.

No exploits in the smoke. **Track B unblocked claim is sound.**

---

### 7. ProofArtifact frozen contract

The shape on `ProofArtifact.swift:9–29` matches the CLAUDE.md spec exactly:
```swift
struct ProofArtifact: Codable, Sendable, Equatable {
    enum Kind { case appAttest, nfcZk, liveness, antiSpoof, faceMatch }
    let kind: Kind
    let producedAtMs: Int64
    let payloadHashHex: String     // lowercase hex SHA-256
    let signatureBase64: String    // App Attest assertion
}
```

**Producers:**

- `ProofArtifactBuilder.build` (`ProofArtifact.swift:42–63`) — the canonical builder. Computes `SHA-256(payload)`, hex-encodes, and signs via App Attest assertion. **Honors the contract.**
- `PassportNfcProducer` (`PassportNfcProducer.swift:15–32`) — calls `ProofArtifactBuilder.build`. **Honors.**
- Mock producers (`MockProofProducers.swift:60–70`): emit `signatureBase64: "mock:<tag>"`. **Violates the documented intent that signatureBase64 is an App Attest assertion** — but this is intentional and called out in the file's own header comment (`MockProofProducers.swift:7–13`). Server-side, the seal-mismatch check still passes (mocks contribute to canonical bytes deterministically), and a future `ENFORCE_APP_CHECK` flip is intended to reject by shape.
- `LivenessFrameProducer` / `AntiSpoofProducer` / `FaceMatchProducer` — all (per CaptureCoordinator inspection) flow through `ProofArtifactBuilder.build`. **Honor.**

**Drift between doc and code:**

- CLAUDE.md says `payloadHashHex` is "lowercase hex SHA-256" — the Swift formatter `String(format: "%02x", $0)` (`ProofArtifact.swift:51`) emits lowercase. Server validates `^[0-9a-f]{64}$` (`index.js:2491, 2633`). **Aligned.**
- CLAUDE.md says `signatureBase64` is "App Attest assertion" — true for real artifacts, falsely true for mocks. Mocks emit `"mock:<tag>"` literally, which is **not valid base64** (the `:` is not in the base64 alphabet). This is detectable by a stricter server-side validator and is the load-bearing escape hatch when `ENFORCE_APP_CHECK` flips on. **Document this contradiction explicitly in CLAUDE.md** — readers might assume mocks emit base64-shaped placeholders.

**Issue 7.A (LOW — doc/code divergence):** Update `ProofArtifact.swift` doc comment (or CLAUDE.md) to note that mock producers emit a non-base64 sentinel `mock:<tag>` to enable server-side shape rejection once enforcement flips.

---

### 8. Custom claims & ring uplift

**What signs the ring tier uplift:**

- `ring` is a custom claim on the Firebase Auth user record. Set only by:
  - Admin via `setUserClaims` (`user-management.js:114–171`) — caller must hold `Ring.TENANT_ADMIN` (per `user-management.js:120` — *not shown but inferred*, confirmed by the import of `requireRing`).
  - The invite flow's `beforeUserCreated` and `beforeUserSignedIn` blocking triggers (`index.js:2809–2853`). These set `ring` based on the matched invite doc.
- `humanityVerified` (the user-doc fast-path flag) is set only by the **task handler `anchorIdentityCommitmentTask`** (`on-chain-tasks.js:444–450`) after a successful on-chain anchor. **A user cannot influence their own `humanityVerified` flag without going through anchorCommitment + the on-chain anchor task.** Caveat: see Issue 5.A — they can launder another user's commitment to flip the flag.
- The user **cannot** set their own custom claims from the client. Firebase Auth custom claims are server-only via `admin.auth().setCustomUserClaims`. **Good.**

**Where the claim is read:**

- `AuthService.swift:42–43` reads `ring` and `role` from the local ID token. UI uses these for tier-conditional rendering, but server-side decisions always re-check via `requireRing` against the token Firebase verified.
- The pairing claim path (`index.js:3629`) reads `request.auth.token.ring` — sourced from the cryptographically verified token, not user input.

**Verdict:** ring uplift is server-controlled. Subject to Issue 5.A being fixed, `humanityVerified` is also server-controlled.

---

### 9. PairingCoordinator desktop pairing handshake

**Mechanism:** the QR carries a 6-character bearer code with no signature, no DH, no challenge. Codes are 36-char alphabet, ≈ 36^6 = 2.2B values, 5-minute TTL, single-use by code-status.

Flow:
1. Desktop calls `requestPairingCode` (authed) → server creates `pairing_sessions/{sessionId}` with `code`, `desktopUid`, `status: AWAITING_MOBILE`, `expiresAtMs: now + 5min`. Returns `{sessionId, code, expiresAtMs}` (`pairing.js:67–85`).
2. Desktop renders the code as a QR.
3. Mobile scans QR (`QRScannerView`), feeds the value to `PairingCoordinator.claim` (`PairingCoordinator.swift:66–91`), strips `foundation://pair/` prefix, calls `claimPairingSession(code:)`.
4. Server `claimPairingSession` (`index.js:3618–3636`) requires Firebase Auth + `ensureFreshPairingAuth(request)` (≤30 min for standard tier, ≤5 min for unattested) + atomically claims the session, supersedes any prior pair for this mobileUid, sets `mobileUid` + `mobileRing`.

**Cryptographic properties:**

- **The code is a bearer token.** Whoever shows up first with the code wins the session. There is no per-mobile binding before scan time — this is by design (the QR has to work cross-device).
- **Brute-forcing:** 5-minute TTL × 2.2B values × Firestore query rate-limit. Unauthenticated guessing is impossible because `claimPairingSession` requires auth + fresh sign-in. An authed user could brute-force a code of an unrelated session, but each guess hits `requireAuth`+`ensureFreshPairingAuth`+a Firestore query — Firebase callable rate-limits + Cloud Logging would catch this. *Marginal*.
- **Transport:** QR is rendered on a desktop screen the legitimate user controls. Adversary in front of the screen can read it; this is the inherent failure mode of any QR-pairing, accepted threat.
- **Stolen-phone defense:** the `ensureFreshPairingAuth` gate at `index.js:3596–3616` means a thief whose only credential is the unlocked phone (signed in days ago) cannot claim a desktop pair without re-doing email-link auth (which requires inbox access — a separate factor). **Good.**
- **Single-active-pair:** server enforces atomic supersede in transaction (`pairing.js:140–164`). Prior session flipped to `STATUS_DISCONNECTED` with `disconnectReason: superseded`. **Good.**

**Issue 9.A (LOW — code charset):** 32-char ambiguity-stripped alphabet × 6 chars ≈ 1.07B effective values (32^6, since `CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"` is 32 chars at `pairing.js:24`, despite the comment claiming 36^6). 5-minute TTL × Firebase callable QPS makes this fine for the demo, but a future-tightening review should consider 8 chars (32^8 ≈ 1.1T) for a comfortable margin if pairing volume scales.

**Issue 9.B (LOW — release path bypass):** the comment at `index.js:3656–3666` explicitly opts out of `ensureFreshPairingAuth` for the release path, with a stated DoS analysis. The reasoning is sound (90s heartbeat-stale catches what release misses), but this is worth re-reading once App Attest enforcement flips — a compromised non-fresh session can still issue release requests.

**No DH, no signed challenge — but this is appropriate for the threat model.** The pairing model is "phone == bearer of identity → desktop is a viewport"; a DH would not protect against the actual attack (an adversary reading the QR off the user's screen).

---

### 10. QR code crypto

`QRScannerView.swift:14–62` is a thin AVFoundation back-camera QR scanner. The decoded string is whatever the desktop encoded — a bare 6-char code, optionally prefixed `foundation://pair/`. **Nothing is signed; the QR is plaintext.** Binding to user identity is purely server-side via the `claimPairingSession` callable's `requireAuth` + Firestore session lookup.

This matches the design call-out at `pairing.js:1–14` and the comment at `QRScannerView.swift:8–12` ("HARD INVARIANT: the QR payload is a short pairing code only. No image frames are persisted, no payload bytes leave the device beyond the call site's normal route").

**No issues with the QR layer itself.** The auth_time freshness gate is what enforces the trust property.

---

## Findings table

| # | Issue | File:line | Severity | Fix |
|---|---|---|---|---|
| 1.A | No rate limit on `issueAttestationNonce` — authenticated user can fill `attestation_nonces` between sweeps | `functions/index.js:2400-2408`; `cleanup.js:68-78` | LOW | Add per-uid throttle (e.g. 5 unconsumed, 20/hr). |
| 2.A | Server doesn't validate `signatureBase64` charset/length | `functions/index.js:2639-2641` | LOW | Add `^[A-Za-z0-9+/=]+$` + ≤1024 length cap. |
| 2.B | `BiometricSealer` documented as wired into `submitAnchor`; actually passed `nil` | `CaptureCoordinator.swift:567-606`; `BiometricSealer.swift:25-28` | HIGH | Either wire the seal (recommended) or update doc to match. |
| 2.C | Commitment hash + on-chain PDA encode no uid; cross-uid hash collisions are possible (and exploited by 5.A) | `EnclaveSeal.swift:21-34`; `identity-onchain.js:30,64-67` | HIGH | Bind uid into `canonicalBytes()`, OR seed PDA with `[uid, hash]`, OR document uid-anonymous-on-chain explicitly + protect Firestore mapping (see 5.A). |
| 3.A | Adopted `OnChainAlreadyAnchored` records lose original tx signature | `on-chain-tasks.js:410-420,437` | MEDIUM | Backfill via `getSignaturesForAddress`. |
| 4.A | `BiometricSealer` doc drift (same root as 2.B) | `BiometricSealer.swift:25-28` | MEDIUM | Pair with 2.B. |
| 4.B | `signedAtMs` not bounds-checked server-side | `functions/index.js:2515-2524` | LOW | Reject seals outside `now ± 24h` skew once verification ships. |
| 5.A | Captured anchorCommitment payload from user A can be replayed by user B to flip B's `humanityVerified` flag (replay across uids) | `functions/index.js:2666-2738`; `on-chain-tasks.js:399-452` | HIGH | See 2.C fix; alternatively add prior-uid check before adopting an existing PDA. |
| 5.B | Per-artifact App Attest assertions described as verified but actually not verified at `anchorCommitment` time | `functions/index.js:2566-2582` | MEDIUM | Either wire verification via `@plantagoai/attestation` against the stored credential, or update the comment to reflect reality. |
| 5.C | No `producedAtMs` freshness check on `anchorCommitment` | `functions/index.js:2602-2603` | MEDIUM | Reject if `commitment.producedAtMs < now - 24h`. |
| 6.A | When real Phase 3 circuit replaces multiplier2, audit panic handling + typed input wrapping | `MoproSmokeBridge.swift:60-69`; `mopro-smoke/src/lib.rs:54-59` | LOW | Type-wrap circuit inputs; add `catch_unwind` at FFI boundary. |
| 7.A | Mock producers emit `signatureBase64: "mock:<tag>"` (non-base64 sentinel) — doc says "App Attest assertion" | `MockProofProducers.swift:60-70`; `ProofArtifact.swift:22` | LOW | Document the sentinel in the contract. |
| 9.A | Comment claims 36^6 pairing-code space; actual alphabet is 32 chars (1.07B) | `functions/lib/pairing.js:21-24` | LOW | Fix comment, or extend to 8 chars if scale demands. |
| 9.B | Release path bypasses `ensureFreshPairingAuth` | `functions/index.js:3656-3666` | LOW | Document the DoS-tradeoff is accepted; re-check once App Attest enforcement flips. |

---

## Threat model gaps

1. **Solana on-chain commitment is uid-anonymous by design** (`identity-onchain.js:6-7`). This is a deliberate privacy property — but then the **server-side Firestore mapping is the only authoritative uid↔hash binding**. That mapping is built in `anchorCommitment` from the request's `requireAuth` uid, with no challenge from the chain. Result: the off-chain mapping can be forged by replay (Issue 5.A), and the on-chain receipt cannot be used to disprove a forgery (because it's uid-free by design). This tension should be made explicit in the architecture doc; the fix likely requires uid-binding at canonical-bytes time so the seal's hash itself encodes uid.

2. **Phase 7 enclave seal is not (yet) cryptographically signed.** `EnclaveSeal.seal` produces a SHA-256 commitment but does not sign it with any key. `BiometricSealer` exists and could provide that signature, but `submitAnchor` passes `biometricSeal: nil`. The "Secure-Enclave-sign + submit" promise in `CLAUDE.md`'s parallel-execution-plan section is currently delivered as "SHA-256 + submit". Decide whether to wire the seal or update the spec.

3. **Per-artifact App Attest assertions are not verified at `anchorCommitment`.** The comment promises a "Layer 3" verification (`index.js:2570-2576`) that does not exist in code. The verifier infrastructure does exist in `@plantagoai/attestation` (it has `verifyAppleAttestation` for the *initial* attest), but assertion-verification (the lightweight per-call signature) requires the credential lookup at `identity_proofs/{uid}/mobile_attestations/{credentialId}` — that wiring is not in the callable.

4. **Attestation tier is client-asserted.** The `attestationTier` field in callable payloads (`FunctionsService.swift:225-229`) is set by the client based on local state. A client claiming `standard` tier that actually skipped attestation gets the longer 30-minute freshness window. The server has no way to verify the tier matches reality without re-checking the stored attestation record. Worth tightening: server should derive tier from the existence of a stored `mobile_attestations` doc for the uid, not trust the client's self-report.

5. **App Check is opted out on every mobile callable.** Comments at `index.js:2391-2399, 2560-2582, 3556-3559, 3618-3621` etc. explicitly opt out with documented rationale. The rationale is valid (the system has stronger gates), but it does mean a stolen ID token cannot be invalidated by App Check alone — every defense lives at the callable level. When `ENFORCE_APP_CHECK` flips, expect a non-trivial integration cycle.

---

## Specific replay-attack walk-throughs

### Walk-through A — cross-uid commitment replay (Issue 5.A — HIGH)

**Goal:** Attacker (user B) gains `humanityVerified: true` on their user doc + a Solana on-chain commitment without performing the verification flow themselves.

**Preconditions:**
- B has a valid Firebase Auth ID token (B can sign in normally).
- Attacker has captured one full `anchorCommitment` request payload `{commitment, artifacts, biometricSeal: null}` from user A. Any of: a rooted client, a shared TLS-terminating proxy in a hostile environment, an exfiltration tool on a stolen device, a memory-dump from a debugger build.

**Steps:**

1. Attacker takes A's captured payload verbatim.

2. Attacker submits to `anchorCommitment` with B's auth token.

3. Server (`index.js:2583-2777`):
   - `requireAuth(request)` returns `uid = B`. ✅
   - Shape validation passes (artifact array is well-formed).
   - `canonicalSealBytes(artifacts)` produces the same bytes A produced. SHA-256 matches `commitment.hashHex`. ✅
   - Firestore lookup at `identity_commitments/B/commitments/{hashHex}` — does not exist (B has never anchored this hash).
   - Server stamps `identity_commitments/B/commitments/{hashHex}` with `{uid: B, hashHex, ..., status: "queued"}` and enqueues `anchorIdentityCommitmentTask` with `{uid: B, hashHex}`.
   - Returns `{accepted: true, status: "queued"}`.

4. Task handler `anchorIdentityCommitmentTask` (`on-chain-tasks.js:364-498`) runs:
   - Calls `anchorIdentityCommitmentOnChain({hashHex})`.
   - PDA `[b"commitment", hash]` already exists from A's anchor. Throws `OnChainAlreadyAnchored` with `recordAddress`.
   - Handler at lines 410-420 **adopts** the existing PDA: `chain = {recordAddress, signature: null, slot: null, cluster: "devnet"}`.
   - Stamps `identity_commitments/B/commitments/{hashHex}` with `status: "anchored"`, `on_chain.record_address`, `txSignature: null`.
   - Stamps `users/B` with `humanityVerified: true, humanityVerifiedAt: serverTimestamp()`.

5. Result: B's user doc is flagged `humanityVerified: true` against A's on-chain record, with a null tx signature (only telltale — not user-visible).

**Why each defense fails:**
- Seal-mismatch check: passes — same canonical bytes hash to same hex.
- Firebase Auth check: passes — B has a real auth token.
- Per-artifact App Attest assertion: not verified server-side at this callable (Issue 5.B).
- Biometric seal: would have caught this if it bound uid into the signed payload, but (a) it's not sent (Issue 2.B) and (b) the field as designed signs only `commitment.hashHex`, not `uid + hashHex`.
- On-chain PDA collision: detected, but the handler treats it as an idempotent adoption rather than a forgery signal.

**Fix priorities:** 2.C and 5.A share the root cause. Bind uid into `canonicalBytes()`. That single change makes seal-mismatch fail at step 3 (B's request claims hash H_A; server re-derives bytes including uid=B; gets H_B ≠ H_A; rejects with "seal-mismatch").

### Walk-through B — captured-nonce replay against `recordMobileAttestation`

**Goal:** Attacker re-submits a captured `(nonce, attestation)` to record a fresh attestation under their own uid.

**Steps:**

1. Attacker captures A's `recordMobileAttestation` payload `{nonce, attestation: {platform, keyId, attestation: <CBOR_b64>}}`.

2. Attacker submits with B's auth token within 15 minutes.

3. Server (`server.ts:152-201`):
   - `consumeNonce({db, uid: B, nonce, now})`:
     - Reads `attestation_nonces/{nonce}`. Doc exists (A's issue).
     - Checks `data.uid !== B` → throws `nonce/uid-mismatch`. ✅
   - **Blocked at step 1 of the verifier.**

4. Even if attacker tries to issue their own nonce as B and pair it with A's CBOR: the CBOR's embedded nonce extension was computed from A's nonce and A's authData, so `apple/nonce-mismatch` fires at `verify-apple.ts:123`.

**Result: not exploitable.** This part of the system is solid.

### Walk-through C — pairing-code brute force

**Goal:** authed attacker brute-forces a victim's pairing code to take over the desktop session.

**Setup:** ~1.07B values (32^6), 5-minute TTL. Each guess costs one `claimPairingSession` callable invocation (rate-limited by Firebase, plus `requireAuth` + `ensureFreshPairingAuth` checks). Even at 100 calls/sec, expected guesses to find one of ~10 active codes is around 10^7 calls — would take days, way past the 5-minute window.

**Result: economically infeasible.** Issue 9.A's note about future scaling stands but no exploit today.

---

## Summary

The Phase 1 (App Attest) cryptographic plumbing is sound: nonce contract is correctly UTF-8 + per-uid + 15-min TTL + transactional consume, and the Apple CBOR verifier walks all seven required checks against Apple's root CA. `BiometricSealer` is well-designed (`.biometryCurrentSet` + Secure Enclave + correct re-enrollment semantics). Pairing's stale-auth gate is appropriate for the stolen-phone threat model.

**The real gaps live at the seam between Phase 7 (`anchorCommitment`) and the Solana anchor program**: the Secure Enclave biometric seal is documented but not actually shipped (`biometricSeal: nil` in CaptureCoordinator), per-artifact App Attest assertions are not server-verified at `anchorCommitment` time, and neither the canonical-bytes commitment hash nor the on-chain PDA encodes the user's uid. The combination produces a high-severity replay-across-uids primitive (Issue 5.A) where one user's captured anchor payload flips a different user's `humanityVerified` flag. The single-line fix is to bind uid into `EnclaveSeal.canonicalBytes` (and mirror it on the server's `canonicalSealBytes`), which closes 2.C and 5.A simultaneously.

MOPRO smoke is bounded and benign; the real audit will land when the multiplier2 circuit is swapped for the NFC-bound circuit.
