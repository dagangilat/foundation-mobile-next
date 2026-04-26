import SwiftUI

// Foundation's hero is one visual rendered in three places —
//   1. ios/FoundationMobile/LaunchScreen.storyboard  (UIKit static; can't share code)
//   2. foundation-mobile-claude (this file, used by LoadingView + HomeView)
//   3. foundation-global/evoting-frontend + plantagoai (web hero, lucide-react)
// Within iOS, LoadingView and HomeView previously each defined their own
// hero/pillar/solanaPill helpers. The two definitions drifted (font
// weights, spacing, icon sizing) on every change. Centralizing into
// SolanaPill + PillarsHero makes drift structurally impossible: every
// surface that wants the hero imports the same view.
//
// Icon assets (Images.xcassets/Pillar{Voice,Share,Market}) are shared
// lucide SVGs. Icon edge = 40pt = 83% of the 48pt pillar label,
// matching the web ratios.

struct SolanaPill: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.brandGreen)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("Powered by Solana Blockchain")
                .font(.callout)
                .foregroundStyle(Theme.brandGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.pillBg)
        .cornerRadius(999)
    }
}

struct PillarsHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
            pillar(asset: "PillarVoice", label: "Voice.", color: Theme.voice)
            pillar(asset: "PillarShare", label: "Share.", color: Theme.share)
            pillar(asset: "PillarMarket", label: "Market.", color: Theme.market)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Voice, Share, and Market")
    }

    private func pillar(asset: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(color)
        }
    }
}
