import SwiftUI

struct MainView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var externalRequestsManager: ExternalRequestsManager

    @StateObject private var viewModel = ViewModel()
    @StateObject private var passportViewModel = PassportViewModel()

    var body: some View {
        ZStack {
            // No tab bar: Home is the root, Profile is opened from Home's
            // header and returns to it. The Identity tab is hidden (nothing
            // selects .identity any more); its passport flow is launched from
            // Home's status card instead. .scanQr never was a screen - it
            // opens the QR sheet below.
            switch viewModel.selectedTab {
                case .home: HomeView()
                case .identity: IdentityView()
                case .scanQr: EmptyView()
                case .profile: ProfileView()
            }
            // Stays mounted on every screen so deep-link and QR proof
            // requests (and Foundation's own verification) keep working.
            ExternalRequestsView()
        }
        .environmentObject(viewModel)
        .environmentObject(passportViewModel)
        .onAppear(perform: checkNotificationPermission)
        .dynamicSheet(isPresented: $viewModel.isQrCodeScanSheetShown, fullScreen: true) {
            ScanQRView(
                onBack: { viewModel.isQrCodeScanSheetShown = false },
                onScan: processQrCode
            )
        }
        // Passport registration runs in the background after the scan sheet
        // closes and can stop to ask for a re-scan that revokes an earlier
        // registration. This sheet used to live on IdentityView; it is
        // mounted here so it can appear whichever screen is showing.
        .dynamicSheet(isPresented: $passportViewModel.isUserRevoking, fullScreen: true) {
            PassportRevocationView()
                .environmentObject(passportViewModel)
                .interactiveDismissDisabled()
        }
    }

    func checkNotificationPermission() {
        Task { @MainActor in
            if !(await notificationManager.isAuthorized()) {
                try? await notificationManager.request()
            }
        }
    }

    func processQrCode(_ code: String) {
        guard let qrCodeUrl = URL(string: code) else {
            LoggerUtil.common.error("Invalid QR code: \(code, privacy: .public)")
            AlertManager.shared.emitError(.unknown("Invalid QR code"))
            return
        }

        externalRequestsManager.handleRarimeUrl(qrCodeUrl)
        viewModel.isQrCodeScanSheetShown = false
    }
}

#Preview {
    let userManager = UserManager.shared

    return MainView()
        .environmentObject(PassportManager())
        .environmentObject(UserManager())
        .environmentObject(ConfigManager())
        .environmentObject(NotificationManager())
        .environmentObject(ExternalRequestsManager())
        .onAppear {
            _ = try? userManager.createNewUser()
        }
}
