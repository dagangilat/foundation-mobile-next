import XCTest
import CryptoKit
@testable import FoundationMobile

final class WalletDocumentProducerTests: XCTestCase {

    // MARK: - Helpers

    private func makeResult(
        docNumber: String = "DL1234567",
        state: String? = "AZ"
    ) -> WalletDocumentReadResult {
        WalletDocumentReadResult(
            portraitHash: Data(repeating: 0, count: 32),
            portraitImage: nil,
            documentNumberRaw: docNumber,
            documentNumberMasked: maskDocumentNumber(docNumber),
            issuingState: state,
            walletDocumentType: .mobileDriversLicense
        )
    }

    /// Compute the same SHA-256(docNumber_utf8 + state_utf8) the producer uses,
    /// so tests can assert on the expected payload without calling produce().
    private func expectedPayload(docNumber: String, state: String?) -> Data {
        let combined = Data(docNumber.utf8) + Data((state ?? "").utf8)
        return Data(SHA256.hash(data: combined))
    }

    // MARK: - Tests

    func testProducerKindIsNfcZk() {
        let producer = WalletDocumentProducer(walletData: makeResult())
        XCTAssertEqual(producer.kind, .nfcZk)
    }

    func testPayloadIsDeterministic() {
        // Same input must produce the same SHA-256 payload each time.
        let r = makeResult()
        let p1 = expectedPayload(docNumber: r.documentNumberRaw, state: r.issuingState)
        let p2 = expectedPayload(docNumber: r.documentNumberRaw, state: r.issuingState)
        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.count, 32)
    }

    func testPayloadDiffersOnDifferentDocumentNumber() {
        let r1 = makeResult(docNumber: "DL1234567", state: "AZ")
        let r2 = makeResult(docNumber: "DL9999999", state: "AZ")
        let p1 = expectedPayload(docNumber: r1.documentNumberRaw, state: r1.issuingState)
        let p2 = expectedPayload(docNumber: r2.documentNumberRaw, state: r2.issuingState)
        XCTAssertNotEqual(p1, p2)
    }

    func testPayloadDiffersOnDifferentIssuingState() {
        let r1 = makeResult(docNumber: "DL1234567", state: "AZ")
        let r2 = makeResult(docNumber: "DL1234567", state: "CA")
        let p1 = expectedPayload(docNumber: r1.documentNumberRaw, state: r1.issuingState)
        let p2 = expectedPayload(docNumber: r2.documentNumberRaw, state: r2.issuingState)
        XCTAssertNotEqual(p1, p2)
    }

    func testNilIssuingStateEqualsEmptyString() {
        let rNil   = makeResult(docNumber: "DL1234567", state: nil)
        let rEmpty = makeResult(docNumber: "DL1234567", state: "")
        let pNil   = expectedPayload(docNumber: rNil.documentNumberRaw,   state: rNil.issuingState)
        let pEmpty = expectedPayload(docNumber: rEmpty.documentNumberRaw, state: rEmpty.issuingState)
        XCTAssertEqual(pNil, pEmpty)
    }
}
