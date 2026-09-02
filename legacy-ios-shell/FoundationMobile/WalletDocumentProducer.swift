import Foundation
import CryptoKit

// Phase 3a (Wallet variant) — .nfcZk artifact from Wallet/mDL read result.
// Payload: SHA-256(documentNumberRaw_utf8 + issuingState_utf8).
// issuingState nil is treated as "" so the commitment is stable even when
// the field is absent (e.g. MDL on iOS < 18.4 returns no issuing authority).
//
// Mirrors PassportNfcProducer: passes the raw payload bytes into
// ProofArtifactBuilder, which hashes once more before signing. Net:
// payloadHashHex = SHA-256(SHA-256(docNumber + state)).

struct WalletDocumentProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .nfcZk
    let walletData: WalletDocumentReadResult

    /// SHA-256(documentNumberRaw_utf8 + issuingState_utf8).
    /// Extracted for unit-testability; `produce()` is the authoritative caller.
    func payloadBytes() -> Data {
        let combined = Data(walletData.documentNumberRaw.utf8)
            + Data((walletData.issuingState ?? "").utf8)
        return Data(SHA256.hash(data: combined))
    }

    func produce() async throws -> ProofArtifact {
        return try await ProofArtifactBuilder.build(
            kind: .nfcZk,
            payload: payloadBytes()
        )
    }
}
