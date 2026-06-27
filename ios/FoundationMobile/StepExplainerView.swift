import SwiftUI

// Explain-before-you-do screen (design: poh-flow2 C1/C2/C3). One per capture
// stage; the illustration is a lightweight, looping SwiftUI animation per phase
// (no external assets). Copy comes from ExplainerCatalog (tested). Theme-aware.
struct StepExplainerView: View {
    let step: ExplainerStep
    var onReady: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                StepIllustration(kind: step.kind)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
                Text(step.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(step.body)
                    .font(.body)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
                Button(action: onReady) {
                    Text(step.cta)
                        .font(.headline)
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brandGreen)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 420)
        }
    }
}

// Per-phase looping illustration. Each conveys the gesture the user is about to
// perform: a head turning side-to-side (face), a scan line sweeping a document
// (scan), radiating NFC rings from a phone (chip).
private struct StepIllustration: View {
    let kind: ExplainerKind
    @State private var animate = false

    var body: some View {
        content
            .onAppear { animate = true }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .face:
            Image(systemName: "face.smiling")
                .font(.system(size: 60))
                .foregroundStyle(Theme.brandGreen)
                .rotationEffect(.degrees(animate ? 16 : -16))
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animate)
        case .scan:
            ZStack {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.brandGreen)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, Theme.brandGreen.opacity(0.9), .clear],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: 130, height: 3)
                    .offset(y: animate ? 36 : -36)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animate)
            }
            .frame(width: 130, height: 90)
            .clipped()
        case .chip:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Theme.brandGreen.opacity(0.5), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(animate ? 2.6 : 0.7)
                        .opacity(animate ? 0.0 : 0.7)
                        .animation(
                            .easeOut(duration: 1.5).repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.4),
                            value: animate)
                }
                Image(systemName: "iphone")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.brandGreen)
            }
        }
    }
}

#if DEBUG
#Preview {
    StepExplainerView(step: ExplainerCatalog.step(.chip, profile: AppConfig.shared.profile), onReady: {})
}
#endif
