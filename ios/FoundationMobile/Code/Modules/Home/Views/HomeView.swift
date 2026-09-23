import SwiftUI

/// Foundation's Home, the app's single root screen:
///   header (lockup + profile button) → pillars hero → status card → QR scan.
///
/// Unhooked from here (code kept): the "Hi Stranger" greeting, the
/// notifications bell, the widget carousel (HomeWidgetsView), the home
/// onboarding overlay (HomeOnboardingView) and its welcome sheet.
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var mainViewModel: MainView.ViewModel
    @EnvironmentObject private var passportViewModel: PassportViewModel
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var verification: FoundationVerificationManager

    @State private var isScanPassportPresented = false

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
        // Same interrupted-registration bookkeeping IdentityView does, since
        // the registration progress now shows on Home.
        .onChange(of: scenePhase) { newPhase in
            if userManager.user?.status == .unscanned
                && passportViewModel.processingStatus == .processing
                && newPhase == .background
            {
                AppUserDefaults.shared.isRegistrationInterrupted = true
            }
        }
        .onAppear {
            if AppUserDefaults.shared.isRegistrationInterrupted {
                passportViewModel.processingStatus = .failure
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            BrandLockup()

            #if DEVELOPMENT
            Text(verbatim: "Development")
                .caption2()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.warningLighter, in: Capsule())
                .foregroundStyle(Color.warningDark)
            #endif

            Spacer()

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
