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
        // Wallet entries (dg2Accessible: false) are excluded; count matches dg2-accessible subset.
        let dg2Entries = DocumentProfile.all.filter(\.dg2Accessible)
        XCTAssertEqual(available.count, dg2Entries.count)
        XCTAssertTrue(available.allSatisfy(\.dg2Accessible))
    }

    func testStandardsecOffersAllNfcDocuments() {
        let available = DocumentProfile.available(for: buildProfile(faceMatchSource: .documentPhoto))
        // Wallet entries are excluded when WalletDocumentReader.isSupported == false (simulator/iOS <17).
        let nfcEntries = DocumentProfile.all.filter { $0.readingMethod == .nfcChip }
        XCTAssertEqual(Set(available.map(\.id)), Set(nfcEntries.map(\.id)))
    }

    func testLowsecAttestOffersAllNfcDocuments() {
        let available = DocumentProfile.available(for: buildProfile(faceMatchSource: .none))
        let nfcEntries = DocumentProfile.all.filter { $0.readingMethod == .nfcChip }
        XCTAssertEqual(Set(available.map(\.id)), Set(nfcEntries.map(\.id)))
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
}
