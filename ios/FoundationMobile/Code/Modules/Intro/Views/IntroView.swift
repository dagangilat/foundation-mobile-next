import SwiftUI

private enum IntroRoute: Hashable {
    case newIdentity, importIdentity
}

struct IntroView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var securityManager: SecurityManager

    var onFinish: () -> Void

    @State private var isNewIdentitySheetPresented = false
    @State private var isImportIdentitySheetPresented = false

    var body: some View {
        content
            .background(FoundationTheme.bg.ignoresSafeArea())
            .dynamicSheet(isPresented: $isNewIdentitySheetPresented, fullScreen: true) {
                NewIdentityView(
                    onBack: { isNewIdentitySheetPresented = false },
                    onNext: { withAnimation { onFinish() } }
                )
            }
            .dynamicSheet(isPresented: $isImportIdentitySheetPresented, fullScreen: true) {
                ImportIdentityView(
                    onNext: { withAnimation { onFinish() } },
                    onBack: { isImportIdentitySheetPresented = false }
                )
            }
    }

    /// "Your private ID" welcome, per the approved Welcome mockup. "Create my
    /// ID" is the existing new-identity path; "Restore from backup" is the
    /// existing import-identity sheet.
    var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            BrandLockup()
                .frame(height: 44)
            PillarsHero(textSize: 38)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 10) {
                Text("Your private ID")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(FoundationTheme.text)
                Text("Foundation creates a private key that lives only on this phone. It lets you prove you're a real person without showing who you are.")
                    .font(.system(size: 16))
                    .foregroundColor(FoundationTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Button("Create my ID") { onAuthMethodSelect(.newIdentity) }
                    .buttonStyle(FoundationPrimaryButtonStyle())
                Button("Restore from backup") { onAuthMethodSelect(.importIdentity) }
                    .buttonStyle(FoundationTextButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: FoundationTheme.buttonHeight)
            }
        }
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func onAuthMethodSelect(_ route: IntroRoute) {
        switch route {
        case .newIdentity:
            createNewUser()
        case .importIdentity:
            isImportIdentitySheetPresented = true
        }
    }

    private func createNewUser() {
        do {
            try userManager.createNewUser()
            guard let user = userManager.user else {
                throw Errors.userCreationFailed
            }

            try user.save()
            LoggerUtil.common.info("New user created: \(userManager.ethereumAddress ?? "", privacy: .public)")

            securityManager.disablePasscode()

            onFinish()
        } catch {
            userManager.user = nil
            LoggerUtil.common.error("failed to create new user: \(error.localizedDescription, privacy: .public)")
            AlertManager.shared.emitError(.userCreationFailed)
        }
    }
}

#Preview {
    IntroView(onFinish: {})
        .environmentObject(UserManager.shared)
        .environmentObject(SecurityManager.shared)
}
