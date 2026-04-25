import SwiftUI
import UIKit

// Diagnostic dump + send-to-support UI. The home screen surfaces a
// single "Support" button; tapping it presents this sheet, which is the
// only place the user-facing build exposes raw technical state — App
// Attest status, mopro-smoke wiring, multiplier2 proof, commitment hash
// suffix, anchor lifecycle.
//
// "Send to Support" calls FunctionsService.submitSupportTicket which
// writes a Firestore /support/{uuid} doc. Hard invariant on the wire +
// at rest: NO personal details (uid, email, display name, ring) make
// the trip — only the diagnostic strings and a server-generated ticket
// id. The ticket id is shown to the user with a Copy button so they
// can quote it in a separate channel if they want to follow up.

struct SupportSheet: View {
    @ObservedObject var attestation: AttestationCoordinator
    @ObservedObject var capture: CaptureCoordinator
    let proofSmoke: SmokeProofResult

    @Environment(\.dismiss) private var dismiss
    @StateObject private var tracker = SupportSessionTracker.shared

    @State private var phase: Phase = .idle
    @State private var copiedTicketId: Bool = false

    enum Phase: Equatable {
        case idle
        case sending
        case sent(ticketId: String)
        case failed(message: String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    diagnosticsCard
                    actionButton
                    resultCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Support & diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandGreen)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Sections

