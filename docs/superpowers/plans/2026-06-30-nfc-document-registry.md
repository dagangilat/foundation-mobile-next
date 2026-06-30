# NFC-Chip Document Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generalize foundation-mobile's passport-only NFC/MRZ pipeline so it can also read biometric national ID cards (Israel Teudat Zehut, Germany, France, Portugal, Italy, Spain, Japan, Brazil), via a static `DocumentProfile` registry and a document picker, without changing the existing build-time trust-tier model.

**Architecture:** A new `DocumentProfile` registry describes each supported document's MRZ format (TD1 vs TD3) and chip capabilities. The existing `PassportNFCReader` is renamed to `DocumentNFCReader` and refactored to read through a new `ChipReading` protocol — production wraps the real `NFCPassportReader.PassportReader`; tests inject a fake `ChipReadOutcome`, so the hash-integrity/parsing pipeline is verifiable in CI with no physical NFC hardware. A new `DocumentPickerView` lets the user choose their document (device-region default + searchable list), feeding the chosen `DocumentProfile` through `MRZScanView` (which gains a TD1 parser) and into `CaptureCoordinator`/`DocumentNFCReader`.

**Tech Stack:** Swift 5, SwiftUI, XCTest, `NFCPassportReader` SPM package (PACE/BAC chip access), `xcodeproj` Ruby gem for `project.pbxproj` registration.

## Global Constraints

- Minimum iOS target: 16.0 (existing project constraint; unchanged).
- No remote config for the document registry in v1 — `DocumentProfile.all` is static Swift data.
- "Nothing identifying leaves the device" invariant is unchanged: no new network calls, no disk persistence of MRZ/chip data.
- Trust tier (`AppConfig.Profile.TrustTier`) stays a **build-time constant**. No task may introduce per-scan/dynamic tier computation — gating happens at the document picker via `DocumentProfile.available(for:)`.
- Driving licences / mDL and camera-only OCR fallback are out of scope — do not add document types without an NFC chip.
- Every new piece of pure logic (parsing, filtering) needs an XCTest with no physical-hardware dependency; chip-read logic must be testable via the `ChipReading` protocol's fake, never by mocking `NFCPassportModel` directly (it requires a real ASN.1 SOD/DSC chain to pass `verifyPassport`, which is impractical to fabricate — see spec Testing Tier 2).
- Reference spec: `docs/superpowers/specs/2026-06-30-nfc-document-registry-design.md`.

---

### Task 1: `DocumentProfile` registry

**Files:**
- Create: `ios/FoundationMobile/DocumentProfile.swift`
- Test: `ios/FoundationMobileTests/DocumentProfileTests.swift`

**Interfaces:**
- Consumes: `AppConfig.Profile` (existing, `ios/FoundationMobile/AppConfig.swift:32`) — specifically `.faceMatchSource: AppConfig.Profile.FaceMatchSource` (`.dg2 | .documentPhoto | .none`).
- Produces: `DocumentProfile` struct (`id`, `countryCode`, `displayName`, `documentType`, `mrzFormat`, `dg2Accessible`), `DocumentProfile.DocumentType` (`.passport | .nationalId`), `DocumentProfile.MRZFormat` (`.td1 | .td3`), `DocumentProfile.passport` (static), `DocumentProfile.all: [DocumentProfile]`, `DocumentProfile.available(for: AppConfig.Profile) -> [DocumentProfile]`, `DocumentProfile.regionMatch(regionCode: String?) -> DocumentProfile?`. Every later task that touches document selection or chip reading depends on these exact names.

- [ ] **Step 1: Write the failing test**

```swift
// ios/FoundationMobileTests/DocumentProfileTests.swift
import XCTest
@testable import FoundationMobile

final class DocumentProfileTests: XCTestCase {
    private func buildProfile(faceMatchSource: AppConfig.Profile.FaceMatchSource) -> AppConfig.Profile {
        AppConfig.Profile(
            id: "test", label: "Test", description: "",
            requiredPhases: [], faceMatchSource: faceMatchSource, document: nil
        )
    }

    func testHisecGlobalOnlyOffersDg2AccessibleDocuments() {
        let available = DocumentProfile.available(for: buildProfile(faceMatchSource: .dg2))
        XCTAssertEqual(available.count, DocumentProfile.all.count)
        XCTAssertTrue(available.allSatisfy(\.dg2Accessible))
    }

    func testStandardsecOffersAllDocuments() {
        let available = DocumentProfile.available(for: buildProfile(faceMatchSource: .documentPhoto))
        XCTAssertEqual(Set(available.map(\.id)), Set(DocumentProfile.all.map(\.id)))
    }

    func testLowsecAttestOffersAllDocuments() {
        let available = DocumentProfile.available(for: buildProfile(faceMatchSource: .none))
        XCTAssertEqual(Set(available.map(\.id)), Set(DocumentProfile.all.map(\.id)))
    }

    func testRegionMatchFindsIsrael() {
        XCTAssertEqual(DocumentProfile.regionMatch(regionCode: "IL")?.id, "isr-id")
    }

    func testRegionMatchReturnsNilForUnknownRegion() {
        XCTAssertNil(DocumentProfile.regionMatch(regionCode: "ZZ"))
    }

    func testRegionMatchReturnsNilForNilRegion() {
        XCTAssertNil(DocumentProfile.regionMatch(regionCode: nil))
    }

    func testGenericPassportHasNoCountryCode() {
        XCTAssertNil(DocumentProfile.passport.countryCode)
        XCTAssertEqual(DocumentProfile.passport.mrzFormat, .td3)
    }

    func testAllSeededIdsAreUnique() {
        let ids = DocumentProfile.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/DocumentProfileTests 2>&1 | tail -40`
Expected: FAIL — `DocumentProfile.swift` doesn't exist yet, compile error "cannot find type 'DocumentProfile' in scope".

- [ ] **Step 3: Write `DocumentProfile.swift`**

