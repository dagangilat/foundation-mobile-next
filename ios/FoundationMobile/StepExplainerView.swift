import SwiftUI

// Explain-before-you-do screen (design: poh-flow2 C1/C2/C3). One per capture
// stage; the illustration slot is a placeholder pending motion design. Copy
// comes from ExplainerCatalog (tested). Theme-aware.
struct StepExplainerView: View {
    let step: ExplainerStep
    var onReady: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.surface)
                    .frame(height: 220)
                    .overlay(
                        Image(systemName: glyph)
                            .font(.system(size: 52))
                            .foregroundStyle(Theme.brandGreen)
                    )
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

    private var glyph: String {
        switch step.kind {
        case .scan: return "doc.viewfinder"
        case .chip: return "wave.3.right.circle"
        case .face: return "face.smiling"
        }
    }
}

#if DEBUG
#Preview {
    StepExplainerView(step: ExplainerCatalog.step(.chip, profile: AppConfig.shared.profile), onReady: {})
}
#endif
