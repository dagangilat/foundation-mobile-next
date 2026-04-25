import Foundation
import CoreGraphics
import CoreImage
import CryptoKit
import UIKit

// Phase 6 — face-embedding seam. Plugged into FaceMatchProducer to compare
// the passport's DG2 photo against a captured selfie. The protocol is
// minimal on purpose: any embedder that turns a face image into a fixed-
// dimension Float vector will do — ArcFace via Core ML, MobileFaceNet,
// FaceNet, or the deterministic stub below for plumbing tests.
//
// SWAP-IN PROCEDURE (when a real Core ML model lands):
//   1. Drop ArcFaceMobileFaceNet.mlmodel (or equivalent) into
//      ios/FoundationMobile/Resources/face/. Add to Copy Bundle Resources
//      in the pbxproj.
//   2. Implement CoreMLFaceEmbedder below: load the .mlmodel via
//      MLModel(contentsOf:), wrap inputs/outputs through MLFeatureValue,
//      return a normalized [Float] of the model's embedding dimension
//      (typically 128, 256, or 512).
//   3. Switch `FaceEmbedder.default` to return the Core ML embedder when
//      the model file is present in the bundle; fall back to the stub
//      otherwise so dev builds without the model still compile.
//   4. Tune the cosine-distance threshold in FaceMatchProducer based on
//      the model's verification ROC. ArcFace MobileFaceNet typically
//      lands at ~0.4 cosine distance for the FAR=1e-4 operating point.
//
// SECURITY: the embedder runs entirely on-device. Neither the DG2 image
// nor the selfie ever leaves the phone. Only the SHA-256 of the produced
// match decision (decision || distance || threshold || dg2Hash || selfieHash)
// is signed by App Attest and enters the Phase 7 enclave seal.

protocol FaceEmbedder: Sendable {
    /// L2-normalized embedding vector. `dimension` is fixed per implementation
    /// and stable across calls. Cosine similarity is the dot product when
    /// inputs are L2-normalized; cosine distance is `1 - similarity`.
    var dimension: Int { get }
    func embed(_ image: CGImage) async throws -> [Float]
}

enum FaceEmbedderError: Error, LocalizedError {
    case imageRenderFailed
    case modelLoadFailed(String)
    case modelInferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageRenderFailed:
            return "Failed to render the input image into the embedder's expected format."
        case .modelLoadFailed(let m):
            return "Face-embedder model load failed: \(m)"
        case .modelInferenceFailed(let m):
            return "Face-embedder inference failed: \(m)"
        }
    }
}

extension FaceEmbedder {
    /// Cosine distance over L2-normalized vectors. `0` is identical, `1` is
    /// orthogonal, `2` is opposite. ArcFace operating points typically live
    /// in the `0.3–0.5` range; threshold tuning is the producer's job.
    static func cosineDistance(_ a: [Float], _ b: [Float]) -> Float {
        precondition(a.count == b.count, "embedding dimension mismatch")
        var dot: Float = 0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return 1.0 - dot
    }
}

enum FaceEmbedderRegistry {
    /// Returns the embedder Phase 6 should use today. While the Core ML
    /// model isn't bundled, every consumer gets the deterministic stub —
    /// the producer plumbing still runs end-to-end so we can flip
    /// the .faceMatch requirement on in a profile and exercise the artifact-
    /// emit path under the same shape the real path will use.
    static var current: any FaceEmbedder {
        CoreMLFaceEmbedder.tryLoadFromBundle() ?? StubFaceEmbedder()
    }
}

// MARK: - Stub embedder

/// Deterministic, model-free face embedder used until a Core ML model ships.
/// Same input image → same vector; different inputs → uncorrelated vectors.
/// Useful for verifying the FaceMatchProducer wiring (NFC DG2 image arrives,
/// selfie arrives, distance is computed, artifact is emitted), but produces
/// NO meaningful identity decision: a real DG2 photo and a live selfie of
/// the same person look like "different images" to the stub, so cosine
/// distance is high. That's intentional — we don't want a stub silently
/// passing identity checks. Flip to a real embedder before relying on the
/// match decision for any user-visible gate.
struct StubFaceEmbedder: FaceEmbedder {
    let dimension: Int = 128

    func embed(_ image: CGImage) async throws -> [Float] {
        let signature = try Self.smallSignature(of: image)
        let digest = SHA256.hash(data: signature)
        let bytes = Array(digest)

        // Expand SHA-256 (32 bytes) into a `dimension`-element [-1, 1] vector
        // by walking the digest cyclically. Resulting distribution is uniform-
        // ish; the L2 normalize at the end makes magnitude irrelevant for
        // cosine similarity, which is all the producer cares about.
        var vector: [Float] = []
        vector.reserveCapacity(dimension)
        for i in 0..<dimension {
            let byte = bytes[i % bytes.count]
            vector.append(Float(Int8(bitPattern: byte)) / 127.0)
        }
        return Self.l2Normalize(vector)
    }

    /// Render the input image to a 16×16 grayscale buffer; the buffer bytes
    /// become the embedding's deterministic signature. Tiny enough that two
    /// reads of the same passport (same DG2 image) hash identically even
    /// across platform image decode jitter.
    private static func smallSignature(of image: CGImage) throws -> Data {
        let width = 16
        let height = 16
        let bytesPerRow = width
        var buffer = [UInt8](repeating: 0, count: width * height)
        let space = CGColorSpaceCreateDeviceGray()
        let bitmapInfo: UInt32 = 0
        guard let ctx = buffer.withUnsafeMutableBufferPointer({ ptr -> CGContext? in
            CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: bitmapInfo
            )
        }) else {
            throw FaceEmbedderError.imageRenderFailed
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Data(buffer)
    }

    private static func l2Normalize(_ v: [Float]) -> [Float] {
        let mag = sqrt(v.reduce(Float(0)) { $0 + $1 * $1 })
        return mag > 0 ? v.map { $0 / mag } : v
    }
}
