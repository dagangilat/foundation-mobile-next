import SwiftUI

/// Home's status card: the single entry point into verification.
///
/// It folds together the two halves of becoming verified:
///   1. the passport scan + on-device registration proof (formerly only
///      reachable from the Identity tab, whose PassportCard showed progress
///      and errors), started here with "Scan passport";
///   2. Foundation's own L2 verification (`FoundationVerificationManager`),
///      started here once the passport is registered.
///
/// No business logic lives here: every action calls the same code the old
/// Identity tab and verify card called.
struct FoundationVerifyCardView: View {
    @EnvironmentObject private var verification: FoundationVerificationManager
    @EnvironmentObject private var passportManager: PassportManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var passportViewModel: PassportViewModel

    /// Opens the passport scan flow (ScanPassportView), owned by HomeView.
    let onScanPassport: () -> Void

    private enum CardState: Equatable {
        case notScanned
        case building
        case registrationFailed
        case waitlisted
        case ready
        case working
        case verificationFailed(String)
        case verified
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FoundationSectionLabel("Status")
                Spacer()
                if cardState == .verified {
                    Text("Verified")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(FoundationTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FoundationTheme.accentTint, in: Capsule())
                }
            }
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(FoundationTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(caption)
                .font(.system(size: 15))
                .foregroundColor(FoundationTheme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            detail
        }
        .foundationCard()
        .animation(.easeInOut(duration: 0.2), value: cardState)
    }

    // MARK: - State

    private var cardState: CardState {
        if case .verified = verification.state { return .verified }
        guard passportManager.passport != nil else { return .notScanned }
        if passportViewModel.processingStatus == .failure { return .registrationFailed }
        if userManager.user?.status == .unscanned {
            return passportViewModel.processingStatus == .processing ? .building : .notScanned
        }
        // Scanned, but no registration proof: the country is waitlisted.
        if userManager.registerZkProof == nil { return .waitlisted }
        switch verification.state {
        case .starting, .awaitingProof, .polling: return .working
        case .failed(let message): return .verificationFailed(message)
        default: return .ready
        }
    }

    private var title: LocalizedStringKey {
        switch cardState {
        case .notScanned: "Not verified yet"
        case .building: "Building your proof"
        case .registrationFailed: "Something went wrong"
        case .waitlisted: "Not available yet"
        case .ready: "Passport checked"
        case .working: "Verifying…"
        case .verificationFailed: "Not verified yet"
        case .verified: "You're a verified person"
        }
    }

    private var caption: String {
        switch cardState {
        case .notScanned:
            String(localized: "Verify once with your passport's chip to show you're a real, unique person. Your name, photo and passport number stay on this phone.")
        case .building:
            String(localized: "This happens on your phone. Your name, photo and passport number are not uploaded.")
        case .registrationFailed:
            passportViewModel.isPassportFailedByImpossibleRevocation
                ? String(localized: "This passport is already linked to another ID. Restore the ID you used before.")
                : String(localized: "We couldn't finish your proof. Scan your passport again to retry.")
        case .waitlisted:
            String(localized: "Passports from your country can't be verified yet.")
        case .ready:
            String(localized: "One last step: share a private proof with Foundation to finish verifying.")
        case .working:
            String(localized: "Waiting for Foundation to confirm your proof.")
        case .verificationFailed(let message):
            message
        case .verified:
            String(localized: "When a site asks, you can prove this without sharing your name or passport details.")
        }
    }

    // MARK: - Per-state detail

