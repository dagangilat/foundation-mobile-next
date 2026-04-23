import SwiftUI

// Shown while Firebase Auth resolves the initial state. Matches the HomeView
// hero exactly (shield + wordmark + Solana pill + three pillars) so the user
// perceives UILaunchScreen → LoadingView → HomeView as one continuous opening
// sequence. The subtle spinner at the bottom is the only thing that differs.
struct LoadingView: View {
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
        HStack(spacing: 10) {
            ProgressView()
                .tint(Theme.brandGreen)
                .controlSize(.small)
            Text("Checking sign-in…")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
