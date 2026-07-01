import XCTest
@testable import FoundationMobile

// Characterization tests: lock the shipped tier + document-noun derivation so
// later refactors can't regress it. Profiles are built by decoding JSON, the
// way production loads them (Profile has no public memberwise init).
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

    func testMdlFaceMatchSourceIsTierHigh() throws {
        let p = try profile(#"{"id":"x","label":"X","description":"d","requiredPhases":["appAttest","nfcZk","liveness","antiSpoof","faceMatch"],"faceMatchSource":"mdl","document":{"noun":"driving licence or Wallet ID","short":"Wallet ID"}}"#)
        XCTAssertEqual(p.trustTier, .high)
        XCTAssertEqual(p.documentNoun, "driving licence or Wallet ID")
        XCTAssertEqual(p.documentShort, "Wallet ID")
    }
}
