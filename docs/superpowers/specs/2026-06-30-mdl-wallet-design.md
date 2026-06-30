# mDL + Wallet National ID — design

Date: 2026-06-30
Status: approved (pending user review of this doc)

## Roadmap context

This is sub-project 2 of the identity-document roadmap:

1. **NFC-chip document registry** (shipped, PR #12) — biometric national ID cards
   via ICAO eMRTD NFC chip + MRZ.
2. **mDL + Wallet National ID via Apple Verifier API** (this doc) — mobile
   driver's licences and Wallet-stored national IDs via Apple's ProximityReader
   `MobileDocumentReader` framework.
3. **Camera/AI-OCR fallback** — non-chip, non-wallet documents. Not started.

Sub-project 4 (retry-with-fallback + tenant/minimum-tier) remains a cross-cutting
follow-on.

## Problem

Many US users don't carry a passport or a biometric NFC-chip national ID card.
Their Apple Wallet–stored driver's licence (mDL, ISO 18013-5) or Wallet national
ID is the only credential they have, blocking proof-of-humanity conversion.

## Research findings (2026-06-30)

Apple ships a native, publicly documented Verifier API as part of the
`ProximityReader` framework (iOS 17+). Key facts discovered from Apple's own
documentation:

- **No gated entitlement process** — unlike Tap to Pay (`PaymentCardReader`),
  which explicitly says "contact Apple and request the entitlement," the Verifier
  API documentation only says "add the Verifier API capability in Xcode." No
  case-by-case Apple approval described or found anywhere.
- **Optional brand token** — `MobileDocumentReader.prepare(using: Token?)` takes
  an optional brand token. Enrolling in Apple Business Register (for showing your
  brand name/logo in Apple's reader sheet) is optional; `prepare(using: nil)` works
  without it. No server-side dependency to unblock development.
- **Simulator testable** — Apple provides a "Mobile Document Reader (Developer)"
  profile for download that makes Simulator return mock mDL reads. No physical
  device or real mDL needed for dev/CI.
- **Covers both mDL and national ID cards** — same framework, same API, different
  request types: `MobileDriversLicenseDataRequest` and
  `MobileNationalIDCardDataRequest`.
- **Built-in minimal disclosure** — `init(retainedElements:nonRetainedElements:)`:
  caller declares which elements it keeps vs. discards immediately, matching this
  app's "nothing identifying leaves the device" philosophy.
- **ISO 18013-5 BLE/CBOR implementation is NOT needed** — Apple's native API
  handles the entire device-engagement + session-encryption + CBOR-parsing
  stack internally. No external libraries required.

## Architecture

### `DocumentProfile` extensions

The existing `DocumentProfile` struct (added in sub-project 1) is extended with
two new fields rather than replaced:

```swift
enum ReadingMethod: Equatable {
    case nfcChip        // existing: MRZScanView → DocumentNFCReader
    case walletDocument // new: Apple Verifier API, no MRZ scan
}

enum WalletDocumentType: Equatable {
    case mobileDriversLicense
    case nationalIdCard
}
```

- `mrzFormat: MRZFormat` becomes `mrzFormat: MRZFormat?` (nil for wallet entries).
- New field `readingMethod: ReadingMethod` (all existing entries default to
  `.nfcChip`).
- New field `walletDocumentType: WalletDocumentType?` (nil for NFC-chip entries).
- No stored `walletSupported` field — device support is a runtime fact. `DocumentProfile.available(for:)` filters out wallet entries at call time when `readingMethod == .walletDocument && !MobileDocumentReader.isSupported`.

Two new seeded entries:

| id | displayName | readingMethod | walletDocumentType | notes |
|---|---|---|---|---|
| `usa-mdl` | "US Driver's Licence (Wallet)" | walletDocument | mobileDriversLicense | generic, all participating states |
| `usa-walletid` | "US Wallet National ID" | walletDocument | nationalIdCard | same API, different request type |

US state coverage is generic (one entry covering all Apple Wallet participating
states). Per-state enumeration is not needed: if the holder's Wallet doesn't have
a mDL from a participating state, the read fails gracefully with a clear error.

### Trust tier — new `FaceMatchSource` case

`AppConfig.Profile.FaceMatchSource` gets a new case `.mdl` → trust tier `.high`.
An mDL/Wallet-national-ID portrait element comes back from Apple's Verifier API
already cryptographically validated against the issuing authority's signature —
the same trust character as DG2 from an ICAO chip, just a different crypto chain.
Treating it as `.standard` (like a back-camera document photo) would understate its
actual validation strength.

```swift
// AppConfig.Profile.FaceMatchSource — existing cases
case dg2            // ePassport NFC chip face image → .high
case documentPhoto  // back-camera capture → .standard
case none           // no face match → .low
// New:
case mdl            // Apple Verifier API portrait element → .high
```

New build-profile JSON variants (`hisec-mdl` etc.) are needed alongside the
existing `hisec-global` / `standardsec` / `lowsec-attest` when targeting the
mDL flow. `DocumentProfile.available(for:)` filters wallet entries out of the
picker unless the active build profile has `faceMatchSource == .mdl` (or `.none` /
`.documentPhoto` for lower-tier builds — similar logic to `dg2Accessible` gating).

### `WalletDocumentReadResult`

New struct (analogous to `DocumentReadResult`):

```swift
struct WalletDocumentReadResult: @unchecked Sendable, Equatable {
    let portraitHash: Data       // SHA-256(portrait JPEG bytes) — 32 bytes
    let portraitImage: UIImage?  // face photo for face-match; in-memory only
    let documentNumberMasked: String  // last 3 chars, e.g. "•••321"
    let issuingState: String?    // e.g. "AZ" — informational, not secret
    let walletDocumentType: WalletDocumentType
}
```

The portrait image is kept in memory only for the face-match step and released
immediately after. The portrait bytes are never written to disk or sent over the
network. Same "nothing identifying leaves the device" invariant as DG2 handling.

### `WalletDocumentReader`

New `WalletDocumentReader.swift` (actor), analogous to `DocumentNFCReader`:

```swift
@MainActor
final class WalletDocumentReader {
    static let shared = WalletDocumentReader()

    func readDocument(
        profile: DocumentProfile,
        includeFacePhoto: Bool
    ) async throws -> WalletDocumentReadResult
}
```

Internally: `MobileDocumentReader.init()` → `prepare(using: nil)` (no brand token
in v1) → `MobileDocumentReaderSession.requestDocument(_:)` with either
`MobileDriversLicenseDataRequest` or `MobileNationalIDCardDataRequest`, depending
on `profile.walletDocumentType`. Elements requested:

- `portrait` — retained only when `includeFacePhoto` is true (needed for face-match
  in `.mdl` builds); set as `retainedElements` in that case, `nonRetainedElements`
  otherwise.
- `document_number`, `expiry_date`, `age_over_18`, `issuing_authority`,
  `issuing_jurisdiction` — all `nonRetainedElements` (inspected for masking /
  hash input, discarded immediately after).

`includeFacePhoto` is derived by the caller as `faceMatchSource == .mdl` — same
defense-in-depth pattern as `dg2Accessible` check in `DocumentNFCReader`.

**No `ChipReading`-protocol mock is needed** for Tier-2 testing: Apple's Simulator
developer profile already provides a testable mock at the OS level. Unit tests
confirm the response-parsing and field-extraction logic using the Simulator's own
mock response, which is fully automated.

### `CaptureCoordinator` extensions

Three new state cases alongside the existing passport/NFC cases:

```swift
case readyForWalletDocument(framesCount: Int)
case scanningWalletDocument(framesCount: Int)
case walletDocumentReady(framesCount: Int, walletResult: WalletDocumentReadResult)
```

`afterPosesState(framesCount:)` gains a new branch (before the existing ones):

```swift
if profile.readingMethod == .walletDocument && profile requires .nfcZk {
    return .readyForWalletDocument(framesCount: framesCount)
}
```

New `scanWalletDocument(profile: DocumentProfile)` method (analogous to
`scanPassport(mrzKey:profile:)`) transitions `scanningWalletDocument` →
`walletDocumentReady` on success or `.failed(stage: .passportScan)` on error.

`verify()` gains a new arm handling `.walletDocumentReady` — produces the `.nfcZk`
artifact via `WalletDocumentProducer(walletData:).produce()` (payload is
`SHA-256(document_number || issuing_jurisdiction)`) and the `.faceMatch` artifact
using `walletResult.portraitImage` as the reference face (same `FaceMatchProducer`
path as today, different input source).

### `WalletDocumentProducer`

New `WalletDocumentProducer.swift` (analogous to `PassportNfcProducer`):

```swift
struct WalletDocumentProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .nfcZk
    let walletData: WalletDocumentReadResult
    // payload: SHA-256(documentNumberMasked_raw || issuingState)
    // same double-hash binding contract as PassportNfcProducer
}
```

### `CaptureView` wiring

When the user selects a wallet-method profile in the picker:

- Skip `MRZScanView` entirely (no physical card MRZ to scan).
- Show a brief "Hold your phone near the cardholder's phone" instruction view (new
  `WalletDocumentScanView`, minimal copy only — Apple's own system sheet handles
  the actual reader UX once `requestDocument` fires).
- `onScanTap` closure triggers `coordinator.scanWalletDocument(profile:)` directly,
  replacing the `isShowingMRZScan = true` path for these profiles.

### Error handling

- `MobileDocumentReader.isSupported == false` → wallet entries filtered from
  picker at selection time (`available(for:)` check); no dead-end.
- `MobileDocumentReaderError.cancelled` → `.failed(stage: .passportScan, message:
  "Document read cancelled")` — retry button available (same flow as passport NFC
  cancellation).
- `MobileDocumentReaderError.sessionExpired` → `prepare()` is re-called and scan
  retried once automatically before surfacing as a failure.
- Portrait element absent (non-photo-capable wallet credential) → same path as
  `dg2Accessible` false: filtered from picker in `.mdl` builds.

### Testing

**Tier 1 (CI, no hardware):** unit tests for new `DocumentProfile` entries (`readingMethod`, `walletDocumentType`), extended `available(for:)` logic, `WalletDocumentReadResult` field assertions.

**Tier 2 (Simulator, automated):** Apple's "Mobile Document Reader (Developer)"
profile makes the Simulator return a deterministic mock mDL response. Unlike NFC
chip testing (which still needed physical hardware for Tier 2 mock construction),
mDL Simulator testing is fully automated with no fabricated byte fixtures needed.
Download the developer profile, run on Simulator, confirm the full state-machine
flow (picker → `readyForWalletDocument` → `walletDocumentReady` → `verify()` →
`.sealed`) with a real mock response from Apple's Simulator infrastructure.

**Tier 3 (manual, once per document type):** confirm against a real Apple Wallet
mDL (participating-state device) and a real Wallet national ID (if/when available).
Same hardware-gate convention as sub-project 1 — not a blocker for code, required
before enabling for real users.

## Out of scope (this sub-project)

- BLE/CBOR ISO 18013-5 implementation — not needed given Apple's native API.
- Per-state mDL registry entries — one generic `usa-mdl` entry covers all.
- Brand token / Apple Business Register enrollment — `prepare(using: nil)` in v1.
- Google Wallet mDL reading — Apple's Verifier API reads any ISO 18013-5 compliant
  Wallet (including Google Wallet on Android), but this app is iOS-only; Android
  support is a separate track.
- Camera/AI-OCR fallback — sub-project 3.
- Retry-with-fallback + tenant/minimum-tier — follow-on sub-project.
