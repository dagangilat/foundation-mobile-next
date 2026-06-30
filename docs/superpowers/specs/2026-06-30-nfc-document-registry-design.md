# NFC-chip document registry — design

Date: 2026-06-30
Status: approved (pending user review of this doc)

## Roadmap context

This is sub-project 1 of 3 in extending foundation-mobile beyond ICAO
passports to other forms of identity document:

1. **NFC-chip document registry** (this doc) — generalize the existing
   passport NFC/MRZ pipeline to other ICAO-aligned biometric NFC documents
   (national ID cards).
2. **mDL (ISO 18013-5)** — US driving licences and other digital-wallet
   credentials. Different protocol stack (BLE/NFC device engagement,
   mdoc/CBOR), not started.
3. **Camera/AI-OCR fallback** — non-chip documents (older DLs, non-biometric
   IDs), lower trust tier, not started.

A fourth cross-cutting sub-project — retry-with-fallback (multiple attempts
per capture step, falling back to a lower trust ring when the destination
tenant/app accepts it) — was identified during this brainstorm but is
explicitly **out of scope** here. It touches MRZ scan, NFC chip scan, and
face match/liveness uniformly across all document types (today's
passport-only flow included), and introduces a tenant/minimum-trust-tier
concept that doesn't exist in the codebase yet. It needs its own design and
is tracked as a follow-on sub-project.

## Problem

The current pipeline (`PassportNFCReader`, `MRZScanView`, `NFCScanView`,
`DocumentPhotoView`) only reads ICAO passports: TD3 (2×44-char) MRZ format,
passport-specific copy and capture framing. Many users — especially in
Israel and the US — don't carry a passport day-to-day, so proof-of-humanity
conversion is blocked for anyone without one. Several countries' national ID
cards carry the same class of ICAO-aligned biometric NFC chip (PACE/BAC,
DG1/DG2, SOD) that passports do, in TD1 (3×30-char) MRZ format instead of
TD3. The chip-read mechanics the app already has are reusable; only the MRZ
format and document selection/copy are passport-specific today.

Driving licences are explicitly out of scope here: they don't carry an
ICAO-style eMRTD chip. NFC-readable mobile driving licences use ISO 18013-5
(mDL), a different protocol — that's sub-project 2.

## Architecture

### `DocumentProfile` registry

New `DocumentProfile.swift`, static Swift data (no remote config in v1):

```swift
struct DocumentProfile: Identifiable, Equatable {
    let id: String                  // e.g. "passport", "isr-id"
    let countryCode: String?        // ISO 3166-1 alpha-2; nil for generic Passport
    let displayName: String         // "Teudat Zehut", "Passport"
    let documentType: DocumentType  // .passport | .nationalId
    let mrzFormat: MRZFormat        // .td1 | .td3
    let dg2Accessible: Bool         // face photo retrievable via BAC/PACE (no EAC)
}

enum DocumentType { case passport, nationalId }
enum MRZFormat { case td1, td3 }
```

Seeded entries (v1):

| id | country | type | MRZ | dg2Accessible |
|---|---|---|---|---|
| `passport` | (generic) | passport | TD3 | true |
| `isr-id` | IL | nationalId | TD1 | true |
| `deu-id` | DE | nationalId | TD1 | true |
| `fra-id` | FR | nationalId | TD1 | true |
| `prt-id` | PT | nationalId | TD1 | true |
| `ita-id` | IT | nationalId | TD1 | true |
| `esp-id` | ES | nationalId | TD1 | true |
| `jpn-id` | JP | nationalId | TD1 | true |
| `bra-id` | BR | nationalId | TD1 | true |

`dg2Accessible: true` is an assumption for all seeded entries (these are
all marketed as "biometric" ID cards with a face image data group). It is
**not yet empirically verified against real hardware** for any entry except
the existing passport flow. This is a manual verification gate before
shipping each country (see Testing below), not a blocker for writing the
code.

### Picker filtering against the build profile

Trust tier is a **build-time constant** today (`AppConfig.Profile`, one of
`hisec-global` / `standardsec` / `lowsec-attest`, baked in via
`select-profile.sh`), not computed per-scan. This design preserves that:
rather than computing a dynamic tier per document, the document picker
filters out documents the active build can't reach its required tier with.

```swift
extension DocumentProfile {
    static func available(for profile: AppConfig.Profile) -> [DocumentProfile] {
        guard profile.faceMatchSource == .dg2 else { return all }
        return all.filter(\.dg2Accessible)
    }
}
```

