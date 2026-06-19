import SwiftUI

// Phase 4 — prompt bar + progress view for the active-liveness scan.
//
// Two small SwiftUI views kept together because they always render as a
// pair (prompt on top, progress bar below) in CaptureView. Both receive
// plain-value inputs (no ObservedObject) so they re-render cleanly when
// the parent recomputes on coordinator.state changes.

struct PosePromptBar: View {
    let pose: LivenessPose
    // Face-tracker view signal. Used to show a dim "bring your face into
    // frame" subtitle when no face is seen; and a low-light hint when a
    // face is seen but confidence is below the threshold the coordinator
    // uses for matchesTargetPose.
    let faceStatus: FaceStatus

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: pose.sfSymbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text(pose.prompt)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            if let subtitle = subtitleCopy {
                HStack {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hold your head facing \(pose.accessibilityDirection)")
        .accessibilityValue(subtitleCopy ?? "")
    }

    private var subtitleCopy: String? {
        if faceStatus.boundingBox == nil {
            return "Bring your face into the frame"
        }
        if faceStatus.confidence > 0, faceStatus.confidence < FaceTracker.minConfidence {
            return "Move to better lighting"
        }
        return nil
    }
}

struct PoseProgressBar: View {
    let captured: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: Double(captured), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .tint(Theme.brandGreen)
            HStack {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan progress")
        .accessibilityValue("\(captured) of \(total) poses complete")
    }

    private var summary: String {
        let displayIndex = min(captured + 1, total)
        return captured >= total
            ? "Poses complete"
            : "Pose \(displayIndex) of \(total)"
    }
}

extension LivenessPose {
    // Spoken-English direction for VoiceOver. Kept separate from `prompt`
    // so the visual copy can vary without breaking the accessibility
    // label's readability.
    var accessibilityDirection: String {
        switch self {
        case .straight: return "forward"
        case .left: return "to your left"
        case .right: return "to your right"
        case .up: return "upward"
        case .down: return "downward"
        }
    }
}
