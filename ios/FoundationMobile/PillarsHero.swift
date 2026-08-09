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
        AnimatedMeshHero {
            heroContent
        }
    }

    // A white-label profile (e.g. MoMA) can replace the composed
    // three-pillar wordmark with a single bundled hero image by setting
    // theme.branding.hero.mode = "image" in its profile JSON. Falls through
    // to the built-in pillars otherwise. Wrapped in AnimatedMeshHero above
    // so both modes get the same living-mesh background for editions that
    // carry mesh data.
    @ViewBuilder
    private var heroContent: some View {
        if let hero = AppConfig.shared.theme?.branding?.hero,
           hero.mode == "image",
           let assetName = Theme.palette.isDark ? (hero.darkAsset ?? hero.asset) : hero.asset {
            brandedHero(assetName)
        } else {
            pillars
        }
    }

    private var pillars: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Theme.text)
            pillar(asset: "PillarVoice", label: "Voice.", color: Theme.voice)
            pillar(asset: "PillarShare", label: "Share.", color: Theme.share)
            pillar(asset: "PillarMarket", label: "Market.", color: Theme.market)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Voice, Share, and Market")
    }

    // Bundled hero artwork, left-aligned and width-capped to sit in the same
    // space the pillar wordmark occupies. Height is left intrinsic so a
    // wordmark or full hero both lay out sensibly.
    private func brandedHero(_ assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Brand hero")
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

// The Foundation wordmark lockup, shared across the SignIn / Home / WebHome /
// Loading headers. A white-label profile (e.g. MoMA) replaces the
// built-in shield + "Foundation" wordmark with a bundled logo image by setting
// theme.branding.logo in its profile JSON; the default edition renders the
// built-in lockup byte-for-byte as before. Same palette-aware dark/light
// asset resolution as PillarsHero's branded hero.
struct BrandLockup: View {
    var iconSize: CGFloat = 24
    var textSize: CGFloat = 22
    var spacing: CGFloat = 10

    // Resolved branded logo imageset name, or nil for the default edition.
    private var brandedAsset: String? {
        guard let logo = AppConfig.shared.theme?.branding?.logo else { return nil }
        return Theme.palette.isDark ? (logo.darkAsset ?? logo.asset) : logo.asset
    }

    var body: some View {
        if let assetName = brandedAsset {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(height: textSize * 1.5)
                .accessibilityLabel("Foundation")
        } else {
            defaultLockup
        }
    }

    private var defaultLockup: some View {
        HStack(spacing: spacing) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Theme.brandGreen)
            HStack(spacing: 0) {
                Text("Found").foregroundStyle(Theme.text)
                Text("ation").foregroundStyle(Theme.brandGreen)
            }
            .font(.system(size: textSize, weight: .bold))
        }
    }
}
