import Foundation
import CryptoKit
import NFCPassportReader

// Phase 3a — thin wrapper over NFCPassportReader's `PassportReader` that:
// 1. Reads ONLY DG1 (MRZ) + SOD (Security Object). No DG2 (face photo),
//    no DG7 (signature), no DG11/12 (personal details). This honors the
//    "nothing identifying leaves the device" hard invariant AND keeps the
//    on-device chip read fast (~4-6s vs ~12-15s with DG2).
// 2. Runs passive authentication's SOD→DG1 hash match so a tampered DG1
//    is rejected before we emit the proof artifact.
// 3. Does NOT run the chain-to-CSCA check — upstream doesn't bundle a
//    production masterlist (readme admits the bundled PEM is a
//    self-signed stub). Chain verification is a follow-up; tracked as a
//    Phase 3a known gap.
// 4. Returns only SHA-256(DG1 raw bytes) + issuing country code + masked
//    passport-number suffix. DG1 bytes are dropped from memory the moment
//    this function returns.

struct PassportReadResult: Equatable, Sendable {
    let dg1Hash: Data               // SHA-256(DG1 raw bytes) — 32 bytes
    let issuingCountryCode: String  // ISO 3166-1 alpha-3 e.g. "ISR", "PRT"
    let passportNumberMasked: String // last 3 chars only, e.g. "•••321"
}

enum PassportNFCReaderError: Error, LocalizedError {
    case dg1Missing
    case sodMissing
    case dg1HashMismatch   // SOD says DG1 should hash to X; we got Y
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .dg1Missing: return "Passport DG1 (MRZ) not returned by chip read."
        case .sodMissing: return "Passport SOD (security object) not returned by chip read."
        case .dg1HashMismatch:
            return "Passport DG1 hash does not match SOD — chip data integrity check failed."
        case .readFailed(let e):
            return "Passport NFC read failed: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class PassportNFCReader {
    static let shared = PassportNFCReader()

    private let reader: PassportReader

    private init() {
        // masterListURL left nil on purpose — see file header (#3). Without
        // a real CSCA PEM the library would throw on chain verification,
        // but without masterListURL it simply skips that check. The
        // SOD→DG1 hash integrity check STILL runs.
        self.reader = PassportReader(masterListURL: nil)
    }

    // One-shot NFC scan. Presents the system NFC modal; resolves when the
    // chip read completes, the hash-integrity check passes, and we've
    // extracted the minimum proof fields.
    func readPassport(mrzKey: MRZKey) async throws -> PassportReadResult {
        let mrzKeyString = mrzKey.mrzKeyString
        let passport: NFCPassportModel
        do {
            passport = try await reader.readPassport(
                mrzKey: mrzKeyString,
                tags: [.DG1, .SOD],
                skipSecureElements: true,   // drop DG3 (fingerprints), DG4 (iris)
                skipCA: true,                // Chip Authentication — Phase 3b
                skipPACE: false              // PACE first, BAC fallback (library handles both)
            )
        } catch {
            throw PassportNFCReaderError.readFailed(error)
        }

        // verifyPassport(masterListURL:) runs both validateAndExtractSigningCertificates
        // (which is a no-op when masterListURL is nil) and ensureReadDataNotBeenTamperedWith
        // (the SOD→DG1 hash match). We want the second one; the first we
        // accept as not-yet-wired.
        passport.verifyPassport(masterListURL: nil, useCMSVerification: false)
        guard passport.passportDataNotTampered else {
            throw PassportNFCReaderError.dg1HashMismatch
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
            passportNumberMasked: masked
        )
    }
}
