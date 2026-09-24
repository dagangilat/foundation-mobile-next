# Foundation Mobile — Privacy Policy (DRAFT)

> **This is a draft written from a reading of the app's source code. It has
> not been reviewed by a lawyer and must not be published as-is.** It exists
> to give legal counsel an accurate, evidence-grounded starting point,
> instead of counsel (or Dagan) having to reverse-engineer what the app
> actually does from scratch. Every factual claim below is grounded in a
> specific file in this repository; `TODO` markers show what still needs a
> business/legal decision rather than a code reading.

`TODO(Dagan/legal)`: fill in before publishing —
- **Legal entity name**: `TODO` — NOTICE currently reads "Copyright (c) 2026
  Dagan Gilat / Foundation," which is not itself a legal entity name. Confirm
  the actual publishing entity (e.g. a registered company name) for this
  policy's "we"/"us"/"Foundation" references and its footer.
- **Contact email for privacy requests**: `TODO` — the app's general support
  address is `support@foundation-global.com`
  (`android/app/src/main/java/com/rarilabs/rarime/BaseConfig.kt:212,482`).
  Confirm whether privacy-specific requests (data access, deletion,
  complaints) should go to this address or a dedicated one (e.g.
  privacy@...).
- **Governing jurisdiction**: `TODO` — not determinable from the code. This
  affects which specific statutory rights (GDPR, CCPA/CPRA, etc.) must be
  named explicitly rather than described generically as below.
- **Effective date**: `TODO` — set when this is finalized and published.

---

## Last updated

`TODO(Dagan)` — set on publish.

## Who this policy covers

This policy covers the Foundation Mobile app ("Foundation," "the app"), for
iOS (bundle ID `com.foundationnext.mobile`) and Android (application ID
`com.foundationnext.mobile`), published by `TODO(legal entity name)`.

## What Foundation does

Foundation lets you prove you are a unique human, using your passport, for
Foundation's governance platform — without revealing your identity to
Foundation or to the platform. It does this by reading your passport's chip
(via NFC) and photo page (via your camera), generating a cryptographic
zero-knowledge proof of your passport's validity and uniqueness entirely on
your device, and registering that proof. Your name, photo and passport
number are not uploaded. The sections below list exactly what does leave
your device, and where it goes.

## Information we collect, and why

### Passport data — read and processed on your device

When you scan your passport, the app reads the printed machine-readable zone
(via your camera) and the chip's signed data (via NFC). Your name, passport
number, date of birth, nationality and photo are processed on your device
to generate a zero-knowledge proof. **Your name, photo and passport number
are not uploaded.** They stay on your phone, stored in the app's private
storage, until you delete your account or the app.

Camera and NFC access exist only to perform this scan and to scan QR codes
you choose to scan; see the in-app permission prompts ("Foundation reads
your passport's chip to create a private proof that you're a unique person.
Your name, photo and passport number are not uploaded." / the camera prompt
for the passport photo page and QR codes).

### The zero-knowledge proof and the identity registry

The proof your device generates is registered in an open, public identity
registry (the Rarimo identity registry, operated by a third party), through
that registry's relayer service. Registration is anonymous: the registry
records that a valid, unique passport was used, without your name, photo or
passport number. We use your registration to confirm your unique-personhood
status with Foundation's governance platform.

### Passport security data (fallback registration only)

