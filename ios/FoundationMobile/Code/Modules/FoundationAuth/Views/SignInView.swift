import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var alertManager: AlertManager

    @State private var email = ""
    @State private var code = ""
    @State private var emailError = ""
    @State private var codeError = ""
    @State private var codeSent = false
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Sign in to Foundation")
                .h5()
                .foregroundStyle(.textPrimary)

            if codeSent {
                Text("We emailed a 6-digit code to \(email).")
                    .body4()
                    .foregroundStyle(.textSecondary)
                AppTextField(
                    text: $code,
                    errorMessage: $codeError,
                    placeholder: "000000",
                    keyboardType: .numberPad
                )
                AppButton(text: "Verify", loading: isBusy, action: verify)
                    .disabled(isBusy || code.count != 6)
            } else {
                AppTextField(
                    text: $email,
                    errorMessage: $emailError,
                    placeholder: "you@example.com",
                    keyboardType: .emailAddress
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                AppButton(text: "Send code", loading: isBusy, action: sendCode)
                    .disabled(isBusy || !email.contains("@"))
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.bgPrimary, ignoresSafeAreaEdges: .all)
    }

    private func sendCode() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await authService.sendCode(to: email)
                code = ""
                codeError = ""
                codeSent = true
            } catch {
                LoggerUtil.common.error("sendCode failed: \(error.localizedDescription, privacy: .public)")
                alertManager.emitError(.unknown(
                    AuthService.signInErrorMessage(for: error, fallback: "Couldn't send the code. Try again.")
                ))
            }
        }
    }

    private func verify() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                // On success Firebase fires the auth-state listener,
                // AuthService.isSignedIn flips and AppView swaps this view away.
                try await authService.submitCode(code)
            } catch {
                LoggerUtil.common.error("submitCode failed: \(error.localizedDescription, privacy: .public)")
                alertManager.emitError(.unknown("That code didn't work. Try again."))
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthService.shared)
        .environmentObject(AlertManager.shared)
}
