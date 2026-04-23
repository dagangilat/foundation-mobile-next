import SwiftUI

struct SignInView: View {
    enum Status { case idle, sending, sent, error }

    @State private var email: String = ""
    @State private var status: Status = .idle
    @State private var errorText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 20) {
                Text("Sign in")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
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
                    Text("Check your inbox. Tap the link on this device to finish signing in.")
                        .font(.callout)
                        .foregroundStyle(Theme.brandGreen)
                case .error:
                    Text(errorText)
                        .font(.callout)
                        .foregroundStyle(.red)
                case .idle, .sending:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 48)

            Spacer()
        }
    }

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
