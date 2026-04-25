import Foundation
import CryptoKit
import NFCPassportReader
import UIKit

// Phase 3a — thin wrapper over NFCPassportReader's `PassportReader` that:
// 1. Reads DG1 (MRZ) + SOD (Security Object) by default. With
//    `includeFacePhoto: true` it also reads DG2 (the JPEG2000 face image)
//    so Phase 6 (DG2 ↔ selfie face match) has the chip-side reference
//    image. DG3 (fingerprints), DG7 (signature image), DG11/12 (personal
//    details) are NEVER read.
// 2. Runs passive authentication's SOD→DG1 hash match so a tampered DG1
//    is rejected before we emit the proof artifact. When DG2 is included,
//    SOD→DG2 hash integrity is also enforced via the same passive auth.
// 3. Does NOT run the chain-to-CSCA check — upstream doesn't bundle a
//    production masterlist (readme admits the bundled PEM is a
//    self-signed stub). Chain verification is a follow-up; tracked as a
//    Phase 3a known gap.
// 4. Returns SHA-256(DG1 raw bytes) + issuing country + masked passport
//    suffix; with face-photo on, also SHA-256(DG2 raw bytes) + the
//    decoded UIImage. DG1/DG2 raw bytes are dropped from memory the
//    moment this function returns. The UIImage is held by the caller
//    only for the duration of the verify flow and then released.

struct PassportReadResult: @unchecked Sendable {
    let dg1Hash: Data               // SHA-256(DG1 raw bytes) — 32 bytes
    let issuingCountryCode: String  // ISO 3166-1 alpha-3 e.g. "ISR", "PRT"
    let passportNumberMasked: String // last 3 chars only, e.g. "•••321"

    // Phase 6 — populated only when readPassport(..., includeFacePhoto: true).
    // Both fields move together: either both nil (face photo not requested or
    // the chip didn't return DG2) or both non-nil. The image stays in memory
    // only — never written to disk, never sent over the network. Caller is
    // expected to drop it after the face-match decision is sealed.
    let dg2Hash: Data?              // SHA-256(DG2 raw bytes), 32 bytes
    let dg2FaceImage: UIImage?      // JPEG2000 from chip, decoded to UIImage
}

extension PassportReadResult: Equatable {
    // Custom Equatable: identity by hashes only. Two reads of the same
    // passport produce the same dg1Hash / dg2Hash even though the UIImage
    // instances differ; comparing UIImages by reference would make the
    // enclosing CaptureCoordinator.State equality flicker on every read.
    static func == (lhs: PassportReadResult, rhs: PassportReadResult) -> Bool {
        lhs.dg1Hash == rhs.dg1Hash
            && lhs.issuingCountryCode == rhs.issuingCountryCode
            && lhs.passportNumberMasked == rhs.passportNumberMasked
            && lhs.dg2Hash == rhs.dg2Hash
    }
}

enum PassportNFCReaderError: Error, LocalizedError {
    case dg1Missing
    case sodMissing
    case dg1HashMismatch   // SOD says DG1 should hash to X; we got Y
    case dg2Missing        // requested DG2 but chip didn't return it
    case dg2FaceImageMissing  // DG2 read but face image extraction failed
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .dg1Missing: return "Passport DG1 (MRZ) not returned by chip read."
        case .sodMissing: return "Passport SOD (security object) not returned by chip read."
        case .dg1HashMismatch:
            return "Passport DG1 hash does not match SOD — chip data integrity check failed."
        case .dg2Missing:
            return "Passport DG2 (face photo) requested but not returned by chip read."
        case .dg2FaceImageMissing:
            return "Passport DG2 was returned but no face image could be decoded."
        case .readFailed(let e):
            return "Passport NFC read failed: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class PassportNFCReader {
    static let shared = PassportNFCReader()

    private let reader: PassportReader

    // Bundle-lookup for a CSCA masterlist PEM. If the file
    // `csca-masterlist.pem` is present in the app bundle, chain-to-CSCA
    // verification activates and `passport.passportCorrectlySigned`
    // becomes meaningful. If absent (default today), the library simply
    // skips the chain check and we still enforce SOD→DG1 hash integrity.
    //
    // Drop-in sources:
    //   • BSI German masterlist — free, CMS SignedData at
    //     https://www.bsi.bund.de/dok/masterlist (cert bundle, includes most
    //     EU + many non-EU CSCAs). Extract to PEM via the openssl cms /
    //     pkcs7 -print_certs pipeline or the BSI extraction scripts.
    //   • ICAO PKD masterlist — gold standard, application-gated at
    //     https://pkddownloadsg.icao.int/
    //   • Per-country CSCA certs — published by each issuing authority
    //     (IL: MoFa, PT: AMA). Concatenate BEGIN/END CERTIFICATE blocks
    //     into one PEM file.
    //
    // To add one: drop the file at ios/FoundationMobile/Resources/csca-masterlist.pem
    // (register in pbxproj as a Copy Bundle Resource), rebuild — no code change.
    private static let masterListURL: URL? = Bundle.main.url(
        forResource: "csca-masterlist",
        withExtension: "pem"
    )

