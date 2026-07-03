import XCTest
@testable import FoundationMobile

final class VerificationStepPlanTests: XCTestCase {
    private func profile(_ json: String) throws -> AppConfig.Profile {
        try JSONDecoder().decode(AppConfig.Profile.self, from: Data(json.utf8))
    }

    // Target order (matches the runtime capture sequence the user experiences):
    // face → document scan → chip → anti-spoof → biometric seal.
    func testHighSecurityOrderFaceScanChipAntiSpoofSeal() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],"faceMatchSource":"dg2","document":{"noun":"passport","short":"passport"}}"#)
        let titles = VerificationStepPlan.steps(for: p).map(\.title)
        XCTAssertEqual(titles, [
            "Quick face check",
            "Scan your passport",
            "Read the chip",
            "Anti-spoof check",
            "Apple Biometric Seal",
        ])
    }

    // Standard: no chip (no nfcZk), document scan via photo page.
    func testStandardOmitsChip() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","liveness","antiSpoof","faceMatch"],"faceMatchSource":"documentPhoto","document":{"noun":"identity card","short":"ID"}}"#)
        let titles = VerificationStepPlan.steps(for: p).map(\.title)
        XCTAssertEqual(titles, [
            "Quick face check",
            "Scan your identity card",
            "Anti-spoof check",
            "Apple Biometric Seal",
        ])
    }

    // Low security: face check only, then the closing seal. No document/chip/anti-spoof.
    func testLowSecurityIsFaceThenSeal() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","liveness"],"faceMatchSource":"none"}"#)
        let titles = VerificationStepPlan.steps(for: p).map(\.title)
        XCTAssertEqual(titles, [
            "Quick face check",
            "Apple Biometric Seal",
        ])
    }

    // The final biometric seal closes every edition.
    func testSealIsAlwaysLast() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],"faceMatchSource":"dg2","document":{"noun":"passport","short":"passport"}}"#)
        let steps = VerificationStepPlan.steps(for: p)
        XCTAssertEqual(steps.last?.title, "Apple Biometric Seal")
    }

    // Wallet/mDL: the real flow is a single Apple ProximityReader "Read from
    // Wallet" tap, not the MRZ photo-page scan + separate NFC chip read that
    // dg2/documentPhoto profiles show. The checklist must not promise a chip
    // tap that never happens for this profile.
    func testMdlProfileGetsWalletCopyNotChipInstructions() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],"faceMatchSource":"mdl","document":{"noun":"driving licence or Wallet ID","short":"Wallet ID"}}"#)
        let steps = VerificationStepPlan.steps(for: p)

        XCTAssertTrue(steps.contains { $0.title.contains("Wallet") })
        XCTAssertFalse(steps.contains { $0.title == "Read the chip" })
    }
}
