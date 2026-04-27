import Foundation
import CryptoKit

// Phase 7 skeleton. Concatenates the available ProofArtifacts in canonical
// order, hashes, and returns the commitment hash that gets submitted to the
// Phase 2 Solana Anchor verifier. The real implementation additionally signs
// the hash with a Secure-Enclave-generated key before submission.
//
// Backend and mobile develop against this shape in parallel: the backend
// accepts `{ commitmentHashHex, artifactKinds }` and verifies only that the
// expected kinds are present; mobile emits mocks for disabled kinds so the
// fan-in is always complete.

enum EnclaveSeal {
    struct Commitment: Codable, Sendable, Equatable {
        let commitmentHashHex: String
        let artifactKinds: [ProofArtifact.Kind]
        let producedAtMs: Int64
    }

    enum Error: Swift.Error {
        case missingUid
    }

    /// Bind the user identity into the commitment hash. A captured
    /// payload from user A cannot be replayed by user B (with B's auth
    /// token) because B's reconstruction would hash to a different
    /// value and fail the server's seal-mismatch gate.
    /// Server's canonicalSealBytes(uid, artifacts) mirrors this exactly.
    static func seal(uid: String, artifacts: [ProofArtifact]) -> Commitment {
        let sorted = artifacts.sorted { $0.kind.rawValue < $1.kind.rawValue }
        var buffer = Data()
        buffer.append(Data("uid:\(uid)\n".utf8))
        for artifact in sorted {
            buffer.append(artifact.canonicalBytes())
            buffer.append(0x0a)
        }
        let hash = Data(SHA256.hash(data: buffer))
        return Commitment(
            commitmentHashHex: hash.map { String(format: "%02x", $0) }.joined(),
            artifactKinds: sorted.map(\.kind),
            producedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }
}
