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

    func produce() async throws -> ProofArtifact {
        let docNumberBytes = Data(walletData.documentNumberRaw.utf8)
        let stateBytes = Data((walletData.issuingState ?? "").utf8)
        let combined = docNumberBytes + stateBytes
        let payload = Data(SHA256.hash(data: combined))
        return try await ProofArtifactBuilder.build(
            kind: .nfcZk,
            payload: payload
        )
    }
}