```swift
// ios/FoundationMobile/DocumentProfile.swift
import Foundation

// Sub-project 1 (2026-06-30) — registry of ICAO-aligned biometric NFC
// documents the app can read, beyond the original passport-only pipeline.
// Static data, no remote config in v1. See
// docs/superpowers/specs/2026-06-30-nfc-document-registry-design.md.

struct DocumentProfile: Identifiable, Equatable {
    enum DocumentType: Equatable {
        case passport
        case nationalId
    }

    enum MRZFormat: Equatable {
        case td1   // 3 lines x 30 chars — national ID cards
        case td3   // 2 lines x 44 chars — passports
    }

    let id: String                  // e.g. "passport", "isr-id"
    let countryCode: String?        // ISO 3166-1 alpha-2; nil for generic Passport
    let displayName: String         // "Teudat Zehut", "Passport"
    let documentType: DocumentType
    let mrzFormat: MRZFormat
    // Face photo (DG2) retrievable via BAC/PACE alone, no EAC. Assumed true
    // for every seeded national-ID entry pending hardware verification —
    // see the spec's Testing section, Tier 3. Not yet verified against any
    // real document except the existing passport flow.
    let dg2Accessible: Bool

    static let passport = DocumentProfile(
        id: "passport", countryCode: nil, displayName: "Passport",
        documentType: .passport, mrzFormat: .td3, dg2Accessible: true
    )

    static let all: [DocumentProfile] = [
        .passport,
        DocumentProfile(id: "isr-id", countryCode: "IL", displayName: "Teudat Zehut",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "deu-id", countryCode: "DE", displayName: "Personalausweis",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "fra-id", countryCode: "FR", displayName: "Carte nationale d'identité",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "prt-id", countryCode: "PT", displayName: "Cartão de Cidadão",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "ita-id", countryCode: "IT", displayName: "Carta d'Identità Elettronica",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "esp-id", countryCode: "ES", displayName: "DNI electrónico",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "jpn-id", countryCode: "JP", displayName: "My Number Card",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "bra-id", countryCode: "BR", displayName: "Carteira de Identidade Nacional",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
    ]

    // Documents the active build profile can reach its required trust tier
    // with. hisec-global (faceMatchSource == .dg2) only offers documents
    // whose chip exposes DG2 via BAC/PACE; standardsec/lowsec-attest don't
    // depend on DG2 for face match, so every registry document is offered.
    static func available(for profile: AppConfig.Profile) -> [DocumentProfile] {
        guard profile.faceMatchSource == .dg2 else { return all }
        return all.filter(\.dg2Accessible)
    }

    // Best-guess national-ID entry for the device's region, if the registry
    // has one. Used by DocumentPickerView's default screen.
    static func regionMatch(regionCode: String?) -> DocumentProfile? {
        guard let regionCode else { return nil }
        return all.first { $0.countryCode == regionCode }
    }
}
```

- [ ] **Step 4: Register the new file with the Xcode project**

```bash
cd ios && ruby -e "
require 'xcodeproj'
project_path = File.expand_path('FoundationMobile.xcodeproj')
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FoundationMobile' }
raise 'FoundationMobile target not found' unless target
group = project.main_group.find_subpath('FoundationMobile', true)
group.set_source_tree('<group>')
relative_path = 'FoundationMobile/DocumentProfile.swift'
ref = group.files.find { |f| f.path == relative_path } || group.new_reference(relative_path)
ref.path = relative_path
ref.name = 'DocumentProfile.swift'
target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
project.save
puts 'DocumentProfile.swift registered.'
"
```

- [ ] **Step 5: Register the test file and run tests**

```bash
ruby scripts/add-test-target.rb
xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/DocumentProfileTests 2>&1 | tail -40
```
Expected: PASS — all 8 tests in `DocumentProfileTests` green.

- [ ] **Step 6: Commit**

```bash
git add ios/FoundationMobile/DocumentProfile.swift ios/FoundationMobileTests/DocumentProfileTests.swift ios/FoundationMobile.xcodeproj/project.pbxproj
git commit -m "feat(docs): add DocumentProfile NFC-chip document registry"
```

---

### Task 2: TD1 MRZ parser

**Files:**
- Modify: `ios/FoundationMobile/MRZScanView.swift` (add to the existing `enum MRZParser`, after `parseTD3`, currently ending around line 455)
- Test: `ios/FoundationMobileTests/MRZParserTests.swift`

**Interfaces:**
- Consumes: existing `MRZKey` struct and `MRZKey.checkDigit(_:)` (`ios/FoundationMobile/MRZScanView.swift:17-46`, unchanged).
- Produces: `MRZParser.parseTD1(lines: [String]) -> MRZKey?`. Task 5 (MRZScanView view-layer wiring) calls this alongside the existing `parseTD3`.

- [ ] **Step 1: Write the failing test**

This uses ICAO 9303 Part 5's own published TD1 worked example (not a real person's document), so the check digits are independently verifiable against the standard.

```swift
// ios/FoundationMobileTests/MRZParserTests.swift
import XCTest
@testable import FoundationMobile

final class MRZParserTests: XCTestCase {
    // ICAO 9303 Part 5 worked example.
    private let td1Lines = [
        "I<UTOD231458907<<<<<<<<<<<<<<<",
        "7408122F1204159UTO<<<<<<<<<<<6",
        "ERIKSSON<<ANNA<MARIA<<<<<<<<<<",
    ]

    func testParseTD1ExtractsDocumentNumberDobExpiry() {
        let key = MRZParser.parseTD1(lines: td1Lines)
        XCTAssertEqual(key, MRZKey(
            passportNumber: "D23145890",
            dateOfBirth: "740812",
            dateOfExpiry: "120415"
        ))
    }

    func testParseTD1ToleratesLineOrderShuffle() {
        let shuffled = [td1Lines[2], td1Lines[0], td1Lines[1]]
        XCTAssertEqual(MRZParser.parseTD1(lines: shuffled), MRZParser.parseTD1(lines: td1Lines))
    }

    func testParseTD1ReturnsNilOnGarbageInput() {
        XCTAssertNil(MRZParser.parseTD1(lines: ["not an mrz", "still not"]))
    }

    func testParseTD1ReturnsNilWhenCheckDigitWrong() {
        var corrupted = td1Lines
        corrupted[0] = "I<UTOD231458901<<<<<<<<<<<<<<<"   // check digit 7 -> 1
        XCTAssertNil(MRZParser.parseTD1(lines: corrupted))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/MRZParserTests 2>&1 | tail -40`
Expected: FAIL — `MRZParser` has no member `parseTD1`.

- [ ] **Step 3: Add `parseTD1` to `MRZParser`**

In `ios/FoundationMobile/MRZScanView.swift`, inside `enum MRZParser { ... }`, immediately after the closing brace of `parseTD3` (currently ending at line 455, just before `// Manual-entry fallback`), insert:

