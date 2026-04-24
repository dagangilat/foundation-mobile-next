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
            ZStack {
                // Soft always-on guide ellipse (centered, ~60% width).
                // Helps the user find the frame before a face is even
                // locked on. Dashed so it reads as a hint not a target.
                guideEllipse(in: geo.size)

                if let bbox = faceStatus.boundingBox {
                    let rect = Self.viewRect(from: bbox, in: geo.size)
                    Ellipse()
                        .stroke(
                            faceStatus.matchesTargetPose
                                ? Theme.brandGreen
                                : Theme.muted.opacity(0.7),
                            style: StrokeStyle(lineWidth: 3)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .animation(.easeInOut(duration: 0.12), value: rect)
                        .animation(
                            .easeInOut(duration: 0.15),
                            value: faceStatus.matchesTargetPose
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func guideEllipse(in size: CGSize) -> some View {
        let w = size.width * 0.6
        let h = size.height * 0.75
        return Ellipse()
            .strokeBorder(
                Theme.muted.opacity(0.25),
                style: StrokeStyle(lineWidth: 2, dash: [6, 6])
            )
            .frame(width: w, height: h)
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
