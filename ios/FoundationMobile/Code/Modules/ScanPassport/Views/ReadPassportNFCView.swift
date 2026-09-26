import AVKit
import NFCPassportReader
import SwiftUI

/// Why a chip read failed, as far as the chip step needs to know: it stays
/// on that step either way, and only changes which way out comes first.
/// Mirrors Android's `ChipReadFailure`.
enum ChipReadFailure {
    /// Tag lost, timeout, a bad response...: another try usually works.
    case readFailed
    /// The chip refused the access key made from the photo page (MRZ): most
    /// likely a misread page, so scanning the page again comes first.
    case keyRejected

    init(_ error: Error) {
        // The reader reports a refused BAC key (SW 0x6300, or an empty
        // MUTUAL AUTHENTICATE answer) as InvalidMRZKey; a failed PACE falls
        // back to BAC, so it ends up here too.
        if case NFCPassportReaderError.InvalidMRZKey = error {
            self = .keyRejected
        } else {
            self = .readFailed
        }
    }

    /// The reason behind Home's bell if the flow is left without a good read.
    var reason: String {
        switch self {
        case .readFailed:
            return String(localized: "The passport chip couldn't be read.")
        case .keyRejected:
            return String(localized: "The chip didn't accept the details from the passport page.")
        }
    }
}

/// The chip read. A failed read keeps the person here, with the photo page
/// details (MRZ) already read: "Try again" repeats the chip read alone, and
/// "Scan passport page again" goes back to the camera. When the chip refused
/// the page's details, the page comes first.
struct ReadPassportNFCView: View {
    @EnvironmentObject private var passportViewModel: PassportViewModel
    @EnvironmentObject private var userManager: UserManager

    let onNext: (_ passport: Passport) -> Void
    /// "Scan passport page again": back to the photo page (MRZ) camera.
    let onScanPageAgain: () -> Void
    let onResponseError: () -> Void
    let onClose: () -> Void
    /// Header Back (to the chip explainer). Without it, Back goes to the
    /// photo page (`onScanPageAgain`).
    var onPrevious: (() -> Void)? = nil
    /// A read failed. Called once per failure, while this screen stays and
    /// offers another try; NFC missing on this device is not reported.
    var onChipReadFailed: (ChipReadFailure) -> Void = { _ in }
    /// The chip was read (even if the passport then turns out to be expired):
    /// an earlier failure no longer stands.
    var onChipRead: () -> Void = {}
    /// Start the NFC scan as soon as the screen shows, as "Start chip scan"
    /// on the chip explainer asks. "Scan chip" stays for another try.
    var startsScanOnAppear = false

    @State private var useExtendedMode = false
    @State private var hasAutoStarted = false
    /// False on a device that can't read NFC chips: the screen then says so
    /// instead of offering a scan that could only fail. It can't change while
    /// the app runs (iOS has no NFC switch), so it is read once.
    @State private var isNFCAvailable = NFCScanner.isReadingAvailable
    /// Why the last read failed, until the next try.
    @State private var failure: ChipReadFailure? = nil

    var body: some View {
        ScanPassportLayoutView(
            currentStep: 1,
            title: "Hold your phone on the passport",
            onPrevious: onPrevious ?? onScanPageAgain,
            onClose: onClose
        ) {
            VStack(spacing: 24) {
                if !isNFCAvailable {
                    // No scan to offer: Back (header) leaves the step.
                    NFCUnavailableCard()
                        .padding(.horizontal, FoundationTheme.horizontalPadding)

                    Spacer()
                } else if let failure {
                    ChipReadFailureCard(failure: failure)
                        .padding(.horizontal, FoundationTheme.horizontalPadding)

                    Spacer()

                    failureButtons(failure)
                        .padding(.horizontal, FoundationTheme.horizontalPadding)
                        .padding(.bottom, 24)
                } else {
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
                }
            }
        }
        .onAppear {
            guard isNFCAvailable, failure == nil, startsScanOnAppear, !hasAutoStarted else { return }
            hasAutoStarted = true
            // Let the screen slide in before the system NFC sheet covers it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scanPassport()
            }
        }
    }

    /// The likelier fix first: the chip again after a read failure, the
    /// photo page when the chip refused its details. The other one is the
    /// smaller text button.
    @ViewBuilder
    private func failureButtons(_ failure: ChipReadFailure) -> some View {
        VStack(spacing: 4) {
            switch failure {
            case .readFailed:
                Button("Try again", action: retryChipRead)
                    .buttonStyle(FoundationPrimaryButtonStyle())
                Button("Scan passport page again", action: onScanPageAgain)
                    .buttonStyle(FoundationTextButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .keyRejected:
                Button("Scan passport page again", action: onScanPageAgain)
                    .buttonStyle(FoundationPrimaryButtonStyle())
                Button("Try again", action: retryChipRead)
                    .buttonStyle(FoundationTextButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    /// "Try again": the chip read only, in a new NFC session (every
    /// `scanPassport` starts one), with the photo page details as they are.
    private func retryChipRead() {
        failure = nil
        useExtendedMode = false
        scanPassport()
    }

    private func chipReadFailed(_ error: Error) {
        let kind = ChipReadFailure(error)
        failure = kind
        onChipReadFailed(kind)
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
                    failure = nil
                    onChipRead()

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
                    case NFCPassportReaderError.UserCanceled:
                        // The person closed the system scan sheet: not a
                        // failed read. The screen stays as it was, with its
                        // button for another try.
                        break
                    case NFCPassportReaderError.Unknown:
                        if useExtendedMode {
                            chipReadFailed(error)
                            return
                        }

                        useExtendedMode = true
                        // Still inside the chip read: tell the person now, not via the bell.
                        AlertManager.shared.emitScanFlowError(.unknown("A scanning error occurred. Attempting to use extended mode. Please try again."))
                        scanPassport()
                    case NFCPassportReaderError.ResponseError(let reason, _, _)
                        where reason == "Referenced data not found":
                        // A chip this app can't read yet: its own screen
                        // ("Get in touch"). Leaving from there still counts
                        // as a failed try.
                        onChipReadFailed(.readFailed)
                        onResponseError()
                    default:
                        // Stay on the chip step: another try, or the photo
                        // page again. (It used to go straight back to the
                        // photo page camera for any chip hiccup.)
                        chipReadFailed(error)
                    }
                }
            }
        )
    }
}

/// Why the last read failed, in the verify flow's card style.
private struct ChipReadFailureCard: View {
    let failure: ChipReadFailure

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(FoundationTheme.dangerIcon)
                .frame(width: 40, height: 40)
                .background(FoundationTheme.dangerTint, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(FoundationTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundColor(FoundationTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foundationCard(padding: 18)
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringKey {
        switch failure {
        case .readFailed: return "The chip read didn't finish"
        case .keyRejected: return "The chip didn't open"
        }
    }

    private var detail: LocalizedStringKey {
        switch failure {
        case .readFailed:
            return "Keep the top of your phone flat on the passport and hold still until it buzzes, then try again."
        case .keyRejected:
            return "The chip didn't accept the details from the passport page. Scan the page again."
        }
    }
}

#Preview {
    let userManager = UserManager.shared

    return ReadPassportNFCView(
        onNext: { _ in },
        onScanPageAgain: {},
        onResponseError: {},
        onClose: {}
    )
    .environmentObject(userManager)
    .environmentObject(PassportViewModel())
    .onAppear {
        _ = try? userManager.createNewUser()
    }
}

#Preview("Chip refused the page's details") {
    ChipReadFailureCard(failure: .keyRejected)
        .padding(24)
        .background(FoundationTheme.bg)
}
