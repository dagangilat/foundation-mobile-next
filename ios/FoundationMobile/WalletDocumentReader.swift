import Foundation
import CryptoKit
import UIKit

// Sub-project 1 (2026-07-01) — mDL + Wallet National ID reader.
// Uses Apple ProximityReader Verifier API (iOS 17+).
// Wrapped in #if canImport so CI builds on iOS 16 Simulators compile clean.
// Full ProximityReader framework linking + entitlement is a PR-checklist item.

// MARK: - WalletDocumentReadResult

struct WalletDocumentReadResult: @unchecked Sendable, Equatable {
    let portraitHash: Data              // SHA-256(portrait JPEG bytes) — 32 bytes
    let portraitImage: UIImage?         // in-memory only; nil when includeFacePhoto=false
    let documentNumberRaw: String       // full document number (for SHA-256 payload)
    let documentNumberMasked: String    // display: last 3 chars only, e.g. "•••321"
    let issuingState: String?           // e.g. "AZ", informational
    let walletDocumentType: DocumentProfile.WalletDocumentType

    static func == (lhs: WalletDocumentReadResult, rhs: WalletDocumentReadResult) -> Bool {
        lhs.portraitHash == rhs.portraitHash &&
        lhs.documentNumberRaw == rhs.documentNumberRaw &&
        lhs.documentNumberMasked == rhs.documentNumberMasked &&
        lhs.issuingState == rhs.issuingState &&
        lhs.walletDocumentType == rhs.walletDocumentType
        // portraitImage excluded — UIImage equality by pixel data is expensive;
        // identity is covered by portraitHash.
    }
}

// MARK: - WalletDocumentError

enum WalletDocumentError: Error {
    case unsupportedOS
    case invalidProfile
    case sessionExpired   // caller should retry once
    case cancelled
}

// MARK: - Masking helper

func maskDocumentNumber(_ raw: String) -> String {
    guard raw.count > 3 else { return raw }
    return String(repeating: "•", count: raw.count - 3) + raw.suffix(3)
}

// MARK: - WalletDocumentReader

#if canImport(ProximityReader)
import ProximityReader

@MainActor
final class WalletDocumentReader {
    static let shared = WalletDocumentReader()
    private init() {}

    nonisolated static var isSupported: Bool {
        if #available(iOS 17, *) {
            return MobileDocumentReader.isSupported
        }
        return false
    }

    func readDocument(
        profile: DocumentProfile,
        includeFacePhoto: Bool
    ) async throws -> WalletDocumentReadResult {
        guard #available(iOS 17, *) else { throw WalletDocumentError.unsupportedOS }
        guard let walletType = profile.walletDocumentType else {
            throw WalletDocumentError.invalidProfile
        }

        let reader = MobileDocumentReader()
        // prepare() returns a MobileDocumentReaderSession
        let session = try await reader.prepare(using: nil)

        do {
            switch walletType {
            case .mobileDriversLicense:
                return try await readMDL(session: session, includeFacePhoto: includeFacePhoto)
            case .nationalIdCard:
                if #available(iOS 18, *) {
                    return try await readNationalID(session: session, includeFacePhoto: includeFacePhoto)
                } else {
                    throw WalletDocumentError.unsupportedOS
                }
            }
        } catch let err as MobileDocumentReaderError {
            switch err {
            case .cancelled:
                throw WalletDocumentError.cancelled
            case .sessionExpired:
                throw WalletDocumentError.sessionExpired
            default:
                throw err
            }
        }
    }

    @available(iOS 17, *)
    private func readMDL(
        session: MobileDocumentReaderSession,
        includeFacePhoto: Bool
    ) async throws -> WalletDocumentReadResult {
        let request = MobileDriversLicenseDataRequest(
            retainedElements: includeFacePhoto ? [.portrait] : [],
            nonRetainedElements: [.documentNumber, .issuingAuthority]
        )
        let response = try await session.requestDocument(request)
        let elements = response.documentElements
        let portraitBytes = elements.portraitData
        // documentNumber on MDL response is available iOS 18.4+
        let docNumberRaw: String
        if #available(iOS 18.4, *) {
            docNumberRaw = elements.documentNumber ?? ""
        } else {
            docNumberRaw = ""
        }

        return buildResult(
            portraitBytes: portraitBytes,
            includeFacePhoto: includeFacePhoto,
            docNumberRaw: docNumberRaw,
            issuingState: nil,
            walletDocumentType: .mobileDriversLicense
        )
    }

    @available(iOS 18, *)
    private func readNationalID(
        session: MobileDocumentReaderSession,
        includeFacePhoto: Bool
    ) async throws -> WalletDocumentReadResult {
        // MobileNationalIDCardDataRequest requires a Locale.Region.
        // Use .unitedStates as default; callers with specific profiles can
        // be extended in a follow-up task.
        // .documentNumber element is iOS 18.4+; build request conditionally
        let nonRetained: [MobileNationalIDCardDataRequest.Element]
        if #available(iOS 18.4, *) {
            nonRetained = [.documentNumber]
        } else {
            nonRetained = []
        }
        let request = MobileNationalIDCardDataRequest(
            region: .unitedStates,
            retainedElements: includeFacePhoto ? [.portrait] : [],
            nonRetainedElements: nonRetained
        )
        let response = try await session.requestDocument(request)
        let elements = response.documentElements
        let portraitBytes = elements.portraitData
        let docNumberRaw: String
        if #available(iOS 18.4, *) {
            docNumberRaw = elements.documentNumber ?? ""
        } else {
            docNumberRaw = ""
        }

        return buildResult(
            portraitBytes: portraitBytes,
            includeFacePhoto: includeFacePhoto,
            docNumberRaw: docNumberRaw,
            issuingState: nil,
            walletDocumentType: .nationalIdCard
        )
    }

    private func buildResult(
        portraitBytes: Data?,
        includeFacePhoto: Bool,
        docNumberRaw: String,
        issuingState: String?,
        walletDocumentType: DocumentProfile.WalletDocumentType
    ) -> WalletDocumentReadResult {
        let portraitHash: Data
        if let bytes = portraitBytes {
            portraitHash = Data(SHA256.hash(data: bytes))
        } else {
            portraitHash = Data(SHA256.hash(data: Data()))
        }
        let portraitImage: UIImage? = (includeFacePhoto ? portraitBytes : nil).flatMap { UIImage(data: $0) }

        return WalletDocumentReadResult(
            portraitHash: portraitHash,
            portraitImage: portraitImage,
            documentNumberRaw: docNumberRaw,
            documentNumberMasked: maskDocumentNumber(docNumberRaw),
            issuingState: issuingState,
            walletDocumentType: walletDocumentType
        )
    }
}

#else // ProximityReader not linked — stub for iOS 16 CI builds

@MainActor
final class WalletDocumentReader {
    static let shared = WalletDocumentReader()
    private init() {}

    nonisolated static var isSupported: Bool { false }

    func readDocument(
        profile: DocumentProfile,
        includeFacePhoto: Bool
    ) async throws -> WalletDocumentReadResult {
        throw WalletDocumentError.unsupportedOS
    }
}

#endif
