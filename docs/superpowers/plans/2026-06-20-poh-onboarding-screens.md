# PoH Onboarding Screens — Implementation Plan (Plan 1 of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Proof-of-Human onboarding flow screens (overview checklist → per-step explainers → polished capture states → verified trust-tier screen) as designed in `docs/design/poh-onboarding`, driven by the active profile.

**Architecture:** All presentation *logic* (profile-derived step lists, trust-tier ladder status, explainer routing) is extracted into small pure value types that are unit-tested with XCTest. SwiftUI views stay thin and consume those types; views are verified by build + Xcode preview/screenshot review gates, not unit tests. Everything edition-specific (document noun, which steps apply, achieved tier) comes from `AppConfig.Profile`.

**Tech Stack:** Swift 5 / SwiftUI, XCTest (new `FoundationMobileTests` target added via the `xcodeproj` Ruby gem), Xcode 17 / iОS 16 deployment, baked-profile JSON config.

**Scope note:** This is Plan 1 of 2. The runtime **tiered-fallback engine** (chip-unreadable → complete as Standard Security at runtime; error screens E2 + the achieved-vs-baked tier split) is a separate high-risk subsystem — **Plan 2**, to be written after its own design pass. This plan is additive and does not change the seal/anchor pipeline or the baked-profile model.

## Global Constraints

- **Tier vocabulary** = the zk classification, verbatim: `High Security` (hisec-global), `Standard Security` (standardsec), `Low Security` (lowsec-attest). Never "Passport-grade".
- **Document noun is profile-injected** via `AppConfig.Profile.documentNoun` (default `"identity document"`). Copy uses possessive (`your <noun>'s chip`) — never "a/an <noun>".
- **Tier derivation** (already in `Profile.trustTier`): `faceMatchSource` `dg2`→`.high`, `documentPhoto`→`.standard`, `none`→`.low`.
- **Colors** come from `Theme` (active palette) — no hardcoded hex in views. `Theme.onAccent` for text on a filled accent.
- **Profile phases** raw values: `appAttest`, `nfcZk`, `liveness`, `antiSpoof`, `faceMatch` (`ProofArtifact.Kind`). Check via `profile.requires(_:)`.
- **No release footprint** for debug-only affordances — guard with `#if DEBUG`.
- **Frequent commits**, conventional-commit messages ending with the `Co-Authored-By: Claude Opus 4.8` trailer.
- Build verification command (simulator, no signing):
  `xcodebuild -project FoundationMobile.xcodeproj -scheme FoundationMobile -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

**Pre-existing on `feature/poh-onboarding` (do not rebuild — harden with tests):** `VerifiedView.swift` (Variant B), `Profile.trustTier` / `Profile.document`, the `HomeView` `.sealed` fullScreenCover + DEBUG gear edition preview. An uncommitted draft `VerificationOverviewView.swift` exists; **Task 3 supersedes it** (delete and recreate test-first).

---

### Task 1: Add the `FoundationMobileTests` unit-test target

**Files:**
- Create: `ios/scripts/add-test-target.rb`
- Create: `ios/FoundationMobileTests/SmokeTests.swift`
- Modify: `ios/FoundationMobile.xcodeproj/project.pbxproj` (written by the script)

**Interfaces:**
- Produces: a `FoundationMobileTests` unit-test bundle hosted by the app, runnable via `xcodebuild test`, with `@testable import FoundationMobile`. Later tasks add files to its group `FoundationMobileTests/`.

- [ ] **Step 1: Write the registration script**

```ruby
# ios/scripts/add-test-target.rb — idempotent: adds a unit-test target +
# shared scheme test action. Run once. Requires: gem install xcodeproj.
require 'xcodeproj'

proj_path = File.expand_path('../FoundationMobile.xcodeproj', __dir__)
project   = Xcodeproj::Project.open(proj_path)
app       = project.targets.find { |t| t.name == 'FoundationMobile' }
raise 'app target missing' unless app

