import Foundation
import CoreGraphics
import CryptoKit
import UIKit
import CoreImage

// Phase 6 — real `.faceMatch` artifact. Replaces MockFaceMatchProducer when
// SensorFeatureFlags.faceMatch is true and a passport DG2 image is in hand.
//
// Inputs:
//   - DG2 face image from the passport chip (from PassportNFCReader with
//     includeFacePhoto: true)
//   - selfie JPEG bytes from CameraSession (the same first-pose frame the
//     liveness producer hashes — reusing it avoids a second camera capture)
//
// Output: `ProofArtifact(.faceMatch)` whose payload binds:
//   - the boolean match decision
//   - the cosine distance (rounded to 4 decimal places, encoded as an int
//     to keep the payload deterministic across float-print drift)
//   - the threshold the decision was made against
//   - SHA-256(DG2) — pins the artifact to the chip's exact face image
//   - SHA-256(selfie JPEG) — pins it to the captured selfie
//
// HARD INVARIANT: neither the DG2 image nor the selfie image leaves the
// device. Only the SHA-256 of the canonical decision string above does,
// signed by the device's App Attest key, and only as part of the Phase 7
// commitment hash (i.e. one hash inside another hash).

struct FaceMatchProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .faceMatch

    let dg2Image: UIImage
    let dg2Hash: Data
    let selfieJpeg: Data
    let embedder: any FaceEmbedder

    /// Cosine-distance threshold for the match decision. Anything ≤ threshold
    /// is treated as "same person". The default is conservative for a
    /// stub-embedder world (where genuine matches will fail anyway, so the
    /// producer just emits decision=false truthfully). Re-tune per the
    /// embedder's verification ROC when a real model lands.
    static let defaultThreshold: Float = 0.45

    init(
        dg2Image: UIImage,
        dg2Hash: Data,
        selfieJpeg: Data,
        embedder: any FaceEmbedder = FaceEmbedderRegistry.current
    ) {
        self.dg2Image = dg2Image
        self.dg2Hash = dg2Hash
        self.selfieJpeg = selfieJpeg
        self.embedder = embedder
    }

    func produce() async throws -> ProofArtifact {
        guard let dg2CG = dg2Image.cgImage else {
            throw FaceEmbedderError.imageRenderFailed
        }
        guard let selfieCG = Self.decodeSelfie(jpeg: selfieJpeg) else {
            throw FaceEmbedderError.imageRenderFailed
        }

        let dg2Embedding = try await embedder.embed(dg2CG)
        let selfieEmbedding = try await embedder.embed(selfieCG)

        let distance = type(of: embedder).cosineDistance(dg2Embedding, selfieEmbedding)
        let threshold = Self.defaultThreshold
        let accepted = distance <= threshold

        let selfieHash = Data(SHA256.hash(data: selfieJpeg))
        let payload = Self.canonicalPayload(
            accepted: accepted,
            distance: distance,
            threshold: threshold,
            dg2Hash: dg2Hash,
            selfieHash: selfieHash
        )
        return try await ProofArtifactBuilder.build(kind: .faceMatch, payload: payload)
    }

    // Deterministic payload encoding so the audit-side verifier can
    // reconstruct the exact bytes that were hashed and signed. The integer
    // distance/threshold encoding (×10000, rounded) sidesteps Float printing
    // drift across Swift versions. Keys are sorted lexicographically.
    static func canonicalPayload(
        accepted: Bool,
        distance: Float,
        threshold: Float,
        dg2Hash: Data,
        selfieHash: Data
    ) -> Data {
        let distanceMilli = Int((distance * 10_000).rounded())
        let thresholdMilli = Int((threshold * 10_000).rounded())
        let line = "faceMatch:accepted=\(accepted ? 1 : 0):dg2=\(dg2Hash.hexLower):distance10000=\(distanceMilli):selfie=\(selfieHash.hexLower):threshold10000=\(thresholdMilli)"
        return Data(line.utf8)
    }

    private static func decodeSelfie(jpeg: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(jpeg as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}

private extension Data {
    var hexLower: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
