import Foundation
import CryptoKit

// Mock ProofProducers for sensor kinds whose real implementations haven't
// landed yet. Phase 7 (EnclaveSeal) and the Phase 2 Solana callable develop
// against the full fan-in — toggle a SensorFeatureFlag on once the real
// producer ships, and the mock falls away.
//
// Mocks intentionally don't route through ProofArtifactBuilder: the builder
// requires an App Attest-attested key to sign payloadHashHex, which a
// synthetic "mock:<kind>" payload has no business carrying. Mock artifacts
// are clearly labeled via a "mock:<tag>" signature so a backend verifier can
// reject them by shape when ENFORCE_APP_CHECK flips on.

struct MockNfcZkProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .nfcZk
    func produce() async throws -> ProofArtifact {
        MockProof.artifact(kind: kind, tag: "nfc-zk")
    }
}

struct MockLivenessProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .liveness
    func produce() async throws -> ProofArtifact {
        MockProof.artifact(kind: kind, tag: "liveness")
    }
}

struct MockAntiSpoofProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .antiSpoof
    func produce() async throws -> ProofArtifact {
        MockProof.artifact(kind: kind, tag: "anti-spoof")
    }
}

struct MockFaceMatchProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .faceMatch
    func produce() async throws -> ProofArtifact {
        MockProof.artifact(kind: kind, tag: "face-match")
    }
}

enum ProofProducerRegistry {
    // Returns a mock producer ONLY when the active profile does not require
    // this kind. When the profile DOES require it, returns nil so the real
    // producer (built explicitly by CaptureCoordinator.verify) is used.
    static func producer(for kind: ProofArtifact.Kind) -> (any ProofProducer)? {
        guard !AppConfig.shared.profile.requires(kind) else { return nil }
        switch kind {
        case .appAttest: return nil
        case .nfcZk: return MockNfcZkProducer()
        case .liveness: return MockLivenessProducer()
        case .antiSpoof: return MockAntiSpoofProducer()
        case .faceMatch: return MockFaceMatchProducer()
        }
    }
}

private enum MockProof {
    static func artifact(kind: ProofArtifact.Kind, tag: String) -> ProofArtifact {
        let payload = Data("mock:\(tag)".utf8)
        let hash = Data(SHA256.hash(data: payload))
        let hashHex = hash.map { String(format: "%02x", $0) }.joined()
        return ProofArtifact(
            kind: kind,
            producedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
            payloadHashHex: hashHex,
            signatureBase64: "mock:\(tag)"
        )
    }
}
