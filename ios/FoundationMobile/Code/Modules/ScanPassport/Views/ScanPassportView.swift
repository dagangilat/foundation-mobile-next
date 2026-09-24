import Alamofire
import SwiftUI

private enum ScanPassportState {
    /// Development-only JSON import; no button leads here any more.
    case importJson
    case scanMRZ
    case readNFC
    case chipError
}

struct ScanPassportView: View {
    @EnvironmentObject private var passportManager: PassportManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var passportViewModel: PassportViewModel

    let onClose: () -> Void

    @State private var state: ScanPassportState = .scanMRZ

    var body: some View {
        switch state {
        case .importJson:
            ImportFileView(
                onFinish: { passport in
                    onClose()
                    Task { await register(passport) }
                },
                onClose: onClose
            )
        case .scanMRZ:
            VStack(spacing: 8) {
                ScanPassportMRZView(
                    onNext: { mrzKey in
                        passportViewModel.setMrzKey(mrzKey)

                        withAnimation { state = .readNFC }
                    },
                    onClose: onClose
                )
            }
            .padding(.bottom, 16)
            .environmentObject(passportViewModel)
        case .readNFC:
            ReadPassportNFCView(
                onNext: { passport in
                    onClose()
                    Task { await register(passport) }
                },
                onBack: { withAnimation { state = .scanMRZ } },
                onResponseError: { withAnimation { state = .chipError } },
                onClose: onClose
            )
            .environmentObject(passportViewModel)
        case .chipError:
            PassportChipErrorView(onClose: onClose)
        }
    }

    private func register(_ passport: Passport) async {
        do {
            passportManager.setPassport(passport)

            let zkProof = try await passportViewModel.register()

            if passportViewModel.processingStatus != .success { return }

            userManager.registerZkProof = zkProof
            userManager.user?.status = .passportScanned

            LoggerUtil.common.info("Passport read successfully")
        } catch {
            LoggerUtil.common.error("error while registering passport: \(error, privacy: .public)")

            passportViewModel.lastErrorMessage = PassportViewModel.describe(error)

            if passportViewModel.isUserRegistered {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onClose()
                }
            }

            if let afError = error as? AFError {
                if case .sessionTaskFailed = afError {
                    LoggerUtil.common.error("Network connection lost")

                    AlertManager.shared.emitError(.connectionUnstable)

                    onClose()

                    passportViewModel.processingStatus = .failure

                    return
                }
            } else if let error = error as? Errors {
                AlertManager.shared.emitError(error)

                onClose()

                passportViewModel.processingStatus = .failure

                return
            }

            // Any other error (contract, circuit, proving): register() has
            // already marked the attempt failed; say so instead of failing
            // silently.
            AlertManager.shared.emitError(.unknown(PassportViewModel.describe(error)))
            passportViewModel.processingStatus = .failure
        }
    }
}

#Preview {
    let userManager = UserManager.shared

    return ScanPassportView(onClose: {})
        .environmentObject(userManager)
        .environmentObject(PassportManager())
        .environmentObject(PassportViewModel())
        .onAppear {
            _ = try? userManager.createNewUser()
        }
}
