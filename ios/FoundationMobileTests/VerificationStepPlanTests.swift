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
}
