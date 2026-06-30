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
