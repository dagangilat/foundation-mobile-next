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

    // MARK: - Tests

    func testProducerKindIsNfcZk() {
        let producer = WalletDocumentProducer(walletData: makeResult())
        XCTAssertEqual(producer.kind, .nfcZk)
    }

    /// produce() must be reachable and route through ProofArtifactBuilder.
    /// In the test environment there is no attested key, so the builder throws
    /// noAttestedKey — confirming produce() was called (not a local reimplementation).
    func testProduceThrowsNoAttestedKeyInTestEnvironment() async {
        let producer = WalletDocumentProducer(walletData: makeResult())
        do {
            _ = try await producer.produce()
            XCTFail("Expected produce() to throw ProofArtifactBuilderError.noAttestedKey")
        } catch ProofArtifactBuilderError.noAttestedKey {
            // Expected: confirms produce() was called and reached ProofArtifactBuilder
        } catch {
            XCTFail("Unexpected error from produce(): \(error)")
        }
    }

    func testPayloadIsDeterministic() async throws {
        let result = makeResult()
        let p1 = WalletDocumentProducer(walletData: result).payloadBytes()
        let p2 = WalletDocumentProducer(walletData: result).payloadBytes()
        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.count, 32)
    }

    func testPayloadDiffersOnDifferentDocumentNumber() async throws {
        let r1 = makeResult(docNumber: "DL1234567")
        let r2 = makeResult(docNumber: "DL9999999")
        let p1 = WalletDocumentProducer(walletData: r1).payloadBytes()
        let p2 = WalletDocumentProducer(walletData: r2).payloadBytes()
        XCTAssertNotEqual(p1, p2)
    }

    func testPayloadDiffersOnDifferentIssuingState() async throws {
        let r1 = makeResult(state: "AZ")
        let r2 = makeResult(state: "CA")
        let p1 = WalletDocumentProducer(walletData: r1).payloadBytes()
        let p2 = WalletDocumentProducer(walletData: r2).payloadBytes()
        XCTAssertNotEqual(p1, p2)
    }

    func testNilIssuingStateEqualsEmptyString() async throws {
        let r1 = makeResult(state: nil)
        let r2 = makeResult(state: "")
        let p1 = WalletDocumentProducer(walletData: r1).payloadBytes()
        let p2 = WalletDocumentProducer(walletData: r2).payloadBytes()
        XCTAssertEqual(p1, p2)
    }
}
