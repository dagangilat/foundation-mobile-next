import SwiftUI

/// The Home entry point into Foundation verification. Placed on Home rather
/// than behind the QR tab because, unlike Rarimo's flow, ours is not initiated
/// by scanning someone else's code - the app asks our own backend for it.
struct FoundationVerifyCardView: View {
    @EnvironmentObject private var verification: FoundationVerificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verify with Foundation")
                .subtitle5()
                .foregroundStyle(.textPrimary)
            Text(caption)
                .body4()
                .foregroundStyle(.textSecondary)
            AppButton(text: buttonTitle) {
                Task { await verification.beginVerification() }
            }
            .disabled(isBusy)
        }
        .padding(16)
        .background(.bgComponentPrimary)
        .cornerRadius(16)
    }

    private var caption: String {
        switch verification.state {
        case .notRegistered: "Scan your passport first, then come back here."
        case .verified: "You're a verified Foundation member."
        case .failed(let message): message
        default: "Prove you're a unique human, without revealing who you are."
        }
    }

    /// `AppButton.text` is a `LocalizedStringResource`, not a `String` - every
    /// case here is a literal, so the switch types cleanly. `caption` cannot
    /// do the same because `.failed` carries a runtime `String`.
    private var buttonTitle: LocalizedStringResource {
        switch verification.state {
        case .verified: "Verified"
        case .starting, .awaitingProof, .polling: "Working…"
        default: "Verify"
        }
    }

    private var isBusy: Bool {
        switch verification.state {
        case .starting, .awaitingProof, .polling, .verified: true
        default: false
        }
    }
}
