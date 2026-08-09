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

    // MARK: - Real bundled profiles decode cleanly against the full AppConfig schema

    /// AppConfig.load() decodes the ENTIRE AppConfig struct and fatalErrors on
    /// failure. This decodes every checked-in profile JSON the same way, so a
    /// schema change or a hand-edit typo in any of the 8 profiles fails a fast
    /// unit test instead of a runtime crash reachable only by building with
    /// that specific profile selected.
    func testAllBundledProfilesDecodeAgainstFullAppConfigSchema() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let profilesDir = thisFile
            .deletingLastPathComponent()  // FoundationMobileTests/
            .deletingLastPathComponent()  // ios/
            .appendingPathComponent("FoundationMobile/Resources/profiles")

        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertEqual(
            files.count, 8,
            "expected 8 profile JSONs in Resources/profiles — update this count if a profile was added/removed"
        )

        for file in files {
            let data = try Data(contentsOf: file)
            XCTAssertNoThrow(
                try JSONDecoder().decode(AppConfig.self, from: data),
                "\(file.lastPathComponent) failed to decode as AppConfig"
            )
        }
    }

    // MARK: - theme.palette strings resolve to their intended v2 Theme names

    /// Reads each web-matched profile JSON straight off disk (same pattern as
    /// the schema test above) and asserts its theme.palette string is the
    /// v2-renamed value, not a leftover pre-redesign name.
    func testWebMatchedEditionsUseTheirV2PaletteNames() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let profilesDir = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FoundationMobile/Resources/profiles")

        let expected: [String: String] = [
            "foundation.json": "foundation",
            "moma.json": "moma",
            "tel-aviv.json": "ocean",
            "san-francisco.json": "sunset",
        ]
        for (file, expectedPaletteName) in expected {
            let data = try Data(contentsOf: profilesDir.appendingPathComponent(file))
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            XCTAssertEqual(config.themePaletteName, expectedPaletteName, "\(file) theme.palette")
        }
    }
}
