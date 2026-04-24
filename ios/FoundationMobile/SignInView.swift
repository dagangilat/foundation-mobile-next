import SwiftUI

struct SignInView: View {
    enum Status { case idle, sending, sent, error }

    @State private var email: String = ""
    @State private var status: Status = .idle
    @State private var errorText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                solanaPill
                formSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // Matches HomeView / LoadingView header exactly so the sign-in screen
    // reads as the same app, not a different entry surface.
    private var header: some View {
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

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sign in")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 12)
            Text("Enter your invited email. We'll send a one-tap sign-in link.")
                .foregroundStyle(Theme.muted)

            TextField("", text: $email,
                      prompt: Text("Email").foregroundColor(Theme.muted))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(14)
                .background(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .cornerRadius(8)
                .foregroundStyle(.white)
                .disabled(status == .sending || status == .sent)

            submitButton

            switch status {
            case .sent:
                sentCard
            case .error:
                errorCard
            case .idle, .sending:
                EmptyView()
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if status == .sending {
                    ProgressView().tint(Theme.bg)
                }
                Text(status == .sent ? "Sent" : "Send sign-in link")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.brandGreen)
            .foregroundStyle(Theme.bg)
            .cornerRadius(8)
        }
        .disabled(email.isEmpty || status == .sending || status == .sent)
    }

    // Post-send confirmation — same visual language as HomeView's ringCard
    // (surface bg, brand-green border) so the user reads it as a receipt,
    // not just a status message.
    private var sentCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.brandGreen)
            VStack(alignment: .leading, spacing: 4) {
                Text("Check your inbox")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("We sent a sign-in link to \(email.trimmingCharacters(in: .whitespacesAndNewlines)). Tap it on this device to finish signing in.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.brandGreen.opacity(0.4)))
        .cornerRadius(12)
    }

    private var errorCard: some View {
        Text(errorText)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    @MainActor
    private func submit() async {
        status = .sending
        errorText = ""
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await AuthService.shared.sendSignInLink(email: trimmed)
            status = .sent
        } catch {
            status = .error
            errorText = error.localizedDescription
        }
    }
}
