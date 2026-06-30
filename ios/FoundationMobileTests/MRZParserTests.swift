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

    // USA passports go through the same generic, country-agnostic TD3 format
    // as every other ICAO passport — no USA-specific parsing code exists or
    // is needed. This fixture exists to make that explicit rather than
    // leaving it implicit: passport number 123456789, DOB 1990-01-01,
    // expiry 2030-01-01, check digits computed per ICAO 9303 Part 3 §4.9.
    private let usPassportTD3Lines = [
        "P<USASMITH<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<",
        "1234567897USA9001011M3001019<<<<<<<<<<<<<<<<",
    ]

    func testParseTD3ExtractsUSPassportFields() {
        let key = MRZParser.parseTD3(lines: usPassportTD3Lines)
        XCTAssertEqual(key, MRZKey(
            passportNumber: "123456789",
            dateOfBirth: "900101",
            dateOfExpiry: "300101"
        ))
    }
}
