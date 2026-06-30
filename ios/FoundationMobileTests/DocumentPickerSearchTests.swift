import XCTest
@testable import FoundationMobile

final class DocumentPickerSearchTests: XCTestCase {
    func testEmptyQueryReturnsAllProfiles() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "")
        XCTAssertEqual(result.count, DocumentProfile.all.count)
    }

    func testQueryFiltersByDisplayNameCaseInsensitive() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "teudat")
        XCTAssertEqual(result.map(\.id), ["isr-id"])
    }

    func testWhitespaceOnlyQueryReturnsAllProfiles() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "   ")
        XCTAssertEqual(result.count, DocumentProfile.all.count)
    }

    func testNoMatchReturnsEmpty() {
        let result = DocumentPickerSearch.filter(DocumentProfile.all, query: "zzzznomatch")
        XCTAssertTrue(result.isEmpty)
    }
}
