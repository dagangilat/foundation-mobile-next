# mDL + Wallet National ID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Apple Wallet mDL (mobile driver's licence) and Wallet National ID support to foundation-mobile via Apple's `ProximityReader` Verifier API (`MobileDocumentReader`), extending the existing `DocumentProfile` registry and capture pipeline so US users without an ICAO NFC-chip passport or national ID can complete proof-of-humanity verification against their Apple Wallet credential.

**Architecture:** `DocumentProfile` gains a `ReadingMethod` enum (`.nfcChip` | `.walletDocument`) and optional `walletDocumentType`, making `mrzFormat` optional. Two new entries (`usa-mdl`, `usa-walletid`) are seeded. A new `WalletDocumentReader` actor wraps `MobileDocumentReader`; its result struct (`WalletDocumentReadResult`) mirrors `DocumentReadResult`. `CaptureCoordinator` gains three new states and a `scanWalletDocument(profile:)` method; `CaptureView` bypasses `MRZScanView` for wallet profiles and shows a new `WalletDocumentScanView`. `AppConfig.Profile.FaceMatchSource` gets a `.mdl` case → `.high` trust tier; a matching `hisec-mdl.json` build profile is added. A new `WalletDocumentProducer` produces the `.nfcZk` artifact from the wallet response.

**Tech stack:** Swift 5, SwiftUI, XCTest, `ProximityReader` framework (iOS 17+), Apple "Mobile Document Reader (Developer)" Simulator profile for automated Tier-2 tests.

**Reference spec:** `docs/superpowers/specs/2026-06-30-mdl-wallet-design.md`

---

## Global Constraints

- Minimum iOS target: 16.0 (existing project constraint). `ProximityReader` Verifier API requires iOS 17+. Gate all wallet code behind `if #available(iOS 17, *)`; `DocumentProfile.available(for:)` already filters at call time via `MobileDocumentReader.isSupported`.
- "Nothing identifying leaves the device" invariant is unchanged. Portrait bytes stay in memory only for the face-match step. `document_number`, `expiry_date`, and `issuing_jurisdiction` are read as `nonRetainedElements` — inspected in-process for masking/hash only.
- No brand token in v1 — `prepare(using: nil)` throughout.
- `WalletDocumentProducer` reuses the existing `.nfcZk` `ProofArtifact.Kind`. No new kind values are added.
- Trust tier stays build-time. Wallet entries are only offered when the active profile has `faceMatchSource == .mdl` (or `.none` / `.documentPhoto` for lower-tier builds). This is enforced by extending `DocumentProfile.available(for:)`.
- Every new pure-logic path (profile filtering, field masking, result struct init) needs an XCTest with no physical-hardware dependency. The Simulator developer profile handles automated Tier-2 (full state-machine flow) without fabricated byte fixtures.
- Do NOT import `ProximityReader` anywhere outside `WalletDocumentReader.swift`. Keep the framework boundary sharp so every other file compiles and tests fine when `MobileDocumentReader.isSupported == false`.

---

### Task 1: `DocumentProfile` extensions

**Files:**
- Modify: `ios/FoundationMobile/DocumentProfile.swift`
- Modify: `ios/FoundationMobileTests/DocumentProfileTests.swift`

**Current state of `DocumentProfile.swift`:**
- `enum DocumentType: Equatable { case passport, nationalId }`
- `enum MRZFormat: Equatable { case td1, td3 }`
- Fields: `id`, `countryCode`, `displayName`, `documentType`, `mrzFormat: MRZFormat`, `dg2Accessible: Bool`
- Static entries: `.passport` + 8 national-ID entries (isr, deu, fra, prt, ita, esp, jpn, bra)
- Methods: `available(for:)`, `regionMatch(regionCode:)`

**Changes:**

