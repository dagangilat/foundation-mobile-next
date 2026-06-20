import SwiftUI

// Post-verification "You're verified" screen (PoH onboarding, Variant B —
// the trust-tier ladder). Shown once humanity is sealed. Renders the achieved
// trust tier on a ladder (Low / Standard / High Security) so a tiered-fallback
// outcome reads clearly: the tier you reached is highlighted, lower tiers are
// shown as cleared, and a higher tier (if any) is locked with an upgrade hint.
//
// Everything edition-specific is injected:
//   • `tier`         — the achieved AppConfig.Profile.TrustTier
//   • `documentNoun` — the credential word for this edition ("passport",
//                      "driving licence", …); copy uses possessive ("your
//                      <noun>'s chip") to stay grammatical for any noun.
// Colors come from the active Theme palette so the screen white-labels with
// the rest of the app. Design source: docs/design/poh-onboarding (Variant B).
struct VerifiedView: View {
    let tier: AppConfig.Profile.TrustTier
    let documentNoun: String
    /// Primary CTA — proceed into Foundation (mirrors "Connect to Foundation").
    var onEnter: () -> Void
    /// Optional "Upgrade now" affordance, shown only below High Security.
    var onUpgrade: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer(minLength: 8)
                header
                ladder
                if tier < .high { upsell }
                Spacer(minLength: 8)
                Text("Your proof lives on this device · nothing on our servers")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 360)
        }
    }

    // MARK: - Header (seal + title + assurance subtitle)

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(accent.opacity(0.18), lineWidth: 6).scaleEffect(1.16))
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(Theme.onAccent)
            }
            Text("You're verified")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var subtitle: String {
        switch tier {
        case .high:     return "Highest assurance — your \(documentNoun)'s chip checked out"
        case .standard: return "Standard assurance — verified from your \(documentNoun)"
        case .low:      return "Verified on this device"
        }
    }

    // MARK: - Tier ladder

    private var ladder: some View {
        VStack(spacing: 8) {
            rungRow(.high)
            rungRow(.standard)
            rungRow(.low)
        }
    }

    private func rungRow(_ rung: AppConfig.Profile.TrustTier) -> some View {
        let status = rungStatus(rung)
        return HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(status == .locked ? Color.clear : rungAccent(rung))
                    .overlay(
                        Circle().stroke(status == .locked ? Theme.border : Color.clear, lineWidth: 2)
                    )
                    .frame(width: 22, height: 22)
                Image(systemName: status == .locked ? "lock.fill" : "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(status == .locked ? Theme.muted : Theme.onAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(rungName(rung))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(status == .locked ? Theme.muted : Theme.text)
                Text(rungMeta(rung, status))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if status == .current {
                Text("YOU'RE HERE")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(rungAccent(rung))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(rungAccent(rung).opacity(0.18))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(status == .current ? rungAccent(rung).opacity(0.10) : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(status == .current ? rungAccent(rung) : Theme.border, lineWidth: 1)
        )
        .opacity(status == .locked ? 0.55 : 1)
    }

    private enum RungStatus { case done, current, locked }

    private func rungStatus(_ rung: AppConfig.Profile.TrustTier) -> RungStatus {
        if rung == tier { return .current }
        return rung < tier ? .done : .locked
    }

    private func rungName(_ rung: AppConfig.Profile.TrustTier) -> String {
        switch rung {
        case .high:     return "High Security"
        case .standard: return "Standard Security"
        case .low:      return "Low Security"
        }
    }

    private func rungMeta(_ rung: AppConfig.Profile.TrustTier, _ status: RungStatus) -> String {
        switch rung {
        case .high:
            return status == .locked
                ? "Needs your \(documentNoun)'s chip"
                : "Chip authenticated · face matched to your \(documentNoun)"
        case .standard:
            return status == .current ? "Document verified · you can vote" : "Document verified"
        case .low:
            return "Device + liveness"
        }
    }

    // MARK: - Upgrade hint + buttons

    private var upsell: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(Theme.brandCyan)
            Text("Scan your \(documentNoun)'s chip anytime to reach High Security.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.brandCyan.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.brandCyan.opacity(0.32), lineWidth: 1))
    }

    private var buttons: some View {
        VStack(spacing: 4) {
            Button(action: onEnter) {
                Text("Enter Foundation")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGreen)
                    .cornerRadius(14)
            }
            if tier < .high, let onUpgrade {
                Button(action: onUpgrade) {
                    Text("Upgrade now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
            }
        }
    }

    // MARK: - Colors

    /// Accent for the achieved tier (header seal + emphasis).
    private var accent: Color { tier == .standard ? Theme.brandCyan : Theme.brandGreen }

    /// Accent for a specific rung when it is the current one.
    private func rungAccent(_ rung: AppConfig.Profile.TrustTier) -> Color {
        rung == .standard ? Theme.brandCyan : Theme.brandGreen
    }
}

#if DEBUG
#Preview("High — passport") {
    VerifiedView(tier: .high, documentNoun: "passport", onEnter: {})
}

#Preview("Standard — driving licence") {
    VerifiedView(tier: .standard, documentNoun: "driving licence", onEnter: {}, onUpgrade: {})
}

#Preview("Low — device only") {
    VerifiedView(tier: .low, documentNoun: "identity document", onEnter: {})
}
#endif
