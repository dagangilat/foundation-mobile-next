import AVKit
import NFCPassportReader
import SwiftUI

struct ReadPassportNFCView: View {
    @EnvironmentObject private var passportViewModel: PassportViewModel
    @EnvironmentObject private var userManager: UserManager

    let onNext: (_ passport: Passport) -> Void
    let onBack: () -> Void
    let onResponseError: () -> Void
    let onClose: () -> Void
    /// Header Back (to the chip explainer). Without it, Back does what a
    /// failed read does (`onBack`).
    var onPrevious: (() -> Void)? = nil
    /// Start the NFC scan as soon as the screen shows, as "Start chip scan"
    /// on the chip explainer asks. "Scan chip" stays for another try.
    var startsScanOnAppear = false

    @State private var useExtendedMode = false
    @State private var hasAutoStarted = false
    /// False on a device that can't read NFC chips: the screen then says so
    /// instead of offering a scan that could only fail. It can't change while
    /// the app runs (iOS has no NFC switch), so it is read once.
    @State private var isNFCAvailable = NFCScanner.isReadingAvailable

    var body: some View {
        ScanPassportLayoutView(
            currentStep: 1,
            title: "Hold your phone on the passport",
            onPrevious: onPrevious ?? onBack,
            onClose: onClose
        ) {
            VStack(spacing: 24) {
                if isNFCAvailable {
                    LoopVideoPlayer(url: passportViewModel.isUSA ? Videos.readNfcUsa : Videos.readNfc)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, FoundationTheme.horizontalPadding)

                    (Text("Hold your phone flat").foregroundColor(FoundationTheme.text).bold()
                        + Text(" on the photo page until it buzzes. Most chips read in a few seconds."))
                        .font(.system(size: 16))
                        .foregroundColor(FoundationTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .foundationCard(padding: 18)
                        .padding(.horizontal, FoundationTheme.horizontalPadding)

                    Spacer()

                    Button("Scan chip", action: scanPassport)
                        .buttonStyle(FoundationPrimaryButtonStyle())
                        .padding(.horizontal, FoundationTheme.horizontalPadding)
                        .padding(.bottom, 24)
                } else {
                    // No scan to offer: Back (header) leaves the step.
                    NFCUnavailableCard()
                        .padding(.horizontal, FoundationTheme.horizontalPadding)

                    Spacer()
                }
            }
        }
        .onAppear {
            guard isNFCAvailable, startsScanOnAppear, !hasAutoStarted else { return }
            hasAutoStarted = true
            // Let the screen slide in before the system NFC sheet covers it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scanPassport()
            }
        }
    }

    private func scanPassport() {
        guard NFCScanner.isReadingAvailable else {
            isNFCAvailable = false
            return
        }

        NFCScanner.scanPassport(
            passportViewModel.mrzKey ?? "",
            userManager.userChallenge,
            useExtendedMode,
            onCompletion: { result in
                switch result {
                case .success(let passport):
                    if passport.isExpired {
                        LoggerUtil.common.info("Passport is expired")
                        AppNotificationStore.shared.postVerificationFailure(reason: "Passport is expired", retry: .scanPassport)
                        onClose()
                        return
                    }

                    if !passport.isOver18 {
                        LoggerUtil.common.info("User is underage")
                        AppNotificationStore.shared.postVerificationFailure(reason: "You are under 18", retry: .scanPassport)
                        onClose()
                        return
                    }

                    if passport.documentType != DocumentType.passport.rawValue {
                        LoggerUtil.common.info("Document is not ePassport")
                        AppNotificationStore.shared.postVerificationFailure(reason: "Document is not ePassport", retry: .scanPassport)
                        onClose()
                        return
                    }

                    self.onNext(passport)
                case .failure(let error):
                    LoggerUtil.common.error("failed to read passport data: \(error.localizedDescription, privacy: .public)")
                    switch error {
                    case NFCScannerError.nfcNotAvailable:
                        // Not a failed read: say so on this screen.
                        isNFCAvailable = false
                    case NFCPassportReaderError.Unknown:
                        if useExtendedMode {
                            onBack()
                            return
                        }

                        useExtendedMode = true
                        // Still inside the chip read: tell the person now, not via the bell.
                        AlertManager.shared.emitScanFlowError(.unknown("A scanning error occurred. Attempting to use extended mode. Please try again."))
                        scanPassport()
                    case NFCPassportReaderError.ResponseError(let reason, _, _)
                        where reason == "Referenced data not found":
                        onResponseError()
                    default:
                        onBack()
                    }
                }
            }
        )
    }
}

#Preview {
    let userManager = UserManager.shared

    return ReadPassportNFCView(
        onNext: { _ in },
        onBack: {},
        onResponseError: {},
        onClose: {}
    )
    .environmentObject(userManager)
    .environmentObject(PassportViewModel())
    .onAppear {
        _ = try? userManager.createNewUser()
    }
}
