import MessageUI
import SwiftUI

private enum ProfileRoute: Hashable {
    case authMethod, recovery, theme, appIcon
}

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppView.ViewModel
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var passportManager: PassportManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var appIconManager: AppIconManager
    @EnvironmentObject private var securityManager: SecurityManager
    @EnvironmentObject private var decentralizedAuthManager: DecentralizedAuthManager
    @EnvironmentObject private var notificationManager: NotificationManager

    @StateObject private var homeWidgetsViewModel = HomeWidgetsViewModel()

    @State private var path: [ProfileRoute] = []

    @State private var isPrivacySheetPresented = false
    @State private var isTermsSheetPresented = false
    @State private var isShareWithDeveloper = false
    @State private var isAccountDeleting = false

    @State private var isDebugOptionsShown = false

    var body: some View {
        NavigationStack(path: $path) {
            content.navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .authMethod:
                    AuthMethodView(onBack: { path.removeLast() })
                        .navigationBarBackButtonHidden()
                case .recovery:
                    ProfileRouteLayout(
                        title: String(localized: "Recovery Method"),
                        onBack: { path.removeLast() }
                    ) {
                        RecoveryMethodSelectionView()
                    }
                    .navigationBarBackButtonHidden()
                case .theme:
                    ThemeView(onBack: { path.removeLast() })
                        .navigationBarBackButtonHidden()
                case .appIcon:
                    AppIconView(onBack: { path.removeLast() })
                        .navigationBarBackButtonHidden()
                }
            }
        }
#if DEVELOPMENT
        .sheet(isPresented: $isDebugOptionsShown, content: DebugOptionsView.init)
