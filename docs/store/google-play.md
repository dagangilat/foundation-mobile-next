# Google Play Console — submission text (draft)

Status: **draft for Dagan to review and paste in.** Every claim below is
grounded in the current code (file:line references given); anything the code
does not settle is marked `TODO`.

Source app: `applicationId = "com.foundationnext.mobile"`, Kotlin namespace
`com.rarilabs.rarime` (deliberately unchanged, see Open Decision OD-3 —
invisible to users; `android/app/build.gradle.kts`). App label
`@string/app_name` (AndroidManifest.xml `android:label="@string/app_name"`).

## App name (30 characters max)

    Foundation

10 characters. Same name reasoning as the iOS listing (docs/store/app-store-connect.md).
`TODO(Dagan)`: same availability caveat — confirm "Foundation" isn't already
taken on Play; if so use the same qualified variant chosen for iOS so the two
listings match.

## Short description (80 characters max)

    Prove you're a unique human with your passport. Your data stays on-device.

76 characters.

## Full description (4000 characters max)

    Foundation lets you prove you are a unique human — without revealing who you are.

    Using your passport's chip and a zero-knowledge proof generated entirely on your phone, Foundation issues you a private, unforgeable proof of unique personhood for Foundation's governance platform. Your name, photo, and passport number never leave your device — only the cryptographic proof does.

    HOW IT WORKS
    • Scan the machine-readable zone on your passport's photo page with your camera.
    • Tap your phone to your passport's NFC chip to read its signed data.
    • Foundation generates a zero-knowledge proof on your device confirming you hold a valid, unique passport — without transmitting the passport's contents.
    • Sign in to your Foundation account with an emailed one-time code.

    WHY THIS MATTERS
    Foundation's governance platform needs to know that each voice is one real, unique person — without collecting a registry of who everyone is. Zero-knowledge proofs make that possible: the proof convinces the server you're a unique passport holder without disclosing your identity.

    PRIVACY BY DESIGN
    • Passport data (photo, MRZ, chip contents) is processed only on your device and is never uploaded.
    • Only the zero-knowledge proof is sent to Foundation's servers.
    • Sign-in uses your email address and a one-time code — no password to leak.
    • You can permanently delete your account and its server-side data from within the app at any time.
    • Optional encrypted backup of your recovery key to Google Drive (a private app-scoped file in your own Drive), so you can restore access if you lose your device.

    OPEN SOURCE
    Foundation Mobile is free, open-source software (GPL-3.0) built on Rarimo's open-source passport identity protocol. The complete source code is public.

    DEVICE REQUIREMENTS
    Foundation requires a phone with NFC hardware to read the passport chip, and currently ships for arm64 (arm64-v8a) devices only.

    Foundation is free to use.

~1,750 characters — well under the 4000 limit.

`TODO(Dagan)`: same note as iOS — confirm "Foundation's governance platform"
phrasing against whatever public description of the platform is approved.

## Category

**Suggested: Tools** (or **Productivity**, matching the iOS
`LSApplicationCategoryType = public.app-category.productivity` used in
`ios/Info.plist` via pbxproj, for consistency across stores).
`TODO(Dagan)`: pick one and keep both store listings' categories aligned;
Play does not read a value out of the Android manifest/gradle for this the
way iOS reads `LSApplicationCategoryType`, so there's no code-level default
to match — it's a Play Console-only choice.

## Contact details / Privacy URL

- Email: `support@foundation-global.com` — confirmed in code
  (`android/app/src/main/java/com/rarilabs/rarime/BaseConfig.kt:212,482`,
  `override val FEEDBACK_EMAIL = "support@foundation-global.com"`, used by
  `SendEmailUtil.kt` for the in-app feedback flow).
- Website: `TODO(Dagan)` — confirm the public marketing site URL.
- Privacy Policy URL: `TODO(Dagan)` — the Android build currently points a
  constant at `https://foundation-next-app-web.web.app/legal/privacy`
  (`android/app/src/main/java/com/rarilabs/rarime/util/Constants.kt:14`).
  Confirm this is the real, final, publicly reachable privacy policy before
  submitting (or publish docs/store/privacy-policy.md, once legal has
  reviewed it, and use that URL instead).

## App access

The app requires sign-in (email + one-time code — `AuthService`/
`FoundationFunctionsService.requestSignInCode`/`verifySignInCode`,
`android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationFunctionsService.kt`)
before most functionality is usable, so the "App access" section needs
instructions for reviewers.

    All functionality requires signing in with an email address, which
    receives a one-time 6-digit code (no password).

    TODO(Dagan): provide a demo account email here that Play's reviewer can
    use to receive a real sign-in code, or a fixed test code configured
    server-side for review. Full verification also requires scanning a
    physical passport's NFC chip, which the reviewer will not have — TODO(Dagan):
    attach a screen-recording link showing a full scan -> proof ->
    verified-member flow.