```swift
    // Parse a TD1 (3x30-char) MRZ — national ID card format — from a set
    // of OCR-recognized lines. Unlike TD3 (where every needed field sits
    // on one line), TD1 splits document number (line 1) from DOB/expiry
    // (line 2), so we scan all candidate lines for each piece
    // independently and combine the first valid match of each. Field
    // offsets per ICAO 9303 Part 5: line 1 = doc code(2) + issuing
    // state(3) + doc number(9) + check digit(1) + optional(15); line 2 =
    // DOB(6) + check(1) + sex(1) + expiry(6) + check(1) + nationality(3)
    // + optional(11) + composite check(1).
    static func parseTD1(lines: [String]) -> MRZKey? {
        let cleaned = lines.map { line -> String in
            let up = line.uppercased()
            return up.filter { ch in
                (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9") || ch == "<"
            }
        }.filter { !$0.isEmpty }

        var documentNumber: String?
        var dateOfBirth: String?
        var dateOfExpiry: String?

        for candidate in cleaned where candidate.count >= 30 {
            let chars = Array(String(candidate.prefix(30)))

            if documentNumber == nil {
                let docNumberRaw = String(chars[5..<14])
                let docNumberCheck = chars[14]
                if docNumberCheck.isASCII,
                   let checkDigit = docNumberCheck.wholeNumberValue,
                   checkDigit == MRZKey.checkDigit(docNumberRaw) {
                    documentNumber = docNumberRaw
                }
            }

            if dateOfBirth == nil || dateOfExpiry == nil {
                let dob = String(chars[0..<6])
                let dobCheck = chars[6]
                let expiry = String(chars[8..<14])
                let expCheck = chars[14]
                if dobCheck.isASCII, let dobCheckDigit = dobCheck.wholeNumberValue,
                   dobCheckDigit == MRZKey.checkDigit(dob),
                   dob.allSatisfy({ $0.isNumber }),
                   expCheck.isASCII, let expCheckDigit = expCheck.wholeNumberValue,
                   expCheckDigit == MRZKey.checkDigit(expiry),
                   expiry.allSatisfy({ $0.isNumber }) {
                    dateOfBirth = dob
                    dateOfExpiry = expiry
                }
            }
        }

        guard let documentNumber, let dateOfBirth, let dateOfExpiry else { return nil }
        return MRZKey(
            passportNumber: documentNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
    }
```

- [ ] **Step 4: Register the test file and run tests**

```bash
cd ios && ruby scripts/add-test-target.rb
xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/MRZParserTests 2>&1 | tail -40
```
Expected: PASS — all 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add ios/FoundationMobile/MRZScanView.swift ios/FoundationMobileTests/MRZParserTests.swift ios/FoundationMobile.xcodeproj/project.pbxproj
git commit -m "feat(docs): add TD1 MRZ parser for national ID cards"
```

---

### Task 3: `ChipReading` protocol + `DocumentNFCReader` (renamed from `PassportNFCReader`) + call-site updates

This is the core generalization. It is one task, not several, because renaming `PassportNFCReader` → `DocumentNFCReader` and `PassportReadResult` → `DocumentReadResult` breaks every call site simultaneously — the project must compile at the end of this task, so all four call sites are fixed here. The document picker doesn't exist yet (Task 4), so every call site passes `DocumentProfile.passport` for now — behavior for the existing passport flow is unchanged.

**Files:**
- Create: `ios/FoundationMobile/ChipReading.swift`
- Rename + rewrite: `ios/FoundationMobile/PassportNFCReader.swift` → `ios/FoundationMobile/DocumentNFCReader.swift`
- Modify: `ios/FoundationMobile/PassportNfcProducer.swift`
- Modify: `ios/FoundationMobile/CaptureCoordinator.swift` (state case at line 34, `scanPassport` at line 301, `verify()` at lines 376/380-384/442-445)
- Modify: `ios/FoundationMobile/NFCScanView.swift` (line 124, field rename only)
- Modify: `ios/FoundationMobile/CaptureView.swift` (line 290, field rename only — picker wiring is Task 5)
- Test: `ios/FoundationMobileTests/DocumentNFCReaderTests.swift`

**Interfaces:**
- Consumes: `DocumentProfile` (Task 1), `MRZKey`/`MRZKey.mrzKeyString` (existing, `MRZScanView.swift:17-46`).
- Produces: `ChipReadOutcome` struct, `ChipReading` protocol, `LiveChipReader` (production conformance), `DocumentReadResult` struct (replaces `PassportReadResult`, adds `documentType`, renames `passportNumberMasked` → `documentNumberMasked`), `DocumentNFCReaderError`, `DocumentNFCReader` class with `DocumentNFCReader.shared` and `init(chipReader: ChipReading)`, `DocumentNFCReader.readDocument(mrzKey:profile:includeFacePhoto:) async throws -> DocumentReadResult`. Task 5 calls `DocumentNFCReader.shared.readDocument` and constructs `MRZScanView`/`NFCScanView` with a real `DocumentProfile` selection.

- [ ] **Step 1: Write the failing tests**

```swift
// ios/FoundationMobileTests/DocumentNFCReaderTests.swift
import XCTest
import CryptoKit
import NFCPassportReader
@testable import FoundationMobile

final class DocumentNFCReaderTests: XCTestCase {
    private struct FakeChipReader: ChipReading {
        let outcome: Result<ChipReadOutcome, Error>
        func read(
            mrzKeyString: String, tags: [DataGroupId],
            skipSecureElements: Bool, skipCA: Bool, skipPACE: Bool
        ) async throws -> ChipReadOutcome {
            try outcome.get()
        }
    }

    private let dg1Bytes = Data("synthetic-dg1".utf8)
    private let dg2RawBytes = Data("synthetic-dg2-raw".utf8)
    // Minimal valid 1x1 PNG so UIImage(data:) succeeds.
    private let dg2ImageBytes = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    private func key() -> MRZKey {
        MRZKey(passportNumber: "X123456", dateOfBirth: "900101", dateOfExpiry: "300101")
    }

