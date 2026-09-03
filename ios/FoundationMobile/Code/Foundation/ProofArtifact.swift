import Foundation
import CryptoKit

// The universal shape every sensor phase emits. Phase 7 (enclave seal)
// concatenates an ordered list of these, hashes the bytes, and signs with
// the Secure Enclave key. Freeze this contract — changing it means
// re-signing every previously-emitted artifact.

struct ProofArtifact: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case appAttest      // DCAppAttestService attestation - the only kind
                            // anchorCommitment requires
                            // (ANCHOR_COMMITMENT_REQUIRED_KINDS = ["appAttest"])
        case nfcZk          // the Rarimo registration proof, once the passport
                            // is registered on L2
    }

    let kind: Kind
    let producedAtMs: Int64
    let payloadHashHex: String    // lowercase hex SHA-256 of the sensor's raw output
    let signatureBase64: String   // App Attest assertion over payloadHashHex bytes

    // Deterministic serialization for the Phase 7 seal input. Any change to
    // this format invalidates every previously-signed artifact.
    func canonicalBytes() -> Data {
        let line = "\(kind.rawValue):\(producedAtMs):\(payloadHashHex):\(signatureBase64)"
        return Data(line.utf8)
    }
}

// Sensors conform to this. The coordinator / enclave seal doesn't care which
// phase produced the artifact — it only cares about the shape.
protocol ProofProducer: Sendable {
    var kind: ProofArtifact.Kind { get }
    func produce() async throws -> ProofArtifact
}

enum ProofArtifactBuilderError: Error {
    case noAttestedKey
}

enum ProofArtifactBuilder {
    static func build(
        kind: ProofArtifact.Kind,
        payload: Data
    ) async throws -> ProofArtifact {
        guard let keyId = Keychain.getAttestedKeyId() else {
            throw ProofArtifactBuilderError.noAttestedKey
        }
        let hash = Data(SHA256.hash(data: payload))
        let hashHex = hash.map { String(format: "%02x", $0) }.joined()
        let signature = try await AttestationService.shared.generateAssertion(
            keyId: keyId,
            payloadBase64: hash.base64EncodedString()
        )
        return ProofArtifact(
            kind: kind,
            producedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
            payloadHashHex: hashHex,
            signatureBase64: signature
        )
    }
}
