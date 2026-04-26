# iOS Security Audit — 2026-04-26

Auditor: senior iOS security review pass.
Repo: `/Users/dagan/dev/foundation/foundation-mobile-claude`
Branch: `claude/show-backlog-Woum4`

This is a security-posture audit. The "nothing identifying leaves the device" privacy invariant is a separate review — but where a security control would also enforce that invariant (e.g. ATS / TLS pinning, deep-link sanitization), it is noted.

---

## Scope (12 areas)

1. Authentication flow (email-link sign-in, Universal Links, pending-email Keychain slot, custom claim trust).
2. App Attest implementation (factory dispatch, KeyId persistence, server challenge, failure modes, simulator carve-out).
3. Keychain usage (ACLs, biometric protection, what is and isn't stored).
4. Secure Enclave usage (key generation params, ACL flags, freshness binding, replay).
5. PairingCoordinator + WebKit attack surface (WebView, JS bridge, message handlers, origins, mobile-WebView marker).
6. Deep links / Universal Links (AASA domains, parameter sanitization).
7. TLS / network configuration (ATS, pinning, RPC URL trust).
8. QR code handling (payload validation, phishing risk).
9. Permissions / entitlements / capabilities (least privilege).
10. DoS / abuse vectors on the client (malformed server / NFC / QR / Solana payloads).
11. Secrets in the binary (GoogleService-Info, hardcoded API keys, debug tokens).
12. Build-time / dependency hygiene (Podfile.lock, transitive vulns).

---

## Per-area findings

### 1. Authentication flow

**Today (file:line):**
- `AuthService.swift:71-74` — `sendSignInLink` always stashes the typed email in Keychain *before* the server confirms invite gating. The callable returns `sent: false` for unauthorized emails but the email is persisted regardless.
- `AuthService.swift:82-93` — `completeSignIn` reads the URL string, checks `Auth.auth().isSignIn(withEmailLink:)` (Firebase SDK validates link signature/format), then signs the user in with the Keychain-stashed email + the link.
- `FoundationMobileApp.swift:13-22` — `.onOpenURL { … completeSignIn(url:) }`: every URL handed to the app is fed straight into `completeSignIn`. There is no host/scheme/origin allowlist before that call.
- `Claims` are read from `getIDTokenResult().claims` (`AuthService.swift:42-54`). Only `ring` and `role` are pulled; `auth_time` is read separately via `currentAuthAgeMs()` for freshness gating.
- `AuthService.swift:84` uses `url.absoluteString` directly with no sanitization; `signIn(withEmail:link:)` is fed the raw absoluteString.

**Risks:**
- **A1 (HIGH) — Universal Link / cross-device email-link replay window.** Firebase email links are unbounded by default until you set a short `expiresIn`/`continueUrl` policy. Anyone who obtains the email link before the user does (mail-server compromise, shared inbox, screen-share, cross-device push of the email) and opens it on the *same* device is signed in as that user — `pendingEmail` is on disk, so the legitimate first-open and an attacker first-open look identical. There is no second factor (no PIN, no biometric, no device-binding token). This is the single biggest auth weakness because the rest of the security model assumes the signed-in user equals the human in possession of the device.
- **A2 (HIGH) — Pending email persisted regardless of invite gating.** Anti-enumeration (return `sent: false` on no-access) is a server good practice, but persisting `pendingEmail` for an email that has no link (`AuthService.swift:73`) means a passing third-party link of the form `…?mode=signIn&oobCode=…` will get consumed *as that pending email* if a real link for that email arrives later from any source. Practically: the pending slot has no expiry; a stale entry from a yesterday-attempt sits in Keychain until cleared. Mitigation: stamp `pendingEmail` with a short TTL (e.g. 30 min) and refuse `completeSignIn` if expired.
- **A3 (HIGH) — `onOpenURL` accepts any URL.** There is no check that the inbound URL's host is one of the two AASA-associated domains. Firebase's `isSignIn(withEmailLink:)` does cryptographic validation of the link, but a custom-scheme attack via a different app installing a `foundation://…` scheme is impossible (we don't register one), and `https://` URLs are limited by associated-domains, so the practical exposure is bounded. Still, defense-in-depth: explicitly check `url.host == "foundation-global.com" || url.host == "solanavote-devnet.firebaseapp.com"` before handing to Firebase. Cite: `FoundationMobileApp.swift:13-22`, `AuthService.swift:84`.
- **A4 (MEDIUM) — Custom-claim trust.** `apply(user:) AuthService.swift:41-54` reads `ring` and `role` from `getIDTokenResult().claims` without forcing a refresh. If the server revokes a role mid-session, the client keeps acting on the stale claim until the next forced refresh (~1h). Not a full bypass — the server is the actual gatekeeper on every callable — but downgrades that should kick a user out of a role surface keep them there visually.
- **A5 (MEDIUM) — Shared-device exposure.** `kSecAttrAccessibleAfterFirstUnlock` (Keychain.swift:50) means any user who unlocks the phone post-reboot can read `pendingEmail`. Combined with the unbounded email link + no biometric gate on launch, a shared phone has zero defense between sign-out / sign-in. CLAUDE.md mentions "biometric on launch" elsewhere but no such gate exists in the audited code. If shared-device is part of the threat model, gate `RootView` with LAContext on each cold launch.
- **A6 (LOW) — `signOut` is best-effort.** `AuthService.swift:120-146` releases the pair before calling `Auth.auth().signOut()` — good. But `try Auth.auth().signOut()` runs synchronously on @MainActor and cannot fail in practice; not a security issue.

**Specific fixes:**
- **A1/A2:** Add `pendingEmailIssuedAtMs` next to `pendingEmail` in Keychain; reject in `completeSignIn` if older than 30 min. Set Firebase `ActionCodeSettings.handleCodeInApp = true` server-side and use `force_same_device` if available; document the cross-device caveat in CLAUDE.md.
- **A3:** In `FoundationMobileApp.swift:13`, prefix with:
  ```swift
  guard let host = url.host,
        host == "foundation-global.com" || host == "solanavote-devnet.firebaseapp.com"
  else { return }
  ```
- **A4:** In `apply(user:)` call `user.getIDTokenResult(forcingRefresh: true)` periodically (every ~5 min via a Task) when ring/role is load-bearing.
- **A5:** Optional cold-launch LAContext gate in `RootView` before resolving `auth.state`.

---

### 2. App Attest implementation

**Today:**
- `AppCheckFactory.swift:5-18` — `#if targetEnvironment(simulator)` returns `AppCheckDebugProvider`, otherwise `AppAttestProvider`. Not gated on `#if DEBUG`. Comment is correct: dev-signed device builds use real App Attest.
- `FoundationMobile.entitlements:10-11` — `com.apple.developer.devicecheck.appattest-environment = development`. A production submission requires flipping this to `production`.
- `AttestationService.swift:24-49` — generateKey, attestKey using `clientDataHash = SHA256(utf8(nonce))`. Server contract per `reference_app_attest_challenge.md` — both sides hash UTF-8 bytes of the nonce string; consistent.
- `AttestationService.swift:57-72` — `generateAssertion` self-heals on `DCError.invalidKey (3)` by clearing Keychain + full re-attest + retry. Avoids hardcoding `DCError` enum import (defensible).
- `AttestationCoordinator.swift:91-153` — End-to-end attest with 30s hard timeout, 10s user-skip escape. On failure, drops to `.unattested` tier, server enforces tighter freshness windows server-side based on `attestationTier` injected in `FunctionsService.swift:225-230`.
- `AttestationService.swift:122-184` — `#if DEBUG` block writes the raw CBOR attestation + nonce + clientDataHash to `Documents/`. Wrapped in `#if DEBUG`.

**Risks:**
- **B1 (HIGH) — Production environment string is `development`.** `FoundationMobile.entitlements:10-11`. Must flip to `production` for App Store submission. App Store distribution with `appattest-environment = development` will validate against Apple's sandbox; the server CBOR verifier in `@plantagoai/attestation/server` will reject sandbox attestations once production policy lands. Tracked in CLAUDE.md as "next action 2" but not yet done — flag as a release-gate.
- **B2 (HIGH) — Client never enforces `accepted` rigorously.** `AttestationCoordinator.swift:140-144` — if `result.accepted == true` AND Keychain has a keyId, set `.attested`; else `.failed`. But the user can simply tap "Continue without attestation" (`skipAttestation` at line 168) at the 10s mark, dropping to `.unattested`. Server is meant to enforce tighter windows on unattested tier (`AttestationCoordinator.swift:11-15`), but the *demo* posture admits unattested → standard escalation paths via lowsec-attest profile. Make sure the production profile (hisec-global) does not accept `.unattested` for mutating callables. If `claimPairingSession` accepts `attestationTier=unattested` on hisec-global, the App Attest gate is effectively cosmetic. Confirm server-side; client-side can also refuse to send the tier on hisec-global.
- **B3 (MEDIUM) — Replay window on the attestation nonce.** `AttestationCoordinator.swift:204-220` races attestation against a 30s sleep using a TaskGroup. The server-issued nonce has `expiresAtMs` (`FunctionsService.swift:6`) — make sure the server actually enforces it; client doesn't check expiry locally before consuming. A leaked nonce + a replayed CBOR would be defeated only by the server's `expiresAtMs` check + per-nonce single-use semantics. Not a client fix; confirm in `@plantagoai/attestation/server`.
- **B4 (MEDIUM) — Debug attestation dump on disk.** `AttestationService.swift:138-184` writes raw CBOR + nonce + clientDataHash to `Documents/` under `#if DEBUG`. Documents directory is iCloud-backed and Xcode-extractable. The risk is not the attestation itself (it is bound to the device) but that a TestFlight build accidentally compiled with `DEBUG` would leak nonces and key IDs to anyone who can extract the container. Add a runtime guard: `#if DEBUG` AND `ProcessInfo.processInfo.environment["FOUNDATION_DEBUG_DUMPS"] != nil` so even a misconfigured `DEBUG` build doesn't dump unless an env var is set.
- **B5 (LOW) — `AppCheckDebugProvider` shipping.** Compile-time `targetEnvironment(simulator)` correctly excludes the debug provider from device builds. Good. Verify in Release archives that `AppCheckDebugProvider` is not symbol-present (it shouldn't be — `#if targetEnvironment(simulator)` is hard-stripped). Confirm by `nm -gU FoundationMobile | grep -i debugprovider` on a Release build.

**Specific fixes:**
- **B1:** Edit `FoundationMobile.entitlements:11` to `<string>production</string>` for App Store builds; gate via xcconfig `APPATTEST_ENVIRONMENT` and a separate Release entitlements file.
- **B2:** In `FunctionsService.injectAttestationTier` (line 225), short-circuit to *not* send when tier is unattested for callables that demand standard tier (or just refuse to call them). Belt-and-suspenders alongside server-side enforcement.
- **B3:** Server: enforce `expiresAtMs` < now + ≤120 s window. Client: discard the cached `nonce` after one use; re-issue if the user retries.
- **B4:** Wrap the dump in `#if DEBUG && FOUNDATION_DEBUG_DUMPS_ENABLED` and only set the latter when explicitly opted in. Or write only `keyId` + `clientDataHashHex`, not the raw CBOR.

---

### 3. Keychain usage

**Today:**
- `Keychain.swift:38-51` — One generic password slot with `service = com.foundationglobal.mobile`, two accounts (`pendingSignInEmail`, `appAttestKeyId`).
- ACL: `kSecAttrAccessibleAfterFirstUnlock` (line 50). Not `…ThisDeviceOnly`.
- No `kSecAttrAccessControl` (no biometric lock).
- No iCloud Keychain opt-out (`kSecAttrSynchronizable` not set; defaults to non-sync, but explicit is safer).

**Risks:**
- **C1 (MEDIUM) — Keychain entries restored to a new device via iTunes/Finder backup.** `kSecAttrAccessibleAfterFirstUnlock` (without `…ThisDeviceOnly`) means encrypted backups carry these items to a restored device. `appAttestKeyId` is device-bound (the Secure Enclave key isn't restorable, so the keyId is useless on a new device — `generateAssertion` will fail with `invalidKey` and the app self-heals via re-attest). But `pendingEmail` *does* travel; a restored device would see the prior pending email, and if it intercepts a fresh email link addressed to that address, sign-in completes. Bound by needing the email link too.
- **C2 (MEDIUM) — No biometric protection on `pendingEmail`.** Anyone who unlocks the device once after reboot can read `pendingEmail`. Not high-value alone (just the user's email), but combined with A5/shared-device, contributes.
- **C3 (LOW) — Missing protection for App Attest key invalidation race.** When `generateAssertion` self-heals (`AttestationService.swift:64-71`), it deletes the Keychain entry and re-attests in the same call. If the process is killed mid-flight, Keychain is empty + Apple's backend already tracks the new attest. Recoverable via next launch (full re-attest), no data loss.

**Specific fixes:**
- **C1:** Change `Keychain.swift:50` to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. This survives backup but doesn't restore to a new device.
- **C2:** For `pendingEmail`, optionally upgrade to `kSecAttrAccessControl` with `.userPresence` (passcode/biometric prompt on read) — but this adds friction to the sign-in flow. Likely over-rotating for the threat model.
- **C3:** No fix needed.

---

### 4. Secure Enclave usage

**Today:**
- `BiometricSealer.swift:160-193` — Generates ECDSA P-256 in Secure Enclave with `kSecAttrTokenIDSecureEnclave`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, ACL flags `[.privateKeyUsage, .biometryCurrentSet]`. Excellent — `biometryCurrentSet` invalidates the key on biometric set change.
- `BiometricSealer.swift:91-122` — `sign(payload:prompt:)` uses `.ecdsaSignatureMessageX962SHA256` — SecKey hashes the payload internally; the caller passes raw bytes.
- `EnclaveSeal.swift:14-35` — Concatenates `artifact.canonicalBytes()` separated by `0x0a`, SHA-256s, builds `Commitment`. *Not* signed by the Secure Enclave key as a default — the biometric seal is sent only as an *optional* sidecar (`AnchorCommitmentRequest.biometricSeal: nil` in `CaptureCoordinator.swift:594`).
- `BiometricSealer.swift:51` — `keyTag = "com.foundation.biometric-seal-key.v1"` — versioned, allows re-rotation by bumping suffix.

**Risks:**
- **D1 (HIGH) — Sealed payload is not bound to a server-issued nonce.** `EnclaveSeal.seal` (`EnclaveSeal.swift:21-34`) hashes only the artifacts. `producedAtMs` is the *client* clock; an attacker controlling client time can backdate or future-date a seal indefinitely. The server must enforce a freshness window using its own clock (and refuse seals where `producedAtMs` is far from server time). If the server only checks `commitmentHashHex` matches the canonical reconstruction (which is the documented behavior in `FunctionsService.swift:31-42`), the seal can be replayed any time the same artifacts are reproduced. Mitigation: include a server-issued `anchorNonce` in the canonical bytes before hashing, or sign over `(commitmentHashHex || serverNonce)` with the BiometricSealer.
- **D2 (HIGH) — BiometricSealer is wired but not used.** `CaptureCoordinator.swift:570-595` sets `biometricSeal: nil` with a comment that it's deferred. The Face-ID-as-consent property documented in `BiometricSealer.swift:15-23` is therefore not actually emitted. The server has no way to verify the user authorized this commitment. Re-enable per the comment when the per-gate-prompt design is finalized; for now treat the BiometricSealer functionality as unverified.
- **D3 (MEDIUM) — Force-unwrap in `lookupKey`.** `BiometricSealer.swift:157` — `result as! SecKey`. `SecItemCopyMatching` with `kSecReturnRef` + `kSecClassKey` returns a SecKey, so the cast is correct, but a future refactor that adds `kSecReturnAttributes` would return a CFDictionary and crash. Use `result as? SecKey` and treat nil as a "not found / regenerate" outcome.
- **D4 (LOW) — `localizedReason = prompt` set on LAContext but not passed through.** `BiometricSealer.swift:96-99` sets `context.localizedReason` but the implicit Face ID prompt comes from the Secure Enclave's accessControl, not LAContext, since the LAContext is never `setCredential`/`evaluatePolicy`'d before signing. The prompt the user actually sees is system-default ("Authenticate to use this key") rather than your `prompt` string. Either pass `kSecUseAuthenticationContext: context` in a new query attribute (requires re-fetching the key), or drop the LAContext code as misleading.
- **D5 (LOW) — Public key sent on every anchor call.** `FunctionsService.swift:67-79` documents this. Server can build a per-uid registry "lazily." Not a security weakness — public keys are public — but worth noting that swapping the public key mid-session could let a compromised client convince the server to update the registry. Server should pin `(uid, publicKey)` after first observation and reject mismatches without an attested re-enrollment flow.

**Specific fixes:**
- **D1:** Fold a server-issued nonce into the seal. Easiest path: extend `AnchorCommitmentRequest` with `commitmentNonce: String` issued by `issueAnchorNonce`; canonical bytes include it before SHA-256. Server enforces single-use + ≤60s freshness.
- **D2:** Unblock the per-anchor BiometricSealer signing. Even one entry-gate sign per session is a step up from `nil`. Update `submitAnchor` (`CaptureCoordinator.swift:567`) to call `BiometricSealer.shared.sign(payload: Data(commitment.commitmentHashHex.utf8), prompt: …)` and attach the result.
- **D3:** Replace `as!` with `as?` in `BiometricSealer.swift:157`.
- **D4:** Either delete `LAContext` lines 96-99 or wire it via `kSecUseAuthenticationContext`.

---

### 5. PairingCoordinator + WebKit attack surface

**Today:**
- `WebHomeView.swift:186-232` — `WKWebView` with `config.allowsInlineMediaPlayback = true`, `websiteDataStore = .default()`. Loads `https://foundation-global.com/`.
- `WebHomeView.swift:212-220` — Document-start `WKUserScript` injects two globals on every load: `window.__foundationMobileBridgePending = true` and `window.__foundationMobileWebView = true`. Marker is *only* set inside this WKWebView's content world; it cannot be set by any external page navigated to.
- `WebHomeView.swift:280-321` — `evaluateJavaScript(js)` injects a custom Firebase auth token by calling `window.__foundationSignInWithCustomToken('<escaped>')`. Token is escaped with `\\` and `'` replacement before string interpolation.
- No `WKScriptMessageHandler` registered. Web → native communication is one-directional (native → web only).
- No CSP set on the WKWebView (CSP would come from the web app's response headers, not the client).
- No allow-list on navigation: `WKNavigationDelegate` is registered but doesn't implement `decidePolicyFor`; any link the web app navigates to is allowed.

**Risks:**
- **E1 (HIGH) — Open navigation policy.** `Coordinator: WKNavigationDelegate` (`WebHomeView.swift:238-323`) does not implement `webView(_:decidePolicyFor:decisionHandler:)`. If the loaded foundation-global.com page contains a link or auto-redirect to attacker.com, the WebView will navigate there *with the `__foundationMobileWebView` and `__foundationSignInWithCustomToken` markers still injected on every navigation* (because `forMainFrameOnly: true` + `injectionTime: .atDocumentStart` re-runs per navigation). An attacker page on a different origin could call `window.__foundationSignInWithCustomToken` (if it was not cleared) — although the bridge function is defined by *foundation-global*'s React bundle, not by us, so on attacker.com the bridge function is absent and the inject loop hits `bridge_timeout`. The actual exposure is the leak of `__foundationMobileWebView = true` to an attacker page, which is harmless; and the leak of the `__foundationSignInWithCustomToken('<token>')` *call* into attacker.com if that page somehow defined the function. Treat as a defense-in-depth gap: lock navigation to `foundation-global.com` and its known sub-paths.
- **E2 (HIGH) — Custom token injection via JS string interpolation.** `WebHomeView.swift:267-296` builds a JS string with single-quote escaping. Firebase custom tokens are JWT (`base64url.base64url.base64url`) — no quotes, no backslashes, no newlines, so the escaping is safe in practice. But if the server ever returns a non-JWT value (error, "stale_auth", a debug echo, etc.) the code will still interpolate and `evaluateJavaScript` it. Because `mintToken()` is called in a `do { … } catch { … }` (line 75-86), errors don't reach this path; only successful responses with a `customToken` field are passed. Still, hardening: validate token shape `^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$` before injection.
- **E3 (MEDIUM) — Custom token logged.** `WebHomeView.swift:298-310` `print("[WebHome] sign-in bridge ok uid=\(dict["uid"] ?? "nil"))"` — uid only, OK. `print("[WebHome] inject error: \(error.localizedDescription)")` — error.localizedDescription from `evaluateJavaScript` shouldn't echo the source JS, but if it ever did, the token would land in OSLog. Safer: don't print error details from a flow that interpolates secrets.
- **E4 (LOW) — `__foundationMobileWebView` marker is a server-trust flag.** `WebHomeView.swift:208-220` describes the marker as letting the web app skip the AccessGate pair-gate. From the iOS side this is fine — the marker is set by *our* user script before the page loads, so a page can't fake it from outside this WebView. The risk is the *web side*: if `foundation-global.com` reads `window.__foundationMobileWebView` and grants any privilege based on it, that privilege flows to any page navigated *to* in the same WebView. The mobile-WebView marker should not gate anything more sensitive than UI cosmetics.
- **E5 (LOW) — Pairing claim path.** `PairingCoordinator.swift:66-91` — claims via callable; server enforces auth-freshness + uniqueness. `extractCode` strips `foundation://pair/` if present and trims whitespace. Code goes straight to the server which is the actual gatekeeper. Fine.
- **E6 (MEDIUM) — `WKWebView` data store is shared default.** `WebHomeView.swift:195` uses `.default()` — the WKWebsiteDataStore. Cookies and localStorage persist across launches *and across users on the same device after sign-out*. After `signOut()` the next user's WebHomeView shows the prior user's cookies. Either clear `WKWebsiteDataStore.default()` on signOut, or use a non-persistent data store.

**Specific fixes:**
- **E1:** Add `decidePolicyFor` in the Coordinator:
  ```swift
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let allowed: Set<String> = ["foundation-global.com", "www.foundation-global.com"]
    if let host = navigationAction.request.url?.host, allowed.contains(host) {
      decisionHandler(.allow)
    } else if navigationAction.navigationType == .linkActivated {
      // Open out-of-app links in Safari, never inline
      UIApplication.shared.open(navigationAction.request.url!)
      decisionHandler(.cancel)
    } else {
      decisionHandler(.cancel)
    }
  }
  ```
- **E2:** Add token-shape regex validation in `WebHomeView.swift:74-86` before assigning `customToken`.
- **E3:** Remove `print` of `error.localizedDescription` in the inject path; or log only `error.code`.
- **E4:** Keep the marker scope read-only on the web side — only used to skip a UI gate. Already documented.
- **E6:** In `AuthService.signOut`, clear WKWebsiteDataStore:
  ```swift
  await WKWebsiteDataStore.default().removeData(
    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
    modifiedSince: .distantPast
  )
  ```

---

### 6. Deep links / Universal Links

**Today:**
- `FoundationMobile.entitlements:5-9` — AASA-associated domains: `foundation-global.com` and `solanavote-devnet.firebaseapp.com`. No `webcredentials:` entry.
- `FoundationMobileApp.swift:13-22` — `.onOpenURL { … completeSignIn(url:) }`. No host/scheme check. No URL parsing — full string fed to Firebase SDK.
- `Info.plist` — No `CFBundleURLTypes` registered (no custom URL scheme). Universal Links only.

**Risks:**
- **F1 (HIGH) — No host allowlist on `onOpenURL`.** Already noted as A3. Apple's AASA/UL flow guarantees the inbound URL host matches one of the entitlement domains — but defense-in-depth.
- **F2 (LOW) — Pairing scheme `foundation://pair/`.** `PairingCoordinator.swift:184-190` parses this scheme, but `Info.plist` doesn't register it as a `CFBundleURLScheme`, so `foundation://…` won't open the app via deeplink — it's only used as a marker prefix in QR payloads. Good. If you later register it, sanitize identical to A3.

**Specific fixes:**
- See A3.

---

### 7. TLS / network configuration

**Today:**
- `Info.plist` — No `NSAppTransportSecurity` block; ATS defaults apply. No `NSAllowsArbitraryLoads`. Good.
- `SolanaRPC.swift:7` — Devnet RPC endpoint hardcoded: `https://api.devnet.solana.com`. URLSession default; no pinning.
- `FunctionsService.swift:160` — Functions region us-east1, default Firebase URLs. No custom session, no pinning.
- No URLSessionDelegate implementing `urlSession(_:didReceive:completionHandler:)` for cert pinning anywhere in the codebase.

**Risks:**
- **G1 (MEDIUM) — No TLS pinning.** Standard ATS chains-to-public-CA only. A malicious enterprise CA installed on the device can MITM all traffic to `api.devnet.solana.com`, `*.cloudfunctions.net`, `*.firebaseapp.com`. The mobile device is the trust anchor, so this is a "user installed a profile they shouldn't have" risk; demo-grade ATS is acceptable. Pinning would be an upgrade for production: pin Firebase + Apple App Attest API endpoints. Note: pinning the Solana RPC is harder (devnet endpoints rotate).
- **G2 (LOW) — `SolanaRPC` is read-only and only fetches `getAccountInfo`.** `SolanaRPC.swift:26-40` — pubkey is interpolated into JSON but JSON encoding handles escaping correctly (`JSONSerialization.data(withJSONObject:)`). No URL injection vector. Response decoding is a typed `Decodable` envelope — unknown fields dropped; mostly safe.
- **G3 (LOW) — Hardcoded RPC endpoint.** `SolanaRPC.devnet` is the only instance; if a profile ever wants a different RPC, it's not config-driven. Devnet stays the same; not a near-term concern.

**Specific fixes:**
- **G1:** Optional. If pursuing, use `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` with a SHA-256 SPKI pinset for Firebase and Apple endpoints. Document pin rotation procedure.

---

### 8. QR code handling

**Today:**
- `QRScannerView.swift:139-153` — `metadataOutput(_:didOutput:from:)` reads `first.stringValue` from `AVMetadataMachineReadableCodeObject`, dispatches to `onScanned`.
- `PairingCoordinator.swift:184-190` — `extractCode` trims whitespace, strips `foundation://pair/` prefix if present, splits on `?` — very forgiving parser.
- The decoded code is sent to `FunctionsService.claimPairingSession(code:)`. Server validates.

**Risks:**
- **H1 (MEDIUM) — Phishing pairing flow.** A QR placed in the wild encoding `foundation://pair/<attacker-controlled-code>` will be scanned without warning. The server must reject codes that don't belong to a valid in-flight desktop pairing (presumably rate-limited and requiring `requestPairingCode` to have been called). If the server's `claimPairingSession` is well-protected (rate-limited, code is random-128-bit, single-use, expires fast), the worst the user can do is fail to claim. If it just pairs whatever they scan, this is a desktop-takeover vector.
- **H2 (LOW) — No payload validation on the client.** `extractCode` accepts any string. Could flag a length cap (e.g. ≤64 chars) and a charset filter (alphanumeric + dashes) before sending to the server, to fail fast on garbage.
- **H3 (LOW) — Single-shot stop on first scan.** Good — no continuous capture.

**Specific fixes:**
- **H1:** Server-side. Verify in foundation-global that `claimPairingSession` requires a fresh `requestPairingCode` write within a short TTL and rejects unknown codes with a stable error.
- **H2:** Add to `extractCode`:
  ```swift
  guard code.count <= 64,
        code.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return "" }
  ```

---

### 9. Permissions / entitlements / capabilities

**Today:**
- `FoundationMobile.entitlements`:
  - `com.apple.developer.associated-domains` — `applinks:` for two domains.
  - `com.apple.developer.devicecheck.appattest-environment` — `development`.
  - `com.apple.developer.nfc.readersession.formats` — `["TAG"]`.
- `Info.plist`:
  - `NSCameraUsageDescription`, `NSFaceIDUsageDescription`, `NFCReaderUsageDescription` — all present, all correct.
  - `com.apple.developer.nfc.readersession.iso7816.select-identifiers = ["A0000002471001"]` — ICAO ePassport AID. Tight scope.
  - No background modes (`UIBackgroundModes`) — good, NFC, camera, audio not required in background.
  - `LSRequiresIPhoneOS=true`, `arm64` only, portrait only (iPhone), all four orientations on iPad.
  - No App Groups, no Keychain access groups beyond the default.

**Risks:**
- **I1 (HIGH, release-gate) — `appattest-environment = development`.** Already covered as B1.
- **I2 (LOW) — No Push Notifications, no App Groups, no Background Modes.** Tight. Good.
- **I3 (LOW) — NFC iso7816 select-identifier scope.** Single AID `A0000002471001` (ICAO MRTD). Good, no overprovision.

**Specific fixes:**
- See B1.

---

### 10. DoS / abuse vectors on the client

**Today:**
- `FunctionsService.decode` (line 232-235) uses `JSONDecoder` on `Any` deserialized via `JSONSerialization`. Throws on shape mismatch — handled by callers via `do/try/catch`.
- `SolanaRPC.getAccountInfo` (line 26-40) — typed Decodable. Unknown fields ignored.
- `PassportNFCReader.swift:118-208` — Wraps NFCPassportReader's read; throws `PassportNFCReaderError.readFailed(error)` on any underlying throw. Hash mismatch = explicit throw. UIImage-from-bytes: `UIImage(data: Data(dg2Concrete.imageData))` (line 185) — ImageIO decodes JPEG/JPEG2000. **A malformed JPEG2000 from the chip cannot crash UIImage**, but a hostile chip could supply an extremely large image (decompression bomb) that consumes memory. iOS's ImageIO has a soft 100M-pixel cap.
- `MRZScanView.swift:289-336` — Parser is bounded (≤44 chars per line), check-digit gated; rejects malformed strings cleanly. Good.
- `AppConfig.swift:111-119` — `fatalError` if profile JSON missing. *Intentionally fail-loud* per comment, so a misconfigured build crashes immediately at launch. Not a runtime DoS — it's developer ergonomics.
- `RootView.swift:20` — `try? await Task.sleep(...)` — no crash path.
- `BiometricSealer.swift:157` — `as! SecKey` — covered as D3.
- `EnclaveSeal.swift:21-34` — Operates on bounded artifacts; no length checks but artifacts come from controlled producers.

**Risks:**
- **J1 (MEDIUM) — DG2 image decompression bomb.** `PassportNFCReader.swift:185` decodes whatever the chip returns. A malicious or corrupted chip (or a relay attacker between phone and chip — unlikely on NFC's <4cm range) supplying a crafted JPEG2000 could spike memory. Add a size guard: refuse `dg2Concrete.imageData.count > 200_000` (real DG2 photos are 15-25 KB).
- **J2 (MEDIUM) — Server response trust.** `RecordAttestationResult.commitment: String?` (`FunctionsService.swift:22`), `AnchorCommitmentResult` fields (line 83-96) — all optional, all typed. No fields are interpolated into shell commands or filesystem paths. Largest concern: `commitmentDocPath: String?` is fed to `Firestore.firestore().document(path)` (`CaptureCoordinator.swift:617`). If the server returns a malicious path, the snapshot listener subscribes to that doc. Worst case: the client subscribes to a doc it shouldn't and reads its `status`/`slot`/`txSignature` fields. With Firestore rules properly locked down (only the server can write commitments; clients can only read their own), this is bounded by the rules. Still, validate `commitmentDocPath.hasPrefix("commitments/")` before subscribing.
- **J3 (LOW) — `fatalError` on missing AppConfig.** `AppConfig.swift:115`. Crashes launch if profile JSON missing. By design (per the comment) — auditable that a misbuilt binary is dead-on-arrival, not silently wrong. Keep.
- **J4 (LOW) — Force-unwraps in `AVCaptureVideoPreviewLayer` casts.** `CaptureView.swift:409`, `DocumentPhotoView.swift:348`, `MRZScanView.swift:280`, `QRScannerView.swift:169`. The `layerClass` override guarantees the cast; safe.

**Specific fixes:**
- **J1:** In `PassportNFCReader.swift:184-189`, guard:
  ```swift
  guard dg2Concrete.imageData.count < 200_000 else {
    throw PassportNFCReaderError.dg2FaceImageMissing
  }
  ```
- **J2:** In `CaptureCoordinator.observeCommitmentDoc` (line 613), guard the path prefix before calling `db.document(path)`.

---

### 11. Secrets in the binary

**Today:**
- `GoogleService-Info.plist` — `API_KEY = AIzaSyBb5Cvhm2ndMdz8A90KnpP5w1-7XOGV2yk`, `CLIENT_ID`, `GOOGLE_APP_ID`, `PROJECT_ID`, `STORAGE_BUCKET`. All Firebase iOS-client values; Google's docs explicitly mark these as safe to ship in the binary.
- No `.env`, no other plists with credentials.
- No hardcoded RPC secret keys, no Solana keypairs (per invariant).
- `SolanaRPC.devnet` URL is the public devnet endpoint.

**Risks:**
- **K1 (LOW) — Firebase API key restriction.** `AIzaSyBb…` is meant to be public, but Google requires you to restrict it via Cloud Console (HTTP referrers / iOS bundle ID restriction + API restriction list). If unrestricted, an attacker can use this key against billed Firebase services (Identity Toolkit, etc.) at scale. Verify in GCP console: API key → Application restrictions = iOS apps → bundle id `com.foundationglobal.mobile`; API restrictions = limit to Identity Toolkit, Cloud Functions, App Check, Firestore.
- **K2 (LOW) — Project ID public.** `solanavote-devnet`. Not sensitive.

**Specific fixes:**
- **K1:** Verify GCP API key restriction. Document in `reference_*` memory.

---

### 12. Build-time / dependency hygiene

**Today (Podfile.lock):**
- Firebase 12.12.x suite (current as of 2026-04 — Firebase 12.x is the current major).
- `NFCPassportReader 2.3.0` (latest 2.x).
- `OpenSSL-Universal 3.3.3001` (OpenSSL 3.3, current).
- `gRPC-C++ / gRPC-Core 1.69.0` (Firebase-pinned, current).
- `BoringSSL-GRPC 0.0.37` (gRPC's bundled BoringSSL).
- `RecaptchaInterop 101.0.0` (Firebase Auth dep).
- `CocoaPods 1.15.2` lockfile (per-developer Bundler is `1.16.2` per memory).

**Risks:**
- **L1 (LOW) — OpenSSL 3.3 has CVEs of historical record but no active critical RCE on iOS-built static libs.** `OpenSSL-Universal 3.3.3001` is OpenSSL 3.3.0 (October 2024). Track upstream advisories; nothing high-severity to flag today.
- **L2 (LOW) — `NFCPassportReader 2.3.0`.** Open-source library that ingests NFC chip bytes. If the library has a parser bug for malformed DG records, that's a code-execution vector inside a memory-safe Swift parser (low likelihood). Watch the upstream `AndyQ/NFCPassportReader` issue tracker. The `~> 2.0` constraint in `Podfile:14` will auto-pick up 2.x patch releases on `pod update`.
- **L3 (LOW) — `BoringSSL-GRPC` shipped alongside OpenSSL-Universal.** Two TLS stacks linked in. Increases binary size and attack surface modestly. Not a fix unless trimming size matters.
- **L4 (LOW) — Privacy manifest bundling.** `PrivacyInfo.xcprivacy` is shipped (good — App Store now requires it). Reasons claimed: `C617.1` (file timestamp), `CA92.1`/`1C8F.1`/`C56D.1` (UserDefaults), `35F9.1` (boot time). Reasonable for Firebase + iOS basics.

**Specific fixes:**
- **L1:** Subscribe to OpenSSL advisory list.
- **L2:** Pin `NFCPassportReader` to `~> 2.3.0` (not `~> 2.0`) to require explicit review of minor bumps.

---

## Cross-cutting observations

- **Two-tier attestation creates a confusing trust gradient.** "Standard" vs "unattested" tiers are sent on every callable (`FunctionsService.swift:225-230`), and the server is the actual gatekeeper. The audit found no client-side enforcement that refuses to call mutating callables when `tier == .unattested`. If the server fully enforces this, fine — but be explicit. A profile-aware client refusal would be defense-in-depth.
- **Secure Enclave seal is wired but disabled.** The biggest single security upgrade available is to enable BiometricSealer.shared.sign on every anchor submission, with a server-issued nonce in the canonical bytes. Today the cryptographic story leans entirely on App Attest + Firebase auth.
- **Email-link auth is a known weak link.** The whole stolen-but-still-signed-in-phone defense pivots on `auth_time` freshness gates. That works while the user is current, but the *initial* auth has no second factor. For a YC demo this is fine; for production verifiable identity it should be pair-with-biometric or pair-with-WebAuthn.
- **Universal Link host check missing — easy win.** A 5-line guard in `FoundationMobileApp.swift:13` is good hygiene independent of any specific known attack.
- **WKWebView lacks navigation policy + data-store cleanup on signOut.** Both straightforward to fix; WKWebView with default data store + open navigation has historically been the place mobile apps leak state.
- **Several `as!` force-casts.** All currently safe by construction (custom `layerClass`), but `BiometricSealer:157` should be defensive (`as?`).

---

## Severity-ordered summary table

| Sev | ID | File:line | One-line fix |
|---|---|---|---|
| HIGH | A1 | `AuthService.swift:71-93` | Stamp `pendingEmail` with TTL; require ≤30 min between request and consume. |
| HIGH | A2 | `AuthService.swift:73`, `Keychain.swift:18-20` | Clear stale `pendingEmail` on app launch if older than TTL. |
| HIGH | A3 / F1 | `FoundationMobileApp.swift:13` | Guard `url.host ∈ {foundation-global.com, solanavote-devnet.firebaseapp.com}` before `completeSignIn`. |
| HIGH | B1 / I1 | `FoundationMobile.entitlements:11` | Flip `appattest-environment` to `production` in the Release entitlements file. |
| HIGH | B2 | `FunctionsService.swift:225-230`, `AttestationCoordinator.skipAttestation` | Refuse to send unattested tier to mutating callables on hisec-global profile. |
| HIGH | D1 | `EnclaveSeal.swift:21-34`, `FunctionsService.swift:43-65` | Bind seal to a server-issued nonce inside the canonical bytes. |
| HIGH | D2 | `CaptureCoordinator.swift:594` | Wire `BiometricSealer.shared.sign(commitment.hashHex)` into `biometricSeal`. |
| HIGH | E1 | `WebHomeView.swift:238-323` | Implement `decidePolicyFor` with a foundation-global.com host allowlist. |
| HIGH | H1 | `PairingCoordinator.swift:66-91` (server-side) | Confirm server-side rate limit + single-use + TTL on pairing codes. |
| MEDIUM | A4 | `AuthService.swift:41-58` | Force-refresh ID token periodically when `ring`/`role` is load-bearing. |
| MEDIUM | A5 | `RootView.swift` / `Keychain.swift:50` | Optional cold-launch LAContext gate; upgrade Keychain accessibility flag. |
| MEDIUM | B3 | `AttestationService.swift` (server) | Server enforces `expiresAtMs` + single-use on attestation nonce. |
| MEDIUM | B4 | `AttestationService.swift:122-184` | Gate debug dump behind both `#if DEBUG` and a runtime env var. |
| MEDIUM | C1 | `Keychain.swift:50` | Change to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| MEDIUM | C2 | `Keychain.swift:9-11` | Optional: Keychain ACL with `.userPresence` for `pendingEmail`. |
| MEDIUM | E2 | `WebHomeView.swift:267-296` | Validate JWT shape before injecting custom token. |
| MEDIUM | E3 | `WebHomeView.swift:298-310` | Stop printing `error.localizedDescription` from token-injection JS. |
| MEDIUM | E6 | `AuthService.signOut` | Clear `WKWebsiteDataStore.default()` on sign-out. |
| MEDIUM | G1 | `FunctionsService.swift:154-160`, `SolanaRPC.swift` | Optional TLS pinning for Firebase + Apple endpoints. |
| MEDIUM | H2 | `PairingCoordinator.swift:184-190` | Add charset + length cap on extracted pairing code. |
| MEDIUM | J1 | `PassportNFCReader.swift:184-189` | Guard `dg2Concrete.imageData.count < 200_000` before `UIImage(data:)`. |
| MEDIUM | J2 | `CaptureCoordinator.swift:613` | Guard `commitmentDocPath.hasPrefix("commitments/")` before subscribing. |
| LOW | A6 | `AuthService.swift:120-146` | None — best-effort signOut is correct. |
| LOW | B5 | `AppCheckFactory.swift` | Verify Release archive doesn't ship `AppCheckDebugProvider` symbols. |
| LOW | C3 | `AttestationService.swift:64-71` | None — self-heal flow is correct. |
| LOW | D3 | `BiometricSealer.swift:157` | Replace `as!` with `as?`; treat nil as regenerate. |
| LOW | D4 | `BiometricSealer.swift:96-99` | Either wire `kSecUseAuthenticationContext` or drop unused LAContext. |
| LOW | D5 | `FunctionsService.swift:67-79` | Server pins `(uid, publicKey)` after first observation. |
| LOW | E4 | `WebHomeView.swift:208-220` | Keep `__foundationMobileWebView` non-load-bearing on the web side. |
| LOW | E5 | `PairingCoordinator.swift:66-91` | None. |
| LOW | F2 | `Info.plist` | None — no custom URL scheme registered. |
| LOW | G2 | `SolanaRPC.swift:26-40` | None. |
| LOW | G3 | `SolanaRPC.swift:7` | Optional: profile-driven RPC endpoint. |
| LOW | H3 | `QRScannerView.swift:139-153` | None. |
| LOW | I2/I3 | `FoundationMobile.entitlements` | None — minimum-needed only. |
| LOW | J3 | `AppConfig.swift:115` | None — fatalError is intentional. |
| LOW | J4 | `CaptureView.swift:409` etc. | None — `layerClass` override makes cast safe. |
| LOW | K1 | GCP console (out-of-repo) | Verify Firebase API-key application + API restrictions. |
| LOW | K2 | `GoogleService-Info.plist` | None. |
| LOW | L1 | `Podfile.lock:1392` | Subscribe to OpenSSL advisories. |
| LOW | L2 | `Podfile:14` | Pin `NFCPassportReader` to `~> 2.3.0`. |
| LOW | L3 | `Podfile.lock` | None — two TLS stacks acceptable. |
| LOW | L4 | `PrivacyInfo.xcprivacy` | None — manifest is correct. |
