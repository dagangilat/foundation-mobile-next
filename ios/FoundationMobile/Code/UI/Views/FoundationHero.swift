import Foundation
import SwiftUI

// Foundation's brand pieces, ported from the original Foundation shell
// (PillarsHero.swift and AnimatedMeshHero.swift, deleted in bfeab73):
//   - BrandLockup: shield + "Foundation" wordmark, used in every header.
//   - PillarsHero: "Your Voice. Share. Market." inside the mesh hero, shared by
//     the loading screen, Welcome and Home so they cannot drift apart.
//   - AnimatedMeshHero + AngledCutShape: the living gradient behind the hero.
//
// The white-label (AppConfig branding) branches of the originals are dropped:
// this app ships one edition.

/// The Foundation wordmark lockup: half-filled shield + "Found" "ation".
struct BrandLockup: View {
    var iconSize: CGFloat = 24
    var textSize: CGFloat = 22
    var spacing: CGFloat = 10

    var body: some View {
        HStack(spacing: spacing) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(FoundationTheme.accent)
            HStack(spacing: 0) {
                Text(verbatim: "Found").foregroundColor(FoundationTheme.text)
                Text(verbatim: "ation").foregroundColor(FoundationTheme.accent)
            }
            .font(.system(size: textSize, weight: .bold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Foundation"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// "Your / Voice. / Share. / Market." with the pillar icons, inside the mesh.
/// Icon edge is 40pt for a 48pt label (83%), matching the web hero.
struct PillarsHero: View {
    var textSize: CGFloat = 48

    private var iconSize: CGFloat { (textSize * 40.0 / 48.0).rounded() }
    private var rowSpacing: CGFloat { (textSize * 6.0 / 48.0).rounded() }

    var body: some View {
        AnimatedMeshHero {
            VStack(alignment: .leading, spacing: rowSpacing) {
                Text("Your")
                    .font(.system(size: textSize, weight: .bold))
                    .foregroundColor(FoundationTheme.text)
                pillar(asset: "PillarVoice", label: "Voice.", color: FoundationTheme.voice)
                pillar(asset: "PillarShare", label: "Share.", color: FoundationTheme.share)
                pillar(asset: "PillarMarket", label: "Market.", color: FoundationTheme.market)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Your Voice, Share, and Market"))
        }
    }

    private func pillar(asset: String, label: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: textSize, weight: .bold))
                .foregroundColor(color)
        }
    }
}

/// Wraps hero content in a living gradient mesh with an angled bottom cut.
///
/// iOS 18+: an animated 3x3 `MeshGradient` whose edge midpoints and centre
/// drift slowly; frozen when Reduce Motion is on.
/// iOS 16-17: a static fallback of soft radial blobs in the same colours over
/// the same base, clipped by the same shape.
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
            TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { timeline in
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: Self.meshPoints(at: timeline.date.timeIntervalSinceReferenceDate),
                    colors: Self.meshColors(base: FoundationTheme.meshBase, blobs: FoundationTheme.meshBlobs)
                )
            }
            .clipShape(AngledCutShape())
            .accessibilityHidden(true)
        } else {
            StaticMeshBackground()
                .clipShape(AngledCutShape())
                .accessibilityHidden(true)
        }
    }

    /// 3x3 control-point grid in unit-square space. Corners stay pinned so the
    /// mesh always covers its rect; the edge midpoints and the centre drift on
    /// independent sine phases.
    static func meshPoints(at time: TimeInterval) -> [SIMD2<Float>] {
        func wobble(_ seed: Double, amplitude: Double = 0.05, speed: Double = 0.25) -> Float {
            Float(amplitude * sin(time * speed + seed))
        }
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(0.5 + wobble(0.0, amplitude: 0.03), 0 + wobble(1.4, amplitude: 0.03)),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0 + wobble(2.1, amplitude: 0.03), 0.5 + wobble(0.7)),
            SIMD2<Float>(0.5 + wobble(3.6), 0.5 + wobble(4.2)),
            SIMD2<Float>(1 + wobble(1.9, amplitude: 0.03), 0.5 + wobble(2.8)),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0.5 + wobble(5.0, amplitude: 0.03), 1 + wobble(0.3, amplitude: 0.03)),
            SIMD2<Float>(1, 1),
        ]
    }

    /// Blobs sit on the four edge midpoints (the points that drift); the base
    /// fills the corners and the centre.
    static func meshColors(base: Color, blobs: [Color]) -> [Color] {
        guard blobs.count == 4 else { return Array(repeating: base, count: 9) }
        return [
            base, blobs[0], base,
            blobs[1], base, blobs[2],
            base, blobs[3], base,
        ]
    }
}

/// Pre-iOS-18 stand-in for the mesh: soft radial blobs (each fading to clear,
/// so no blur pass is needed) over the base wash,
/// placed like the web hero (green top, cyan left, blue right, violet bottom).
private struct StaticMeshBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let radius = max(geometry.size.width, geometry.size.height) * 0.6
            ZStack {
                FoundationTheme.meshBase
                blob(FoundationTheme.meshBlobs[0], center: UnitPoint(x: 0.55, y: 0.0), radius: radius)
                blob(FoundationTheme.meshBlobs[1], center: UnitPoint(x: 0.0, y: 0.55), radius: radius)
                blob(FoundationTheme.meshBlobs[2], center: UnitPoint(x: 1.0, y: 0.5), radius: radius)
                blob(FoundationTheme.meshBlobs[3], center: UnitPoint(x: 0.4, y: 1.0), radius: radius)
            }
        }
    }

    private func blob(_ color: Color, center: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(
            colors: [color, color.opacity(0)],
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    }
}

/// Angled-cut trapezoid, the SwiftUI twin of the web hero's
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

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        BrandLockup()
        PillarsHero()
        Spacer()
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(FoundationTheme.bg)
}