    @MainActor
    func testReadDocumentSucceedsAndHashesDg1() async throws {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: nil, dg2ImageBytes: nil,
            dataNotTampered: true, issuingAuthority: "ISR", documentNumber: "X123456"
        )))
        let reader = DocumentNFCReader(chipReader: fake)
        let result = try await reader.readDocument(mrzKey: key(), profile: .passport)

        XCTAssertEqual(result.dg1Hash, Data(SHA256.hash(data: dg1Bytes)))
        XCTAssertEqual(result.issuingCountryCode, "ISR")
        XCTAssertEqual(result.documentNumberMasked, "•••456")
        XCTAssertEqual(result.documentType, .passport)
        XCTAssertNil(result.dg2Hash)
        XCTAssertNil(result.dg2FaceImage)
    }

    @MainActor
    func testReadDocumentWithFacePhotoHashesRawDg2AndDecodesImage() async throws {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: dg2RawBytes, dg2ImageBytes: dg2ImageBytes,
            dataNotTampered: true, issuingAuthority: "DEU", documentNumber: "Y987654"
        )))
        let profile = DocumentProfile.all.first { $0.id == "deu-id" }!
        let reader = DocumentNFCReader(chipReader: fake)
        let result = try await reader.readDocument(
            mrzKey: key(), profile: profile, includeFacePhoto: true
        )

        XCTAssertEqual(result.dg2Hash, Data(SHA256.hash(data: dg2RawBytes)))
        XCTAssertNotNil(result.dg2FaceImage)
        XCTAssertEqual(result.documentType, .nationalId)
    }

    @MainActor
    func testTamperedDataThrowsHashMismatch() async {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: nil, dg2ImageBytes: nil,
            dataNotTampered: false, issuingAuthority: "ISR", documentNumber: "X123456"
        )))
        let reader = DocumentNFCReader(chipReader: fake)
        do {
            _ = try await reader.readDocument(mrzKey: key(), profile: .passport)
            XCTFail("expected dg1HashMismatch")
        } catch DocumentNFCReaderError.dg1HashMismatch {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    @MainActor
    func testMissingDg2RawBytesThrowsWhenFacePhotoRequested() async {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: nil, dg2ImageBytes: nil,
            dataNotTampered: true, issuingAuthority: "ISR", documentNumber: "X123456"
        )))
        let reader = DocumentNFCReader(chipReader: fake)
        do {
            _ = try await reader.readDocument(mrzKey: key(), profile: .passport, includeFacePhoto: true)
            XCTFail("expected dg2Missing")
        } catch DocumentNFCReaderError.dg2Missing {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/DocumentNFCReaderTests 2>&1 | tail -40`
Expected: FAIL — `ChipReading`, `ChipReadOutcome`, `DocumentNFCReader` don't exist yet.

- [ ] **Step 3: Create `ChipReading.swift`**

```swift
// ios/FoundationMobile/ChipReading.swift
import Foundation
import NFCPassportReader

// Sits between DocumentNFCReader and the NFCPassportReader library so
// tests can substitute a fake without fabricating a real ASN.1 SOD/DSC/
// CSCA chain. NFCPassportModel's own hash-integrity check
// (verifyPassport) only ever runs in LiveChipReader (production); test
// fixtures construct ChipReadOutcome directly instead of trying to
// reproduce real X.509/CMS signing.
//
// dg1Bytes / dg2RawBytes are the full TLV-wrapped data group bytes (what
// the chip's SOD hashes over — these become dg1Hash/dg2Hash downstream).
// dg2ImageBytes is the separately-decoded JPEG/JPEG2000 image payload
// from inside DG2 (what becomes the UIImage). The two DG2 byte sources
// are different slices of the same data group and must stay separate:
// the hash binds to the SOD-verifiable raw bytes, not the decoded image.
struct ChipReadOutcome {
    let dg1Bytes: Data?
    let dg2RawBytes: Data?
    let dg2ImageBytes: Data?
    let dataNotTampered: Bool       // mirrors NFCPassportModel.passportDataNotTampered
    let issuingAuthority: String
    let documentNumber: String
}

protocol ChipReading {
    func read(
        mrzKeyString: String,
        tags: [DataGroupId],
        skipSecureElements: Bool,
        skipCA: Bool,
        skipPACE: Bool
    ) async throws -> ChipReadOutcome
}

// Production implementation — wraps the real NFCPassportReader.PassportReader,
// runs verifyPassport() exactly as the original passport-only
// PassportNFCReader did, and maps NFCPassportModel down to ChipReadOutcome.
//
// Bundle-lookup for a CSCA masterlist PEM. If `csca-masterlist.pem` is
// present in the app bundle, chain-to-CSCA verification activates and
// `passportCorrectlySigned` becomes meaningful; if absent (default today),
// the library skips the chain check and we still enforce SOD->DG1/DG2 hash
// integrity. Drop-in sources: BSI German masterlist
// (bsi.bund.de/dok/masterlist), ICAO PKD (pkddownloadsg.icao.int), or
// per-country CSCA certs concatenated into one PEM. To add one: drop the
// file at ios/FoundationMobile/Resources/csca-masterlist.pem (register as
// a Copy Bundle Resource), rebuild — no code change.
struct LiveChipReader: ChipReading {
    private let reader: PassportReader
    private let masterListURL: URL?

    init(masterListURL: URL?) {
        self.reader = PassportReader(masterListURL: masterListURL)
        self.masterListURL = masterListURL
    }

    func read(
        mrzKeyString: String,
        tags: [DataGroupId],
        skipSecureElements: Bool,
        skipCA: Bool,
        skipPACE: Bool
    ) async throws -> ChipReadOutcome {
        let passport = try await reader.readPassport(
            mrzKey: mrzKeyString,
            tags: tags,
            skipSecureElements: skipSecureElements,
            skipCA: skipCA,
            skipPACE: skipPACE
        )
        passport.verifyPassport(masterListURL: masterListURL, useCMSVerification: false)

        if masterListURL != nil && !passport.passportCorrectlySigned {
            // Chain check ran but failed — soft signal only, the bundled
            // masterlist may simply not cover this document's CSCA. SOD->DGn
            // hash integrity (passportDataNotTampered) is the hard gate.
            // 2026-04-26 security review M-H-6: don't log issuingAuthority
            // in release builds.
            #if DEBUG
            print("[LiveChipReader] chain-to-CSCA verification failed for \(passport.issuingAuthority); accepting hash-integrity only.")
            #endif
        }

        let dg1Bytes = passport.getDataGroup(.DG1).map { Data($0.data) }
        var dg2RawBytes: Data?
        var dg2ImageBytes: Data?
        if let dg2 = passport.getDataGroup(.DG2) {
            dg2RawBytes = Data(dg2.data)
            if let dg2Concrete = dg2 as? DataGroup2, !dg2Concrete.imageData.isEmpty {
                dg2ImageBytes = Data(dg2Concrete.imageData)
            }
        }

        return ChipReadOutcome(
            dg1Bytes: dg1Bytes,
            dg2RawBytes: dg2RawBytes,
            dg2ImageBytes: dg2ImageBytes,
            dataNotTampered: passport.passportDataNotTampered,
            issuingAuthority: passport.issuingAuthority,
            documentNumber: passport.documentNumber
        )
    }
}
```

- [ ] **Step 4: Rename and rewrite `PassportNFCReader.swift` → `DocumentNFCReader.swift`**

```bash
cd ios && git mv FoundationMobile/PassportNFCReader.swift FoundationMobile/DocumentNFCReader.swift
```

Replace the full contents of `ios/FoundationMobile/DocumentNFCReader.swift` with:

```swift
import Foundation
import CryptoKit
import NFCPassportReader
import UIKit

// Sub-project 1 (2026-06-30) — generalized from the original passport-only
// PassportNFCReader to any DocumentProfile-described ICAO-aligned chip
// (passports + national ID cards). Read logic (PACE/BAC, DG1/DG2
// extraction, SOD hash-integrity check) is unchanged; only the resulting
// documentType differs per profile. Reads through the ChipReading protocol
// (see ChipReading.swift) so the pipeline is testable without physical
// NFC hardware. See docs/superpowers/specs/2026-06-30-nfc-document-registry-design.md.

struct DocumentReadResult: @unchecked Sendable {
    let dg1Hash: Data               // SHA-256(DG1 raw bytes) — 32 bytes
    let issuingCountryCode: String  // ISO 3166-1 alpha-3 e.g. "ISR", "PRT"
    let documentNumberMasked: String // last 3 chars only, e.g. "•••321"
    let documentType: DocumentProfile.DocumentType

    // Populated only when readDocument(..., includeFacePhoto: true). Both
    // fields move together: either both nil (face photo not requested or
    // the chip didn't return DG2) or both non-nil. The image stays in
    // memory only — never written to disk, never sent over the network.
    let dg2Hash: Data?              // SHA-256(DG2 raw bytes), 32 bytes
    let dg2FaceImage: UIImage?      // decoded chip face photo
}

extension DocumentReadResult: Equatable {
    // Custom Equatable: identity by hashes only. Two reads of the same
    // document produce the same dg1Hash/dg2Hash even though the UIImage
    // instances differ; comparing UIImages by reference would make the
    // enclosing CaptureCoordinator.State equality flicker on every read.
    static func == (lhs: DocumentReadResult, rhs: DocumentReadResult) -> Bool {
        lhs.dg1Hash == rhs.dg1Hash
            && lhs.issuingCountryCode == rhs.issuingCountryCode
            && lhs.documentNumberMasked == rhs.documentNumberMasked
            && lhs.documentType == rhs.documentType
            && lhs.dg2Hash == rhs.dg2Hash
    }
}

enum DocumentNFCReaderError: Error, LocalizedError {
    case dg1Missing
    case dg1HashMismatch
    case dg2Missing
    case dg2FaceImageMissing
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .dg1Missing: return "Document DG1 (MRZ) not returned by chip read."
        case .dg1HashMismatch:
            return "Document DG1 hash does not match SOD — chip data integrity check failed."
        case .dg2Missing:
            return "Document DG2 (face photo) requested but not returned by chip read."
        case .dg2FaceImageMissing:
            return "Document DG2 was returned but no face image could be decoded."
        case .readFailed(let e):
            return "Document NFC read failed: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class DocumentNFCReader {
    static let shared = DocumentNFCReader(chipReader: LiveChipReader(masterListURL: Self.masterListURL))

    private let chipReader: ChipReading

    private static let masterListURL: URL? = Bundle.main.url(
        forResource: "csca-masterlist",
        withExtension: "pem"
    )

    // Test seam: production always goes through `.shared` (wired to
    // LiveChipReader); tests construct their own instance with a fake.
    init(chipReader: ChipReading) {
        self.chipReader = chipReader
    }

    // One-shot NFC scan. Presents the system NFC modal; resolves when the
    // chip read completes, the hash-integrity check passes, and we've
    // extracted the minimum proof fields.
    //
    // `includeFacePhoto` is gated on the caller side by the active
    // profile's .faceMatch requirement + faceMatchSource == .dg2, AND
    // documentProfile.dg2Accessible. Adding DG2 to the read roughly
    // doubles on-chip dwell time (~4-6s -> ~10-12s).
    func readDocument(
        mrzKey: MRZKey,
        profile: DocumentProfile,
        includeFacePhoto: Bool = false
    ) async throws -> DocumentReadResult {
        let mrzKeyString = mrzKey.mrzKeyString
        let tags: [DataGroupId] = includeFacePhoto ? [.DG1, .DG2, .SOD] : [.DG1, .SOD]
        let outcome: ChipReadOutcome
        do {
            outcome = try await chipReader.read(
                mrzKeyString: mrzKeyString,
                tags: tags,
                skipSecureElements: true,   // drop DG3 (fingerprints), DG4 (iris)
                skipCA: true,                // Chip Authentication — future work
                skipPACE: false              // PACE first, BAC fallback (library handles both)
            )
        } catch {
            throw DocumentNFCReaderError.readFailed(error)
        }

        guard outcome.dataNotTampered else {
            throw DocumentNFCReaderError.dg1HashMismatch
        }
        guard let dg1Bytes = outcome.dg1Bytes else {
            throw DocumentNFCReaderError.dg1Missing
        }
        let dg1Hash = Data(SHA256.hash(data: dg1Bytes))

        var dg2Hash: Data?
        var dg2FaceImage: UIImage?
        if includeFacePhoto {
            guard let dg2RawBytes = outcome.dg2RawBytes else {
                throw DocumentNFCReaderError.dg2Missing
            }
            dg2Hash = Data(SHA256.hash(data: dg2RawBytes))
            guard let dg2ImageBytes = outcome.dg2ImageBytes,
                  let decoded = UIImage(data: dg2ImageBytes) else {
                throw DocumentNFCReaderError.dg2FaceImageMissing
            }
            dg2FaceImage = decoded
        }

        let fullNumber = outcome.documentNumber
        let masked: String
        if fullNumber.count >= 3 {
            let last3 = String(fullNumber.suffix(3))
            masked = "•••\(last3)"
        } else {
            masked = "•••"
        }

        return DocumentReadResult(
            dg1Hash: dg1Hash,
            issuingCountryCode: outcome.issuingAuthority,
            documentNumberMasked: masked,
            documentType: profile.documentType,
            dg2Hash: dg2Hash,
            dg2FaceImage: dg2FaceImage
        )
    }
}
```

- [ ] **Step 5: Update `PassportNfcProducer.swift`**

```swift
// ios/FoundationMobile/PassportNfcProducer.swift
import Foundation

// Phase 3a — real .nfcZk artifact. Replaces MockNfcZkProducer's synthetic
// "mock:nfc-zk" payload with a SHA-256(DG1) signed by the device's App
// Attest key via ProofArtifactBuilder. The signed payload becomes the
// artifact's payloadHashHex; the App Attest assertion becomes its
// signatureBase64. The Phase 7 enclave seal concatenates this with the
// other artifacts and the commitment hash is what the server audits.

struct PassportNfcProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .nfcZk
    let documentData: DocumentReadResult

    func produce() async throws -> ProofArtifact {
        return try await ProofArtifactBuilder.build(
            kind: .nfcZk,
            payload: documentData.dg1Hash
        )
    }
}
```

- [ ] **Step 6: Update `CaptureCoordinator.swift`**

At line 34, change the state case:

```swift
        case passportReady(framesCount: Int, passport: DocumentReadResult)