    private init() {
        self.reader = PassportReader(masterListURL: Self.masterListURL)
    }

    // One-shot NFC scan. Presents the system NFC modal; resolves when the
    // chip read completes, the hash-integrity check passes, and we've
    // extracted the minimum proof fields.
    //
    // `includeFacePhoto` is gated on the caller side by the active profile's
    // .faceMatch requirement + faceMatchSource=dg2. Adding DG2 to the read
    // roughly doubles the on-chip dwell time (~4-6s → ~10-12s) because DG2
    // is the largest data group on the chip.
    func readPassport(
        mrzKey: MRZKey,
        includeFacePhoto: Bool = false
    ) async throws -> PassportReadResult {
        let mrzKeyString = mrzKey.mrzKeyString
        let tags: [DataGroupId] = includeFacePhoto ? [.DG1, .DG2, .SOD] : [.DG1, .SOD]
        let passport: NFCPassportModel
        do {
            passport = try await reader.readPassport(
                mrzKey: mrzKeyString,
                tags: tags,
                skipSecureElements: true,   // drop DG3 (fingerprints), DG4 (iris)
                skipCA: true,                // Chip Authentication — Phase 3b
                skipPACE: false              // PACE first, BAC fallback (library handles both)
            )
        } catch {
            throw PassportNFCReaderError.readFailed(error)
        }

        // verifyPassport(masterListURL:) runs both validateAndExtractSigningCertificates
        // (chain-to-CSCA — only meaningful when masterListURL is non-nil) and
        // ensureReadDataNotBeenTamperedWith (SOD→DGn hash match across every
        // data group that was read, independent of the masterlist). We gate on
        // the hash-integrity check; the chain check is a soft signal — log-only
        // today since the bundled masterlist is optional. Flip this to a gate
        // once BSI / ICAO PKD is bundled.
        passport.verifyPassport(masterListURL: Self.masterListURL, useCMSVerification: false)
        guard passport.passportDataNotTampered else {
            throw PassportNFCReaderError.dg1HashMismatch
        }
        if Self.masterListURL != nil && !passport.passportCorrectlySigned {
            // Chain check ran but failed — surface so the user knows the
            // masterlist is present but doesn't cover this passport's CSCA.
            // Still accept the scan (DG1 integrity holds); demo-grade posture.
            print("[PassportNFCReader] chain-to-CSCA verification failed for \(passport.issuingAuthority); accepting DG1-integrity only.")
        }

        // Extract DG1 raw bytes for hashing. NFCPassportModel.getDataGroup
        // returns the DataGroup superclass which exposes `.data` — the
        // whole TLV wrapper (which is what SOD hashes over).
        guard let dg1 = passport.getDataGroup(.DG1) else {
            throw PassportNFCReaderError.dg1Missing
        }
        guard passport.getDataGroup(.SOD) != nil else {
            throw PassportNFCReaderError.sodMissing
        }

        let dg1Bytes = Data(dg1.data)
        let dg1Hash = Data(SHA256.hash(data: dg1Bytes))

        // Phase 6 — DG2 face photo when requested. Both the raw-bytes hash
        // (binds the artifact to the chip's exact DG2 contents) and the
        // decoded UIImage (input to the on-device face-embedding model)
        // are returned. The library decodes the JPEG2000 internally via
        // its DataGroup2 wrapper.
        var dg2Hash: Data?
        var dg2FaceImage: UIImage?
        if includeFacePhoto {
            guard let dg2 = passport.getDataGroup(.DG2) else {
                throw PassportNFCReaderError.dg2Missing
            }
            dg2Hash = Data(SHA256.hash(data: Data(dg2.data)))
            // DataGroup2.getImage() is internal to the library; reach through
            // the public `imageData: [UInt8]` (raw JPEG or JPEG2000 bytes per
            // ISO 19794-5). UIImage(data:) on iOS handles both formats via
            // ImageIO.
            if let dg2Concrete = dg2 as? DataGroup2, !dg2Concrete.imageData.isEmpty {
                dg2FaceImage = UIImage(data: Data(dg2Concrete.imageData))
            }
            guard dg2FaceImage != nil else {
                throw PassportNFCReaderError.dg2FaceImageMissing
            }
        }

        let issuing = passport.issuingAuthority  // e.g. "ISR"
        let fullNumber = passport.documentNumber   // e.g. "123456789"
        let masked: String
        if fullNumber.count >= 3 {
            let last3 = String(fullNumber.suffix(3))
            masked = "•••\(last3)"
        } else {
            masked = "•••"
        }

        return PassportReadResult(
            dg1Hash: dg1Hash,
            issuingCountryCode: issuing,
            passportNumberMasked: masked,
            dg2Hash: dg2Hash,
            dg2FaceImage: dg2FaceImage
        )
    }
}
