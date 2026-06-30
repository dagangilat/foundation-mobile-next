import XCTest
@testable import FoundationMobile

final class MRZParserTests: XCTestCase {
    // ICAO 9303 Part 5 worked example.
    private let td1Lines = [
        "I<UTOD231458907<<<<<<<<<<<<<<<",
        "7408122F1204159UTO<<<<<<<<<<<6",
        "ERIKSSON<<ANNA<MARIA<<<<<<<<<<",
    ]

    func testParseTD1ExtractsDocumentNumberDobExpiry() {
        let key = MRZParser.parseTD1(lines: td1Lines)
        XCTAssertEqual(key, MRZKey(
            passportNumber: "D23145890",
            dateOfBirth: "740812",
            dateOfExpiry: "120415"
        ))
    }

    func testParseTD1ToleratesLineOrderShuffle() {
        let shuffled = [td1Lines[2], td1Lines[0], td1Lines[1]]
        XCTAssertEqual(MRZParser.parseTD1(lines: shuffled), MRZParser.parseTD1(lines: td1Lines))
    }

    func testParseTD1ReturnsNilOnGarbageInput() {
        XCTAssertNil(MRZParser.parseTD1(lines: ["not an mrz", "still not"]))
    }

    func testParseTD1ReturnsNilWhenCheckDigitWrong() {
        var corrupted = td1Lines
        corrupted[0] = "I<UTOD231458901<<<<<<<<<<<<<<<"   // check digit 7 -> 1
        XCTAssertNil(MRZParser.parseTD1(lines: corrupted))
    }
}