- [ ] **Step 1: Add `ReadingMethod` and `WalletDocumentType` enums to `DocumentProfile.swift`**

  Inside the `DocumentProfile` struct (before the stored properties), add:

  ```swift
  enum ReadingMethod: Equatable {
      case nfcChip        // MRZScanView → DocumentNFCReader
      case walletDocument // Apple ProximityReader Verifier API, no MRZ scan
  }

  enum WalletDocumentType: Equatable {
      case mobileDriversLicense
      case nationalIdCard
  }
  ```

- [ ] **Step 2: Update stored properties**

  - Change `let mrzFormat: MRZFormat` → `let mrzFormat: MRZFormat?`
  - Add `let readingMethod: ReadingMethod`
  - Add `let walletDocumentType: WalletDocumentType?`

  Update every existing static entry to pass `readingMethod: .nfcChip, walletDocumentType: nil`. The existing `MRZFormat` values remain non-nil for all NFC entries.

- [ ] **Step 3: Add two new static entries**

  ```swift
  static let usaMDL = DocumentProfile(
      id: "usa-mdl",
      countryCode: "USA",
      displayName: "US Driver's Licence (Wallet)",
      documentType: .nationalId,
      mrzFormat: nil,
      dg2Accessible: false,
      readingMethod: .walletDocument,
      walletDocumentType: .mobileDriversLicense
  )

  static let usaWalletID = DocumentProfile(
      id: "usa-walletid",
      countryCode: "USA",
      displayName: "US Wallet National ID",
      documentType: .nationalId,
      mrzFormat: nil,
      dg2Accessible: false,
      readingMethod: .walletDocument,
      walletDocumentType: .nationalIdCard
  )
  ```

  Add both to `DocumentProfile.all`.

- [ ] **Step 4: Extend `available(for:)`**

  After the existing `dg2Accessible` filter, add a wallet-device filter:

  ```swift
  // Filter wallet entries on devices/OS versions that don't support MobileDocumentReader.
  // Guard is always true on iOS <17; MobileDocumentReader.isSupported handles the runtime check.
  if #available(iOS 17, *) {
      // keep wallet entries only when the device supports them
      return filtered.filter { profile in
          profile.readingMethod == .nfcChip || MobileDocumentReader.isSupported
      }
  } else {
      return filtered.filter { $0.readingMethod == .nfcChip }
  }
  ```

  `import ProximityReader` at the top of `DocumentProfile.swift` (gated with `#if canImport(ProximityReader)` block — or move the filter into an extension in `WalletDocumentReader.swift` to avoid the import; either approach is acceptable as long as it compiles on iOS 16 simulators without the framework).

  **Recommended approach:** keep `DocumentProfile.swift` free of `ProximityReader` import. Add a static helper `WalletDocumentReader.isSupported: Bool` (returns `false` on iOS <17) and call it from `available(for:)`. See Task 3 for `WalletDocumentReader`.

- [ ] **Step 5: Write/extend tests in `DocumentProfileTests.swift`**

  Add:

  ```swift
  func testWalletEntriesHaveNilMRZFormat() {
      XCTAssertNil(DocumentProfile.usaMDL.mrzFormat)
      XCTAssertNil(DocumentProfile.usaWalletID.mrzFormat)
  }

  func testWalletEntriesReadingMethod() {
      XCTAssertEqual(DocumentProfile.usaMDL.readingMethod, .walletDocument)
      XCTAssertEqual(DocumentProfile.usaWalletID.readingMethod, .walletDocument)
      XCTAssertEqual(DocumentProfile.usaMDL.walletDocumentType, .mobileDriversLicense)
      XCTAssertEqual(DocumentProfile.usaWalletID.walletDocumentType, .nationalIdCard)
  }

  func testNfcEntriesHaveNonNilMRZFormat() {
      let nfcEntries = DocumentProfile.all.filter { $0.readingMethod == .nfcChip }
      XCTAssertTrue(nfcEntries.allSatisfy { $0.mrzFormat != nil })
  }

  func testAllEntriesInAllArray() {
      let ids = Set(DocumentProfile.all.map(\.id))
      XCTAssertTrue(ids.contains("usa-mdl"))
      XCTAssertTrue(ids.contains("usa-walletid"))
  }
  ```

  Existing `DocumentProfileTests` tests must still pass unchanged.

