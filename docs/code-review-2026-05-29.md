# Code Review — Foundation Mobile (iOS)
**Date:** 2026-05-29  
**Reviewer:** Claude (subagent)  
**Scope:** Full codebase — `bcd2d792..2e2dcc32`  
**Verdict:** Not production-ready — 3 critical issues (1 needs immediate action on live credentials)

---

## Strengths

- Deep-link attack surface eliminated: email-link path retired, `onOpenURL` is a documented no-op.
- CSCA-chain non-verification gap is flagged inline (not hidden), documented as a Phase 3a known gap.
- WKWebView domain allowlist (`WebContainer.decidePolicyFor`) prevents token exfiltration to third-party navigations.
- JWT shape regex guard before `callAsyncJavaScript` injection removes the string-escape injection class.
- Token passed through `arguments:` rather than string-interpolated — correct WKWebView API usage.
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` on the biometric seal key is the right choice for Secure Enclave data.
- Generation counter in `AttestationCoordinator` correctly defends against stale DCAppAttestService callback races.
- Biometric consent gate (GDPR Art. 9 / BIPA) recorded server-side before any biometric capture — correct order.
- WKWebsiteDataStore cleared on sign-out, preventing cross-user cookie leakage.
- `@MainActor` / actor isolation applied consistently across `AuthService`, `AttestationCoordinator`, `CaptureCoordinator`, `PairingCoordinator`.
- Mock artifacts labeled `mock:<tag>` in `signatureBase64` so server-side enforcement can reject them when hardened.

---

## Issues

### Critical (Must Fix)

**1. `GoogleService-Info.plist` committed with live Firebase API key**  
`ios/FoundationMobile/GoogleService-Info.plist`

The file is tracked in git and contains:
```
<key>API_KEY</key>
<string>AIzaSyBb5Cvhm2ndMdz8A90KnpP5w1-7XOGV2yk</string>
```

Anyone with repo access can use this to enumerate Auth users, attempt quota exhaustion, or abuse any Firebase resource with permissive rules. **Rotate immediately.**

**Fix:**
1. Rotate the API key in Firebase Console now.
2. Add `ios/FoundationMobile/GoogleService-Info.plist` to `.gitignore`.
3. In CI (`.github/workflows/ios-ci.yml`), inject via:
   ```sh
   echo "$GOOGLE_SERVICE_INFO_B64" | base64 -d > ios/FoundationMobile/GoogleService-Info.plist
   ```

---

**2. `Keychain.swift` uses `kSecAttrAccessibleAfterFirstUnlock` for sensitive items**  
`ios/FoundationMobile/Keychain.swift:81`

```swift
query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
```

This makes the App Attest key ID and pending sign-in email readable while the device is locked — accessible to background processes and to an attacker with a jailbroken device. `BiometricSealer.swift` correctly uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; the Keychain utility should match.

**Fix:**
```swift
query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

---

**3. `WKUserContentController` message handler retain cycle**  
`ios/FoundationMobile/WebHomeView.swift:257-261`

`WKUserContentController.add(_:name:)` retains the handler strongly. WKWebView can hold the content controller alive after dismissal, creating a retain cycle: `WKWebView → WKUserContentController → SignOutMessageHandler`. This leaks memory and may trigger unexpected sign-outs on subsequent page loads.

**Fix:** Add to `WebContainer.Coordinator.deinit`:
```swift
deinit {
    webView?.configuration.userContentController
        .removeScriptMessageHandler(forName: "foundationMobileSignOut")
}
```

---

### Important (Should Fix)

**4. Unguarded `print` in release builds**  
`ios/FoundationMobile/HomeView.swift:856`

```swift
print("[HomeView] biometric gate skipped: \(error)")
```

Outside `#if DEBUG`. LAError descriptions can include biometric enrollment state metadata, written to the unified log and readable via Console.app with USB access. `AuthService.swift:123` explicitly flags this risk.

**Fix:**
```swift
#if DEBUG
print("[HomeView] biometric gate skipped: \(error)")
#endif
```

---

**5. Mock-producer loop missing `.nfcZk` for `lowsec-attest` profile**  
`ios/FoundationMobile/CaptureCoordinator.swift:500-506`

The mock-producer fallback loop only iterates `[.antiSpoof, .faceMatch]`. On `lowsec-attest`, `MockNfcZkProducer` would be registered but never called, so the commitment submitted to the server is silently missing the `.nfcZk` artifact.

