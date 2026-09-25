import Alamofire
import SwiftUI

/// The guided passport flow, in order: task guide → photo-page explainer →
/// camera (MRZ) → "Photo page read" → guide → chip explainer → chip (NFC) →
/// "Chip read" → guide → "Build my proof", which closes the flow and starts
/// registration exactly as a finished chip scan used to (progress and
/// failures show on Home's status card).
private enum ScanPassportState {
    /// Development-only JSON import; no button leads here any more.
    case importJson
    /// The task guide; the stage is the step that is next.
    case guide(PassportVerifyStage)
    case photoExplainer
    case scanMRZ
    case photoConfirm
    case chipExplainer
    case readNFC
    case chipConfirm
    case chipError
}

struct ScanPassportView: View {
    @EnvironmentObject private var passportManager: PassportManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var passportViewModel: PassportViewModel

    let onClose: () -> Void

    @State private var state: ScanPassportState = .guide(.photoPage)
    /// The chip read, held until "Build my proof" hands it to registration.
    @State private var scannedPassport: Passport?
    /// Whether the chip screen starts the NFC scan by itself (coming from the
    /// chip explainer) or waits for "Scan chip" (coming back to it).
    @State private var startsChipScan = false

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
        case .guide(let stage):
            PassportVerifyGuideView(
                stage: stage,
                onBack: onClose,
                onContinue: { continueFromGuide(stage) }
            )
        case .photoExplainer:
            PassportPhotoExplainerView(
                onBack: { go(to: .guide(.photoPage)) },
                onContinue: { go(to: .scanMRZ) }
            )
        case .scanMRZ:
            VStack(spacing: 8) {
                ScanPassportMRZView(
                    onNext: { mrzKey in
                        passportViewModel.setMrzKey(mrzKey)

                        go(to: .photoConfirm)
                    },
                    onClose: onClose,
                    onBack: { go(to: .photoExplainer) }
                )
            }
            .padding(.bottom, 16)
            .environmentObject(passportViewModel)
        case .photoConfirm:
            PassportPhotoConfirmView(
                mrzKey: passportViewModel.mrzKey,
                onBack: { go(to: .scanMRZ) },
                onContinue: { go(to: .guide(.chip)) },
                onScanAgain: { go(to: .scanMRZ) }
            )
        case .chipExplainer:
            PassportChipExplainerView(
                onBack: { go(to: .guide(.chip)) },
                onContinue: {
                    startsChipScan = true
                    go(to: .readNFC)
                }
            )
        case .readNFC:
            ReadPassportNFCView(
                onNext: { passport in
                    scannedPassport = passport
                    startsChipScan = false
                    go(to: .chipConfirm)
                },
                // A failed read goes back to the photo page, as before: a
                // wrong MRZ is the usual reason the chip won't open.
                onBack: { go(to: .scanMRZ) },
                onResponseError: { go(to: .chipError) },
                onClose: onClose,
                onPrevious: { go(to: .chipExplainer) },
                startsScanOnAppear: startsChipScan
            )
            .environmentObject(passportViewModel)
        case .chipConfirm:
            PassportChipConfirmView(
                onBack: {
                    startsChipScan = false
                    go(to: .readNFC)
                },
                onContinue: { go(to: .guide(.proof)) }
            )
        case .chipError:
            PassportChipErrorView(onClose: onClose)
        }
    }

    private func go(to newState: ScanPassportState) {
        withAnimation { state = newState }
    }

    private func continueFromGuide(_ stage: PassportVerifyStage) {
        switch stage {
        case .photoPage:
            go(to: .photoExplainer)
        case .chip:
            go(to: .chipExplainer)
        case .proof:
            buildProof()
        }
    }

    /// "Build my proof": what a successful chip scan used to do straight
    /// away - close the flow and register in the background.
    private func buildProof() {
        guard let passport = scannedPassport else {
            // No chip read to prove (should not happen): read it again.
            go(to: .chipExplainer)
            return
        }

        onClose()
        Task { await register(passport) }
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