```

Replace `scanPassport` (lines 301-332) with:

```swift
    // Phase 3a — NFC chip read step. Called from CaptureView once
    // MRZScanView hands back a parsed MRZ key. Transitions through
    // .scanningPassport → .passportReady(...) → (user taps Verify).
    func scanPassport(mrzKey: MRZKey, profile: DocumentProfile) {
        let frames: Int
        switch state {
        case .readyForPassport(let n): frames = n
        case .failed(let stage, _) where stage == .passportScan || stage == .verify:
            frames = lastFramesCount
        default: return
        }

        state = .scanningPassport(framesCount: frames)
        passportScanTask?.cancel()
        passportScanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await DocumentNFCReader.shared.readDocument(
                    mrzKey: mrzKey,
                    profile: profile,
                    includeFacePhoto: AppConfig.shared.profile.requires(.faceMatch) &&
                                      AppConfig.shared.profile.faceMatchSource == .dg2 &&
                                      profile.dg2Accessible
                )
                self.state = .passportReady(framesCount: frames, passport: result)
            } catch {
                self.state = .failed(stage: .passportScan, message: error.localizedDescription)
            }
        }
    }
```

In `verify()` (around line 374-398), change:

```swift
        let passportData: PassportReadResult?
```
to:
```swift
        let passportData: DocumentReadResult?
