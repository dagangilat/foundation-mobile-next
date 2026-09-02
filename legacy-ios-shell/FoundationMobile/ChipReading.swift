import Foundation
import NFCPassportReader

// Sits between DocumentNFCReader and the NFCPassportReader library so
// tests can substitute a fake without fabricating a real ASN.1 SOD/DSC/
// CSCA chain. NFCPassportModel's own hash-integrity check
// (verifyPassport) only ever runs in LiveChipReader (production); test
// fixtures construct ChipReadOutcome directly instead of trying to
// reproduce real X.509/CMS signing.
//
// dg1Bytes / dg2RawBytes are the full TLV-wrapped data group bytes (what
// the chip's SOD hashes over — these become dg1Hash/dg2Hash downstream).
// dg2ImageBytes is the separately-decoded JPEG/JPEG2000 image payload
// from inside DG2 (what becomes the UIImage). The two DG2 byte sources
// are different slices of the same data group and must stay separate:
// the hash binds to the SOD-verifiable raw bytes, not the decoded image.
struct ChipReadOutcome {
    let dg1Bytes: Data?
    let dg2RawBytes: Data?
    let dg2ImageBytes: Data?
    let dataNotTampered: Bool       // mirrors NFCPassportModel.passportDataNotTampered
    let issuingAuthority: String
    let documentNumber: String
}

protocol ChipReading {
    func read(
        mrzKeyString: String,
        tags: [DataGroupId],
        skipSecureElements: Bool,
        skipCA: Bool,
        skipPACE: Bool
    ) async throws -> ChipReadOutcome
}

// Production implementation — wraps the real NFCPassportReader.PassportReader,
// runs verifyPassport() exactly as the original passport-only
// PassportNFCReader did, and maps NFCPassportModel down to ChipReadOutcome.
//
// Bundle-lookup for a CSCA masterlist PEM. If `csca-masterlist.pem` is
// present in the app bundle, chain-to-CSCA verification activates and
// `passportCorrectlySigned` becomes meaningful; if absent (default today),
// the library skips the chain check and we still enforce SOD->DG1/DG2 hash
// integrity. Drop-in sources: BSI German masterlist
// (bsi.bund.de/dok/masterlist), ICAO PKD (pkddownloadsg.icao.int), or
// per-country CSCA certs concatenated into one PEM. To add one: drop the
// file at ios/FoundationMobile/Resources/csca-masterlist.pem (register as
// a Copy Bundle Resource), rebuild — no code change.
struct LiveChipReader: ChipReading {
    private let reader: PassportReader
    private let masterListURL: URL?

    init(masterListURL: URL?) {
        self.reader = PassportReader(masterListURL: masterListURL)
        self.masterListURL = masterListURL
    }

    func read(
        mrzKeyString: String,
        tags: [DataGroupId],
        skipSecureElements: Bool,
        skipCA: Bool,
        skipPACE: Bool
    ) async throws -> ChipReadOutcome {
        let passport = try await reader.readPassport(
            mrzKey: mrzKeyString,
            tags: tags,
            skipSecureElements: skipSecureElements,
            skipCA: skipCA,
            skipPACE: skipPACE
        )
        passport.verifyPassport(masterListURL: masterListURL, useCMSVerification: false)

        if masterListURL != nil && !passport.passportCorrectlySigned {
            // Chain check ran but failed — soft signal only, the bundled
            // masterlist may simply not cover this document's CSCA. SOD->DGn
            // hash integrity (passportDataNotTampered) is the hard gate.
            // 2026-04-26 security review M-H-6: don't log issuingAuthority
            // in release builds.
            #if DEBUG
            print("[LiveChipReader] chain-to-CSCA verification failed for \(passport.issuingAuthority); accepting hash-integrity only.")
            #endif
        }

        let dg1Bytes = passport.getDataGroup(.DG1).map { Data($0.data) }
        var dg2RawBytes: Data?
        var dg2ImageBytes: Data?
        if let dg2 = passport.getDataGroup(.DG2) {
            dg2RawBytes = Data(dg2.data)
            if let dg2Concrete = dg2 as? DataGroup2, !dg2Concrete.imageData.isEmpty {
                dg2ImageBytes = Data(dg2Concrete.imageData)
            }
        }

        return ChipReadOutcome(
            dg1Bytes: dg1Bytes,
            dg2RawBytes: dg2RawBytes,
            dg2ImageBytes: dg2ImageBytes,
            dataNotTampered: passport.passportDataNotTampered,
            issuingAuthority: passport.issuingAuthority,
            documentNumber: passport.documentNumber
        )
    }
}
