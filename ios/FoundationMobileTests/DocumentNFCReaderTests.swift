import XCTest
import CryptoKit
import NFCPassportReader
@testable import FoundationMobile

final class DocumentNFCReaderTests: XCTestCase {
    private struct FakeChipReader: ChipReading {
        let outcome: Result<ChipReadOutcome, Error>
        func read(
            mrzKeyString: String, tags: [DataGroupId],
            skipSecureElements: Bool, skipCA: Bool, skipPACE: Bool
        ) async throws -> ChipReadOutcome {
            try outcome.get()
        }
    }

    private let dg1Bytes = Data("synthetic-dg1".utf8)
    private let dg2RawBytes = Data("synthetic-dg2-raw".utf8)
    // Minimal valid 1x1 PNG so UIImage(data:) succeeds.
    private let dg2ImageBytes = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    private func key() -> MRZKey {
        MRZKey(passportNumber: "X123456", dateOfBirth: "900101", dateOfExpiry: "300101")
    }

    @MainActor
    func testReadDocumentSucceedsAndHashesDg1() async throws {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: nil, dg2ImageBytes: nil,
            dataNotTampered: true, issuingAuthority: "ISR", documentNumber: "X123456"
        )))
        let reader = DocumentNFCReader(chipReader: fake)
        let result = try await reader.readDocument(mrzKey: key(), profile: .passport)

        XCTAssertEqual(result.dg1Hash, Data(SHA256.hash(data: dg1Bytes)))
        XCTAssertEqual(result.issuingCountryCode, "ISR")
        XCTAssertEqual(result.documentNumberMasked, "•••456")
        XCTAssertEqual(result.documentType, .passport)
        XCTAssertNil(result.dg2Hash)
        XCTAssertNil(result.dg2FaceImage)
    }

    @MainActor
    func testReadDocumentWithFacePhotoHashesRawDg2AndDecodesImage() async throws {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: dg2RawBytes, dg2ImageBytes: dg2ImageBytes,
            dataNotTampered: true, issuingAuthority: "DEU", documentNumber: "Y987654"
        )))
        let profile = DocumentProfile.all.first { $0.id == "deu-id" }!
        let reader = DocumentNFCReader(chipReader: fake)
        let result = try await reader.readDocument(
            mrzKey: key(), profile: profile, includeFacePhoto: true
        )

        XCTAssertEqual(result.dg2Hash, Data(SHA256.hash(data: dg2RawBytes)))
        XCTAssertNotNil(result.dg2FaceImage)
        XCTAssertEqual(result.documentType, .nationalId)
    }

    @MainActor
    func testTamperedDataThrowsHashMismatch() async {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: nil, dg2ImageBytes: nil,
            dataNotTampered: false, issuingAuthority: "ISR", documentNumber: "X123456"
        )))
        let reader = DocumentNFCReader(chipReader: fake)
        do {
            _ = try await reader.readDocument(mrzKey: key(), profile: .passport)
            XCTFail("expected dg1HashMismatch")
        } catch DocumentNFCReaderError.dg1HashMismatch {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    @MainActor
    func testMissingDg2RawBytesThrowsWhenFacePhotoRequested() async {
        let fake = FakeChipReader(outcome: .success(ChipReadOutcome(
            dg1Bytes: dg1Bytes, dg2RawBytes: nil, dg2ImageBytes: nil,
            dataNotTampered: true, issuingAuthority: "ISR", documentNumber: "X123456"
        )))
        let reader = DocumentNFCReader(chipReader: fake)
        do {
            _ = try await reader.readDocument(mrzKey: key(), profile: .passport, includeFacePhoto: true)
            XCTFail("expected dg2Missing")
        } catch DocumentNFCReaderError.dg2Missing {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
