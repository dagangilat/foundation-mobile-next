import Foundation

// Toggle individual sensor phases during the parallel build. A phase that's
// disabled produces a deterministic mock ProofArtifact so Phase 7 (enclave
// seal) and the Phase 2 Solana callable can integrate against the full
// fan-in from day one. Flip a flag to true once the real sensor ships.

enum SensorFeatureFlags {
    static let nfcZk: Bool = false       // Phase 3 — MOPRO-bound Self circuit
    static let liveness: Bool = false    // Phase 4 — MediaPipe active liveness
    static let antiSpoof: Bool = false   // Phase 5 — Silent-Face-Anti-Spoofing
    static let faceMatch: Bool = false   // Phase 6 — ArcFace DG2 ↔ selfie match

    static func isEnabled(_ kind: ProofArtifact.Kind) -> Bool {
        switch kind {
        case .appAttest: return true     // Phase 1 always on
        case .nfcZk: return nfcZk
        case .liveness: return liveness
        case .antiSpoof: return antiSpoof
        case .faceMatch: return faceMatch
        }
    }
}