For `hisec-global` (`faceMatchSource == .dg2`), only `dg2Accessible`
documents are offered. For `standardsec` (`documentPhoto`) and
`lowsec-attest` (`none`), all registry documents are offered — face match in
those profiles doesn't depend on DG2 regardless of document type.

### MRZ parsing

Add `MRZParser.parseTD1(lines:)` alongside the existing `parseTD3` in
`MRZScanView.swift`. Same checksum/key-derivation algorithm as TD3, different
field offsets (3 lines × 30 chars vs 2 lines × 44 chars). Once a
`DocumentProfile` has been selected, `MRZScanView` knows which format to
expect from `profile.mrzFormat` and attempts that parser first based on
detected line geometry, falling back to the other format if the OCR'd
geometry doesn't match (handles the case where a user scans the wrong
document for their selection — see Error handling).

### Chip read

Rename `PassportNFCReader` → `DocumentNFCReader` (mechanical rename; the
read logic — PACE/BAC, DG1/DG2 extraction, SOD hash-integrity check — is
unchanged and already document-agnostic, it just needs a document-agnostic
name). Add a `DocumentProfile` parameter:

```swift
func readDocument(
    mrzKey: MRZKey,
    profile: DocumentProfile,
    includeFacePhoto: Bool
) async throws -> DocumentReadResult
```

`includeFacePhoto` is computed by the caller as
`activeBuildProfile.faceMatchSource == .dg2 && documentProfile.dg2Accessible`
— same logic as the picker filter, applied again at read time as a
defense-in-depth check (the picker should already guarantee this, but the
reader shouldn't trust that invariant blindly).

`PassportReadResult` → `DocumentReadResult`, adding:
```swift
let documentType: DocumentProfile.DocumentType
```
All other fields (`dg1Hash`, `issuingCountryCode`, `passportNumberMasked` →
consider renaming to `documentNumberMasked`, `dg2Hash`, `dg2FaceImage`)
carry over unchanged in meaning.

### Document picker UX

New picker step before MRZ capture:

- **Default screen**: two entries computed from `Locale.current.region` —
  "[Region] National ID" (if `DocumentProfile.all` has a `countryCode` match
  for the device region) and "Passport" (always shown — MRZ format is
  country-agnostic, no per-country passport entry needed). Below these, an
  "Other document" link.
- **"Other document"**: live-search list, scoped strictly to
  `DocumentProfile.available(for: activeProfile)` — i.e., already filtered by
  build-profile capability. No unsupported/greyed-out entries; if it's not
  selectable, it's not listed.
- Selecting an entry sets the active `DocumentProfile` for the rest of the
  flow, driving MRZ format expectation and card-vs-booklet capture copy in
  `DocumentPhotoView`/`MRZScanView` (front/back card capture vs photo-page
  capture).

### Error handling

- **Profile/document mismatch**: if neither TD1 nor TD3 parsing succeeds
  against the selected profile's expected format within the existing scan
  budget, surface a "this doesn't look like a [selected document]" message
  before ever attempting NFC — avoids a confusing chip-read failure when the
  real problem is the user picked the wrong picker entry.
- **`dg2Accessible` wrong in practice**: chip exists but DG2 read fails
  despite the registry saying `true` — falls through the existing
  `PassportNFCReaderError.dg2Missing` / `.dg2FaceImageMissing` paths
  unchanged, now reachable for ID cards too.
- **No behavior change** to SOD↔DG1/DG2 hash-integrity enforcement, the
  "nothing identifying leaves the device" invariant, or the chain-to-CSCA
  soft-check — all unchanged from the existing passport path.

### Testing

- Unit tests: `MRZParser.parseTD1` (checksum + field-offset cases per seeded
  country's known MRZ layout), `DocumentProfile.available(for:)` filtering
  per build profile, TD1/TD3 format auto-detection from OCR'd line geometry.
- **Manual hardware-in-the-loop verification required before shipping each
  country**: confirm `dg2Accessible` holds against a real document (PACE/BAC
  succeeds, DG2 actually returns a usable face image) for each of Israel,
  Germany, France, Portugal, Italy, Spain, Japan, Brazil before that
  country's `DocumentProfile` ships. This mirrors how passport support was
  validated and is not automatable.

## Out of scope (this sub-project)

- Driving licences / mDL (ISO 18013-5) — sub-project 2.
- Camera/AI-OCR fallback for non-chip documents — sub-project 3.
- Retry-with-fallback across capture steps + tenant/minimum-tier concept —
  follow-on sub-project, not yet designed.
- Dynamic (per-scan) trust tier computation — current build-time-constant
  model is preserved; registry filtering happens at the picker instead.
