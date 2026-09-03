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
    /// True from the moment "Yes" is tapped until the server has answered.
    /// Drives the blocking overlay and disables both destructive rows, because
    /// `.alert` dismisses itself on any button tap and cannot host a spinner.
    @State private var isAccountDeletionInFlight = false

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
        .overlay {
            if isAccountDeletionInFlight {
                AccountDeletionOverlay()
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
                            .disabled(isAccountDeletionInFlight)
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
                            .disabled(isAccountDeletionInFlight)
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
                    Button("Yes", role: .destructive, action: deleteAccount)
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
    ///
    /// `rearmPasscodeLock()` is the third leg, and the one that only exists
    /// because the Sign Out row does. `SecurityManager.isPasscodeCorrect` was
    /// only ever armed in `SecurityManager.init`, so mid-session it stayed
    /// `true` from the departing member's own unlock and the next person to
    /// sign in on this device skipped `LockScreenView` entirely - inheriting
    /// the local Rarimo identity that is still on disk. Sign-out has to leave
    /// the gate the way a cold launch would.
    @MainActor
    private func signOutOfFoundation() {
        AuthService.shared.signOut()
        FoundationVerificationManager.shared.reset()
        securityManager.rearmPasscodeLock()
    }

    /// Delete Account, in the only order that can be correct.
    ///
    /// `deleteMyAccount` is `requireAuth`-gated server-side, so it has to run
    /// while the Firebase session is still live: calling it after
    /// `signOutOfFoundation()` would fail `unauthenticated` on every single
    /// invocation and delete nothing at all, which is materially what this
    /// screen did before - the alert promised "all your data" and erased not
    /// one server-side byte.
    ///
    /// So every local mutation is gated behind the server answering. If the
    /// call throws we keep the Firebase session, keep every manager, keep every
    /// `AppUserDefaults` flag, and say so. The state that must never exist is
    /// the opposite one: a device that believes the account is gone while the
    /// server still holds the data.
    private func deleteAccount() {
        guard !isAccountDeletionInFlight else { return }
        isAccountDeletionInFlight = true

        Task { @MainActor in
            defer { isAccountDeletionInFlight = false }

            do {
                let result = try await FunctionsService.shared.deleteMyAccount()
                LoggerUtil.common.info(
                    "deleteMyAccount succeeded (deleted=\(result.deletedDocs.map(String.init) ?? "?", privacy: .public), anonymized=\(result.anonymizedDocs.map(String.init) ?? "?", privacy: .public))"
                )
            } catch {
                LoggerUtil.common.error("deleteMyAccount failed: \(error.localizedDescription, privacy: .public)")
                // Deliberately NOT "nothing was changed": the callable drops the
                // Solana wallet, the Storage objects and the path-keyed docs
                // before the data-map sweep runs, so a throw can leave a
                // partially deleted account server-side. Retrying is the right
                // advice - every one of those helpers tolerates already-missing
                // data - but promising an untouched server would be a lie.
                AlertManager.shared.emitError(
                    .unknown(String(localized: "Couldn't delete your account. Please try again."))
                )
                return
            }

            eraseLocalAccountState()
        }
    }

    /// The local half of deletion - byte for byte the sequence that shipped
    /// before this change, only its trigger moved. Reached ONLY after the
    /// server has confirmed the account is gone.
    @MainActor
    private func eraseLocalAccountState() {
        appViewModel.isIntroFinished = false
        AppUserDefaults.shared.isHomeOnboardingCompleted = false
        AppUserDefaults.shared.hasPointsBalance = false

        // The Foundation member identity goes FIRST among the local steps.
        // Every reset below only touches Rarimo's local identity; before Task
        // B11 the Firebase session survived "Delete Account" untouched, and
        // because `securityManager.reset()` sends AppView back to the intro the
        // UI looked like the deletion had worked. The next person to set the
        // device up would then scan their own passport, tap Verify, and have
        // `startL2Verification` answer `already_verified_l2` for the PREVIOUS
        // member's still-signed-in uid - verified without a single check of
        // their own.
        signOutOfFoundation()

        passportManager.reset()
        // Lands after `signOutOfFoundation()`'s `rearmPasscodeLock()` and
        // overwrites it, which is correct on this path and not a conflict:
        // `reset()` clears the passcode outright (`passcodeState = .unset`,
        // `isPasscodeCorrect = true`), so there is no passcode left to gate on.
        // The re-arm matters for the PLAIN Sign Out path, which never resets.
        securityManager.reset()
        userManager.reset()
        decentralizedAuthManager.reset()
        notificationManager.reset()
        homeWidgetsViewModel.reset()

        Task {
            try? await notificationManager.unsubscribe(fromTopic: ConfigManager.shared.notifications.claimableTopic)
        }
    }
}

/// Blocking "this is happening" state for the one flow in the app that cannot
/// be interrupted or repeated. A SwiftUI `.alert` dismisses itself the instant
/// any button is tapped and has no room for a spinner, so the busy state lives
/// here instead of fighting that API - and unlike disabling a button, this also
/// stops a second tap from arriving through the rows underneath.
private struct AccountDeletionOverlay: View {
    var body: some View {
        ZStack {
            Color.bgPrimary.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                Text("Deleting your account…")
                    .body3()
                    .foregroundStyle(.textSecondary)
            }
        }
        .transition(.opacity)
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
