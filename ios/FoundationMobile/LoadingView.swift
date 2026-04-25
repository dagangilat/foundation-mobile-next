import SwiftUI

// Shown while Firebase Auth resolves the initial state. Matches the HomeView
// hero exactly (shield + wordmark + Solana pill + three pillars) so the user
// perceives UILaunchScreen → LoadingView → HomeView as one continuous opening
// sequence. Footer rotates through plausible phases as time elapses so a slow
// cold launch (Debug + Pods + Firebase init) never feels frozen — the copy
// changes even when no real progress is observable to the view.
struct LoadingView: View {
    var message: String? = nil
    @State private var phaseIndex: Int = 0
    @State private var startedAt: Date = Date()

    // Rotating copy for cold-launch waits. Wall-clock thresholds come from
    // AppConfig (loading.phaseThresholdsMs); the copy is local since it's
    // brand-voice rather than tunable.
    private static let phaseTexts: [String] = [
        "Loading Foundation…",
        "Verifying device trust…",
        "Connecting to Solana…",
        "Almost ready…",
    ]
    private static var phases: [(after: TimeInterval, text: String)] {
        let thresholds = AppConfig.shared.loading.phaseThresholdsMs
        return zip(thresholds, phaseTexts).map { ($0 / 1000.0, $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            solanaPill
            hero
            Spacer(minLength: 0)
            footerSpinner
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            // No fancy timer — drive phase advances off Task.sleep so the
            // animation still works under SwiftUI's view-identity changes.
            startedAt = Date()
            for (i, phase) in Self.phases.enumerated() where i > 0 {
                let target = startedAt.addingTimeInterval(phase.after)
                let delay = target.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    phaseIndex = i
                }
            }
        }
    }

    private var currentPhaseText: String {
        if let message { return message }
        return Self.phases[phaseIndex].text
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.brandGreen)
            HStack(spacing: 0) {
                Text("Found").foregroundStyle(.white)
                Text("ation").foregroundStyle(Theme.brandGreen)
            }
            .font(.system(size: 22, weight: .bold))
        }
    }

    private var solanaPill: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.brandGreen).frame(width: 8, height: 8)
            Text("Powered by Solana Blockchain")
                .font(.callout)
                .foregroundStyle(Theme.brandGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.pillBg)
        .cornerRadius(999)
    }

    // KEEP IN SYNC across three surfaces — Foundation's hero is one
    // visual that lives in three repos (storyboards can't run code,
    // and the web app + plantagoai have their own renderers):
    //   1. ios/FoundationMobile/LaunchScreen.storyboard  (UIKit static)
    //   2. foundation-global/evoting-frontend            (web app hero)
    //   3. plantagoai/...                                (org-level source of truth)
    // Any text / icon / color / weight change here must land in all
    // three. Treat plantagoai as the spec; the other two follow.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
            pillar(icon: "waveform", label: "Voice.", color: Theme.voice)
            pillar(icon: "square.and.arrow.up", label: "Share.", color: Theme.share)
            pillar(icon: "chart.line.uptrend.xyaxis", label: "Market.", color: Theme.market)
        }
    }

    private func pillar(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(color)
            Text(label).font(.system(size: 48, weight: .bold)).foregroundStyle(color)
        }
    }

    private var footerSpinner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(Theme.brandGreen)
                    .controlSize(.small)
                Text(currentPhaseText)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .transition(.opacity)
                    .id(currentPhaseText)
            }
            // Indeterminate progress bar — drawn as a slim 2pt capsule with a
            // moving brand-green segment. Honest about not knowing the ETA;
            // gives the eye something to track while iOS finishes warming up.
            IndeterminateBar()
                .frame(height: 2)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct IndeterminateBar: View {
    @State private var sweepOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.muted.opacity(0.18))
                Capsule()
                    .fill(Theme.brandGreen)
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: sweepOffset * geo.size.width)
            }
            .clipShape(Capsule())
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    sweepOffset = 1.0
                }
            }
        }
    }
}
