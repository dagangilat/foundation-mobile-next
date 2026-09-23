# App Store Connect — submission text (draft)

Status: **draft for Dagan to review and paste in.** Every claim below is
grounded in the current code (file:line references given); anything the code
does not settle is marked `TODO`. Do not paste this in without reading the
TODOs — several are blocking (legal review, real URLs, a demo account).

Source app: `com.foundationnext.mobile`, display name **Foundation**
(`ios/FoundationMobile.xcodeproj/project.pbxproj:2744` —
`INFOPLIST_KEY_CFBundleDisplayName = Foundation`).

---

## App name (30 characters max)

    Foundation

10 characters. Matches `INFOPLIST_KEY_CFBundleDisplayName` exactly
(pbxproj:2744, 2801, 2924, 3040 — same value on every build configuration).

`TODO(Dagan)`: "Foundation" alone is likely already taken or too generic on
the App Store. If so, a qualified variant is needed, e.g. "Foundation:
Proof of Human" (29 chars) or "Foundation Identity" (20 chars) — pick one and
keep it consistent with the subtitle below.

## Subtitle (30 characters max)

    Prove you're a unique human

28 characters. Drawn from README.md:3 ("Prove you are a unique human with a
passport, without revealing who you are.").

## Promotional text (170 characters max, can be changed any time without review)

    Verify your unique humanity with your passport — entirely on your phone. Only a zero-knowledge proof leaves your device. No passport data is ever uploaded.

169 characters. Grounded in: passport processed on-device via NFC
(`com.apple.developer.nfc.readersession.iso7816.select-identifiers` in
ios/Info.plist) + MRZ camera scan
(`INFOPLIST_KEY_NSCameraUsageDescription`, pbxproj:2747: "Foundation uses the
camera to scan the machine-readable zone on your passport photo page."), and
docs/app-store-review-notes.md: "All passport data is processed on-device;
only a zero-knowledge proof leaves the phone."

## Description (4000 characters max)

    Foundation lets you prove you are a unique human — without revealing who you are.

    Using your passport's chip and a zero-knowledge proof generated entirely on your phone, Foundation issues you a private, unforgeable proof of unique personhood for Foundation's governance platform. Your name, photo, and passport number never leave your device — only the cryptographic proof does.

    HOW IT WORKS
    • Scan the machine-readable zone on your passport's photo page with your camera.
    • Tap your phone to your passport's NFC chip to read its signed data.
    • Foundation generates a zero-knowledge proof on your device confirming you hold a valid, unique passport — without transmitting the passport's contents.
    • Sign in to your Foundation account with an emailed one-time code.
    • Unlock the app locally with Face ID / biometrics — your biometric data never leaves your device or reaches Foundation.

    WHY THIS MATTERS
    Foundation's governance platform needs to know that each voice is one real, unique person — without collecting a registry of who everyone is. Zero-knowledge proofs make that possible: the proof convinces the server you're a unique passport holder without disclosing your identity.

    PRIVACY BY DESIGN
    • Passport data (photo, MRZ, chip contents) is processed only on your device and is never uploaded.
    • Only the zero-knowledge proof is sent to Foundation's servers.
    • Sign-in uses your email address and a one-time code — no password to leak.
    • You can permanently delete your account and its server-side data from within the app at any time.
    • Optional encrypted backup of your recovery key to iCloud, so you can restore access if you lose your device.

    OPEN SOURCE
    Foundation Mobile is free, open-source software (GPL-3.0) built on Rarimo's open-source passport identity protocol. The complete source code is public.

    Foundation is free to use.

~1,650 characters — well under the 4000 limit.

`TODO(Dagan)`: Replace "Foundation's governance platform" language with
whatever public description of Foundation's platform is approved for
marketing use; I've kept it generic and accurate to what NOTICE/README say
("Foundation's governance platform") without inventing specifics.

## Keywords (100 characters max, comma-separated, no spaces needed around commas)

    passport,identity,zero-knowledge,proof,privacy,verification,human,unique,governance,voting

99 characters.

## URLs

- Support URL: `TODO(Dagan)` — needs a real, reachable support page (not just
  a mailto). `FEEDBACK_EMAIL` in code resolves to
  `support@foundation-global.com` (android/app/src/main/java/.../BaseConfig.kt:212,482)
  — a support page can point here, but Apple wants a URL, not a bare email.
- Marketing URL: `TODO(Dagan)` — `WEB_APP_URL` is an env-injected placeholder
  in ios/Info.plist (`${WEB_APP_URL}`), not a committed value. Confirm the
  public marketing site.
- Privacy Policy URL: `TODO(Dagan)` — `PRIVACY_POLICY_URL` is likewise
  env-injected in ios/Info.plist. The Android build currently points a
  constant at `https://foundation-next-app-web.web.app/legal/privacy`
  (android/.../util/Constants.kt:14) — confirm this is the real, final,
  publicly reachable policy URL (or publish docs/store/privacy-policy.md,
  see that file, once legal has reviewed it) before submitting.

## Category

- Primary: **Utilities** — suggested change from the current Info.plist
  value. `INFOPLIST_KEY_LSApplicationCategoryType` is currently
  `public.app-category.productivity` (pbxproj:2745, 2802, 2925, 3041), but
  App Store Connect's own category picker for an identity/verification app
  more commonly fits **Utilities**; Productivity is a defensible second
  choice and matches the shipped Info.plist value exactly, so it is the
  safer no-code-change option.
  `TODO(Dagan)`: decide whether to keep Productivity (matches code, zero
  risk) or ask engineering to change the Info.plist key to Utilities before
  submission.
- Secondary: Utilities (if Productivity is kept as primary), or none.

## Age rating questionnaire

Apple's current (2026) age-rating questionnaire is a set of yes/no content
questions rather than a single age picker. Based on what the app actually
does (identity verification, no user-generated content feed, no gambling, no
violence, no mature themes):

- Unrestricted Web Access: **No**
- Cartoon or Fantasy Violence / Realistic Violence: **No**
- Sexual Content or Nudity: **No**
- Profanity or Crude Humor: **No**
- Alcohol, Tobacco, or Drug Use/References: **No**
- Mature/Suggestive Themes: **No**
- Horror/Fear Themes: **No**
- Gambling (Simulated or Contests): **No**
- Medical/Treatment Information: **No**
- Loot Boxes: **No**
- Contests: **No**
- Unrestricted access to third-party/user-generated content: **No**

Expected resulting rating: **4+**.

`TODO(Dagan)`: the app collects a government ID document (passport) as its
core function. Apple's questionnaire does not have a dedicated "ID
verification" flag, but confirm at submission time whether Apple's current
form (it changes) asks about this directly — answer honestly if so.

## Price

**Free.** Grounded in README.md:3 area / docs/app-store-review-notes.md:
"The app is distributed free."

## App Privacy ("nutrition label")

Grounded directly in `ios/FoundationMobile/PrivacyInfo.xcprivacy`, which
already declares the following `NSPrivacyCollectedDataTypes` (all with
`NSPrivacyCollectedDataTypeTracking = false` and purpose
`AppFunctionality`):

| Data type (App Store Connect label) | Linked to identity? | Used for tracking? | Grounding |
|---|---|---|---|
| Email Address | Yes | No | PrivacyInfo.xcprivacy `NSPrivacyCollectedDataTypeEmailAddress` (Linked: true). Matches `AuthService.sendCode(to:)` emailing a 6-digit sign-in code (ios/FoundationMobile/Code/Foundation/AuthService.swift) via Foundation's `requestSignInCode`/`verifySignInCode` callables (FunctionsService.swift). |
| User ID | Yes | No | PrivacyInfo.xcprivacy `NSPrivacyCollectedDataTypeUserID`. Matches the Firebase Auth `uid` (`AuthService.uid`, AuthService.swift). |
| Device ID | Yes | No | PrivacyInfo.xcprivacy `NSPrivacyCollectedDataTypeDeviceID`. Matches the App Attest key/device attestation (`AttestationService`, referenced from AuthService.swift `registerDeviceAttestationIfNeeded()`) and/or the FCM registration token (NotificationManager.swift, FoundationApp.swift `didReceiveRegistrationToken`). |
| Sensitive Info (Apple's category for data like government ID) | Yes | No | PrivacyInfo.xcprivacy `NSPrivacyCollectedDataTypeSensitiveInfo`. Covers the zero-knowledge proof derived from passport data (the proof itself, not raw passport contents, is what is transmitted — see FoundationVerificationManager.swift's `beginVerification()`/`startL2Verification` flow and docs/app-store-review-notes.md's "only a zero-knowledge proof leaves the phone"). `TODO(Dagan)`: confirm with the backend team exactly what is asserted about the proof payload (e.g., nationality/circuit metadata) so this row's description in Apple's label picker (which asks for a more specific sub-type) is precise. |
| Other Diagnostic Data | No (not linked) | No | PrivacyInfo.xcprivacy `NSPrivacyCollectedDataTypeOtherDiagnosticData`. Covers crash/error logs (`LoggerUtil` calls throughout, e.g. AuthService.swift `error(...)`) and Firebase Analytics' default auto-collected diagnostics — see note below. |

Data types **not** declared as collected in PrivacyInfo.xcprivacy and not
found in the code: Contacts, Location, Health, Financial Info, Browsing
History, Photos (beyond the on-device MRZ camera frame, which is not
uploaded), Search History.

**Important nuance to flag to Dagan before finalizing the nutrition label:**
Firebase Analytics (`FirebaseAnalytics` product, linked in
`ios/FoundationMobile.xcodeproj/project.pbxproj:3304,3314` and built into
both the main app and an extension target) is present in the compiled app.
No explicit `Analytics.logEvent(...)` call was found anywhere under
`ios/FoundationMobile` — it is linked but not obviously driven by app code —
however, the Firebase Analytics SDK auto-collects some data by default (app
opens/foreground events, device model, OS version, an analytics identifier)
once `FirebaseApp.configure()` runs (FoundationApp.swift), unless explicitly
disabled via `FirebaseAnalyticsCollectionEnabled = false`, which is **not**
set anywhere in ios/Info.plist. `TODO(Dagan)`: either (a) explicitly disable
Firebase Analytics collection if it isn't wanted, and drop the "Analytics"
purpose from the label, or (b) confirm it is wanted and add an explicit
"Usage Data" / "Product Interaction" row with purpose "Analytics" to the
label — right now the label doesn't mention it at all, and Apple can reject
for a label that doesn't match the compiled binary's actual SDK behavior.

**Tracking**: `NSPrivacyTracking` is `false` at the top level of
PrivacyInfo.xcprivacy, and no `NSPrivacyTrackingDomains` array is present
(confirmed empty per docs/app-store-review-notes.md's note on the AppsFlyer
removal). Answer **"No, we do not use data for tracking"** in App Store
Connect's tracking question.

## Export compliance

`ios/Info.plist` sets `ITSAppUsesNonExemptEncryption` to **false**
(`<key>ITSAppUsesNonExemptEncryption</key><false/>`). This tells Apple the
app either uses no encryption, or only encryption that qualifies for the
standard exemptions (HTTPS/TLS, or crypto used solely for authentication /
digital signature / DRM, using industry-standard algorithms).

**Why this looks plausibly right:** all of the app's networking is to
Firebase (Auth, Functions, App Check) and Foundation's own HTTPS APIs —
standard TLS. The zero-knowledge proof system (`witnesscalc` +
`rapidsnark`, see THIRD_PARTY_LICENSES.md) authenticates a passport holder's
uniqueness rather than encrypting content for confidentiality, which is the
kind of use Apple's authentication/signature exemption is meant to cover.

**Why this needs a human check, not just this doc's judgement:** Apple's
export-exemption categories are narrow and the zk-SNARK proving stack
(Groth16 proofs, elliptic-curve pairing crypto) is not the textbook
"HTTPS-only" case the `false` answer is usually used for. Whether it
qualifies for the authentication exemption or actually requires a real
export classification (self-classification report / ERN under French or US
export rules) is a legal/export-compliance question, not a code-reading one.
`TODO(Dagan)`: **confirm `ITSAppUsesNonExemptEncryption = false` with
whoever owns export compliance before the first submission** — this is
called out because getting it wrong is a real (if rarely enforced) legal
exposure, not just a form field.

docs/app-store-review-notes.md's Open Decision OD-2 (the GPL/App Store EULA
conflict) is a separate, already-flagged legal item — re-surfacing it here
because both are "needs a real legal read" items due before submission.

## App Review notes (the private note to Apple's reviewer)

    Foundation verifies that a user holds a unique, valid passport, using a
    zero-knowledge proof generated on-device. Reviewer notes:

    SIGN-IN: The app requires signing in with an email address; Foundation
    emails a 6-digit one-time code (no password). TODO(Dagan): provide a demo
    account's email address here that the reviewer can use to receive a real
    code, or a fixed test code configured server-side for App Review. Without
    one, the reviewer cannot get past sign-in.

    PASSPORT SCAN: Full verification requires scanning a real physical
    passport's NFC chip and MRZ, which the reviewer will not have. TODO(Dagan):
    attach a screen-recording (link here) showing a full scan -> proof ->
    verified-member flow, so the reviewer can see the feature working without
    needing a physical passport.

    PERMISSIONS REQUESTED:
    - NFC: reads the passport chip's signed data on-device. Core function of
      the app; nothing read is uploaded.
    - Camera: scans the passport's printed machine-readable zone (MRZ) on-
      device; no photo is uploaded.
    - Face ID: local app-lock only. No biometric data leaves the device or is
      sent to Foundation (see NSFaceIDUsageDescription in Info.plist).
    - App Attest entitlement: used to prove requests to Foundation's backend
      come from a genuine, unmodified build of this app (anti-spoofing),
      registered against the signed-in member's account after sign-in.

    OPEN SOURCE / LICENSING: this app is free and open-source (GPL-3.0). It
    statically links the GPL-3.0 `witnesscalc` and LGPL-3.0 `rapidsnark`
    zero-knowledge proving libraries. Complete corresponding source is public.
    TODO(Dagan): confirm the GPL/App Store EULA permission language (see
    docs/app-store-review-notes.md Open Decision OD-2) has had its legal
    review before this note is finalized, since it may need to say something
    specific to Apple here.

## Screenshot size requirements

Apple currently (2026) requires screenshots sized for the largest device in
each display-size family you support; App Store Connect will scale them down
for smaller devices in the same family automatically if you only upload the
largest size per family. Since this app is portrait-only
(`INFOPLIST_KEY_UISupportedInterfaceOrientations =
UIInterfaceOrientationPortrait`, pbxproj:2752 etc.) and supports iPad in
landscape+portrait (`..._iPad` key, pbxproj:2753), plan for:

- **iPhone 6.9" display** (e.g. iPhone 16 Pro Max class): 1320 × 2868 px
  (portrait) — required if the app supports the newest iPhone size class.
- **iPhone 6.5" display** (e.g. iPhone 11 Pro Max / XS Max class): 1284 × 2778
  px or 1242 × 2688 px (portrait) — still accepted as a fallback size on many
  accounts.
- **iPad 13" display** (e.g. iPad Pro 12.9" class): 2064 × 2752 px (portrait)
  or 2752 × 2064 (landscape) — required if you mark the app as iPad-
  compatible, which the Info.plist orientation keys suggest it is.

`TODO(Dagan)`: Apple's exact required-size list shifts most years as new
device classes ship; **confirm the current required sizes in App Store
Connect's Media Manager at upload time** rather than trusting this table —
it reflects what was current for 2026 device classes, not a live spec.