**Fix:** Add `.nfcZk` to the loop, or replace the explicit list with `ProofArtifact.Kind.allCases` filtered by already-emitted kinds.

---

**6. `AttestationCoordinator.tier` returns `.standard` during transitional states**  
`ios/FoundationMobile/AttestationCoordinator.swift:56-62`

During `.idle`, `.attesting`, `.failed`, `tier` returns `.standard` (optimistic). If `mintWebSessionToken` is dispatched while attestation is still in-flight and later resolves to `.unattested`, the server-side tier stamp on that request is incorrect — creating misleading audit records.

**Fix:** Return `.unattested` during transitional states. The UI gates already block high-value callables on `verifyStage`, so there is no user-facing friction cost.

---

**7. `AntiSpoofProducer` loads CoreML models synchronously on `@MainActor`**  
`ios/FoundationMobile/AntiSpoofProducer.swift:56-64`

`MLModel.compileModel(at:)` is blocking and can take 1–2s per model on a cache miss. The initializer runs on `@MainActor` inside a `CaptureCoordinator.verify()` Task, freezing the UI for 2–4s on first run.

**Fix:** Move model loading into `produce()` (which already runs inside a detached Task), or wrap `loadBundled` in a background continuation.

---

**8. `CaptureCoordinator.verify()` latent concurrency trap in `CameraSession.frames()`**  
`ios/FoundationMobile/CameraSession.swift:78-93`

`frames()` stores the `AsyncStream.Continuation` from the `@MainActor` context while `captureOutput` mutates `continuations` via a `@MainActor` dispatch. Currently safe because all callers are `@MainActor` coordinators, but easy to violate accidentally.

**Fix:** Add a comment documenting the `@MainActor` requirement on callers. No code change required now.

---

### Minor (Nice to Have)

**9. `PairingCoordinator.startHeartbeat` transitions to `.failed` on first error**  
`ios/FoundationMobile/PairingCoordinator.swift:176-179`  
Comment says "two consecutive missed beats" but implementation fails immediately. A single transient network blip surfaces `.failed` to the UI.

**10. WKWebView navigation allowlist missing subdomains**  
`ios/FoundationMobile/WebHomeView.swift:307-310`  
`allowedHosts` only includes `foundation-global.com` and `www.foundation-global.com`. The three-pillar hostname routing (`voice.`, `share.`, `market.`) will cause navigations to be cancelled if the web app redirects to these subdomains.

**11. `select-profile.sh` uses `$SRCROOT` which may not resolve outside Xcode**  
`ios/scripts/select-profile.sh:5`  
A direct shell invocation without `SRCROOT` set produces a misleading path error. `set -e` means it hard-fails rather than silently shipping the wrong profile — the risk is a confusing CI message.

---

## Recommendations

1. **Immediately:** Rotate Firebase API key, gitignore `GoogleService-Info.plist`, add CI secret injection.
2. **Before TestFlight / App Store:** Fix Keychain accessibility class (issue 2) and WKUserContentController retain cycle (issue 3).
3. **Before `hisec-global` goes live:** Fix mock-producer `.nfcZk` gap (issue 5) and release-build `print` (issue 4).
4. **Before wide TestFlight rollout:** Fix `AntiSpoofProducer` blocking init (issue 7) and `AttestationCoordinator.tier` conservative default (issue 6).
5. **Phase 3a tracking:** Add CSCA masterlist bundle (flagged inline in `PassportNFCReader.swift`) before treating NFC scan as production-grade evidence.

---

## Fix Priority

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Firebase API key in git — rotate immediately | Critical | ⬜ Open |
| 2 | Keychain `kSecAttrAccessibleAfterFirstUnlock` | Critical | ⬜ Open |
| 3 | WKUserContentController retain cycle | Critical | ⬜ Open |
| 4 | Release-build `print` in `HomeView` | Important | ⬜ Open |
| 5 | Mock-producer loop missing `.nfcZk` | Important | ⬜ Open |
| 6 | `AttestationCoordinator.tier` conservative default | Important | ⬜ Open |
| 7 | `AntiSpoofProducer` blocking CoreML load | Important | ⬜ Open |
| 8 | `CameraSession.frames()` caller docs | Minor | ⬜ Open |
| 9 | Heartbeat 2-miss policy | Minor | ⬜ Open |
| 10 | WKWebView subdomain allowlist | Minor | ⬜ Open |
| 11 | `select-profile.sh` `$SRCROOT` doc | Minor | ⬜ Open |