- [ ] **Step 6: Register any new files with xcodeproj, build + test**

  Run `ruby ios/scripts/add-test-target.rb` to register new/changed test files.
  Build target `FoundationMobile` — confirm zero errors.
  Run `DocumentProfileTests` — all pass.

---

### Task 2: `AppConfig.FaceMatchSource.mdl` + `hisec-mdl.json` profile

**Files:**
- Modify: `ios/FoundationMobile/AppConfig.swift`
- Create: `ios/FoundationMobile/Resources/profiles/hisec-mdl.json`
- Modify: `ios/FoundationMobileTests/ProfileTierTests.swift` (or create if absent)

**Current state:**
- `FaceMatchSource: String, Decodable, Sendable { case dg2, documentPhoto, none }`
- `trustTier` switch: `.dg2 → .high`, `.documentPhoto → .standard`, `.none → .low`

**Changes:**

- [ ] **Step 1: Add `.mdl` case to `FaceMatchSource`**

  ```swift
  case mdl   // Apple ProximityReader Verifier API portrait → .high
  ```

- [ ] **Step 2: Extend `trustTier` switch**

  Add `case .mdl: return .high`.

- [ ] **Step 3: Create `hisec-mdl.json`**

  Copy `hisec-global.json` as the base. Change:

  ```json
  {
    "schemaVersion": 4,
    "profile": {
      "id": "hisec-mdl",
      "label": "High Security — Wallet ID",
      "faceMatchSource": "mdl",
      "requiredPhases": ["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],
      "document": {"noun": "driving licence or Wallet ID", "short": "Wallet ID"}
    },
    "liveness": { ... },   // identical to hisec-global.json
    "antiSpoof": { ... },  // identical
    "faceMatch": { ... }   // identical
  }
  ```

  Adjust `"noun"` / `"short"` strings as needed for the instruction copy.

- [ ] **Step 4: Write/extend tier tests**

  In `ProfileTierTests.swift` (create if absent):

  ```swift
  func testMdlFaceMatchSourceIsTierHigh() {
      let profile = makeProfile(faceMatchSource: "mdl")
      XCTAssertEqual(profile.trustTier, .high)
  }
  ```

  where `makeProfile` decodes a minimal JSON string with the given `faceMatchSource` field.

- [ ] **Step 5: Build + test**

  Confirm `AppConfig` decodes `"mdl"` without crashing. Confirm `trustTier` returns `.high`. Run all `ProfileTierTests` — pass.

---

### Task 3: `WalletDocumentReadResult` + `WalletDocumentReader`

**Files:**
- Create: `ios/FoundationMobile/WalletDocumentReader.swift`
- Create: `ios/FoundationMobileTests/WalletDocumentReaderTests.swift`

**Dependency:** Task 1 (`DocumentProfile.ReadingMethod`, `WalletDocumentType`) must be complete.

**Design:**

```swift
// WalletDocumentReadResult — analogous to DocumentReadResult
struct WalletDocumentReadResult: @unchecked Sendable, Equatable {
    let portraitHash: Data           // SHA-256(portrait JPEG bytes) — 32 bytes
    let portraitImage: UIImage?      // in-memory only for face-match; nil when includeFacePhoto=false
    let documentNumberMasked: String // last 3 digits only, e.g. "•••321"
    let issuingState: String?        // e.g. "AZ", informational
    let walletDocumentType: DocumentProfile.WalletDocumentType
}

// WalletDocumentReader — actor, analogous to DocumentNFCReader
@MainActor
final class WalletDocumentReader {
    static let shared = WalletDocumentReader()

    // Returns false on iOS <17 (no ProximityReader) — used by DocumentProfile.available(for:)
    static var isSupported: Bool {
        if #available(iOS 17, *) { return MobileDocumentReader.isSupported }
        return false
    }

    func readDocument(
        profile: DocumentProfile,
        includeFacePhoto: Bool
    ) async throws -> WalletDocumentReadResult
}
```

