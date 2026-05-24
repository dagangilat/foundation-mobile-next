import SwiftUI

// Phase 4 — SwiftUI overlay that draws an ellipse around the user's face.
// The ellipse is green when the current target pose is held, muted
// otherwise. A soft guide ellipse is always visible to help the user
// center their face before the tracker locks on.
//
// Coordinate conversion (Vision → SwiftUI):
//   - Vision bounding boxes are normalized (0..1) with origin at the
//     bottom-left, because that's how Vision quirks around Core Graphics.
//   - SwiftUI's coordinate space is top-left origin, so we flip Y by
//     `1 - y`.
//   - The CVPixelBuffer Vision analyzes is NOT mirrored — Vision sees the
//     true world. But the AVCaptureVideoPreviewLayer underneath mirrors
//     the selfie view for display. To keep the overlay visually anchored
//     to the user's face as they see themselves, we flip X:
//     `mirroredX = 1 - x - w`.
//   - This X-flip is the ONLY place we compensate for the front-camera
//     mirror. Yaw thresholds in LivenessPose stay in raw (non-mirrored)
//     Vision frame; the prompt text ("turn left") describes the user's
//     real-world direction, which after mirror matches what the user sees
//     their head doing in the preview.

struct FaceEllipseOverlay: View {
    let faceStatus: FaceStatus

    var body: some View {
        GeometryReader { geo in
            guideEllipse(in: geo.size)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func guideEllipse(in size: CGSize) -> some View {
        let w = size.width * 0.6
        let h = size.height * 0.75
        // Explicit .position at geo center: a bare .frame inside a ZStack
        // inside a GeometryReader anchors to topLeading (SwiftUI quirk),
        // which manifested on device as an oval floating left-of-center.
        return Ellipse()
            .strokeBorder(
                Theme.muted.opacity(0.25),
                style: StrokeStyle(lineWidth: 2, dash: [6, 6])
            )
            .frame(width: w, height: h)
            .position(x: size.width / 2, y: size.height / 2)
    }

    private var accessibilityLabel: String {
        if faceStatus.boundingBox == nil {
            return "Position your face in the oval"
        }
        return faceStatus.matchesTargetPose
            ? "Pose held, capturing"
            : "Face detected, adjust head position"
    }

    // Map a Vision-normalized bounding box (origin bottom-left, not
    // mirrored) to a view-space CGRect, applying the front-camera
    // preview mirror on X. Pure; lives here so it's easy to unit test
    // on a future iteration.
    static func viewRect(from bbox: CGRect, in size: CGSize) -> CGRect {
        // Flip X for the mirrored preview:
        //   mirroredX = 1 - (x + w)
        let mirroredX = 1.0 - bbox.origin.x - bbox.size.width
        // Flip Y because SwiftUI's origin is top-left:
        //   topY = 1 - (y + h)
        let topY = 1.0 - bbox.origin.y - bbox.size.height

        return CGRect(
            x: mirroredX * size.width,
            y: topY * size.height,
            width: bbox.size.width * size.width,
            height: bbox.size.height * size.height
        )
    }
}