```

And at line 444, change:
```swift
                    let nfcArtifact = try await PassportNfcProducer(passportData: passport).produce()
```
to:
```swift
                    let nfcArtifact = try await PassportNfcProducer(documentData: passport).produce()
```

- [ ] **Step 7: Update `NFCScanView.swift`**

At line 124, change `result.passportNumberMasked` to `result.documentNumberMasked`:

```swift
                Text("\(prettyCountry(result.issuingCountryCode)) \(docNoun) \(result.documentNumberMasked). Tap verify to sign and seal the commitment.")
```

- [ ] **Step 8: Update `CaptureView.swift`**

At line 290, change `passport.passportNumberMasked` to `passport.documentNumberMasked`:

```swift
                Text("Passport scanned (\(passport.issuingCountryCode) \(passport.documentNumberMasked)) — ready to verify")
```

At lines 86 and 138, the two `coordinator.scanPassport(mrzKey: key)` calls become:

```swift
                        coordinator.scanPassport(mrzKey: key, profile: .passport)
```

(Hardcoding `.passport` is intentional and temporary — Task 5 replaces it with the user's actual picker selection. The existing passport-only flow's behavior is unchanged by this task.)

- [ ] **Step 9: Update the Xcode project file reference for the rename**

```bash
cd ios && ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('FoundationMobile.xcodeproj')
ref = project.files.find { |f| f.path == 'FoundationMobile/PassportNFCReader.swift' }
raise 'old file reference not found' unless ref
ref.path = 'FoundationMobile/DocumentNFCReader.swift'
ref.name = 'DocumentNFCReader.swift'
target = project.targets.find { |t| t.name == 'FoundationMobile' }
group = project.main_group.find_subpath('FoundationMobile', true)
chip_reading_ref = group.files.find { |f| f.path == 'FoundationMobile/ChipReading.swift' } || group.new_reference('FoundationMobile/ChipReading.swift')
chip_reading_ref.path = 'FoundationMobile/ChipReading.swift'
chip_reading_ref.name = 'ChipReading.swift'
target.add_file_references([chip_reading_ref]) unless target.source_build_phase.files_references.include?(chip_reading_ref)
project.save
puts 'DocumentNFCReader.swift + ChipReading.swift registered.'
"
```

- [ ] **Step 10: Register the test file, build, and run tests**

```bash
ruby scripts/add-test-target.rb
xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -60
xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/DocumentNFCReaderTests 2>&1 | tail -40
```
Expected: build succeeds with zero errors (confirms every renamed call site compiles); all 4 `DocumentNFCReaderTests` pass.

- [ ] **Step 11: Run the full test suite to catch any other stale references**

```bash
xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -80
```
Expected: PASS — `SmokeTests`, `TrustTierLadderTests`, `ExplainerStepTests`, `HumanityVerificationStateTests`, `VerificationStepPlanTests`, `ProfileTierTests` all still green (none of them reference the renamed types, but this confirms it).

- [ ] **Step 12: Commit**

```bash
git add ios/FoundationMobile/ChipReading.swift ios/FoundationMobile/DocumentNFCReader.swift \
        ios/FoundationMobile/PassportNfcProducer.swift ios/FoundationMobile/CaptureCoordinator.swift \
        ios/FoundationMobile/NFCScanView.swift ios/FoundationMobile/CaptureView.swift \
        ios/FoundationMobileTests/DocumentNFCReaderTests.swift ios/FoundationMobile.xcodeproj/project.pbxproj
git commit -m "refactor(docs): generalize PassportNFCReader to DocumentNFCReader via ChipReading protocol"
```

---

### Task 4: `DocumentPickerView`

**Files:**
- Create: `ios/FoundationMobile/DocumentPickerView.swift`
- Test: `ios/FoundationMobileTests/DocumentPickerSearchTests.swift`

**Interfaces:**
- Consumes: `DocumentProfile`, `DocumentProfile.available(for:)`, `DocumentProfile.regionMatch(regionCode:)` (Task 1); `AppConfig.Profile`, `AppConfig.shared.profile` (existing); `Theme` (existing, `ios/FoundationMobile/Theme.swift` — `.bg`, `.brandGreen`, `.surface`, `.text`, `.muted`).
- Produces: `DocumentPickerView` (SwiftUI view, `init(buildProfile: AppConfig.Profile, onSelected: (DocumentProfile) -> Void, onCancel: () -> Void)`), `DocumentPickerSearch.filter(_:query:) -> [DocumentProfile]`. Task 5 presents this view as a sheet from `CaptureView`.

- [ ] **Step 1: Write the failing test**

```swift
// ios/FoundationMobileTests/DocumentPickerSearchTests.swift
import XCTest
@testable import FoundationMobile