unless project.targets.any? { |t| t.name == 'FoundationMobileTests' }
  test = project.new_target(:unit_test_bundle, 'FoundationMobileTests', :ios, '16.0')
  test.add_dependency(app)
  test.build_configurations.each do |c|
    c.build_settings['TEST_HOST']                 = '$(BUILT_PRODUCTS_DIR)/FoundationMobile.app/FoundationMobile'
    c.build_settings['BUNDLE_LOADER']             = '$(TEST_HOST)'
    c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.foundationglobal.mobile.tests'
    c.build_settings['GENERATE_INFOPLIST_FILE']   = 'YES'
    c.build_settings['SWIFT_VERSION']             = '5.0'
    c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']= '16.0'
    c.build_settings['CODE_SIGNING_ALLOWED']      = 'NO'
  end
  group = project.main_group.find_subpath('FoundationMobileTests', true)
  group.set_source_tree('<group>')
  Dir[File.join(__dir__, '..', 'FoundationMobileTests', '*.swift')].sort.each do |f|
    base = File.basename(f)
    ref  = group.new_reference("FoundationMobileTests/#{base}")
    test.add_file_references([ref])
  end
end
project.save

# Shared scheme so `xcodebuild test -scheme FoundationMobile` runs the bundle.
scheme_path = Xcodeproj::XCScheme.shared_data_dir(proj_path)
scheme = File.exist?(File.join(scheme_path, 'FoundationMobile.xcscheme')) ?
  Xcodeproj::XCScheme.new(File.join(scheme_path, 'FoundationMobile.xcscheme')) :
  Xcodeproj::XCScheme.new
test = project.targets.find { |t| t.name == 'FoundationMobileTests' }
scheme.add_build_target(app) if scheme.build_action.entries.empty?
unless scheme.test_action.testables.any? { |t| t.buildable_references.first&.target_name == 'FoundationMobileTests' }
  ref = Xcodeproj::XCScheme::TestAction::TestableReference.new(test)
  scheme.test_action.add_testable(ref)
end
scheme.save_as(proj_path, 'FoundationMobile', true)
puts 'FoundationMobileTests target + scheme test action ready.'
```

- [ ] **Step 2: Write a smoke test**

```swift
// ios/FoundationMobileTests/SmokeTests.swift
import XCTest
@testable import FoundationMobile

final class SmokeTests: XCTestCase {
    func testTrueIsTrue() { XCTAssertTrue(true) }
}
```

- [ ] **Step 3: Run the script**

Run: `cd ios && gem install xcodeproj --user-install >/dev/null 2>&1; ruby scripts/add-test-target.rb`
Expected: `FoundationMobileTests target + scheme test action ready.`

- [ ] **Step 4: Run the test bundle to verify it fails-then-passes wiring is live**

Run: `cd ios && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/SmokeTests 2>&1 | grep -E "Test Suite .* passed|failed|TEST EXECUTE SUCCEEDED|error:"`
Expected: `** TEST SUCCEEDED **` (SmokeTests passes).

- [ ] **Step 5: Commit**

```bash
git add ios/scripts/add-test-target.rb ios/FoundationMobileTests/SmokeTests.swift ios/FoundationMobile.xcodeproj
git commit -m "test: add FoundationMobileTests unit-test target + scheme

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Characterize `Profile.trustTier` + `documentNoun` with tests

Locks the already-shipped tier/noun behavior so later refactors can't regress it. Profiles are built by decoding JSON (mirrors production; `Profile` has no public memberwise init).

**Files:**
- Create: `ios/FoundationMobileTests/ProfileTierTests.swift`
- Modify: `ios/scripts/add-test-target.rb` is idempotent — rerun to register the new file (Step 4).

**Interfaces:**
- Consumes: `AppConfig.Profile` (Decodable), `Profile.trustTier`, `Profile.documentNoun`, `Profile.documentShort`.

- [ ] **Step 1: Write the failing tests**

