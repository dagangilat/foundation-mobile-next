import Foundation
import CoreGraphics
import CryptoKit
import UIKit
import CoreImage

// Phase 6 — real `.faceMatch` artifact. Replaces MockFaceMatchProducer when
// the active profile requires .faceMatch.
//
// Reference image source (controlled by the active profile's
// `faceMatchSource` field) is one of:
//   - `.dg2`           — passport chip's DG2 face image (hisec-global)
//   - `.documentPhoto` — back-camera capture of the document's face region
//                        (standardsec, for IDs without an RFID chip)
//
// Probe image is always the selfie JPEG from the liveness pose loop's
// first frame (straight-on neutral, matches both reference modalities).
//
// Output: `ProofArtifact(.faceMatch)` whose payload binds:
//   - the reference source (so the verifier knows which trust posture applies)
//   - the boolean match decision
//   - the cosine distance (×10000, rounded — sidesteps Float-print drift)
//   - the threshold the decision was made against
//   - SHA-256(reference image bytes) — pins the artifact to that exact image
//   - SHA-256(selfie JPEG) — pins it to the captured selfie
//
// HARD INVARIANT: neither the reference image nor the selfie image leaves
// the device. Only the SHA-256 of the canonical decision string above does,
// signed by the device's App Attest key, and only as part of the Phase 7
// commitment hash (i.e. one hash inside another hash).

enum FaceMatchSource: String, Sendable {
    case dg2
    case documentPhoto
}

struct FaceMatchProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .faceMatch

    let referenceImage: UIImage
    let referenceHash: Data
    let source: FaceMatchSource
    let selfieJpeg: Data
    let threshold: Float
    let embedder: any FaceEmbedder

    /// Conservative default for the stub-embedder world; AppConfig overrides
    /// per-profile (hisec-global: 0.45, standardsec: 0.55 — tighter because
    /// document-photo references are noisier than chip-bound DG2).
    static let defaultThreshold: Float = 0.45

    init(
        referenceImage: UIImage,
        referenceHash: Data,
        source: FaceMatchSource,
        selfieJpeg: Data,
        threshold: Float = FaceMatchProducer.defaultThreshold,
        embedder: any FaceEmbedder = FaceEmbedderRegistry.current
    ) {
        self.referenceImage = referenceImage
        self.referenceHash = referenceHash
        self.source = source
        self.selfieJpeg = selfieJpeg
        self.threshold = threshold
        self.embedder = embedder
    }

    func produce() async throws -> ProofArtifact {
        guard let refCG = referenceImage.cgImage else {
            throw FaceEmbedderError.imageRenderFailed
        }
        guard let selfieCG = Self.decodeSelfie(jpeg: selfieJpeg) else {
            throw FaceEmbedderError.imageRenderFailed
        }

        let refEmbedding = try await embedder.embed(refCG)
        let selfieEmbedding = try await embedder.embed(selfieCG)

        let distance = type(of: embedder).cosineDistance(refEmbedding, selfieEmbedding)
        let accepted = distance <= threshold

        let selfieHash = Data(SHA256.hash(data: selfieJpeg))
        let payload = Self.canonicalPayload(
            accepted: accepted,
            distance: distance,
            threshold: threshold,
            source: source,
            referenceHash: referenceHash,
            selfieHash: selfieHash
        )
        return try await ProofArtifactBuilder.build(kind: .faceMatch, payload: payload)
    }

    // Schema v2 canonical payload. Keys lexicographic. The `source` field is
    // load-bearing — it tells the verifier whether to trust the reference as
    // a CSCA-signed chip image (`dg2`) or as a tamperable camera capture
    // (`documentPhoto`). v1 (no source field) is deprecated in lock-step
    // with foundationmobile.json schemaVersion bump 1 → 2.
    static func canonicalPayload(
        accepted: Bool,
        distance: Float,
        threshold: Float,
        source: FaceMatchSource,
        referenceHash: Data,
        selfieHash: Data
    ) -> Data {
        let distanceMilli = Int((distance * 10_000).rounded())
        let thresholdMilli = Int((threshold * 10_000).rounded())
        let line = "faceMatch:accepted=\(accepted ? 1 : 0):distance10000=\(distanceMilli):reference=\(referenceHash.hexLower):selfie=\(selfieHash.hexLower):source=\(source.rawValue):threshold10000=\(thresholdMilli)"
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