## Ads

**No.** No ad SDK (AdMob, Unity Ads, IronSource, AppLovin, MoPub, etc.) is
present in `android/app/build.gradle.kts` (checked directly — none found).
The former AppsFlyer attribution/referral SDK was removed
(`BaseConfig.kt:27-30`: "APPSFLYER_DEV_KEY were deliberately removed by Task
C5 ... along with the earn/wallet modules and AppsFlyer integration"), and no
`appsflyer` reference remains outside comments recording its removal.

## Content rating questionnaire guidance

Based on what the app actually does (identity/passport verification, no
user-generated content feed, no violence, no gambling, no mature themes):

- Violence: None.
- Sexuality: None.
- Language: None.
- Controlled Substance: None.
- User-generated content / user interaction: The app has no chat, forum, or
  content-sharing feature between users; answer "No" to user-generated
  content questions.
- Shares personal info with other users: No — the whole point of the
  zero-knowledge design is that other users/the platform do not see your
  identity.
- Digital purchases: `TODO(Dagan)` — confirm there are no in-app purchases
  (none found in the code: no Play Billing library in
  `android/app/build.gradle.kts`).

Expected resulting rating: comparable to Apple's 4+/Everyone tier, but the
IARC questionnaire determines the actual rating — answer it directly in
Play Console rather than relying solely on this summary.

## Target audience

`TODO(Dagan) — this is a real decision, not just a form field.` Suggested:
**18+ only**, i.e. do not mark the app as appealing to or targeting children,
and set the target age group to Adults only. Reasoning: the app's entire
function is collecting/reading a government-issued passport via NFC and
camera and using it to create an identity-bound proof for a governance
platform — Play's Families/children policies place extra restrictions on
apps that process government ID or biometric-adjacent data from minors, and
a passport holder able to meaningfully use this app is effectively an adult
in nearly all jurisdictions anyway. Marking any age range that includes
children would likely also trigger additional Play Families Policy
requirements (Families ads policy, Designed For Families program rules) that
don't fit this app. **Dagan/legal should confirm** rather than accept this
suggestion blindly, since it affects store placement and policy scope.

## Data safety form

Grounded in the same evidence as the iOS nutrition label
(docs/store/app-store-connect.md's App Privacy section) plus Android-specific
code:

| Data type | Collected? | Shared with third parties? | Optional? | Purpose | Encrypted in transit? | Deletion available? |
|---|---|---|---|---|---|---|
| Email address | Yes | No (sent to Foundation's own Firebase-backed backend only — `FoundationFunctionsService.requestSignInCode`/`verifySignInCode`) | No (required to sign in) | Account management / authentication | Yes (HTTPS/Firebase Functions) | Yes — see Account deletion below |
| User IDs (Firebase uid) | Yes | No | No | App functionality / account management | Yes | Yes |
| Device or other IDs (App Attest / Play Integrity token, FCM registration token) | Yes | Shared with Google/Firebase infrastructure as part of App Check (Play Integrity) and Cloud Messaging, which are Foundation's own chosen processors, not ad/analytics third parties | No | App functionality (anti-spoofing attestation — `firebase-appcheck-playintegrity` + `com.google.android.play:integrity` in build.gradle.kts; push notifications via `firebase-messaging`) | Yes | Yes (tied to account deletion / sign-out) |
| Government IDs (passport) | Processed on-device only; **not** transmitted or stored server-side in raw form | No | N/A | The zero-knowledge proof derived from it is transmitted for verification — see Sensitive Info row below | On-device processing (NFC read + MRZ scan; see `AndroidManifest.xml` camera/NFC permissions) | N/A — nothing raw ever leaves the device |
| Other sensitive info (the zero-knowledge proof itself) | Yes | No (goes to Foundation's own verificator service) | No | Core app functionality — proves unique personhood without revealing identity | Yes | Yes, via account deletion |
| App activity / diagnostics | Likely, via Firebase (see note below) | Possibly, via Google/Firebase's own infrastructure as processor | N/A | Analytics / diagnostics — `TODO(Dagan)`, see note below | Yes | N/A |

**Important nuance to flag to Dagan:** `com.google.firebase:firebase-analytics`
is a direct dependency in `android/app/build.gradle.kts` (`implementation("com.google.firebase:firebase-analytics")`,
plus the legacy `firebase-core:9.6.1`). No explicit `FirebaseAnalytics`
logging call (`.logEvent`, etc.) was found anywhere under
`android/app/src/main/java` — grepped directly, no hits — so it may be an
unused transitive leftover, or it may be silently auto-collecting default
events (app opens, device info) the moment `google-services.json` is
present, the same ambiguity flagged for iOS. `TODO(Dagan)`: either
explicitly disable Firebase Analytics collection (Play Console has a
`firebase_analytics_collection_enabled` manifest meta-data flag for this) if
unwanted, or declare it properly in the Data safety form as an "Analytics"
purpose row if it's meant to be collecting. **Do not submit the Data safety
form claiming no analytics collection without resolving this** — Play does
static + runtime SDK scanning and a mismatch is a real rejection/enforcement
risk.

**Data deletion**: `deleteMyAccount`
(`android/app/src/main/java/com/rarilabs/rarime/foundation/FoundationAccountDeletionManager.kt`
and `FoundationFunctionsService.kt`) is a real, in-app, irreversible
server-side hard delete — the code's own comments cite GDPR Art. 17 — gated
so it always runs before local sign-out, specifically to avoid the app
*looking* like it deleted the account while the server still held the data
(see the extensive comment in `FoundationAccountDeletionManager.kt`
describing exactly that prior bug). Answer **"Yes, users can request that
data be deleted"** in the Data safety form, and reference the in-app
"Delete account" flow (`ProfileViewModel.kt`, `ProfileScreen.kt`) rather than
only an external web form.

**Data in transit**: all network calls found are HTTPS (Firebase
Functions/Auth SDKs, `RELAYER_URL`, `EVM_RPC_URL`, `storage.googleapis.com`
circuit downloads in `BaseConfig.kt`) — no cleartext HTTP endpoints were
found. Answer "Yes, data is encrypted in transit" for every row.

## Government app / financial features declarations

- **Government app**: **No.** Foundation is not built or operated by a
  government entity; it is Foundation's own governance-platform app that
  happens to use a passport as an identity credential. Answer "No" to Play's
  "is this a government app" declaration.
- **Financial features**: **No,** with a caveat. The `earn`/wallet UI modules
  and their user-facing crypto features were removed (`BaseConfig.kt:27-30`:
  "...gone along with the earn/wallet modules..."). The app does still talk
  to blockchain infrastructure under the hood (`RELAYER_URL`, `EVM_RPC_URL`,
  `STATE_KEEPER_CONTRACT_ADDRESS`, `REGISTRATION_SMT_CONTRACT_ADDRESS` in
  `BaseConfig.kt`), but this is for the identity-registration smart contracts
  the zero-knowledge proof protocol relies on, not a user-facing wallet,
  exchange, loan, or payments feature. `TODO(Dagan)`: confirm with
  engineering that no user-facing send/receive/trade functionality remains
  reachable in the shipped app before answering "No" here — the code
  reference (`WalletUtil.kt` still exists as a utility file) is not by
  itself proof that no UI path reaches it.

## Health

**No.** No `HealthConnect`, `HEALTH_CONNECT`, fitness, or medical data
permissions or SDKs were found in `AndroidManifest.xml` or
`android/app/build.gradle.kts`.

## Graphics requirements

- **App icon**: 512 × 512 px, 32-bit PNG (with alpha), max 1 MB.
- **Feature graphic**: 1024 × 500 px, JPG or 24-bit PNG (no alpha).
- **Phone screenshots**: minimum 2, maximum 8; each side between 320 px and
  3840 px, and the longest side no more than twice the shortest side (i.e.
  16:9 or narrower aspect ratios work; very elongated images are rejected).
  JPG or 24-bit PNG (no alpha).
- **7" / 10" tablet screenshots**: optional but recommended if the app is
  marked tablet-compatible; same format/size rules as phone screenshots at
  tablet resolutions.

`TODO(Dagan)`: Play Console's exact accepted ranges shift occasionally;
confirm current requirements in Play Console's Store listing graphics panel
at upload time.

## Personal developer account: 12-tester / 14-day closed testing requirement

If the Play Console developer account this app is published under is a
**personal account created after November 2023**, Google requires — before
the app can go to production — a closed test with at least **12 testers**
opted in continuously for at least **14 days**, plus a completed
pre-launch report review. `TODO(Dagan)`: confirm which kind of account
(personal vs. organization) this will be published under, since the
requirement does not apply to accounts that qualify as organizations. If it
applies, this needs to be scheduled well before the intended launch date —
it is a hard gate Play enforces before allowing a production release, not
just a recommendation, and 14 days of continuous tester opt-in is the
binding constraint on the submission timeline.
