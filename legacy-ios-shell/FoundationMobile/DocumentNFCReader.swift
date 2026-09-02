import Foundation
import CryptoKit
import NFCPassportReader
import UIKit

// Sub-project 1 (2026-06-30) — generalized from the original passport-only
// PassportNFCReader to any DocumentProfile-described ICAO-aligned chip
// (passports + national ID cards). Read logic (PACE/BAC, DG1/DG2
// extraction, SOD hash-integrity check) is unchanged; only the resulting
// documentType differs per profile. Reads through the ChipReading protocol
// (see ChipReading.swift) so the pipeline is testable without physical
// NFC hardware. See docs/superpowers/specs/2026-06-30-nfc-document-registry-design.md.

struct DocumentReadResult: @unchecked Sendable {
    let dg1Hash: Data               // SHA-256(DG1 raw bytes) — 32 bytes
    let issuingCountryCode: String  // ISO 3166-1 alpha-3 e.g. "ISR", "PRT"
    let documentNumberMasked: String // last 3 chars only, e.g. "•••321"
    let documentType: DocumentProfile.DocumentType

    // Populated only when readDocument(..., includeFacePhoto: true). Both
    // fields move together: either both nil (face photo not requested or
    // the chip didn't return DG2) or both non-nil. The image stays in
    // memory only — never written to disk, never sent over the network.
    let dg2Hash: Data?              // SHA-256(DG2 raw bytes), 32 bytes
    let dg2FaceImage: UIImage?      // decoded chip face photo
}

extension DocumentReadResult: Equatable {
    // Custom Equatable: identity by hashes only. Two reads of the same
    // document produce the same dg1Hash/dg2Hash even though the UIImage
    // instances differ; comparing UIImages by reference would make the
    // enclosing CaptureCoordinator.State equality flicker on every read.
    static func == (lhs: DocumentReadResult, rhs: DocumentReadResult) -> Bool {
        lhs.dg1Hash == rhs.dg1Hash
            && lhs.issuingCountryCode == rhs.issuingCountryCode
            && lhs.documentNumberMasked == rhs.documentNumberMasked
            && lhs.documentType == rhs.documentType
            && lhs.dg2Hash == rhs.dg2Hash
    }
}

enum DocumentNFCReaderError: Error, LocalizedError {
    case dg1Missing
    case dg1HashMismatch
    case dg2Missing
    case dg2FaceImageMissing
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .dg1Missing: return "Document DG1 (MRZ) not returned by chip read."
        case .dg1HashMismatch:
            return "Document DG1 hash does not match SOD — chip data integrity check failed."
        case .dg2Missing:
            return "Document DG2 (face photo) requested but not returned by chip read."
        case .dg2FaceImageMissing:
            return "Document DG2 was returned but no face image could be decoded."
        case .readFailed(let e):
            return "Document NFC read failed: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class DocumentNFCReader {
    private static let masterListURL: URL? = Bundle.main.url(
        forResource: "csca-masterlist",
        withExtension: "pem"
    )

    static let shared = DocumentNFCReader(chipReader: LiveChipReader(masterListURL: DocumentNFCReader.masterListURL))

    private let chipReader: ChipReading

    // Test seam: production always goes through `.shared` (wired to
    // LiveChipReader); tests construct their own instance with a fake.
    init(chipReader: ChipReading) {
        self.chipReader = chipReader
    }

    // One-shot NFC scan. Presents the system NFC modal; resolves when the
    // chip read completes, the hash-integrity check passes, and we've
    // extracted the minimum proof fields.
    //
    // `includeFacePhoto` is gated on the caller side by the active
    // profile's .faceMatch requirement + faceMatchSource == .dg2, AND
    // documentProfile.dg2Accessible. Adding DG2 to the read roughly
    // doubles on-chip dwell time (~4-6s -> ~10-12s).
    func readDocument(
        mrzKey: MRZKey,
        profile: DocumentProfile,
        includeFacePhoto: Bool = false
    ) async throws -> DocumentReadResult {
        let mrzKeyString = mrzKey.mrzKeyString
        let tags: [DataGroupId] = includeFacePhoto ? [.DG1, .DG2, .SOD] : [.DG1, .SOD]
        let outcome: ChipReadOutcome
        do {
            outcome = try await chipReader.read(
                mrzKeyString: mrzKeyString,
                tags: tags,
                skipSecureElements: true,   // drop DG3 (fingerprints), DG4 (iris)
                skipCA: true,                // Chip Authentication — future work
                skipPACE: false              // PACE first, BAC fallback (library handles both)
            )
        } catch {
            throw DocumentNFCReaderError.readFailed(error)
        }

        guard outcome.dataNotTampered else {
            throw DocumentNFCReaderError.dg1HashMismatch
        }
        guard let dg1Bytes = outcome.dg1Bytes else {
            throw DocumentNFCReaderError.dg1Missing
        }
        let dg1Hash = Data(SHA256.hash(data: dg1Bytes))

        var dg2Hash: Data?
        var dg2FaceImage: UIImage?
        if includeFacePhoto {
            guard let dg2RawBytes = outcome.dg2RawBytes else {
                throw DocumentNFCReaderError.dg2Missing
            }
            dg2Hash = Data(SHA256.hash(data: dg2RawBytes))
            guard let dg2ImageBytes = outcome.dg2ImageBytes,
                  let decoded = UIImage(data: dg2ImageBytes) else {
                throw DocumentNFCReaderError.dg2FaceImageMissing
            }
            dg2FaceImage = decoded
        }

        let fullNumber = outcome.documentNumber
        let masked: String
        if fullNumber.count >= 3 {
            let last3 = String(fullNumber.suffix(3))
            masked = "•••\(last3)"
        } else {
            masked = "•••"
        }

        return DocumentReadResult(
            dg1Hash: dg1Hash,
            issuingCountryCode: outcome.issuingAuthority,
            documentNumberMasked: masked,
            documentType: profile.documentType,
            dg2Hash: dg2Hash,
            dg2FaceImage: dg2FaceImage
        )
    }
}
