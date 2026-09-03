# App Store / Play Store review notes

## Open-source and licensing disclosure

Foundation Mobile is a fork of Rarimo's `rarime-ios-app` (MIT) that statically
links GPL-3.0 `witnesscalc` and LGPL-3.0 `rapidsnark` proving libraries. The
app is distributed free, and the complete corresponding source is public at
https://github.com/dagangilat/foundation-mobile-next.

Apple's App Store Review Guidelines do not prohibit GPL-licensed apps outright,
but the App Store's standard EULA conflicts with GPL-3.0's terms. Distributing
a GPL-3.0 app on the App Store therefore requires the copyright holder to grant
an additional permission, which we can grant because we are the copyright holder
of the combined work. This is recorded here so the point is not rediscovered at
submission time. **See Open Decision OD-2 — this needs a real legal read before
first submission, not a plan author's judgement.**

## Prior art to check before submitting

Spec § 3 names this as the cheapest next step, and it is still outstanding:
Rarimo's own Freedom Tool apps (Russia2024, Iranians Vote) are real App Store
and Play Store distributions carrying this identical proving stack. They have
solved shipping it at least once. Before the first submission, look at how those
listings are worded and licensed — that is higher-leverage than a cold legal
review.

## Review-sensitive capabilities to declare

| Capability | Why the app needs it |
|---|---|
| NFC (`NFCReaderUsageDescription`) | Reading the passport chip — the core function. |
| Camera | MRZ scan. |
| App Attest entitlement | Anti-spoofing: proves requests come from a genuine build. |
| Face ID | Local app lock only; no biometric data leaves the device. |

## Privacy positioning

All passport data is processed on-device; only a zero-knowledge proof leaves the
phone. `PrivacyInfo.xcprivacy` (recovered from the pre-fork shell after the
Phase B final review found it had been dropped entirely during the shell's
deletion — Apple requires one for submission) declares `NSPrivacyTracking:
false` at the top level and `NSPrivacyCollectedDataTypeTracking: false` on
every individual data type — checked directly, it never declared an
`NSPrivacyTrackingDomains` array, so there was nothing AppsFlyer-related to
strip when Task B5 removed that SDK. Re-audit only if a future task adds a
new required-reason API or a new data collection surface.

## Google Play specifics

- **Target API level:** 35 (`targetSdk`), meeting Play's current requirement.
- **ABI:** `arm64-v8a` only. Declared deliberately — the proving libraries are
  shipped for that ABI alone. Play will restrict device availability
  accordingly; this is expected, not a packaging error.
- **Native debug symbols:** `debugSymbolLevel = "SYMBOL_TABLE"` is already set,
  so the bundle carries symbols for the native crash reports Play expects.
- **Data safety form:** all passport processing is on-device; only a
  zero-knowledge proof leaves the phone. AppsFlyer was removed in Task C5, so
  no advertising or attribution SDK is present — the form must say so.
- **GPL and the Play Store:** unlike the App Store, Google Play's Developer
  Distribution Agreement does not impose EULA terms that conflict with the GPL,
  so Android carries materially less licensing friction than iOS. See Open
  Decision OD-2 — the iOS side is where the legal read is actually needed.
