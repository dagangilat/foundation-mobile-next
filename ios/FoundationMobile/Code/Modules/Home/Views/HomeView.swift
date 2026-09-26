import SwiftUI

/// Foundation's Home, the app's single root screen:
///   header (lockup + bell + profile button) → pillars hero → status card →
///   QR scan.
///
/// The bell opens the app's own notifications (`AppNotificationsSheet`):
/// errors land there instead of popping up over the screen.
///
/// Unhooked from here (code kept): the "Hi Stranger" greeting, the old push
/// notifications screen (NotificationsView), the widget carousel
/// (HomeWidgetsView), the home onboarding overlay (HomeOnboardingView) and
/// its welcome sheet.
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var mainViewModel: MainView.ViewModel
    @EnvironmentObject private var passportViewModel: PassportViewModel
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var verification: FoundationVerificationManager
    @ObservedObject private var notifications = AppNotificationStore.shared

    @State private var isScanPassportPresented = false
    @State private var isNotificationsPresented = false
    /// A "Try again" tapped in the notifications sheet, run once the sheet
    /// has gone (a second sheet can't open while the first is closing).
    @State private var pendingRetry: AppNotification.Retry?

    private var isVerified: Bool {
        if case .verified = verification.state { return true }
        return false
    }

    var body: some View {
        MainViewLayout {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    PillarsHero()
                    FoundationVerifyCardView(onScanPassport: { isScanPassportPresented = true })
                    scanQrButton
                }
                .padding(.horizontal, FoundationTheme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(FoundationTheme.bg.ignoresSafeArea())
        }
        // The passport scan, presented exactly as IdentityView presents it.
        // Closing it (or finishing it) lands back here on Home.
        .dynamicSheet(isPresented: $isScanPassportPresented, fullScreen: true) {
            ScanPassportView(onClose: { isScanPassportPresented = false })
                .environmentObject(passportViewModel)
        }
        .sheet(isPresented: $isNotificationsPresented, onDismiss: runPendingRetry) {
            AppNotificationsSheet(
                onRetry: { retry in
                    pendingRetry = retry
                    isNotificationsPresented = false
                },
                onDone: { isNotificationsPresented = false }
            )
        }
        // Same interrupted-registration bookkeeping IdentityView does, since
        // the registration progress now shows on Home.
        .onChange(of: scenePhase) { newPhase in
            if userManager.user?.status == .unscanned
                && passportViewModel.processingStatus == .processing
                && newPhase == .background
            {
                AppUserDefaults.shared.isRegistrationInterrupted = true
            }
            // Back in the foreground: the member may have finished verifying
            // elsewhere (the web, another device) while the app sat in the
            // background. See `refreshVerificationFromServer()`.
            if newPhase == .active {
                refreshVerificationFromServer()
            }
        }
        .onAppear {
            refreshVerificationFromServer()
            if AppUserDefaults.shared.isRegistrationInterrupted
                && passportViewModel.processingStatus != .failure
            {
                passportViewModel.processingStatus = .failure
            }
            // The card says "The bell has the details." for a failed proof;
            // make sure the bell has them, also for a failure recorded before
            // the bell existed or while the app was closed mid-proof.
            if passportViewModel.processingStatus == .failure && !notifications.hasVerificationFailure {
                let reason = passportViewModel.lastErrorMessage.flatMap { $0.isEmpty ? nil : $0 }
                    ?? String(localized: "We couldn't finish your proof. Scan your passport again to retry.")
                notifications.postVerificationFailure(reason: reason, retry: .scanPassport)
            }
        }
    }

    /// Ask Foundation whether this member is already verified, so a finished
    /// verification still reads as one after a relaunch. The manager's state is
    /// in memory only; without this, every cold launch showed "Passport checked
    /// - Finish verification" to a member who had finished yesterday.
    ///
    /// Only while signed in: AppView keeps Home unreachable while signed out,
    /// but the scene can still go `.active` in the instant a sign-out is being
    /// processed, and the manager itself also returns early without a uid. The
    /// manager decides which states it may touch (never a flow in progress)
    /// and never re-posts the "You're verified" bell entry from here.
    private func refreshVerificationFromServer() {
        guard AuthService.shared.isSignedIn else { return }
        Task { await verification.refreshFromServer() }
    }

    private func runPendingRetry() {
        guard let retry = pendingRetry else { return }
        pendingRetry = nil
        switch retry {
        case .scanPassport:
            isScanPassportPresented = true
        case .finishVerification:
            Task { await verification.beginVerification() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            // Never truncated: the badge and buttons give way first.
            BrandLockup()
                .fixedSize()

            #if DEVELOPMENT
            Text(verbatim: "Dev")
                .caption2()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.warningLighter, in: Capsule())
                .foregroundStyle(Color.warningDark)
                .lineLimit(1)
                .fixedSize()
            #endif

            Spacer()

            Button {
                isNotificationsPresented = true
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(FoundationTheme.text)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if notifications.hasUnreadErrors {
                            Circle()
                                .fill(FoundationTheme.alertDot)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(FoundationTheme.bg, lineWidth: 2))
                                .offset(x: -10, y: 9)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Notifications"))
            .accessibilityValue(notifications.hasUnreadErrors ? Text("Unread") : Text(verbatim: ""))

            Button {
                mainViewModel.selectedTab = .profile
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(FoundationTheme.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Profile"))
        }
        .frame(height: 44)
    }

    /// Opens the existing QR scan sheet (MainView's ScanQRView), the same one
    /// the old scan-QR tab opened, so partner sites can request a proof.
    /// Secondary until verified, then the primary action on Home.
    @ViewBuilder
    private var scanQrButton: some View {
        let button = Button {
            mainViewModel.isQrCodeScanSheetShown = true
        } label: {
            Label("Scan QR code", systemImage: "qrcode.viewfinder")
        }

        if isVerified {
            button.buttonStyle(FoundationPrimaryButtonStyle())
        } else {
            button.buttonStyle(FoundationSecondaryButtonStyle())
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(MainView.ViewModel())
        .environmentObject(PassportViewModel())
        .environmentObject(PassportManager())
        .environmentObject(UserManager())
        .environmentObject(FoundationVerificationManager.shared)
}