    private var intro: some View {
        Text("Hit a wall? Send your device's technical state to the Foundation team. **No personal info** travels with this — no email, no name, no identity. Just the diagnostic state below.")
            .font(.callout)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            section(title: "Device") {
                row(label: "Model", value: deviceModelString)
                row(label: "iOS", value: iosVersionString)
                row(label: "App", value: "\(appVersionString) (\(buildVersionString))")
            }
            divider
            section(title: "Profile") {
                row(label: "ID", value: profileIdString)
            }
            divider
            section(title: "App Attest") {
                row(label: "State", value: attestationDescription)
            }
            divider
            section(title: "MOPRO / multiplier2") {
                row(label: "Bridge", value: moproBridgeDescription)
                row(label: "Proof", value: moproProofDescription)
            }
            divider
            section(title: "Humanity") {
                row(label: "State", value: humanityStateDescription)
                row(label: "Commitment", value: latestCommitmentDescription)
                row(label: "Anchor", value: anchorStatusDescription)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var actionButton: some View {
        let isSending: Bool = {
            if case .sending = phase { return true }
            return false
        }()
        let isSent: Bool = {
            if case .sent = phase { return true }
            return false
        }()
        let atLimit = tracker.isAtLimit
        let disabled = isSending || isSent || atLimit
        VStack(spacing: 6) {
            Button {
                send()
            } label: {
                HStack(spacing: 10) {
                    if isSending { ProgressView().controlSize(.small).tint(.black) }
                    Image(systemName: buttonIcon(isSent: isSent, atLimit: atLimit))
                    Text(buttonLabel(isSending: isSending, isSent: isSent, atLimit: atLimit))
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(atLimit ? Theme.muted : Theme.brandGreen)
                .cornerRadius(12)
                .opacity(disabled ? 0.7 : 1.0)
            }
            .disabled(disabled)
            // Quota copy — keeps the user informed without dominating the
            // sheet. Hidden when count is 0 / limit, surfaced after the
            // first send so they know the cap exists.
            if tracker.sentCount > 0 {
                Text(quotaCaption)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func buttonIcon(isSent: Bool, atLimit: Bool) -> String {
        if atLimit { return "clock.badge.exclamationmark" }
        return isSent ? "checkmark.circle.fill" : "paperplane.fill"
    }

    private func buttonLabel(isSending: Bool, isSent: Bool, atLimit: Bool) -> String {
        if atLimit { return "Session limit reached — relaunch app" }
        if isSending { return "Sending…" }
        if isSent { return "Sent — thank you" }
        return "Send to Foundation Support"
    }

    private var quotaCaption: String {
        let remaining = tracker.remaining
        if remaining == 0 {
            return "Limit hit (\(tracker.maxPerSession) per session). Relaunch the app to reset."
        }
        return "\(remaining) of \(tracker.maxPerSession) sends remaining this session."
    }

    @ViewBuilder
    private var resultCard: some View {
        switch phase {
        case .sent(let ticketId):
            VStack(alignment: .leading, spacing: 10) {
                Text("Reference")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                HStack {
                    Text(ticketId)
                        .font(.callout.monospaced())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = ticketId
                        copiedTicketId = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            await MainActor.run { copiedTicketId = false }
                        }
                    } label: {
                        Image(systemName: copiedTicketId ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundStyle(copiedTicketId ? Theme.brandGreen : Theme.muted)
                    }
                }
                Text("Quote this ticket in any follow-up email so support can correlate.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.brandGreen.opacity(0.4)))
            .cornerRadius(10)
        case .failed(let msg):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn't send")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4)))
        case .idle, .sending:
            EmptyView()
        }
    }

    // MARK: - Send

    private func send() {
        guard !tracker.isAtLimit else { return }
        let payload = SubmitSupportTicketRequest(
            appAttest: attestationDescription,
            moproStatus: "\(moproBridgeDescription) — \(moproProofDescription)",
            humanityState: humanityStateDescription,
            latestCommitment: latestCommitmentDescription,
            anchorStatus: anchorStatusDescription,
            profileId: profileIdString,
            appVersion: appVersionString,
            buildVersion: buildVersionString,
            iosVersion: iosVersionString,
            deviceModel: deviceModelString
        )
        phase = .sending
        Task {
            do {
                let result = try await FunctionsService.shared.submitSupportTicket(payload)
                await MainActor.run {
                    tracker.recordSent()
                    phase = .sent(ticketId: result.ticketId)
                }
            } catch {
                await MainActor.run { phase = .failed(message: error.localizedDescription) }
            }
        }
    }

    // MARK: - Diagnostic strings (single source of truth — same strings
    // we render and the same strings we ship to the support ticket)

    private var deviceModelString: String { UIDevice.current.model }

    private var iosVersionString: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var buildVersionString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    private var profileIdString: String { AppConfig.shared.profile.id }

    private var attestationDescription: String {
        switch attestation.state {
        case .idle: return "queued"
        case .attesting: return "attesting"
        case .unsupported: return "simulator (debug provider)"
        case .alreadyAttested: return "attested (cached keyId)"
        case .attested: return "attested (fresh)"
        case .failed(let msg): return "failed: \(msg)"
        }
    }

    private var moproBridgeDescription: String {
        let prefix = MoproSmokeBridge.isLinked ? "linked" : "stub"
        return "\(prefix) — \(MoproSmokeBridge.hello())"
    }

    private var moproProofDescription: String {
        switch proofSmoke {
        case .ok(let inputs): return "ok (\(inputs.count) public inputs)"
        case .skipped: return "skipped — xcframework not linked"
        case .failed(let msg): return "failed: \(msg)"
        }
    }

    private var humanityStateDescription: String {
        switch capture.state {
        case .idle: return "not yet verified"
        case .unsupported: return "unsupported device"
        case .needsAttestation: return "App Attest pending"
        case .readyForPose(_, let captured, let total):
            return "capturing poses (\(captured)/\(total))"
        case .readyForPassport: return "ready to scan passport"
        case .scanningPassport: return "scanning passport chip"
        case .passportReady: return "passport scanned, ready to verify"
        case .readyForDocumentPhoto: return "ready to capture document"
        case .documentPhotoReady: return "document photo captured, ready to verify"
        case .readyForVerification: return "ready to verify"
        case .verifying(let p): return p == .signing ? "signing" : "sealing"
        case .sealed: return "sealed"
        case .failed(let stage, let msg): return "failed [\(stageName(stage))]: \(msg)"
        }
    }

    private func stageName(_ stage: CaptureCoordinator.FailureStage) -> String {
        switch stage {
        case .poseCapture: return "pose-capture"
        case .livenessTimeout: return "liveness-timeout"
        case .passportScan: return "passport-scan"
        case .verify: return "verify"
        }
    }

    private var latestCommitmentDescription: String {
        guard case .sealed(let commitment) = capture.state else {
            return "n/a — no sealed commitment yet"
        }
        let hex = commitment.commitmentHashHex
        guard hex.count > 16 else { return hex }
        return "\(hex.prefix(12))…\(hex.suffix(4))"
    }

    private var anchorStatusDescription: String {
        switch capture.anchorStatus {
        case .notAttempted: return "n/a"
        case .pending: return "pending"
        case .completed(let r):
            switch r.status {
            case "anchored":
                if let slot = r.slot { return "anchored · slot \(slot)" }
                return "anchored"
            case "queued": return "queued"
            case "anchor-failed": return "anchor-failed (retrying)"
            default:
                return r.status ?? (r.accepted ? "accepted" : "rejected")
            }
        case .failed(let msg): return "audit failed: \(msg.prefix(40))"
        }
    }

    // MARK: - Layout helpers

    private var divider: some View {
        Rectangle().fill(Theme.border).frame(height: 0.5)
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder _ rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brandGreen)
                .textCase(.uppercase)
                .tracking(0.5)
            rows()
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