**Implementation of `readDocument`:**

```
guard #available(iOS 17, *) else { throw WalletDocumentError.unsupportedOS }
let reader = MobileDocumentReader()
try await reader.prepare(using: nil)
let session = try await reader.startReading()

let request: any MobileDocumentRequest
switch profile.walletDocumentType {
case .mobileDriversLicense:
    request = MobileDriversLicenseDataRequest(
        retainedElements: includeFacePhoto ? [.portrait] : [],
        nonRetainedElements: [.documentNumber, .expiryDate, .ageOver18,
                               .issuingAuthority, .issuingJurisdiction]
    )
case .nationalIdCard:
    request = MobileNationalIDCardDataRequest(
        retainedElements: includeFacePhoto ? [.portrait] : [],
        nonRetainedElements: [.documentNumber, .expiryDate, .ageOver18,
                               .issuingAuthority, .issuingJurisdiction]
    )
case nil:
    throw WalletDocumentError.invalidProfile
}

let response = try await session.requestDocument(request)
// Extract fields, build WalletDocumentReadResult, release portrait bytes after hashing
```

Field extraction:
- `portrait` → `UIImage(data:)` stored as `portraitImage`; SHA-256 of the raw bytes stored as `portraitHash`. Portrait bytes are not written to disk.
- `documentNumber` → mask all but last 3 chars → `documentNumberMasked`.
- `issuingJurisdiction` → `issuingState`.

Error enum:

```swift
enum WalletDocumentError: Error {
    case unsupportedOS
    case invalidProfile
    case sessionExpired    // retry once (caller's responsibility)
    case cancelled
}
```

Map `MobileDocumentReaderError.cancelled` → `.cancelled`, `MobileDocumentReaderError.sessionExpired` → `.sessionExpired`.

- [ ] **Step 1: Create `WalletDocumentReader.swift`** with `WalletDocumentReadResult`, `WalletDocumentError`, and `WalletDocumentReader` as above.

- [ ] **Step 2: Update `DocumentProfile.available(for:)` to call `WalletDocumentReader.isSupported`** (back-fill from Task 1 Step 4 if not already done).

- [ ] **Step 3: Write unit tests for result struct + field masking** in `WalletDocumentReaderTests.swift`:

  ```swift
  func testDocumentNumberMaskingKeepsLast3() {
      // Test the masking helper directly (extract as internal func if needed)
      XCTAssertEqual(mask("DL1234567"), "•••567")
      XCTAssertEqual(mask("AB1"), "•••AB1")  // short: no masking below 3 chars
  }

  func testPortraitHashIs32Bytes() {
      let fakeBytes = Data(repeating: 0xAB, count: 64)
      let hash = SHA256.hash(data: fakeBytes)
      XCTAssertEqual(Data(hash).count, 32)
  }

  func testIsSupportedReturnsFalseOnSimulatorWithoutDeveloperProfile() {
      // On iOS <17 CI this should be false; on a configured Simulator it may be true.
      // Just confirm it doesn't crash.
      _ = WalletDocumentReader.isSupported
  }
  ```

  Full state-machine flow (Tier-2) is tested separately in Task 5 (Simulator with developer profile) — unit tests here cover only pure logic.

- [ ] **Step 4: Register new files, build + test**

  Run `ruby ios/scripts/add-test-target.rb`.
  Build — confirm `ProximityReader` import doesn't break iOS 16 Simulator build (use `#if canImport` or `@available` guards at call sites).
  Run `WalletDocumentReaderTests` — pass.

---

### Task 4: `WalletDocumentProducer`

