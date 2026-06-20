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
