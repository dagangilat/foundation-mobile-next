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
