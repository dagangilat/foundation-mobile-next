import XCTest
import CryptoKit
@testable import FoundationMobile

final class WalletDocumentReaderTests: XCTestCase {

    // MARK: - Masking

    func testDocumentNumberMaskingKeepsLast3() {
        XCTAssertEqual(maskDocumentNumber("DL1234567"), "••••••567")
        XCTAssertEqual(maskDocumentNumber("ABC123"), "•••123")
        XCTAssertEqual(maskDocumentNumber("XYZ"), "XYZ")  // exactly 3 — no masking
    }

    func testDocumentNumberMaskingShortInput() {
        // ≤3 chars: no masking
        XCTAssertEqual(maskDocumentNumber(""), "")
        XCTAssertEqual(maskDocumentNumber("A"), "A")
        XCTAssertEqual(maskDocumentNumber("AB"), "AB")
        XCTAssertEqual(maskDocumentNumber("ABC"), "ABC")
    }

    // MARK: - SHA-256

    func testPortraitHashIs32Bytes() {
        let fakeBytes = Data(repeating: 0xAB, count: 64)
        let hash = SHA256.hash(data: fakeBytes)
        XCTAssertEqual(Data(hash).count, 32)
    }

    // MARK: - isSupported

    func testIsSupportedDoesNotCrash() {
        _ = WalletDocumentReader.isSupported
    }

    // MARK: - WalletDocumentReadResult Equatable

    @MainActor
    func testWalletDocumentReadResultEquatable() {
        let hash = Data(repeating: 0x01, count: 32)
        let r1 = WalletDocumentReadResult(
            portraitHash: hash,
            portraitImage: nil,
            documentNumberRaw: "DL1234567",
            documentNumberMasked: maskDocumentNumber("DL1234567"),
            issuingState: "AZ",
            walletDocumentType: .mobileDriversLicense
        )
        let r2 = WalletDocumentReadResult(
            portraitHash: hash,
            portraitImage: nil,
            documentNumberRaw: "DL1234567",
            documentNumberMasked: maskDocumentNumber("DL1234567"),
            issuingState: "AZ",
            walletDocumentType: .mobileDriversLicense
        )
        XCTAssertEqual(r1, r2)

        let r3 = WalletDocumentReadResult(
            portraitHash: Data(repeating: 0x02, count: 32),
            portraitImage: nil,
            documentNumberRaw: "DL9999999",
            documentNumberMasked: maskDocumentNumber("DL9999999"),
            issuingState: "CA",
            walletDocumentType: .nationalIdCard
        )
        XCTAssertNotEqual(r1, r3)
    }
}
