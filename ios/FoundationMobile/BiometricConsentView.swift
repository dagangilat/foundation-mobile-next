import SwiftUI

// 2026-04-26 security review M-CRIT-4: explicit Art. 9 biometric
// consent screen. Presented before the first verify-humanity tap;
// re-presented when BIOMETRIC_VERSION on the server is bumped.
//
// GDPR Art. 9(2)(a) requires consent to be explicit, freely given,
// specific, informed, and unambiguous. BIPA §15(b)(3) requires a
// written release. We ship two independent toggles + a primary
// action that is disabled until both are checked, so the user
// cannot blow past the consent moment by inertia.

struct BiometricConsentView: View {
    let onAccept: () async -> Void
    let onCancel: () -> Void

    @State private var acceptedDataPolicy = false
    @State private var acceptedBiometricProcessing = false
    @State private var submitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        acceptedDataPolicy && acceptedBiometricProcessing && !submitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    whatHappens
                    whatLeavesDevice
                    retentionAndRights
                    consentCheckboxes
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    actionButtons
                }
                .padding(20)
            }
            .navigationTitle("Verify Humanity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before you continue")
                .font(.title2.weight(.semibold))
            Text("Foundation needs your explicit permission to process biometric data on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var whatHappens: some View {
        section(
            title: "What happens",
            bullets: [
                "We capture a short selfie sequence for liveness + anti-spoofing.",
                "We read the face photo from your passport's NFC chip (DG2).",
                "We compute a face-geometry embedding locally and check the match.",
                "Your phone signs a humanity commitment with a Face-ID-protected key.",
            ]
        )
    }

    private var whatLeavesDevice: some View {
        section(
            title: "What leaves your device",
            bullets: [
                "A SHA-256 hash of the verification, signed by Apple App Attest.",
                "A Solana commitment hash, recorded on the public ledger.",
            ],
            footer: "Selfie frames, the DG2 face image, your face embedding, and the MRZ data never leave the device."
        )
    }

    private var retentionAndRights: some View {
        section(
            title: "Retention & your rights",
            bullets: [
                "On-chain commitment hash is permanent (immutable Solana ledger).",
                "Server-side mapping is destroyed within 72h of immediate deletion (or 30d scheduled).",
                "Withdraw consent at any time in Settings — that triggers scheduled deletion.",
                "Request human review (GDPR Art. 22) at privacy@plantagoai.com.",
            ]
        )
    }

    private var consentCheckboxes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $acceptedDataPolicy) {
                Text("I have read the disclosure above and accept the Privacy Policy.")
                    .font(.footnote)
            }
            Toggle(isOn: $acceptedBiometricProcessing) {
                Text("I explicitly consent to biometric data processing for humanity verification (GDPR Art. 9(2)(a) / BIPA §15(b)).")
                    .font(.footnote)
            }
        }
        .padding(.top, 6)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if submitting { ProgressView().tint(.black) }
                    Text(submitting ? "Recording consent…" : "Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.black)
                .background(canSubmit ? Color.green : Color.gray.opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(!canSubmit)

            Button("Not now", action: onCancel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private func section(title: String, bullets: [String], footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(bullet).font(.footnote)
                    }
                }
            }
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        submitting = true
        errorMessage = nil
        do {
            _ = try await FunctionsService.shared.recordBiometricConsent()
            BiometricConsentState.shared.markAccepted(version: "v1")
            await onAccept()
        } catch {
            errorMessage = "Could not record consent: \(error.localizedDescription)"
            submitting = false
        }
    }
}

// Local fast-path cache so the consent gate doesn't round-trip the
// server on every Verify-humanity tap. Server's
// users/{uid}/legal_consent/biometric-processing_v1 doc remains the
// source of truth; this is purely a UI optimization.
@MainActor
final class BiometricConsentState: ObservableObject {
    static let shared = BiometricConsentState()

    @AppStorage("biometricConsentVersion") private var storedVersion: String = ""

    func hasAcceptedCurrentVersion(_ version: String = "v1") -> Bool {
        storedVersion == version
    }

    func markAccepted(version: String) {
        storedVersion = version
    }

    func clear() {
        storedVersion = ""
    }
}
