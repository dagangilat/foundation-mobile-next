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
| Camera | MRZ scan and liveness. |
| App Attest entitlement | Anti-spoofing: proves requests come from a genuine build. |
| Face ID | Local app lock only; no biometric data leaves the device. |

## Privacy positioning

All passport data is processed on-device; only a zero-knowledge proof leaves the
phone. The privacy manifest (`PrivacyInfo.xcprivacy`) must reflect that no
personal data is collected. Re-audit it after Task B5 removed AppsFlyer — the
inherited manifest may still declare tracking domains.