    @ViewBuilder
    private var detail: some View {
        switch cardState {
        case .notScanned:
            Button(action: onScanPassport) {
                Label("Scan passport", systemImage: "person.text.rectangle")
            }
            .buttonStyle(FoundationPrimaryButtonStyle())
            .padding(.top, 4)
        case .building:
            buildingDetail
        case .registrationFailed:
            if let reason = passportViewModel.lastErrorMessage, !reason.isEmpty {
                Text(verbatim: reason)
                    .font(.system(size: 13))
                    .foregroundColor(FoundationTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if !passportViewModel.isPassportFailedByImpossibleRevocation {
                // Starts over from the passport scan (MRZ, then chip), so a
                // bad chip read is redone rather than re-proving the same data.
                Button("Try again", action: onScanPassport)
                    .buttonStyle(FoundationPrimaryButtonStyle())
                    .padding(.top, 4)
            }
            // The app's own log file: send it by any app (Mail, Messages,
            // AirDrop, Files) without a mail account set up on the phone.
            ShareLink(item: AppLogExport(), preview: SharePreview("Foundation app log")) {
                Label("Share app log", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(FoundationTextButtonStyle())
            .frame(maxWidth: .infinity)
        case .waitlisted:
            EmptyView()
        case .ready:
            Button("Finish verification") {
                Task { await verification.beginVerification() }
            }
            .buttonStyle(FoundationPrimaryButtonStyle())
            .padding(.top, 4)
        case .working:
            Button(action: {}) {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(FoundationTheme.onAccent)
                    Text("Working…")
                }
            }
            .buttonStyle(FoundationPrimaryButtonStyle())
            .disabled(true)
            .padding(.top, 4)
        case .verificationFailed:
            Button("Try again") {
                Task { await verification.beginVerification() }
            }
            .buttonStyle(FoundationPrimaryButtonStyle())
            .padding(.top, 4)
        case .verified:
            HStack(spacing: 8) {
                chip("Passport chip", systemImage: "memorychip")
                chip("Unique person", systemImage: "person.crop.circle.badge.checkmark")
            }
        }
    }

    /// The on-device registration, shown as the "Building your proof" steps.
    /// Reading the chip already checked the passport signature and the chip,
    /// so those two rows are done; the last two follow `proofState`.
    private var buildingDetail: some View {
        let isRegistering = passportViewModel.proofState == .createProfile
            || passportViewModel.proofState == .finalizing

        return VStack(alignment: .leading, spacing: 12) {
            stepRow("Passport signature checked", state: .done)
            stepRow("Chip is genuine", state: .done)
            stepRow("Creating your private proof…", state: isRegistering ? .done : .active)
            stepRow("Registering you as a unique person", state: isRegistering ? .active : .pending)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FoundationTheme.border)
                    Capsule()
                        .fill(FoundationTheme.accent)
                        .frame(width: geometry.size.width * min(max(passportViewModel.overallProgress, 0), 1))
                        .animation(.easeInOut, value: passportViewModel.overallProgress)
                }
            }
            .frame(height: 6)
            .padding(.top, 4)
            Text("Keep the app open. This takes a few seconds.")
                .font(.system(size: 14))
                .foregroundColor(FoundationTheme.muted)
        }
        .padding(.top, 4)
    }

    private enum StepState { case done, active, pending }

    private func stepRow(_ label: LocalizedStringKey, state: StepState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                switch state {
                case .done:
                    Circle()
                        .fill(FoundationTheme.accent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FoundationTheme.onAccent)
                case .active:
                    ProgressView()
                        .tint(FoundationTheme.accent)
                        .controlSize(.small)
                case .pending:
                    Circle()
                        .stroke(FoundationTheme.border, lineWidth: 2)
                        .padding(1)
                }
            }
            .frame(width: 24, height: 24)
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(state == .pending ? FoundationTheme.muted : FoundationTheme.text)
        }
    }

    private func chip(_ label: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FoundationTheme.accent)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(FoundationTheme.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(FoundationTheme.bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FoundationTheme.border, lineWidth: 1)
        )
    }
}

#Preview {
    FoundationVerifyCardView(onScanPassport: {})
        .padding(24)
        .background(FoundationTheme.bg)
        .environmentObject(FoundationVerificationManager.shared)
        .environmentObject(PassportManager())
        .environmentObject(UserManager())
        .environmentObject(PassportViewModel())
}