final class DocumentPickerSearchTests: XCTestCase {
    func testEmptyQueryReturnsAllProfiles() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "")
        XCTAssertEqual(result.count, DocumentProfile.all.count)
    }

    func testQueryFiltersByDisplayNameCaseInsensitive() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "teudat")
        XCTAssertEqual(result.map(\.id), ["isr-id"])
    }

    func testWhitespaceOnlyQueryReturnsAllProfiles() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "   ")
        XCTAssertEqual(result.count, DocumentProfile.all.count)
    }

    func testNoMatchReturnsEmpty() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "zzzznomatch")
        XCTAssertTrue(result.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/DocumentPickerSearchTests 2>&1 | tail -40`
Expected: FAIL — `DocumentPickerSearch` doesn't exist yet.

- [ ] **Step 3: Write `DocumentPickerView.swift`**

```swift
// ios/FoundationMobile/DocumentPickerView.swift
import SwiftUI

// Sub-project 1 (2026-06-30) — lets the user choose which document they're
// verifying with before MRZScanView opens. Default screen offers the
// device-region match (if the registry has one) + generic Passport;
// "Other document" opens a live search scoped to whatever the active
// build profile can actually reach its required trust tier with (see
// DocumentProfile.available(for:)).

struct DocumentPickerView: View {
    let buildProfile: AppConfig.Profile
    let onSelected: (DocumentProfile) -> Void
    let onCancel: () -> Void

    @State private var mode: Mode = .defaultScreen
    @State private var searchQuery: String = ""

    enum Mode { case defaultScreen, search }

    private var available: [DocumentProfile] {
        DocumentProfile.available(for: buildProfile)
    }

    private var regionMatch: DocumentProfile? {
        guard let match = DocumentProfile.regionMatch(regionCode: Locale.current.region?.identifier),
              available.contains(match) else { return nil }
        return match
    }

    private var searchResults: [DocumentProfile] {
        DocumentPickerSearch.filter(available, query: searchQuery)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                switch mode {
                case .defaultScreen: defaultView
                case .search: searchView
                }
            }
            .navigationTitle("Choose your document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.brandGreen)
                }
            }
        }
    }

    private var defaultView: some View {
        VStack(spacing: 16) {
            if let regionMatch {
                documentRow(regionMatch)
            }
            documentRow(.passport)
            Button("Other document") { mode = .search }
                .font(.callout)
                .foregroundStyle(Theme.brandGreen)
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var searchView: some View {
        VStack(spacing: 12) {
            TextField("Search country or document", text: $searchQuery)
                .padding(10)
                .background(Theme.surface)
                .cornerRadius(8)
                .foregroundStyle(Theme.text)
                .autocorrectionDisabled()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(searchResults) { profile in
                        documentRow(profile)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func documentRow(_ profile: DocumentProfile) -> some View {
        Button {
            onSelected(profile)
        } label: {
            HStack {
                Text(profile.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }
}

enum DocumentPickerSearch {
    static func filter(_ profiles: [DocumentProfile], query: String) -> [DocumentProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return profiles }
        return profiles.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }
}
```

- [ ] **Step 4: Register the new file with the Xcode project**

```bash
cd ios && ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('FoundationMobile.xcodeproj')
target = project.targets.find { |t| t.name == 'FoundationMobile' }
group = project.main_group.find_subpath('FoundationMobile', true)
relative_path = 'FoundationMobile/DocumentPickerView.swift'
ref = group.files.find { |f| f.path == relative_path } || group.new_reference(relative_path)
ref.path = relative_path
ref.name = 'DocumentPickerView.swift'
target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
project.save
puts 'DocumentPickerView.swift registered.'
"
```

- [ ] **Step 5: Register the test file, build, and run tests**

```bash
ruby scripts/add-test-target.rb
xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/DocumentPickerSearchTests 2>&1 | tail -40
```
Expected: PASS — all 4 tests green.

- [ ] **Step 6: Commit**

```bash
git add ios/FoundationMobile/DocumentPickerView.swift ios/FoundationMobileTests/DocumentPickerSearchTests.swift ios/FoundationMobile.xcodeproj/project.pbxproj
git commit -m "feat(docs): add DocumentPickerView with region default + search"
```

---

### Task 5: Wire the picker + TD1 parsing into the live capture flow

This is the end-to-end integration: selecting a non-passport document in `CaptureView` now actually drives TD1 MRZ parsing and per-document copy, completing the feature.

**Files:**
- Modify: `ios/FoundationMobile/MRZScanView.swift` (struct `MRZScanView`, lines 48-101)
- Modify: `ios/FoundationMobile/NFCScanView.swift` (lines 15-27)
- Modify: `ios/FoundationMobile/CaptureView.swift` (state vars lines 9-22, sheets lines 78-106, NFCScanView call line 176-178, MRZScanView call lines 78-96, chip explainer dismiss lines 136-139)

**Interfaces:**
- Consumes: `DocumentProfile` (Task 1), `MRZParser.parseTD1`/`parseTD3` (Task 2), `DocumentPickerView` (Task 4), `CaptureCoordinator.scanPassport(mrzKey:profile:)` (Task 3).
- Produces: end-to-end document-selection flow. No new public interfaces consumed by later tasks (this is the last task in the plan).

- [ ] **Step 1: Thread `DocumentProfile` into `MRZScanView`**

In `ios/FoundationMobile/MRZScanView.swift`, change the struct declaration (lines 48-58) to:

```swift
struct MRZScanView: View {
    let profile: DocumentProfile
    let onParsed: (MRZKey) -> Void
    let onCancel: () -> Void

    @State private var mode: Mode = .camera
    @State private var manualPassport: String = ""
    @State private var manualDOB: String = ""
    @State private var manualExpiry: String = ""
    @State private var manualError: String?
    @State private var ocrStatus: String
    @StateObject private var ocr = MRZOCRSession()

    enum Mode { case camera, manual }

    init(profile: DocumentProfile, onParsed: @escaping (MRZKey) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.onParsed = onParsed
        self.onCancel = onCancel
        _ocrStatus = State(initialValue: profile.mrzFormat == .td1
            ? "Align the back of your \(profile.displayName) inside the frame"
            : "Align the photo page's bottom two lines inside the frame")
    }
```

Change `.navigationTitle("Scan passport MRZ")` (line 71) to:

```swift
            .navigationTitle("Scan \(profile.displayName) MRZ")
```

In the `.onAppear` block (lines 86-94), set the OCR session's expected format:

```swift
        .onAppear {
            ocr.scanBudgetSeconds = AppConfig.shared.mrzScanBudgetSeconds
            ocr.expectedFormat = profile.mrzFormat
            ocr.onParsed = { key in
                ocr.stop()
                onParsed(key)
            }
            ocr.onStatus = { msg in ocrStatus = msg }
            if mode == .camera { ocr.start() }
        }
```

- [ ] **Step 2: Make `MRZOCRSession` format-aware**

In `ios/FoundationMobile/MRZScanView.swift`, add a property to `MRZOCRSession` (after `var onStatus`, around line 212):

```swift
    var onParsed: ((MRZKey) -> Void)?
    var onStatus: ((String) -> Void)?
    var expectedFormat: DocumentProfile.MRZFormat = .td3
```

Replace the `VNRecognizeTextRequest` closure inside `captureOutput` (lines 310-318):

```swift
        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self, let obs = req.results as? [VNRecognizedTextObservation] else { return }
            let lines: [String] = obs.compactMap { $0.topCandidates(1).first?.string }
            let key: MRZKey?
            switch self.expectedFormat {
            case .td3: key = MRZParser.parseTD3(lines: lines) ?? MRZParser.parseTD1(lines: lines)
            case .td1: key = MRZParser.parseTD1(lines: lines) ?? MRZParser.parseTD3(lines: lines)
            }
            if let key {
                Task { @MainActor in
                    self.lockCandidate(key)
                }
            }
        }
```

- [ ] **Step 3: Thread the selected profile into `NFCScanView`**

In `ios/FoundationMobile/NFCScanView.swift`, change the struct (lines 15-27):

```swift
struct NFCScanView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    let selectedProfile: DocumentProfile?
    // CaptureView owns the MRZ sheet's presentation state; this closure
    // flips it open. Same closure is used by the retry path so a failed
    // scan goes straight back into MRZ entry without an extra tap.
    let onScanTap: () -> Void

    // Until the user has picked a document, fall back to the build
    // profile's generic noun ("identity document", "passport", …).
    private var docNoun: String { selectedProfile?.displayName ?? AppConfig.shared.profile.documentNoun }
    private var docNounCap: String { docNoun.prefix(1).uppercased() + docNoun.dropFirst() }
```

- [ ] **Step 4: Wire the picker into `CaptureView`**

In `ios/FoundationMobile/CaptureView.swift`, add state (after `@State private var isShowingDocPhoto = false` at line 10):

```swift
    @State private var isShowingDocumentPicker = false
    @State private var selectedDocumentProfile: DocumentProfile?
```

Add a new sheet, alongside the existing `.sheet(isPresented: $isShowingMRZScan)` (after the `}` closing that sheet at line 97):

```swift
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPickerView(
                buildProfile: AppConfig.shared.profile,
                onSelected: { profile in
                    selectedDocumentProfile = profile
                    isShowingDocumentPicker = false
                    isShowingMRZScan = true
                },
                onCancel: { isShowingDocumentPicker = false }
            )
        }
```

Change the `MRZScanView(...)` call (lines 79-96) to pass the selected profile, falling back to `.passport` only as the sheet's required non-optional init argument (it is never nil by the time this sheet can present, since the picker always runs first):

```swift
        .sheet(isPresented: $isShowingMRZScan) {
            MRZScanView(
                profile: selectedDocumentProfile ?? .passport,
                onParsed: { key in
                    isShowingMRZScan = false
                    if shownExplainers.contains(.chip) {
                        coordinator.scanPassport(mrzKey: key, profile: selectedDocumentProfile ?? .passport)
                    } else {
                        shownExplainers.insert(.chip)
                        pendingChipKey = key
                        pendingExplainer = .chip
                    }
                },
                onCancel: {
                    isShowingMRZScan = false
                }
            )
        }
```

Change the chip-explainer dismiss handler (lines 136-139):

```swift
            if let key = pendingChipKey {
                pendingChipKey = nil
                coordinator.scanPassport(mrzKey: key, profile: selectedDocumentProfile ?? .passport)
            }
```

Change the `NFCScanView(...)` call (lines 176-178) to pass the selection and open the picker first, falling straight to MRZScanView on subsequent taps once a document has been chosen:

```swift
            if shouldShowNFCPanel {
                NFCScanView(coordinator: coordinator, selectedProfile: selectedDocumentProfile) {
                    if selectedDocumentProfile != nil {
                        isShowingMRZScan = true
                    } else {
                        isShowingDocumentPicker = true
                    }
                }
            } else if shouldShowLiveCamera {
```

Change `promptBlock`'s `.passportReady` case (line 290) for the field rename:

```swift
                Text("Passport scanned (\(passport.issuingCountryCode) \(passport.documentNumberMasked)) — ready to verify")
```

(This line already had its field renamed in Task 3 Step 8 — confirm it reads `documentNumberMasked`, not `passportNumberMasked`, before moving on.)

- [ ] **Step 5: Build**

```bash
cd ios && xcodebuild build -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -60
```
Expected: build succeeds with zero errors.

- [ ] **Step 6: Run the full test suite**

```bash
xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -80
```
Expected: PASS — every test target green, including `DocumentProfileTests`, `MRZParserTests`, `DocumentNFCReaderTests`, `DocumentPickerSearchTests` from Tasks 1-4, plus all pre-existing tests.

- [ ] **Step 7: Manual regression check (simulator, passport path)**

Run the app in the iOS Simulator (`xcodebuild -scheme FoundationMobile build` then launch from Xcode, or `open ios/FoundationMobile.xcworkspace` if still using the CocoaPods workspace per the project README), drive a `hisec-global` build through Capture: pose loop → document picker appears → tap "Passport" → MRZ manual-entry path (simulator has no live camera) → confirm `coordinator.state` reaches `.passportReady` with `documentType == .passport`. CoreNFC itself cannot be exercised in the Simulator — this confirms the picker + MRZ + state-machine wiring only.

- [ ] **Step 8: Note the outstanding manual hardware-verification gate**

No code change — this is a reminder for whoever ships the first non-passport `DocumentProfile` to production. Per the spec's Testing Tier 3: before enabling any of `isr-id` / `deu-id` / `fra-id` / `prt-id` / `ita-id` / `esp-id` / `jpn-id` / `bra-id` for real users, that country's `dg2Accessible: true` assumption must be confirmed against real hardware (official test card, self-personalized JavaCard, or a consented real document) — see `docs/superpowers/specs/2026-06-30-nfc-document-registry-design.md`, Testing section. This plan implements the registry and pipeline; it does not perform that verification.

- [ ] **Step 9: Commit**

```bash
git add ios/FoundationMobile/MRZScanView.swift ios/FoundationMobile/NFCScanView.swift ios/FoundationMobile/CaptureView.swift
git commit -m "feat(docs): wire DocumentPickerView + TD1 parsing into the capture flow"
```

---

## Self-Review

**Spec coverage:**
- `DocumentProfile` registry, seeded countries, `dg2Accessible` flag → Task 1.
- Picker filtering against build profile (`available(for:)`) → Task 1, exercised by Task 4's picker.
- TD1 MRZ parsing, auto-detect with fallback → Task 2 (parser), Task 5 Step 2 (auto-detect/fallback in `MRZOCRSession`).
- `DocumentNFCReader` rename, `includeFacePhoto` defense-in-depth check, `DocumentReadResult` + `documentType` → Task 3.
- `ChipReading` protocol + Tier 2 synthetic-fixture testing → Task 3.
- Document picker UX (region default + Passport + search, scoped to `available(for:)`) → Task 4.
- Error handling: profile/document mismatch surfaced before NFC (TD1/TD3 fallback parsing in Task 5 means a wrong-document scan simply fails to parse within the existing scan budget, falling through to the existing manual-entry path — no separate mismatch state was added beyond what TD1/TD3 fallback parsing already provides); `dg2Accessible` wrong in practice falls through existing `DocumentNFCReaderError` cases (Task 3, unchanged from original).
- Tier 1/Tier 3 testing strategy → Tier 1 covered by Tasks 1/2/4 unit tests; Tier 3 flagged explicitly as a non-code manual gate in Task 5 Step 8.
- Out-of-scope items (mDL, OCR fallback, retry/tenant fallback, dynamic tier) — not touched by any task, confirmed by the Global Constraints section.

**Placeholder scan:** no TBD/TODO markers; every code step has complete, runnable code; every shell command has an expected-result line.

**Type consistency:** `DocumentProfile`, `DocumentProfile.DocumentType`, `DocumentProfile.MRZFormat`, `ChipReadOutcome`, `ChipReading`, `DocumentReadResult`, `DocumentNFCReaderError`, `DocumentNFCReader`, `DocumentPickerSearch` are defined once (Tasks 1, 3, 4) and referenced with identical names/signatures in every later task and test file.