Some passports cannot be proven fully on the phone (for example, because of
the signature algorithm the issuing country uses). For those passports only,
the app falls back to a registration service operated by the identity
registry's provider. In that case the app sends the chip's signed security
data: the document security object (a signed list of fingerprints of the
chip's data groups, not the data itself), the chip's public key (DG15), the
chip's active-authentication signature, and the issuing country's
document-signer certificate. The service checks these and returns a
signature that lets the proof be registered. Your name, photo and passport
number are not part of this data.

`TODO(legal)`: confirm with the registry provider what it retains from the
fallback request and for how long, and link its privacy policy here.

### Information shared with partners, with your consent

When you scan a partner's QR code, the partner may ask you to prove
something about yourself (for example, that you are over 18, or a specific
field such as your name or nationality). The app shows you exactly what the
partner is asking for before anything is sent, and nothing is shared unless
you accept. What you accept is sent to that partner, and that partner's own
privacy policy applies to it.

### Email address and sign-in code

To create and access your Foundation account, we collect your email address.
We send a one-time 6-digit code to that address for sign-in; we do not use
passwords. We retain your email address for as long as your account exists,
to let you sign in and to communicate with you about your account.

### Account identifier (user ID)

Once you sign in, we assign your account a unique identifier (managed via
our authentication provider, Firebase Authentication). This identifier is
used to associate your zero-knowledge proof, verification status, and
account settings with your account.

### Device attestation identifiers

To protect the integrity of the verification process and confirm that
requests to our servers come from a genuine, unmodified copy of the app —
not a tampered or emulated one — the app registers a device-level
attestation credential with our servers after you sign in. On iOS this uses
Apple's App Attest; on Android this uses Google Play Integrity. This does
not identify you personally beyond your account; it identifies your device
as genuine.

### Push notification token

If you allow notifications, the app registers with Firebase Cloud Messaging
(FCM) and subscribes to notification topics (for example, a general
announcements topic) so we can send you app and account-related
notifications. Firebase, operated by Google, acts as our infrastructure
provider for this.

### No analytics or usage tracking

The app does not collect analytics or usage data. The Firebase Analytics
library is part of Google's Firebase SDK that the app is built with, but its
collection is switched off in the app's configuration on both platforms
(`FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED` on iOS,
`firebase_analytics_collection_deactivated` on Android), and the Android
advertising-ID permission is removed. The app does not track you across
other companies' apps or websites.

### Recovery key backup (optional)

If you choose to enable backup, the app can store a copy of your
local recovery key — the credential used to recover access to your identity
if you lose your device — in your own personal cloud storage:

- On iOS, via your personal iCloud account (a private, Foundation-specific
  iCloud container that only this app can read).
- On Android, via your personal Google Drive account (after you explicitly
  sign in with Google for this purpose).

This backup is optional and under your control. We (Foundation) do not have
access to this data — it is stored in your own iCloud/Google Drive account,
not on Foundation's servers. When you delete your account in the app, the
app also deletes this backup from your iCloud or Google Drive.

`TODO(Dagan)`: on Android the backed-up key is stored as plain text inside
the app's private Drive folder (only this app can read that folder). Decide
whether to encrypt it in a future version; changing it needs a migration so
existing backups still restore.

## Information we do not collect

Based on a direct review of the app's code, Foundation does not collect:
your passport photo or MRZ contents in raw form, your biometric data (Face
ID/fingerprint unlock happens entirely on-device and is never transmitted to
us or seen by us), your contacts, your precise location, your browsing or
search history, your financial/payment information, or analytics/usage
data. The app contains no advertising SDK and no install-attribution SDK.

## Who we share information with

- **Firebase / Google Cloud**: Foundation's backend runs on Firebase
  (Authentication, Cloud Functions, App Check, Cloud Messaging), operated by
  Google, which processes the data described above (email, account ID,
  device attestation token and push token) as our service provider.
- **The identity registry and its provider**: receive the anonymous proof,
  and, for passports that need the fallback, the passport security data
  described above.
- **Partners you choose**: receive only what you accept on the consent
  screen after scanning their QR code.
- We do not sell your data, and we do not share it with advertisers. No
  advertising or install-attribution SDK is present in the app (a prior
  attribution/referral SDK was fully removed from the codebase).
- We do not share your name, photo or passport number with anyone except a
  partner you explicitly approve on the consent screen.

## Your choices and rights

- **Account deletion**: you can permanently delete your Foundation account
  and its associated server-side data from within the app, at any time, in
  Profile settings. This performs an irreversible server-side deletion —
  there is no undo. It also deletes the app's data on your device and your
  recovery key backup in iCloud or Google Drive. The anonymous proof already
  registered in the public identity registry stays there; it contains
  nothing that identifies you.
  `TODO(legal)`: confirm and state here the exact
  categories of data this deletes vs. anonymizes vs. retains for legal/
  compliance reasons (the underlying deletion function returns a breakdown
  of deleted vs. anonymized vs. retained records, which this policy should
  summarize plainly once legal has reviewed what that breakdown means in
  practice).
- **Sign-out**: signing out clears your session locally; it does not delete
  your account (use account deletion for that).
- **Notifications**: you can disable push notifications at any time in your
  device settings.
- **Recovery key backup**: you can decline to enable iCloud/Google Drive
  backup. Deleting your account removes it, and you can also delete it
  from your own iCloud/Google Drive account at any time using Apple's or
  Google's own account tools — Foundation does not have access to that
  storage.

`TODO(legal)`: add jurisdiction-specific rights language (e.g. GDPR Articles
15-21 access/rectification/erasure/portability rights for EEA/UK users,
CCPA/CPRA rights for California residents) once the governing
jurisdiction(s) are confirmed.

## Data retention

We retain your account data (email, account ID, verification status) for as
long as your account is active. You can request deletion at any time via the
in-app account deletion flow described above. `TODO(legal)`: confirm and
state any minimum retention periods required for legal, security, or fraud-
prevention purposes.

## Children

Foundation is not directed at, and is not intended for use by, children.
Verifying an account requires a valid passport. `TODO(Dagan/legal)`: confirm
and state a specific minimum age (see the "Target audience" discussion in
docs/store/google-play.md, which flags 18+ as a suggested — not yet decided —
policy).

## Security

Your name, photo and passport number are processed only on your device and
are not uploaded (except to a partner you explicitly approve). Data we do collect is transmitted over encrypted connections (HTTPS/TLS)
to our servers. The app's zero-knowledge proof system is designed so that
the proof itself does not reveal your passport's contents or your identity.
`TODO(legal)`: add any additional security-practice language your counsel
wants included (e.g. encryption-at-rest specifics, incident response
commitments) — this section currently describes only what is directly
verifiable from the app's code and network behavior.

## Open source

Foundation Mobile is free, open-source software, licensed under GPL-3.0. The
complete source code — including exactly what data the app sends and to
where — is public, so this policy's claims can be independently verified.
See the repository's NOTICE and LICENSE files.

## Changes to this policy

`TODO(legal)`: add standard "we may update this policy, and will notify you
of material changes" language per your counsel's preferred wording.

## Contact us

Questions about this policy or your data: `TODO(Dagan)` — insert the
confirmed privacy contact email (see the entity/contact TODOs at the top of
this document).
