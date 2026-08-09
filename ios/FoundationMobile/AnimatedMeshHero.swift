import SwiftUI
import Foundation

// Native SwiftUI equivalent of the web app's animated MeshHero (see
// docs/superpowers/specs/2026-08-09-light-editions-redesign-design.md §3).
// Wraps hero content in a living gradient mesh with an angled bottom cut,
// sourced from the active edition's Theme.palette.meshBase/meshBlobs.
// Editions without mesh data (the mobile-only security editions) render
// their content with no background layer at all — pixel-identical to
// pre-redesign behavior.
//
// MeshGradient requires iOS 18; pre-iOS-18 renders gracefully without gradient.
struct AnimatedMeshHero<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(meshBackground)
    }

    @ViewBuilder
    private var meshBackground: some View {
        if #available(iOS 18, *) {
            if let base = Theme.meshBase,
               let blobs = Theme.meshBlobs,
               blobs.count == 4 {
                TimelineView(.animation(paused: reduceMotion)) { timeline in
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: Self.meshPoints(at: timeline.date.timeIntervalSinceReferenceDate),
                        colors: Self.meshColors(base: base, blobs: blobs)
                    )
                }
                .clipShape(AngledCutShape())
            }
        }
        // else (pre-iOS-18, or no mesh data): no background layer at all.
    }

    /// 3x3 control-point grid for MeshGradient, in unit-square (0...1)
    /// space. Corners stay pinned so the mesh always fully covers its
    /// bounding rect; the 4 edge-midpoints and the center drift slowly on
    /// independent sine phases for an organic, non-repeating feel — the
    /// SwiftUI-native equivalent of the web mesh's 21-30s blob drift.
    static func meshPoints(at time: TimeInterval) -> [SIMD2<Float>] {
        func wobble(_ seed: Double, amplitude: Double = 0.05, speed: Double = 0.25) -> Float {
            Float(amplitude * sin(time * speed + seed))
        }
        return [
            SIMD2(0, 0),
            SIMD2(0.5 + wobble(0.0, amplitude: 0.03), 0 + wobble(1.4, amplitude: 0.03)),
            SIMD2(1, 0),
            SIMD2(0 + wobble(2.1, amplitude: 0.03), 0.5 + wobble(0.7)),
            SIMD2(0.5 + wobble(3.6), 0.5 + wobble(4.2)),
            SIMD2(1 + wobble(1.9, amplitude: 0.03), 0.5 + wobble(2.8)),
            SIMD2(0, 1),
            SIMD2(0.5 + wobble(5.0, amplitude: 0.03), 1 + wobble(0.3, amplitude: 0.03)),
            SIMD2(1, 1),
        ]
    }

    /// Maps base + 4 blob colors onto the 3x3 grid: blobs sit at the 4
    /// edge-midpoints (the points that actually drift), base fills the
    /// corners and center.
    static func meshColors(base: Color, blobs: [Color]) -> [Color] {
        guard blobs.count == 4 else { return Array(repeating: base, count: 9) }
        return [
            base, blobs[0], base,
            blobs[1], base, blobs[2],
            base, blobs[3], base,
        ]
    }
}

/// Angled-cut trapezoid — the SwiftUI equivalent of the web mesh hero's
/// `clip-path: polygon(0 0, 100% 0, 100% 62%, 0 100%)`.
struct AngledCutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
