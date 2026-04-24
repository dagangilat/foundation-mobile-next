import SwiftUI

struct HomeView: View {
    let claims: Claims

    @StateObject private var firestore = FirestoreService.shared
    @StateObject private var attestation = AttestationCoordinator.shared

    private var ringText: String? {
        let ring = firestore.userDoc?.ring ?? claims.ring
        guard let ring else { return nil }
        return Theme.ringLabels[ring] ?? "Ring \(ring)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                solanaPill
                hero
                ringCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .onAppear {
            firestore.observeUser(uid: claims.uid)
            attestation.start()
        }
    }

    private var header: some View {
        HStack {
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
            Spacer()
            Button {
                try? AuthService.shared.signOut()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(Theme.muted)
            }
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

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Signed in")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(claims.email ?? claims.uid)
                .font(.callout)
                .foregroundStyle(.white)
            if let ringText {
                Text(ringText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.brandGreen)
                    .padding(.top, 4)
            } else {
                Text("Ring pending — awaiting first-sign-in claim")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            attestationRow
                .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var attestationRow: some View {
        HStack(spacing: 8) {
            Image(systemName: attestationIcon)
                .font(.caption)
                .foregroundStyle(attestationColor)
            Text(attestationLabel)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var attestationIcon: String {
        switch attestation.state {
        case .idle, .attesting: return "hourglass"
        case .unsupported: return "iphone.slash"
        case .alreadyAttested, .attested: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var attestationColor: Color {
        switch attestation.state {
        case .attested, .alreadyAttested: return Theme.brandGreen
        case .failed: return .orange
        default: return Theme.muted
        }
    }

    private var attestationLabel: String {
        switch attestation.state {
        case .idle: return "App Attest — queued"
        case .unsupported: return "App Attest — simulator (debug provider)"
        case .attesting: return "App Attest — attesting…"
        case .alreadyAttested: return "App Attest — device attested"
        case .attested: return "App Attest — device attested"
        case .failed(let msg): return "App Attest — failed: \(msg)"
        }
    }
}