**Files:**
- Create: `ios/FoundationMobile/WalletDocumentProducer.swift`
- Create: `ios/FoundationMobileTests/WalletDocumentProducerTests.swift`

**Dependency:** Task 3 (`WalletDocumentReadResult`) must be complete.

**Design** (analogous to `PassportNfcProducer`):

```swift
struct WalletDocumentProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .nfcZk
    let walletData: WalletDocumentReadResult

    // Payload: SHA-256(documentNumberMasked_raw_utf8 || issuingState_utf8)
    // Same double-hash binding contract as PassportNfcProducer.
    func produce() async throws -> ProofArtifact
}
```

- [ ] **Step 1: Read `PassportNfcProducer.swift`** to understand the `ProofProducer` protocol and `ProofArtifact` construction pattern. Mirror it exactly.

- [ ] **Step 2: Create `WalletDocumentProducer.swift`** implementing the payload as `SHA-256(documentNumberRaw_utf8 || issuingState_utf8)` where `documentNumberRaw` is the unmasked document number captured transiently during `readDocument` and stored in the result (or if it's already masked, use the masked string — be consistent with whatever `WalletDocumentReadResult` stores).

  > Note: The spec says "SHA-256(document_number || issuing_jurisdiction)" — use the raw (unmasked) document number for the hash input so the commitment is to a full identifier. Store the raw number transiently in a separate internal field if needed, separate from the display-masked `documentNumberMasked`.

- [ ] **Step 3: Write tests** in `WalletDocumentProducerTests.swift`:

  ```swift
  func testProducerKindIsNfcZk() {
      let result = makeWalletResult()
      XCTAssertEqual(WalletDocumentProducer(walletData: result).kind, .nfcZk)
  }

  func testPayloadIsDeterministic() async throws {
      let result = makeWalletResult(documentNumber: "DL1234567", issuingState: "AZ")
      let a = try await WalletDocumentProducer(walletData: result).produce()
      let b = try await WalletDocumentProducer(walletData: result).produce()
      XCTAssertEqual(a.payload, b.payload)
  }

  func testPayloadDiffersOnDifferentDocumentNumber() async throws {
      let r1 = makeWalletResult(documentNumber: "DL1234567", issuingState: "AZ")
      let r2 = makeWalletResult(documentNumber: "DL9999999", issuingState: "AZ")
      let p1 = try await WalletDocumentProducer(walletData: r1).produce()
      let p2 = try await WalletDocumentProducer(walletData: r2).produce()
      XCTAssertNotEqual(p1.payload, p2.payload)
  }
  ```

- [ ] **Step 4: Register, build + test** — all `WalletDocumentProducerTests` pass.

---

### Task 5: `CaptureCoordinator` extensions

**Files:**
- Modify: `ios/FoundationMobile/CaptureCoordinator.swift`
- Modify: `ios/FoundationMobileTests/CaptureCoordinatorTests.swift` (or create)

**Dependencies:** Tasks 1, 3, 4 must be complete.

**Current `CaptureCoordinator.State` cases** (relevant excerpt):
```
idle, unsupported, needsAttestation,
readyForPose(pose:captured:total:),
readyForPassport(framesCount:), scanningPassport(framesCount:),
passportReady(framesCount:passport:),
readyForDocumentPhoto(framesCount:), documentPhotoReady(framesCount:captureJpeg:captureHash:),
readyForVerification(framesCount:),
verifying(phase:), sealed(...), failed(...)
```

**Changes:**

- [ ] **Step 1: Add three new `State` cases**

  ```swift
  case readyForWalletDocument(framesCount: Int)
  case scanningWalletDocument(framesCount: Int)
  case walletDocumentReady(framesCount: Int, walletResult: WalletDocumentReadResult)
  ```

- [ ] **Step 2: Extend `afterPosesState(framesCount:)`**

  Add new branch BEFORE the existing `readyForPassport` branch:

  ```swift
  if profile.readingMethod == .walletDocument && profile.requires(.nfcZk) {
      return .readyForWalletDocument(framesCount: framesCount)
  }
  ```

- [ ] **Step 3: Add `scanWalletDocument(profile:)` method**

  Analogous to `scanPassport(mrzKey:profile:)`:

  ```swift
  @MainActor
  func scanWalletDocument(profile: DocumentProfile) {
      guard case .readyForWalletDocument(let framesCount) = state else { return }
      state = .scanningWalletDocument(framesCount: framesCount)
      Task {
          do {
              let includeFacePhoto = AppConfig.shared.profile.faceMatchSource == .mdl
              let result = try await WalletDocumentReader.shared.readDocument(
                  profile: profile, includeFacePhoto: includeFacePhoto
              )
              await MainActor.run {
                  state = .walletDocumentReady(framesCount: framesCount, walletResult: result)
              }
          } catch WalletDocumentError.cancelled {
              await MainActor.run { state = .failed(stage: .passportScan, message: "Document read cancelled") }
          } catch WalletDocumentError.sessionExpired {
              // Retry once — re-enter readyForWalletDocument so user can tap again
              await MainActor.run { state = .readyForWalletDocument(framesCount: framesCount) }
          } catch {
              await MainActor.run { state = .failed(stage: .passportScan, message: error.localizedDescription) }
          }
      }
  }
  ```

- [ ] **Step 4: Extend `verify()` with new arm**

  In the `verify()` method, add a case for `.walletDocumentReady` that:
  1. Transitions to `verifying(phase: .nfcZk)`.
  2. Calls `WalletDocumentProducer(walletData: walletResult).produce()` to emit `.nfcZk`.
  3. If `profile.faceMatchSource == .mdl`, uses `walletResult.portraitImage` as the reference face for `FaceMatchProducer` (same producer as the `dg2` path, different image source).
  4. Continues with the remaining phases (liveness, antiSpoof, faceMatch) as per the existing verification pipeline.

- [ ] **Step 5: Write coordinator state-machine tests**

  Add to `CaptureCoordinatorTests.swift`:

  ```swift
  func testAfterPosesWalletProfileGoesToReadyForWalletDocument() {
      // Set up coordinator with a mock wallet profile + hisec-mdl config
      // Drive liveness poses to completion
      // Assert state == .readyForWalletDocument(framesCount:)
  }

  func testScanWalletDocumentTransitionsToScanning() {
      // Set state = .readyForWalletDocument(framesCount: 30)
      // coordinator.scanWalletDocument(profile: .usaMDL)
      // Assert state == .scanningWalletDocument(framesCount: 30)
  }
  ```

  Tier-2 (full flow on Simulator with developer profile): run the full state machine on an iPhone Simulator with the "Mobile Document Reader (Developer)" profile installed; confirm `.readyForWalletDocument` → `.scanningWalletDocument` → `.walletDocumentReady` → `.sealed`. Document in test comments as a manual Tier-2 step if not wired into CI.

- [ ] **Step 6: Register, build + test** — unit tests pass.

---

### Task 6: `CaptureView` wiring + `WalletDocumentScanView`

**Files:**
- Modify: `ios/FoundationMobile/CaptureView.swift`
- Create: `ios/FoundationMobile/WalletDocumentScanView.swift`

**Dependencies:** Tasks 1, 5 must be complete.

**Current `CaptureView` state:**
- `@State private var isShowingMRZScan = false`
- `@State private var isShowingDocPhoto = false`
- `@State private var isShowingDocumentPicker = false`
- `@State private var selectedDocumentProfile: DocumentProfile?`
- After picker selection: if profile is non-nil, `isShowingMRZScan = true`
- `NFCScanView` tap: if profile != nil → `isShowingMRZScan = true`, else picker

**Changes:**

- [ ] **Step 1: Add `@State private var isShowingWalletDocScan = false` to `CaptureView`**

- [ ] **Step 2: Route picker selection by `readingMethod`**

  In the `DocumentPickerView` `onSelected` closure, replace the existing unconditional `isShowingMRZScan = true` with:

  ```swift
  selectedDocumentProfile = profile
  if profile.readingMethod == .walletDocument {
      isShowingWalletDocScan = true
  } else {
      isShowingMRZScan = true
  }
  ```

- [ ] **Step 3: Add wallet scan sheet**

  Add a `.sheet(isPresented: $isShowingWalletDocScan)` presenting `WalletDocumentScanView`:

  ```swift
  .sheet(isPresented: $isShowingWalletDocScan) {
      if let profile = selectedDocumentProfile {
          WalletDocumentScanView(profile: profile) {
              coordinator.scanWalletDocument(profile: profile)
              isShowingWalletDocScan = false
          }
      }
  }
  ```

- [ ] **Step 4: Handle `walletDocumentReady` state in `CaptureView` body**

  In the view's state-driven body switch, add a case for `.walletDocumentReady` — display a brief confirmation message ("Document read — verifying…") and auto-trigger `coordinator.verify()`.

- [ ] **Step 5: Create `WalletDocumentScanView.swift`**

  Minimal instruction view — Apple's own system sheet handles the actual reader UX:

  ```swift
  struct WalletDocumentScanView: View {
      let profile: DocumentProfile
      let onScanTap: () -> Void

      var body: some View {
          VStack(spacing: 24) {
              Text("Hold your iPhone near the credential holder's iPhone")
                  .font(.headline)
                  .multilineTextAlignment(.center)
              Text("Apple will prompt you to present the \(profile.displayName).")
                  .foregroundStyle(.secondary)
                  .multilineTextAlignment(.center)
              Button("Start Reading", action: onScanTap)
                  .buttonStyle(.borderedProminent)
          }
          .padding()
      }
  }
  ```

- [ ] **Step 6: Register new files, build + visual inspection**

  Run `ruby ios/scripts/add-test-target.rb`.
  Build on iOS Simulator — confirm no SwiftUI preview or compile errors.
  Manually run the picker → select "US Driver's Licence (Wallet)" → confirm `WalletDocumentScanView` appears (MRZScanView must NOT appear).
  On Simulator with "Mobile Document Reader (Developer)" profile: tap "Start Reading" → confirm system reader sheet fires → confirm state machine reaches `.walletDocumentReady` on mock response → confirm `.sealed` reached.

---

## Task ordering and dependencies

```
Task 1 (DocumentProfile)
  └─► Task 2 (AppConfig + hisec-mdl.json)   [independent of Task 3+]
  └─► Task 3 (WalletDocumentReader)
        └─► Task 4 (WalletDocumentProducer)
              └─► Task 5 (CaptureCoordinator)
                    └─► Task 6 (CaptureView + WalletDocumentScanView)
```

Tasks 1 and 2 can run in parallel. Tasks 3–6 are strictly sequential.

## PR checklist

- [ ] All new files registered in `FoundationMobile.xcodeproj` via `add-test-target.rb`
- [ ] `ProximityReader` linked in the main target's Frameworks phase
- [ ] `NSProximityReaderUsageDescription` added to `Info.plist`
- [ ] Verifier API capability added in Xcode (Signing & Capabilities → + → Mobile Document Reader Verifier)
- [ ] All XCTests pass on iPhone 17 Simulator (iOS 17+)
- [ ] `hisec-mdl.json` included in the app bundle via the Copy Bundle Resources phase
- [ ] `select-profile.sh` unchanged — profile selection mechanism requires no changes
- [ ] Manual Tier-2 sign-off: full flow on Simulator with "Mobile Document Reader (Developer)" profile
- [ ] Tier-3 sign-off (before enabling for real users): confirmed against a real Apple Wallet mDL on a participating-state device
