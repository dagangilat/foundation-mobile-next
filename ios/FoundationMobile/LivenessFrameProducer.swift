import Foundation
import UIKit
import CoreVideo
import VideoToolbox

// Phase 4 liveness standing in for MediaPipe active-liveness until it ships.
// Captures one front-camera frame, hashes a JPEG encoding of it, and routes
// the hash through ProofArtifactBuilder so App Attest signs the hash. No
// pixel-shaped bytes leave this function: the CVPixelBuffer / CGImage /
// UIImage / Data all fall out of scope once the artifact is built.

enum LivenessFrameProducerError: Error {
    case cgImageConversionFailed
    case jpegEncodeFailed
}

struct LivenessFrameProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .liveness

    func produce() async throws -> ProofArtifact {
        let frame = try await CameraSession.shared.captureOneFrame()

        var cgImage: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(frame.pixelBuffer, options: nil, imageOut: &cgImage)
        guard status == noErr, let cgImage else {
            throw LivenessFrameProducerError.cgImageConversionFailed
        }

        // JPEG@0.85 is the stable hash surface: raw BGRA bytes vary run-to-run
        // even on the same scene (ISP jitter, alignment padding), so we hash
        // a deterministic re-encode instead. The buffer never touches disk.
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
            throw LivenessFrameProducerError.jpegEncodeFailed
        }

        return try await ProofArtifactBuilder.build(kind: .liveness, payload: jpegData)
    }
}
