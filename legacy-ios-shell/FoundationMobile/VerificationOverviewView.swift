import SwiftUI

// PoH overview checklist (design: poh-flow2 screen B). Shown after auth, before
// capture — sets expectations up front. Steps come from VerificationStepPlan
// (tested), so a chipless edition never lists a chip read. Theme-aware.
struct VerificationOverviewView: View {
    var onStart: () -> Void

    private var steps: [VerificationStep] {
        VerificationStepPlan.steps(for: AppConfig.shared.profile)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                pill
                VStack(alignment: .leading, spacing: 8) {
                    Text("Let's confirm you're human")
                        .font(.system(size: 25, weight: .bold)).foregroundStyle(Theme.text)
                    Text("A few quick steps. Everything happens on your phone.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    row(number: "\(idx + 1)", filled: false, title: step.title, sub: step.subtitle)
                }
                row(number: "✓", filled: true,
                    title: "You're a verified human", sub: "A proof — never your photos")
                Spacer(minLength: 0)
                Button(action: onStart) {
                    Text("Start").font(.headline).foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.brandGreen).cornerRadius(14)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 28).frame(maxWidth: 420)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
            Text("Proof of human · about a minute")
        }
        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.brandGreen)
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(Capsule().fill(Theme.brandGreen.opacity(0.13)))
    }

    private func row(number: String, filled: Bool, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(filled ? Theme.brandGreen : Theme.brandGreen.opacity(0.14))
                    .frame(width: 30, height: 30)
                Text(number).font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(filled ? Theme.onAccent : Theme.brandGreen)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
                Text(sub).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview { VerificationOverviewView(onStart: {}) }
#endif