```swift
// ios/FoundationMobileTests/ProfileTierTests.swift
import XCTest
@testable import FoundationMobile

final class ProfileTierTests: XCTestCase {
    private func profile(_ json: String) throws -> AppConfig.Profile {
        try JSONDecoder().decode(AppConfig.Profile.self, from: Data(json.utf8))
    }

    func testHighFromDg2() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],"faceMatchSource":"dg2","document":{"noun":"passport","short":"passport"}}"#)
        XCTAssertEqual(p.trustTier, .high)
        XCTAssertEqual(p.documentNoun, "passport")
    }

    func testStandardFromDocumentPhoto() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","liveness","antiSpoof","faceMatch"],"faceMatchSource":"documentPhoto"}"#)
        XCTAssertEqual(p.trustTier, .standard)
        XCTAssertEqual(p.documentNoun, "identity document")  // defaulted, no document block
        XCTAssertEqual(p.documentShort, "ID")
    }

    func testLowFromNone() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","liveness"],"faceMatchSource":"none"}"#)
        XCTAssertEqual(p.trustTier, .low)
    }
}
```

- [ ] **Step 2: Register + run, expect PASS (characterization of existing behavior)**

Run: `cd ios && ruby scripts/add-test-target.rb && xcodebuild test -project FoundationMobile.xcodeproj -scheme FoundationMobile -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FoundationMobileTests/ProfileTierTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`. (If any assert fails, the existing model regressed — fix the model, not the test.)

- [ ] **Step 3: Commit**

```bash
git add ios/FoundationMobileTests/ProfileTierTests.swift ios/FoundationMobile.xcodeproj
git commit -m "test(profile): characterize trustTier + documentNoun derivation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `VerificationStepPlan` + overview screen (Phase 1)

Extract the profile-derived step list into a tested type, then build the overview checklist screen (`poh-flow2` screen B) on top of it, and route into it before capture.

**Files:**
- Delete: `ios/FoundationMobile/VerificationOverviewView.swift` (uncommitted draft — recreate test-first)
- Create: `ios/FoundationMobile/VerificationStepPlan.swift`
- Create: `ios/FoundationMobile/VerificationOverviewView.swift`
- Create: `ios/FoundationMobileTests/VerificationStepPlanTests.swift`
- Modify: `ios/FoundationMobile/HomeView.swift` (Route enum, navigationDestination, the two `Route.capture` pushes in `beginVerifyHumanity`)
- Modify: `ios/FoundationMobile.xcodeproj/project.pbxproj` (register two new app sources — mirror the 4-line `CaptureView.swift` pattern; new IDs must be collision-checked with `grep -c <id> project.pbxproj`)

**Interfaces:**
- Produces:
  - `struct VerificationStep: Equatable { let title: String; let subtitle: String }`
  - `enum VerificationStepPlan { static func steps(for profile: AppConfig.Profile) -> [VerificationStep] }`
  - `struct VerificationOverviewView: View { var onStart: () -> Void }`
  - `HomeView.Route.overview`

- [ ] **Step 1: Write the failing test**

```swift
// ios/FoundationMobileTests/VerificationStepPlanTests.swift
import XCTest
@testable import FoundationMobile

final class VerificationStepPlanTests: XCTestCase {
    private func profile(_ json: String) throws -> AppConfig.Profile {
        try JSONDecoder().decode(AppConfig.Profile.self, from: Data(json.utf8))
    }

    func testHighSecurityHasScanChipFace() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],"faceMatchSource":"dg2","document":{"noun":"passport","short":"passport"}}"#)
        let titles = VerificationStepPlan.steps(for: p).map(\.title)
        XCTAssertEqual(titles, ["Scan your passport", "Read the chip", "Quick face check"])
    }

    func testStandardOmitsChip() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","liveness","antiSpoof","faceMatch"],"faceMatchSource":"documentPhoto","document":{"noun":"identity card","short":"ID"}}"#)
        let titles = VerificationStepPlan.steps(for: p).map(\.title)
        XCTAssertEqual(titles, ["Scan your identity card", "Quick face check"])
    }

    func testLowSecurityIsFaceOnly() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","liveness"],"faceMatchSource":"none"}"#)
        let titles = VerificationStepPlan.steps(for: p).map(\.title)
        XCTAssertEqual(titles, ["Quick face check"])
    }
}
```

- [ ] **Step 2: Run, expect FAIL** (`VerificationStepPlan` undefined)

Run: `cd ios && ruby scripts/add-test-target.rb && xcodebuild test ... -only-testing:FoundationMobileTests/VerificationStepPlanTests 2>&1 | grep -E "error:|cannot find"`
Expected: compile failure — `cannot find 'VerificationStepPlan' in scope`.

- [ ] **Step 3: Implement the model**

```swift
// ios/FoundationMobile/VerificationStepPlan.swift
import Foundation

