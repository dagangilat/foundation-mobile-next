import SwiftUI
import UIKit

/// Email + 6-digit code sign-in, styled after the original Foundation app's
/// SignInView. The backend calls (`AuthService.sendCode` / `submitCode`) and
/// error handling are unchanged.
struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var configManager: ConfigManager

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var isBusy = false
    /// Shown under the fields. Sign-in comes before Home and its bell, so its
    /// errors stay on this screen.
    @State private var errorMessage: String?

    @State private var isTermsPresented = false
    @State private var isPrivacyPresented = false

    @FocusState private var isEmailFocused: Bool
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            VStack(alignment: .leading, spacing: 12) {
                Text("Sign in")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(FoundationTheme.text)
                Text(headline)
                    .font(.system(size: 16))
                    .foregroundColor(FoundationTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 16) {
                emailField
                if codeSent {
                    codeField
                }
                if let errorMessage {
                    FoundationInlineError(message: errorMessage)
                }
                primaryButton
                if codeSent {
                    statusLine
                }
            }

            Spacer(minLength: 0)

            if !codeSent {
                legalLine
            }
        }
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FoundationTheme.bg.ignoresSafeArea())
        .fullScreenCover(isPresented: $isTermsPresented) {
            SafariWebView(url: configManager.general.termsOfUseURL)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isPrivacyPresented) {
            SafariWebView(url: configManager.general.privacyPolicyURL)
                .ignoresSafeArea()
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            BrandLockup()
            Spacer()
            if codeSent {
                Button(action: editEmail) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(FoundationTheme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Close"))
                .disabled(isBusy)
            }
        }
        .frame(height: 44)
    }

    private var headline: String {
        codeSent
            ? String(localized: "We emailed a 6-digit code to \(email). Enter it below to sign in.")
            : String(localized: "Enter your email. We'll send you a 6-digit code.")
    }

    private var emailField: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $email,
                prompt: Text(verbatim: "you@example.com").foregroundColor(FoundationTheme.muted.opacity(0.7))
            )
            .font(.system(size: 17))
            .foregroundColor(FoundationTheme.text)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isEmailFocused)
            .disabled(codeSent || isBusy)
            .onSubmit {
                if canSendCode { sendCode() }
            }

            if codeSent {
                Button(action: editEmail) {
                    Image(systemName: "pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(FoundationTheme.accent)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Edit email"))
                .disabled(isBusy)
            }
        }
        .fieldChrome()
        .contentShape(Rectangle())
        .onTapGesture {
            if !codeSent { isEmailFocused = true }
        }
    }

    private var codeField: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $code,
                prompt: Text("6-digit code").foregroundColor(FoundationTheme.muted.opacity(0.7))
            )
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .foregroundColor(FoundationTheme.text)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($isCodeFocused)
            .disabled(isBusy)
            .onChange(of: code) { newValue in
                // Digits only, capped at 6 (pasted codes often carry spaces).
                let digits = String(newValue.filter(\.isNumber).prefix(6))
                if digits != newValue {
                    code = digits
                }
            }

            Button(action: pasteCode) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(FoundationTheme.accent)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Paste code"))
            .disabled(isBusy)
        }
        .fieldChrome()
        .contentShape(Rectangle())
        .onTapGesture { isCodeFocused = true }
    }

    private var primaryButton: some View {
        Button(action: codeSent ? verify : sendCode) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .tint(FoundationTheme.onAccent)
                }
                Text(buttonTitle)
            }
        }
        .buttonStyle(FoundationPrimaryButtonStyle())
        .disabled(codeSent ? (isBusy || code.count != 6) : (isBusy || !canSendCode))
    }

    private var buttonTitle: LocalizedStringKey {
        switch (codeSent, isBusy) {
        case (false, false): "Send code"
        case (false, true): "Sending…"
        case (true, false): "Verify and sign in"
        case (true, true): "Verifying…"
        }
    }

    private var statusLine: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Check your inbox for the 6-digit code.")
                .font(.system(size: 16))
                .foregroundColor(FoundationTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Resend", action: sendCode)
                .buttonStyle(FoundationTextButtonStyle())
                .disabled(isBusy)
        }
    }

    private var legalLine: some View {
        VStack(spacing: 2) {
            Text("By continuing you agree to the")
            HStack(spacing: 4) {
                Button("Terms") { isTermsPresented = true }
                    .foregroundColor(FoundationTheme.accent)
                Text("and")
                Button("Privacy Policy") { isPrivacyPresented = true }
                    .foregroundColor(FoundationTheme.accent)
            }
        }
        .font(.system(size: 13))
        .foregroundColor(FoundationTheme.muted)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var canSendCode: Bool {
        email.contains("@")
    }

    // MARK: - Actions

    private func editEmail() {
        errorMessage = nil
        codeSent = false
        code = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEmailFocused = true
        }
    }

    private func pasteCode() {
        guard let raw = UIPasteboard.general.string else { return }
        let digits = raw.filter(\.isNumber)
        if digits.count >= 6 {
            code = String(digits.prefix(6))
        }
    }

    private func sendCode() {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                try await authService.sendCode(to: email)
                code = ""
                codeSent = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isCodeFocused = true
                }
            } catch {
                LoggerUtil.common.error("sendCode failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = AuthService.signInErrorMessage(for: error, fallback: "Couldn't send the code. Try again.")
            }
        }
    }

    private func verify() {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                // On success Firebase fires the auth-state listener,
                // AuthService.isSignedIn flips and AppView swaps this view away.
                try await authService.submitCode(code)
            } catch {
                LoggerUtil.common.error("submitCode failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = String(localized: "That code didn't work. Try again.")
            }
        }
    }
}

private extension View {
    /// 60pt white field with a 1pt border, as in the sign-in mockups.
    func fieldChrome() -> some View {
        padding(.horizontal, 16)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FoundationTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(FoundationTheme.border, lineWidth: 1)
            )
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthService.shared)
        .environmentObject(AlertManager.shared)
        .environmentObject(ConfigManager())
}
