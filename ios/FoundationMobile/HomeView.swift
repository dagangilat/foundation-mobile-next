import SwiftUI

struct HomeView: View {
    let claims: Claims

    @StateObject private var firestore = FirestoreService.shared
    @StateObject private var attestation = AttestationCoordinator.shared
    @State private var proofSmoke: SmokeProofResult = .skipped
    @StateObject private var capture = CaptureCoordinator.shared
    @StateObject private var pairing = PairingCoordinator.shared
    @State private var isShowingQRScanner: Bool = false

    private var ringText: String? {
        let ring = firestore.userDoc?.ring ?? claims.ring
        guard let ring else { return nil }
        return Theme.ringLabels[ring] ?? "Ring \(ring)"
    }

    var body: some View {
        NavigationStack {
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
            .navigationDestination(for: HomeView.Route.self) { route in
                switch route {
                case .capture:
                    CaptureView()
                }
            }
        }
        .onAppear {
            firestore.observeUser(uid: claims.uid)
            attestation.start()
        }
        .task {
            proofSmoke = await MoproSmokeBridge.runMultiplier2Smoke()
        }
    }

    enum Route: Hashable {
        case capture
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
            moproRow
            captureRow
            verifyHumanityButton
                .padding(.top, 8)
            pairingRow
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var captureRow: some View {
        HStack(spacing: 8) {
            Image(systemName: captureIcon)
                .font(.caption)
                .foregroundStyle(captureColor)
            Text(captureLabel)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        if case .sealed(let commitment) = capture.state {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortHash(commitment.commitmentHashHex))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.brandGreen)
                Text(kindChecklist(commitment.artifactKinds))
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.muted)
            }
            .padding(.leading, 20)
        }
    }

    private var captureIcon: String {
        switch capture.state {
        case .idle: return "camera"
        case .unsupported: return "iphone.slash"
        case .needsAttestation: return "hourglass"
        case .readyForPose, .readyForPassport, .scanningPassport, .passportReady,
             .readyForDocumentPhoto, .documentPhotoReady, .readyForVerification, .verifying:
            return "hourglass"
        case .sealed: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var captureColor: Color {
        switch capture.state {
        case .sealed: return Theme.brandGreen
        case .failed: return .orange
        default: return Theme.muted
        }
    }

    private var captureLabel: String {
        switch capture.state {
        case .idle: return "Humanity — not yet verified"
        case .unsupported: return "Humanity — requires real device"
        case .needsAttestation: return "Humanity — App Attest pending"
        case .readyForPose(_, let captured, let total):
            return "Humanity — capturing poses (\(captured)/\(total))"
        case .readyForPassport: return "Humanity — ready to scan passport"
        case .scanningPassport: return "Humanity — scanning passport…"
        case .passportReady: return "Humanity — passport scanned, ready to verify"
        case .readyForDocumentPhoto: return "Humanity — ready to capture document"
        case .documentPhotoReady: return "Humanity — document photo captured, ready to verify"
        case .readyForVerification: return "Humanity — ready to verify"
        case .verifying(let phase):
            return phase == .signing ? "Humanity — signing…" : "Humanity — sealing…"
        case .sealed: return "Humanity — sealed · \(anchorSuffix)"
        case .failed(let msg): return "Humanity — failed: \(msg)"
        }
    }

    // Trailing status for the sealed row — visible once the commitment lands
    // locally, then updates live as the server-audit call returns. The
    // callable returns immediately with status:"queued" and the on-chain
    // write happens async (Cloud Tasks → identity_commitments program on
    // devnet). Firestore onSnapshot subscription for live queued→anchored
    // transitions is the next polish.
    private var anchorSuffix: String {
        switch capture.anchorStatus {
        case .notAttempted: return "audit pending"
        case .pending: return "auditing…"
        case .completed(let r):
            switch r.status {
            case "anchored":
                if let slot = r.slot { return "anchored · slot \(slot)" }
                return "anchored"
            case "queued":
                return "queued · anchoring on devnet…"
            case "anchor-failed":
                return "anchor failed — retrying"
            default:
                // Legacy stub or unknown status — fall back to accepted/reason.
                if r.accepted, let slot = r.slot { return "anchored · slot \(slot)" }
                if let reason = r.reason, !reason.isEmpty { return reason }
                return r.accepted ? "sealed" : "audit rejected"
            }
        case .failed(let msg): return "audit failed: \(msg.prefix(40))"
        }
    }

    @ViewBuilder
    private var verifyHumanityButton: some View {
        let enabled = isAttested
        NavigationLink(value: Route.capture) {
            Text(enabled ? "Verify humanity" : "Verify humanity — App Attest pending")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.brandGreen)
                .cornerRadius(10)
                .opacity(enabled ? 1.0 : 0.5)
        }
        .disabled(!enabled)
    }

    private var isAttested: Bool {
        switch attestation.state {
        case .attested, .alreadyAttested: return true
        default: return false
        }
    }

    private func shortHash(_ hex: String) -> String {
        guard hex.count > 16 else { return hex }
        let first = hex.prefix(12)
        let last = hex.suffix(4)
        return "\(first)…\(last)"
    }

    private func kindChecklist(_ kinds: [ProofArtifact.Kind]) -> String {
        let order: [ProofArtifact.Kind] = [.appAttest, .nfcZk, .liveness, .antiSpoof, .faceMatch]
        let set = Set(kinds)
        return order.map { set.contains($0) ? "\u{2713} \($0.rawValue)" : "\u{00B7} \($0.rawValue)" }
            .joined(separator: "  ")
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

    @ViewBuilder
    private var moproRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: MoproSmokeBridge.isLinked ? "checkmark.seal.fill" : "hammer")
                    .font(.caption)
                    .foregroundStyle(MoproSmokeBridge.isLinked ? Theme.brandGreen : Theme.muted)
                Text(MoproSmokeBridge.hello())
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(3)
            }
            HStack(spacing: 8) {
                Image(systemName: proofIcon)
                    .font(.caption)
                    .foregroundStyle(proofColor)
                Text(proofLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
        }
    }

    private var proofIcon: String {
        switch proofSmoke {
        case .ok: return "checkmark.seal.fill"
        case .skipped: return "hourglass"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var proofColor: Color {
        switch proofSmoke {
        case .ok: return Theme.brandGreen
        case .failed: return .orange
        case .skipped: return Theme.muted
        }
    }

    private var proofLabel: String {
        switch proofSmoke {
        case .ok(let publicInputs):
            return "multiplier2: ok (\(publicInputs.count))"
        case .skipped:
            return "multiplier2: awaiting linked xcframework"
        case .failed(let msg):
            return "multiplier2: failed — \(msg)"
        }
    }

    @ViewBuilder
    private var pairingRow: some View {
        switch pairing.state {
        case .idle, .failed:
            Button {
                isShowingQRScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pair desktop")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Theme.brandGreen)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.brandGreen.opacity(0.4)))
            }
            .sheet(isPresented: $isShowingQRScanner) {
                QRScannerView(
                    onScanned: { code in
                        isShowingQRScanner = false
                        pairing.claim(scannedPayload: code)
                    },
                    onCancel: { isShowingQRScanner = false }
                )
            }
        case .claiming:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.muted)
                Text("Pairing desktop…")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        case .paired:
            HStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.caption)
                    .foregroundStyle(Theme.brandGreen)
                Text("Desktop paired")
                    .font(.caption)
                    .foregroundStyle(Theme.brandGreen)
                Spacer()
                Button("Disconnect") { pairing.disconnect() }
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        case .releasing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.muted)
                Text("Disconnecting desktop…")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}