struct VerificationStep: Equatable {
    let title: String
    let subtitle: String
}

// Profile-derived onboarding step list. A chipless edition never promises a
// chip read; a device-only edition is face-check only. Document noun injected.
enum VerificationStepPlan {
    static func steps(for profile: AppConfig.Profile) -> [VerificationStep] {
        var steps: [VerificationStep] = []
        if profile.requires(.nfcZk) || profile.faceMatchSource == .documentPhoto {
            steps.append(VerificationStep(title: "Scan your \(profile.documentNoun)",
                                          subtitle: "Photo page, laid flat"))
        }
        if profile.requires(.nfcZk) {
            steps.append(VerificationStep(title: "Read the chip",
                                          subtitle: "Hold the back of your phone"))
        }
        if profile.requires(.liveness) {
            steps.append(VerificationStep(title: "Quick face check",
                                          subtitle: "A short look at the camera"))
        }
        return steps
    }
}
```

- [ ] **Step 4: Register the source + run, expect PASS**

Add `VerificationStepPlan.swift` to the app target (pbxproj 4-line pattern, collision-checked IDs). Re-run `ruby scripts/add-test-target.rb`.
Run the test command from Step 2 (without the grep): Expected `** TEST SUCCEEDED **`.

- [ ] **Step 5: Build the view on the tested model**

```swift
// ios/FoundationMobile/VerificationOverviewView.swift
import SwiftUI

