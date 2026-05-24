import Foundation
import UIKit
import CoreVideo
import VideoToolbox

// JPEG-encode a single camera frame. Used by CaptureCoordinator during the
// multi-pose liveness capture — each pose produces one JPEG that goes into
// the combined per-frame-hash payload that a single `.liveness` ProofArtifact
// signs. JPEG@0.85 is the stable hash surface: raw BGRA bytes vary run-to-run
// even on the same scene (ISP jitter, alignment padding), so we hash a
// deterministic re-encode instead. The buffer never touches disk.
//
// Until Phase 4 adds MediaPipe active-liveness, there is no ProofProducer
// conformance here — CaptureCoordinator drives the capture loop directly.

enum LivenessFrameEncoderError: Error {
    case cgImageConversionFailed
    case jpegEncodeFailed
}

enum LivenessFrameEncoder {
    static func encodeJpeg(_ frame: FrameBuffer, compressionQuality: CGFloat = 0.85) throws -> Data {
        var cgImage: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(frame.pixelBuffer, options: nil, imageOut: &cgImage)
        guard status == noErr, let cgImage else {
            throw LivenessFrameEncoderError.cgImageConversionFailed
        }
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: compressionQuality) else {
            throw LivenessFrameEncoderError.jpegEncodeFailed
        }
        return jpegData
    }
}