#endif
    }

    var content: some View {
        MainViewLayout {
            VStack(alignment: .leading, spacing: 20) {
                Text("Profile")
                    .subtitle4()
                    .padding(.horizontal, 8)
                VStack(spacing: 12) {
                    ScrollView(showsIndicators: false) {
                        CardContainer {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Account")
                                        .buttonLarge()
                                        .foregroundStyle(.textPrimary)
                                    Text("Address: \(Ethereum.formatAddress(userManager.ethereumAddress ?? ""))")
                                        .body4()
                                        .foregroundStyle(.textSecondary)
                                }
                                Spacer()
                                PassportImageView(image: passportManager.passport?.passportImage, size: 40)
                            }
                        }
                        CardContainer {
                            VStack(spacing: 20) {
                                ProfileRow(
                                    icon: .userShared2Line,
                                    title: String(localized: "Recovery Method"),
                                    action: { path.append(.recovery) }
                                )
                                ProfileRow(
                                    icon: .shieldKeyholeLine,
                                    title: String(localized: "Auth Method"),
                                    action: { path.append(.authMethod) }
                                )
                            }
                        }
                        CardContainer {
                            VStack(spacing: 20) {
                                ProfileRow(
                                    icon: .sunLine,
                                    title: String(localized: "Theme"),
                                    value: settingsManager.colorScheme.title,
                                    action: { path.append(.theme) }
                                )
                                if appIconManager.isAppIconsSupported {
                                    ProfileRow(
                                        icon: .foundationMark,
                                        title: String(localized: "App Icon"),
                                        value: appIconManager.appIcon.title,
                                        action: { path.append(.appIcon) }
                                    )
                                }
                            }
                        }
                        CardContainer {
                            VStack(spacing: 20) {
                                ProfileRow(
                                    icon: .questionLine,
                                    title: String(localized: "Privacy Policy"),
                                    action: { isPrivacySheetPresented = true }
                                )
                                .fullScreenCover(isPresented: $isPrivacySheetPresented) {
                                    SafariWebView(url: configManager.general.privacyPolicyURL)
                                        .ignoresSafeArea()
                                }
                                ProfileRow(
                                    icon: .flagLine,
                                    title: String(localized: "Terms of Use"),
                                    action: { isTermsSheetPresented = true }
                                )
                                .fullScreenCover(isPresented: $isTermsSheetPresented) {
                                    SafariWebView(url: configManager.general.termsOfUseURL)
                                        .ignoresSafeArea()
                                }
                                if MFMailComposeViewController.canSendMail() {
                                    ProfileRow(
                                        icon: .chat2Line,
                                        title: "Give us Feedback",
                                        action: { isShareWithDeveloper = true }
                                    )
                                    .fullScreenCover(isPresented: $isShareWithDeveloper) {
                                        FeedbackMailView(isShowing: $isShareWithDeveloper)
                                    }
                                }
                            }
                        }
#if DEVELOPMENT
                        CardContainer {
                            VStack(spacing: 20) {
                                ProfileRow(
                                    icon: .dotsThreeOutline,
                                    title: String(localized: "Debug Options"),
                                    action: {
                                        isDebugOptionsShown = true
                                    }
                                )
                            }
                        }
#endif
                        CardContainer {
                            Button(action: signOutOfFoundation) {
                                HStack {
                                    Image(.arrowRightUpLine)
                                        .iconMedium()
                                        .padding(6)
                                        .background(.bgComponentPrimary, in: Circle())
                                    Text("Sign Out")
                                        .buttonMedium()
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.textPrimary)
                        }
                        CardContainer {
                            Button(action: { isAccountDeleting = true }) {
                                HStack {
                                    Image(.deleteBin6Line)
                                        .iconMedium()
                                        .padding(6)
                                        .background(.errorLighter, in: Circle())
                                    Text("Delete Account")
                                        .buttonMedium()
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.errorMain)
                        }
                        Text("App version: \(configManager.general.version)")
                            .body5()
                            .foregroundStyle(.textPlaceholder)
                            .padding(.bottom, 20)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 12)
            .background(.bgPrimary)
            .alert(
                "Delete your account?",
                isPresented: $isAccountDeleting,
                actions: {
                    Button("No", role: .cancel) {
                        self.isAccountDeleting = false
                    }
                    Button("Yes", role: .destructive) {
                        appViewModel.isIntroFinished = false
                        AppUserDefaults.shared.isHomeOnboardingCompleted = false
                        AppUserDefaults.shared.hasPointsBalance = false

                        // The Foundation member identity goes FIRST. Every
                        // reset below only touches Rarimo's local identity;
                        // before this call the Firebase session survived
                        // "Delete Account" untouched, and because
                        // `securityManager.reset()` sends AppView back to the
                        // intro the UI looked like the deletion had worked.
                        // The next person to set the device up would then scan
                        // their own passport, tap Verify, and have
                        // `startL2Verification` answer `already_verified_l2`
                        // for the PREVIOUS member's still-signed-in uid -
                        // verified without a single check of their own.
                        signOutOfFoundation()

                        passportManager.reset()
                        securityManager.reset()
                        userManager.reset()
                        decentralizedAuthManager.reset()
                        notificationManager.reset()
                        homeWidgetsViewModel.reset()

                        Task {
                            try? await notificationManager.unsubscribe(fromTopic: ConfigManager.shared.notifications.claimableTopic)
                        }
                    }
                },
                message: {
                    Text("This action is irreversible and will delete all your data.")
                }
            )
        }
    }

    /// Everything that has to happen for the Foundation member identity to stop
    /// being this device's. Shared verbatim by the Sign Out row and the Delete
    /// Account handler so the two cannot drift apart - deletion is sign-out
    /// plus the local resets, never less.
    ///
    /// `AuthService.signOut()` ends the Firebase session and clears both the
    /// pending-email and attested-key Keychain entries; `reset()` drops any
    /// `.verified`/in-flight verification state that described the departing
    /// member. `AppView` keys its first branch on `authService.isSignedIn`, so
    /// the effect either way is an immediate return to `SignInView`.
    @MainActor
    private func signOutOfFoundation() {
        AuthService.shared.signOut()
        FoundationVerificationManager.shared.reset()
    }
}

private struct ProfileRow: View {
    let icon: ImageResource
    let title: String
    var value: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(icon)
                    .iconMedium()
                    .padding(6)
                    .background(.bgComponentPrimary, in: Circle())
                    .foregroundStyle(.textPrimary)
                Text(title)
                    .buttonMedium()
                    .foregroundStyle(.textPrimary)
                Spacer()
                if let value {
                    Text(value)
                        .body4()
                        .foregroundStyle(.textSecondary)
                }
                Image(.caretRight)
                    .iconMedium()
                    .foregroundStyle(.textSecondary)
            }
        }
    }
}

#Preview {
    let userManager = UserManager.shared

    return ProfileView()
        .environmentObject(AppView.ViewModel())
        .environmentObject(MainView.ViewModel())
        .environmentObject(ConfigManager())
        .environmentObject(SettingsManager())
        .environmentObject(PassportManager())
        .environmentObject(SecurityManager())
        .environmentObject(AppIconManager())
        .environmentObject(DecentralizedAuthManager())
        .environmentObject(NotificationManager())
        .environmentObject(userManager)
        .onAppear {
            _ = try? userManager.createNewUser()
        }
}