// PoH overview checklist (design: poh-flow2 screen B). Shown after auth,
// before capture. Steps come from VerificationStepPlan (tested). Theme-aware.
struct VerificationOverviewView: View {
    var onStart: () -> Void
    private var steps: [VerificationStep] {
        VerificationStepPlan.steps(for: AppConfig.shared.profile)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                pill
                VStack(alignment: .leading, spacing: 8) {
                    Text("Let's confirm you're human")
                        .font(.system(size: 25, weight: .bold)).foregroundStyle(Theme.text)
                    Text("A few quick steps. Everything happens on your phone.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    row(number: "\(idx + 1)", filled: false, title: step.title, sub: step.subtitle)
                }
                row(number: "✓", filled: true, title: "You're a verified human",
                    sub: "A proof — never your photos")
                Spacer(minLength: 0)
                Button(action: onStart) {
                    Text("Start").font(.headline).foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.brandGreen).cornerRadius(14)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 28).frame(maxWidth: 420)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
            Text("Proof of human · about a minute")
        }
        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.brandGreen)
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(Capsule().fill(Theme.brandGreen.opacity(0.13)))
    }

    private func row(number: String, filled: Bool, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(filled ? Theme.brandGreen : Theme.brandGreen.opacity(0.14))
                    .frame(width: 30, height: 30)
                Text(number).font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(filled ? Theme.onAccent : Theme.brandGreen)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
                Text(sub).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview { VerificationOverviewView(onStart: {}) }
#endif
```

- [ ] **Step 6: Wire the route in `HomeView.swift`**

In `enum Route`: add `case overview`. In the `.navigationDestination` switch add:
```swift
case .overview:
    VerificationOverviewView(onStart: { captureNavigationPath.append(Route.capture) })
case .capture:
    CaptureView()
```
In `beginVerifyHumanity()`, change **both** `captureNavigationPath.append(Route.capture)` lines (the `BiometricSealer` unavailable fallback and the post-FaceID success exit) to `captureNavigationPath.append(Route.overview)`.

- [ ] **Step 7: Register `VerificationOverviewView.swift`, build, verify route**

Add to pbxproj (4-line pattern). Run the Global-Constraints build command. Expected `** BUILD SUCCEEDED **`. Manual review gate: run app, tap Verify humanity → after Face ID, the overview appears; "Start" pushes into capture. With `tel-aviv` active, the chip step is absent.

- [ ] **Step 8: Commit**

```bash
git add ios/FoundationMobile/VerificationStepPlan.swift ios/FoundationMobile/VerificationOverviewView.swift \
        ios/FoundationMobileTests/VerificationStepPlanTests.swift ios/FoundationMobile/HomeView.swift \
        ios/FoundationMobile.xcodeproj
git commit -m "feat(poh): profile-derived overview checklist screen (Phase 1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Extract + test the trust-tier ladder; refactor `VerifiedView`

`VerifiedView` currently computes rung status inline. Extract to a tested type so the High/Standard/Low ladder logic is locked, then have the view consume it.

**Files:**
- Create: `ios/FoundationMobile/TrustTierLadder.swift`
- Create: `ios/FoundationMobileTests/TrustTierLadderTests.swift`
- Modify: `ios/FoundationMobile/VerifiedView.swift` (replace `rungStatus(_:)` / `rungRow` internals with ladder model)
- Modify: `ios/FoundationMobile.xcodeproj/project.pbxproj` (register `TrustTierLadder.swift`)

**Interfaces:**
- Consumes: `AppConfig.Profile.TrustTier`.
- Produces:
  - `enum RungStatus { case done, current, locked }`
  - `struct LadderRung: Equatable { let tier: AppConfig.Profile.TrustTier; let status: RungStatus }`
  - `enum TrustTierLadder { static func rungs(achieved: AppConfig.Profile.TrustTier) -> [LadderRung] }` — always ordered `[.high, .standard, .low]`.

- [ ] **Step 1: Write the failing test**

```swift
// ios/FoundationMobileTests/TrustTierLadderTests.swift
import XCTest
@testable import FoundationMobile

final class TrustTierLadderTests: XCTestCase {
    typealias Tier = AppConfig.Profile.TrustTier

    func testHighAchieved() {
        let r = TrustTierLadder.rungs(achieved: .high)
        XCTAssertEqual(r, [
            LadderRung(tier: .high,     status: .current),
            LadderRung(tier: .standard, status: .done),
            LadderRung(tier: .low,      status: .done),
        ])
    }

    func testStandardAchievedLocksHigh() {
        let r = TrustTierLadder.rungs(achieved: .standard)
        XCTAssertEqual(r, [
            LadderRung(tier: .high,     status: .locked),
            LadderRung(tier: .standard, status: .current),
            LadderRung(tier: .low,      status: .done),
        ])
    }

    func testLowAchievedLocksAbove() {
        let r = TrustTierLadder.rungs(achieved: .low)
        XCTAssertEqual(r, [
            LadderRung(tier: .high,     status: .locked),
            LadderRung(tier: .standard, status: .locked),
            LadderRung(tier: .low,      status: .current),
        ])
    }
}
```

- [ ] **Step 2: Run, expect FAIL** (`TrustTierLadder` undefined)

Run the test command for `-only-testing:FoundationMobileTests/TrustTierLadderTests`. Expected: `cannot find 'TrustTierLadder'`.

- [ ] **Step 3: Implement**

```swift
// ios/FoundationMobile/TrustTierLadder.swift
import Foundation

enum RungStatus { case done, current, locked }

struct LadderRung: Equatable {
    let tier: AppConfig.Profile.TrustTier
    let status: RungStatus
}

// Ladder rows for the verified screen, highest first. Rungs below the achieved
// tier are cleared (.done); the achieved tier is .current; higher tiers are
// .locked (and drive the upgrade hint).
enum TrustTierLadder {
    static func rungs(achieved: AppConfig.Profile.TrustTier) -> [LadderRung] {
        [AppConfig.Profile.TrustTier.high, .standard, .low].map { tier in
            let status: RungStatus = tier == achieved ? .current
                                   : (tier < achieved ? .done : .locked)
            return LadderRung(tier: tier, status: status)
        }
    }
}
```

- [ ] **Step 4: Register + run, expect PASS**

Add `TrustTierLadder.swift` to the app target (pbxproj), re-run `ruby scripts/add-test-target.rb`, run the test. Expected `** TEST SUCCEEDED **`.

- [ ] **Step 5: Refactor `VerifiedView` to consume the model**

Replace the private `rungStatus(_:)`/`RungStatus` in `VerifiedView` with the shared `TrustTierLadder.rungs(achieved: tier)`; map each `LadderRung.status` to the existing row styling (`.done`/`.current`/`.locked`). Keep all copy (`rungName`, `rungMeta`) and the noun usage identical — this is a pure internal refactor; the rendered output must not change.

- [ ] **Step 6: Build + visual regression gate**

Run the build command. Expected `** BUILD SUCCEEDED **`. Review gate: open `VerifiedView` previews (High/Standard/Low) and confirm pixel-identical to pre-refactor (compare against `docs/design/poh-onboarding/poh-verified-variants.png`).

- [ ] **Step 7: Commit**

```bash
git add ios/FoundationMobile/TrustTierLadder.swift ios/FoundationMobileTests/TrustTierLadderTests.swift \
        ios/FoundationMobile/VerifiedView.swift ios/FoundationMobile.xcodeproj
git commit -m "refactor(poh): extract + test TrustTierLadder; VerifiedView consumes it

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Per-step explainer screens (Phase 2)

The "explain-before-each-step" rhythm: a coaching screen + illustration before each capture stage. Route which explainer precedes which `CaptureCoordinator` state, tested.

**Files:**
- Create: `ios/FoundationMobile/ExplainerStep.swift` (model + copy)
- Create: `ios/FoundationMobile/StepExplainerView.swift` (the screen)
- Create: `ios/FoundationMobileTests/ExplainerStepTests.swift`
- Modify: `ios/FoundationMobile/CaptureView.swift` (present the matching explainer as a one-shot before `.readyForPose` / `.readyForPassport` / `.readyForDocumentPhoto`)
- Modify: `ios/FoundationMobile.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `AppConfig.Profile`, `CaptureCoordinator.State`, `Profile.documentNoun`.
- Produces:
  - `enum ExplainerKind: CaseIterable { case scan, chip, face }`
  - `struct ExplainerStep: Equatable { let kind: ExplainerKind; let title: String; let body: String; let cta: String }`
  - `enum ExplainerCatalog { static func step(_ kind: ExplainerKind, profile: AppConfig.Profile) -> ExplainerStep }`
  - `struct StepExplainerView: View { let step: ExplainerStep; var onReady: () -> Void }`

- [ ] **Step 1: Write the failing test**

```swift
// ios/FoundationMobileTests/ExplainerStepTests.swift
import XCTest
@testable import FoundationMobile

final class ExplainerStepTests: XCTestCase {
    private func profile(_ json: String) throws -> AppConfig.Profile {
        try JSONDecoder().decode(AppConfig.Profile.self, from: Data(json.utf8))
    }

    func testScanExplainerUsesDocumentNoun() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","liveness","antiSpoof","faceMatch"],"faceMatchSource":"documentPhoto","document":{"noun":"driving licence","short":"ID"}}"#)
        let step = ExplainerCatalog.step(.scan, profile: p)
        XCTAssertEqual(step.title, "Scan your driving licence")
        XCTAssertTrue(step.body.contains("driving licence"))
        XCTAssertEqual(step.cta, "I'm ready")
    }

    func testChipExplainerCopy() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],"faceMatchSource":"dg2","document":{"noun":"passport","short":"passport"}}"#)
        let step = ExplainerCatalog.step(.chip, profile: p)
        XCTAssertEqual(step.title, "Read the chip")
        XCTAssertTrue(step.body.contains("passport"))
    }
}
```

- [ ] **Step 2: Run, expect FAIL** (`ExplainerCatalog` undefined). Command mirrors Task 4 Step 2 with `ExplainerStepTests`.

- [ ] **Step 3: Implement the catalog**

```swift
// ios/FoundationMobile/ExplainerStep.swift
import Foundation

enum ExplainerKind: CaseIterable { case scan, chip, face }

struct ExplainerStep: Equatable {
    let kind: ExplainerKind
    let title: String
    let body: String
    let cta: String
}

enum ExplainerCatalog {
    static func step(_ kind: ExplainerKind, profile: AppConfig.Profile) -> ExplainerStep {
        let noun = profile.documentNoun
        switch kind {
        case .scan:
            return ExplainerStep(kind: .scan, title: "Scan your \(noun)",
                body: "Open your \(noun) to the photo page and lay it flat in good light. We'll line up the frame and capture it for you — no perfect aim needed.",
                cta: "I'm ready")
        case .chip:
            return ExplainerStep(kind: .chip, title: "Read the chip",
                body: "Hold the top back of your phone flat against your \(noun)'s photo page. Keep still until it buzzes — about 3–5 seconds.",
                cta: "I'm ready")
        case .face:
            return ExplainerStep(kind: .face, title: "Quick face check",
                body: "Center your face and follow the prompts. This confirms a live person — matched on-device, then discarded.",
                cta: "I'm ready")
        }
    }
}
```

- [ ] **Step 4: Register + run, expect PASS** (mirror Task 4 Step 4).

- [ ] **Step 5: Build the explainer view**

```swift
// ios/FoundationMobile/StepExplainerView.swift
import SwiftUI

// Explain-before-you-do screen (design: poh-flow2 C1/C2/C3). One per capture
// stage; the animation slot is a placeholder pending motion design.
struct StepExplainerView: View {
    let step: ExplainerStep
    var onReady: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.surface)
                    .frame(height: 220)
                    .overlay(Image(systemName: glyph).font(.system(size: 52)).foregroundStyle(Theme.brandGreen))
                Text(step.title).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.text)
                Text(step.body).font(.body).foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
                Button(action: onReady) {
                    Text(step.cta).font(.headline).foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.brandGreen).cornerRadius(14)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 28).frame(maxWidth: 420)
        }
    }

    private var glyph: String {
        switch step.kind {
        case .scan: return "doc.viewfinder"
        case .chip: return "wave.3.right.circle"
        case .face: return "face.smiling"
        }
    }
}

#if DEBUG
#Preview {
    StepExplainerView(step: ExplainerCatalog.step(.chip, profile: AppConfig.shared.profile), onReady: {})
}
#endif
```

- [ ] **Step 6: Gate explainers in `CaptureView`**

Add `@State private var shownExplainers: Set<ExplainerKind> = []` and a `.sheet`/overlay that, on entering `.readyForPose` (face), `.readyForPassport` (chip), `.readyForDocumentPhoto`/`.readyForPose`-with-doc (scan), presents `StepExplainerView` once per kind; `onReady` dismisses and lets the existing capture UI proceed. Do not alter the coordinator — this is a presentation gate only. (Map: scan precedes MRZ/doc capture, chip precedes NFC, face precedes the pose loop.)

- [ ] **Step 7: Register sources, build, manual review gate**

Add both new sources to pbxproj. Build (expect SUCCEEDED). Review: run `hisec-global` → scan/chip/face explainers each appear once before their step; run `tel-aviv` → no chip explainer.

- [ ] **Step 8: Commit**

```bash
git add ios/FoundationMobile/ExplainerStep.swift ios/FoundationMobile/StepExplainerView.swift \
        ios/FoundationMobileTests/ExplainerStepTests.swift ios/FoundationMobile/CaptureView.swift \
        ios/FoundationMobile.xcodeproj
git commit -m "feat(poh): per-step explainer screens before each capture stage (Phase 2)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Capture-state copy polish (Phase 3)

Apply the profile document noun + the mock's coaching tone to the existing live capture surfaces. No new logic — copy + small layout only.

**Files:**
- Modify: `ios/FoundationMobile/MRZScanView.swift` (scan coaching: "Lay your \(noun) flat", glare/edge hint)
- Modify: `ios/FoundationMobile/NFCScanView.swift` (chip-read progress copy: "Most chips read in 3–5 seconds")
- Modify: `ios/FoundationMobile/CaptureView.swift` (the verifying/sealing state → "Building your proof" framing, screen 4)

**Interfaces:**
- Consumes: `AppConfig.shared.profile.documentNoun`.

- [ ] **Step 1: Audit current copy**

Run: `cd ios && grep -rn "passport\|document\|chip" FoundationMobile/MRZScanView.swift FoundationMobile/NFCScanView.swift`
Note each user-facing string to update; replace hardcoded "passport" with `AppConfig.shared.profile.documentNoun` (possessive where needed).

- [ ] **Step 2: Apply the edits** (string-only; mirror `docs/design/poh-onboarding/poh-flow.png` screens 2–4). No code blocks here are prescriptive beyond: every user-facing "passport" → `documentNoun`; chip wait copy → "Most chips read in 3–5 seconds"; verifying state title → "Building your proof".

- [ ] **Step 3: Build + review gate**

Build (expect SUCCEEDED). Review: with `tel-aviv`, capture screens read "identity card", no "passport" anywhere on screen.

- [ ] **Step 4: Commit**

```bash
git add ios/FoundationMobile/MRZScanView.swift ios/FoundationMobile/NFCScanView.swift ios/FoundationMobile/CaptureView.swift
git commit -m "feat(poh): edition-agnostic capture copy + 'Building your proof' framing (Phase 3)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Docs + handoff; seed Plan 2

**Files:**
- Modify: `HANDOFF.md`
- Create: `docs/superpowers/plans/2026-06-20-poh-runtime-tier-fallback.md` (stub spec for Plan 2)

- [ ] **Step 1: Update `HANDOFF.md`** — record the new screens (overview, explainers, verified), the test target, the DEBUG gear preview, and that Plan 2 (runtime fallback / E2) is pending a design pass.

- [ ] **Step 2: Write the Plan 2 stub** — capture the open question (chip mandatory vs runtime downgrade), the affected components (`CaptureCoordinator` state machine, achieved-vs-baked tier, server proof acceptance), and the error screens E1–E4. Mark as "needs brainstorming before writing-plans".

- [ ] **Step 3: Commit**

```bash
git add HANDOFF.md docs/superpowers/plans/2026-06-20-poh-runtime-tier-fallback.md
git commit -m "docs(poh): handoff update + Plan 2 (runtime tier fallback) seed

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Overview checklist (poh-flow2 B) → Task 3 ✓
- Per-step explainers (poh-flow2 C1/C2/C3) → Task 5 ✓
- Capture polish + "Building your proof" (poh-flow 2–4) → Task 6 ✓
- Verified trust-tier screen (Variant B) → pre-existing, hardened in Task 4 ✓
- Profile-injected noun / tier vocabulary → Global Constraints + Tasks 2–6 ✓
- Error screens E1–E4 + runtime fallback (poh-errors, Decision #1) → **deferred to Plan 2** (Task 7 seeds it) ✓ (intentional scope split)
- Auth A1/A2 → "unchanged from today" (existing `SignInView`); no task needed ✓

**Placeholder scan:** Task 6 Step 2 is intentionally copy-only (string edits against a referenced mock) rather than prescribing every literal — acceptable because the change is mechanical noun substitution, not new logic. All logic tasks (1–5) carry full test + impl code.

**Type consistency:** `AppConfig.Profile.TrustTier` (`.high/.standard/.low`), `VerificationStep{title,subtitle}`, `RungStatus{done,current,locked}`, `LadderRung{tier,status}`, `ExplainerKind{scan,chip,face}`, `ExplainerStep{kind,title,body,cta}`, `HomeView.Route.{overview,capture}` — names consistent across producing/consuming tasks.
