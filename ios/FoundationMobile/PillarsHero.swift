import SwiftUI

// Foundation's hero is one visual rendered in three places —
//   1. ios/FoundationMobile/LaunchScreen.storyboard  (UIKit static; can't share code)
//   2. foundation-mobile-claude (this file, used by LoadingView + HomeView)
//   3. foundation-global/evoting-frontend + plantagoai (web hero, lucide-react)
// Centralizing the SwiftUI hero into PillarsHero makes drift between
// LoadingView and HomeView structurally impossible.
//
// Icon assets (Images.xcassets/Pillar{Voice,Share,Market}) are shared
// lucide SVGs. Icon edge = 40pt = 83% of the 48pt pillar label,
// matching the web ratios.
//
// (Previously this file also defined a SolanaPill view for the
// "Powered by Solana Blockchain" badge; that was removed across all
// surfaces — the on-chain anchor verification badge in HomeView's
// verification grid is the canonical place to surface chain
// authenticity to the user.)

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
