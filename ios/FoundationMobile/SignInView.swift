import SwiftUI
import UIKit

// OTP-based sign-in for iOS. User enters email → taps Send → server
// emails a 6-digit code → user reads code from inbox → types it here →
// AuthService.verifyCodeAndSignIn signs them in via Firebase custom
// token. Replaces the email-link path because Gmail iOS bypasses
// Universal Links and strands users on a "Validating…" screen forever.
// See AuthService.swift / functions/index.js for the full rationale.
struct SignInView: View {
    enum Phase: Equatable {
        case enterEmail              // initial — user types email
        case sendingCode             // requestSignInCode in flight
        case enterCode               // email sent, user types 6-digit code
        case verifying               // verifySignInCode in flight
        case error(String)           // last action failed; show message
    }

    @ObservedObject private var deployment = DeploymentService.shared
    @State private var email: String = ""
    @State private var code: String = ""
    @State private var phase: Phase = .enterEmail
    @State private var infoText: String = ""
    @State private var showDeploymentPicker = false
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 20) {
                Text("Sign in")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(headlineCopy)
                    .foregroundStyle(Theme.muted)

                emailField

                if showCodeField {
                    codeField
                }

                primaryButton

                statusLine
            }
            .padding(.horizontal, 20)
            .padding(.top, 48)

            Spacer()
        }
    }

    private var header: some View {
        HStack {
            BrandLockup()
            Spacer()
            if phase == .enterEmail {
                // Gear visible only on the email entry screen — the cancel
                // button takes this slot during code entry.
                Button {
                    showDeploymentPicker = true
                } label: {
                    HStack(spacing: 5) {
                        if deployment.current.id != "production" {
                            Text(deployment.current.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.brandGreen)
                        }
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                deployment.current.id == "production" ? Theme.muted : Theme.brandGreen
                            )
                    }
                }
                .accessibilityLabel("Choose deployment: \(deployment.current.name)")
                .sheet(isPresented: $showDeploymentPicker) {
                    DeploymentPickerView()
                }
            } else {
                Button {
                    phase = .enterEmail
                    code = ""
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("Cancel")
                .disabled(phase == .sendingCode || phase == .verifying)
            }
        }
    }

    private var headlineCopy: String {
        switch phase {
        case .enterEmail, .sendingCode, .error:
            return "Enter your invited email. We'll send you a 6-digit sign-in code."
        case .enterCode, .verifying:
            return "We emailed a 6-digit code to \(email). Enter it below to sign in."
        }
    }

    private var emailField: some View {
        // HStack so we can tuck a pencil-edit affordance on the right
        // when the field is locked. The whole row is wrapped in a
        // background + onTapGesture so taps anywhere in the padded
        // row focus the field — fixes the "have to tap exactly on the
        // text caret to focus" SwiftUI behavior on small devices.
        HStack(spacing: 8) {
            TextField("", text: $email,
                      prompt: Text("Email").foregroundColor(Theme.muted))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($emailFieldFocused)
                .foregroundStyle(Theme.text)
                .disabled(emailLocked)
                .frame(maxWidth: .infinity, alignment: .leading)

            if emailLocked {
                Button {
                    // Pencil tap → unlock email + return to entry phase
                    // for editing. Code/info reset so re-Send produces
                    // a fresh code for the corrected email.
                    phase = .enterEmail
                    code = ""
                    infoText = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        emailFieldFocused = true
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.brandGreen)
                        .frame(width: 32, height: 32)
                        .background(Theme.surface.opacity(0.6))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Edit email")
            }
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !emailLocked {
                emailFieldFocused = true
            }
        }
    }

    private var codeField: some View {
        // HStack with an inline Paste button. Number-pad keyboards on
        // iOS don't expose a paste affordance; the user must long-press
        // the field. The button surfaces it as a one-tap action — and
        // it's the natural flow when the user just copied the code
        // out of the Mail / Gmail app.
        HStack(spacing: 8) {
            TextField("", text: $code,
                      prompt: Text("6-digit code").foregroundColor(Theme.muted))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeFieldFocused)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text)
                .disabled(phase == .verifying)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: code) { newValue in
                    // Strip any non-digits the user might paste from email
                    // formatting (spaces, hyphens). Cap at 6.
                    let digits = newValue.filter(\.isNumber).prefix(6)
                    if String(digits) != newValue {
                        code = String(digits)
                    }
                    // Auto-submit on the 6th digit so the user doesn't have
                    // to tap Verify after typing — matches every OTP flow
                    // they've seen on iOS.
                    if code.count == 6 && phase == .enterCode {
                        Task { await verify() }
                    }
                }

            Button {
                // Read clipboard, accept anything that yields ≥6 consecutive
                // digits. Handles paste from emails that include framing
                // text like "Your code is 123456 — expires in…".
                if let raw = UIPasteboard.general.string {
                    let digits = raw.filter(\.isNumber)
                    if digits.count >= 6 {
                        code = String(digits.prefix(6))
                    }
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.brandGreen)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface.opacity(0.6))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Paste code from clipboard")
            .disabled(phase == .verifying)
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if phase != .verifying {
                codeFieldFocused = true
            }
        }
    }

    private var primaryButton: some View {
        Button {
            Task {
                if showCodeField {
                    await verify()
                } else {
                    await sendCode()
                }
            }
        } label: {
            HStack {
                if phase == .sendingCode || phase == .verifying {
                    ProgressView().tint(Theme.bg)
                }
                Text(buttonLabel)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.brandGreen)
            .foregroundStyle(Theme.bg)
            .cornerRadius(8)
            .opacity(buttonDisabled ? 0.7 : 1.0)
        }
        .disabled(buttonDisabled)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch phase {
        case .enterEmail, .sendingCode, .verifying:
            EmptyView()
        case .enterCode:
            HStack(spacing: 12) {
                Text(infoText.isEmpty ? "Check your inbox for the 6-digit code." : infoText)
                    .font(.callout)
                    .foregroundStyle(Theme.brandGreen)
                Spacer(minLength: 0)
                Button("Resend") {
                    Task { await sendCode() }
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(Theme.brandGreen)
            }
        case .error(let msg):
            Text(msg)
                .font(.callout)
                .foregroundStyle(.red)
        }
    }

    // ── Derived state ──────────────────────────────────────────────────

    private var showCodeField: Bool {
        switch phase {
        case .enterCode, .verifying: return true
        default: return false
        }
    }

    private var emailLocked: Bool {
        switch phase {
        case .sendingCode, .enterCode, .verifying: return true
        default: return false
        }
    }

    private var buttonLabel: String {
        switch phase {
        case .enterEmail, .error: return "Send sign-in code"
        case .sendingCode: return "Sending…"
        case .enterCode: return "Verify and sign in"
        case .verifying: return "Verifying…"
        }
    }

    private var buttonDisabled: Bool {
        switch phase {
        case .sendingCode, .verifying:
            return true
        case .enterCode:
            return code.count != 6
        case .enterEmail, .error:
            return email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // ── Actions ────────────────────────────────────────────────────────

    @MainActor
    private func sendCode() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        phase = .sendingCode
        infoText = ""
        do {
            let outcome = try await AuthService.shared.requestSignInCode(email: trimmed)
            email = trimmed
            // Anti-enumeration: both .sent and .noAccess put the user
            // on the same code-entry screen. If the email truly has no
            // access, there's no code on file and verify will fail —
            // matches the prior email-link behavior of "stash and let
            // the verify step report the truth".
            switch outcome {
            case .sent:
                infoText = ""
            case .noAccess:
                infoText = ""
            }
            phase = .enterCode
            // Tee up the keyboard for the code so the user can type
            // immediately after switching back from their inbox.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                codeFieldFocused = true
            }
        } catch {
            phase = .error(friendlyError(error))
        }
    }

    @MainActor
    private func verify() async {
        guard code.count == 6 else { return }
        phase = .verifying
        do {
            try await AuthService.shared.verifyCodeAndSignIn(email: email, code: code)
            // On success, AuthService.state flips to .signedIn via the
            // Firebase auth-state listener and RootView swaps this view
            // away — no further work here.
        } catch {
            // Wrong code keeps the user on the code screen so they can
            // retry; other errors (expired, attempts exhausted) drop
            // them to the error phase with a Resend affordance.
            let msg = friendlyError(error)
            if msg.lowercased().contains("wrong code") {
                phase = .enterCode
                infoText = msg
                code = ""
                codeFieldFocused = true
            } else {
                phase = .error(msg)
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        // Server returns failed-precondition with the user-facing
        // message already shaped — pass it through verbatim.
        let ns = error as NSError
        let desc = ns.localizedDescription
        if desc.isEmpty { return "Something went wrong. Please try again." }
        return desc
    }
}
