import Foundation
import Vision
import CoreVideo
import CoreGraphics
import Combine

// Phase 4 — Apple Vision driven active-liveness face tracker.
//
// Subscribes to `CameraSession.shared.frames()`, runs a
// VNDetectFaceRectanglesRequest (revision 3 — first revision to expose
// yaw/pitch/roll as Floats) on a background-priority task, and publishes a
// `FaceStatus` back on MainActor. CaptureCoordinator subscribes to the
// @Published status and auto-captures when `matchesTargetPose` stays true
// for POSE_HOLD_DURATION.
//
// Hard invariant: Vision runs locally — no cloud call. Bounding box +
// yaw/pitch are extracted, used for threshold comparison, and dropped; the
// CVPixelBuffer never leaves the device and is not retained past the
// request's lifetime.
//
// Frame throttling: we skip every other frame (half of 30fps → 15Hz
// processing) to keep face-rect + angle extraction well under 10% CPU on
// iPhone 13-class hardware. Raising to full 30fps is safe if needed; it
// just doubles Vision's share of the CPU budget.

struct FaceStatus: Equatable {
    // Normalized Vision coordinates (origin bottom-left, 0..1). nil when no
    // face is detected in the frame.
    let boundingBox: CGRect?
    let yaw: Float?
    let pitch: Float?
    let roll: Float?
    // True when (a) a face is detected with confidence above
    // MIN_CONFIDENCE and (b) yaw + pitch fall within the current target
    // pose's tolerance window.
    let matchesTargetPose: Bool
    // VNFaceObservation.confidence, 0..1. Used by the view to show a
    // "better lighting" hint when the face is seen but unstable.
    let confidence: Float
    // The pose we were matching against when this status snapshot was
    // produced. Lets the view pick the right arrow/color without racing the
    // coordinator's state.
    let targetPose: LivenessPose?

    static let empty = FaceStatus(
        boundingBox: nil,
        yaw: nil,
        pitch: nil,
        roll: nil,
        matchesTargetPose: false,
        confidence: 0,
        targetPose: nil
    )
}

@MainActor
final class FaceTracker: ObservableObject {
    // Minimum VNFaceObservation.confidence for a detection to count toward
    // matchesTargetPose. Below this we surface the face (so the ellipse can
    // still track the user) but never flip the "pose held" signal.
    static let minConfidence: Float = 0.5

    @Published private(set) var status: FaceStatus = .empty

    private var targetPose: LivenessPose?
    private var streamTask: Task<Void, Never>?
    private var frameCounter: Int = 0
    // Process 1 out of every N frames. At 30fps this is 15Hz — plenty for
    // human head motion and easy on the CPU.
    private let frameStride: Int = 2

    func start(targetPose: LivenessPose) {
        self.targetPose = targetPose
        // Reset published status so the UI doesn't carry a stale match flag
        // across pose transitions.
        self.status = FaceStatus(
            boundingBox: nil,
            yaw: nil,
            pitch: nil,
            roll: nil,
            matchesTargetPose: false,
            confidence: 0,
            targetPose: targetPose
        )

        // Cancel any existing subscription and start a fresh one. Each
        // start() call gets its own stream; stop() tears it down.
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            let stream = CameraSession.shared.frames()
            for await frame in stream {
                if Task.isCancelled { break }
                await self.process(frame: frame)
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        targetPose = nil
        frameCounter = 0
        status = .empty
    }

    private func process(frame: FrameBuffer) async {
        frameCounter &+= 1
        guard frameCounter % frameStride == 0 else { return }
        guard let pose = targetPose else { return }

        let pixelBuffer = frame.pixelBuffer

        // Hop off the MainActor for the Vision call — face detection is
        // CPU-heavy and we don't want to block UI updates.
        let result: FaceStatus? = await Task.detached(priority: .userInitiated) {
            Self.detect(pixelBuffer: pixelBuffer, targetPose: pose)
        }.value

        guard let newStatus = result else { return }
        // Only publish when something meaningful changes, to keep the
        // @Published signal quiet for SwiftUI.
        if newStatus != status {
            status = newStatus
        }
    }

    // MARK: — Vision request (nonisolated)

    private nonisolated static func detect(pixelBuffer: CVPixelBuffer, targetPose: LivenessPose) -> FaceStatus {
        let request = VNDetectFaceRectanglesRequest()
        // Revision 3 is the first to expose yaw/pitch/roll on
        // VNFaceObservation. iOS 15+; deployment target is 16.
        if #available(iOS 15.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision3
        }

        // Front camera, portrait: the CVPixelBuffer arrives rotated 90° CCW
        // relative to the upright image the user sees. We declare the
        // orientation as .leftMirrored so Vision analyzes the frame in the
        // same upright frame the user perceives — this is the standard
        // incantation for front-facing capture in portrait. Preview layer
        // mirror is a display-only concern and isn't reflected here; see
        // FaceEllipseOverlay for the overlay-side X-flip.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return FaceStatus(
                boundingBox: nil, yaw: nil, pitch: nil, roll: nil,
                matchesTargetPose: false, confidence: 0, targetPose: targetPose
            )
        }

        guard let obs = (request.results ?? []).first else {
            return FaceStatus(
                boundingBox: nil, yaw: nil, pitch: nil, roll: nil,
                matchesTargetPose: false, confidence: 0, targetPose: targetPose
            )
        }

        let yaw = obs.yaw?.floatValue
        let pitch = obs.pitch?.floatValue
        let roll = obs.roll?.floatValue
        let confidence = obs.confidence

        let matches: Bool = {
            guard confidence >= FaceTracker.minConfidence else { return false }
            guard let yaw, let pitch else { return false }
            return targetPose.matches(yaw: yaw, pitch: pitch)
        }()

        return FaceStatus(
            boundingBox: obs.boundingBox,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            matchesTargetPose: matches,
            confidence: confidence,
            targetPose: targetPose
        )
    }
}
