import SwiftUI

struct ExternalRequestsView: View {
    @EnvironmentObject private var externalRequestsManager: ExternalRequestsManager
    @EnvironmentObject private var userManager: UserManager

    @State private var isSheetPresented = false

    private var sheetTitle: LocalizedStringResource? {
        switch externalRequestsManager.request {
        case .proofRequest: "Proof Request"
        case .lightVerification: "Light Verification"
        default: nil
        }
    }

    var body: some View {
        ZStack {}
            .dynamicSheet(isPresented: $isSheetPresented, title: sheetTitle) {
                switch externalRequestsManager.request {
                case let .proofRequest(proofParamsUrl, urlQueryParams):
                    ProofRequestView(
                        proofParamsUrl: proofParamsUrl,
                        onSuccess: {
                            // AD-2: claim the success SYNCHRONOUSLY, and before
                            // anything below dismisses the sheet. Dismissal
                            // trips the .onChange(of: isSheetPresented) hook,
                            // which releases a still-.awaitingProof state; only
                            // a state already moved to .polling by this call
                            // survives it. Never wrap this in a Task - the
                            // dismissal would win that race and reset a
                            // legitimate verification back to .idle.
                            //
                            // false means the proof was not the one our own
                            // startL2Verification asked for (an externally
                            // scanned request), so there is nothing for
                            // Foundation's backend to report on.
                            let isOurVerification = FoundationVerificationManager.shared.proofRequestSucceeded()

                            isSheetPresented = false

                            handleRedirect(urlQueryParams)

                            if isOurVerification {
                                Task { await FoundationVerificationManager.shared.pollUntilVerified() }
                            }
                        },
                        onDismiss: { isSheetPresented = false }
                    )
                case let .lightVerification(verificationParamsUrl, urlQueryParams):
                    LightVerificationView(
                        verificationParamsUrl: verificationParamsUrl,
                        onSuccess: {
                            isSheetPresented = false

                            handleRedirect(urlQueryParams)
                        },
                        onDismiss: { isSheetPresented = false }
                    )
                default:
                    EmptyView()
                }
            }
            .onChange(of: externalRequestsManager.request) { request in
                if request != nil {
                    isSheetPresented = true
                }
            }
            .onChange(of: isSheetPresented) { isPresented in
                if !isPresented {
                    externalRequestsManager.resetRequest()

                    // AD-2: this is the one hook every sheet close runs
                    // through - Cancel, the sheet's X, swipe-to-dismiss, a
                    // proof-params load failure, a failed uniqueness check,
                    // any generateProof error. Without it, .awaitingProof is
                    // terminal and the Home verify card is stuck on "Working…"
                    // for the rest of the process. This fires on EVERY close,
                    // success included - proofSheetDismissed()'s own guard is
                    // what makes it a no-op there, since a success has already
                    // moved state to .polling synchronously in onSuccess by
                    // the time this runs.
                    FoundationVerificationManager.shared.proofSheetDismissed()
                }
            }
            .onOpenURL { url in
                externalRequestsManager.handleUrl(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                guard let url = userActivity.webpageURL else { return }
                externalRequestsManager.handleUrl(url)
            }
    }

    func handleRedirect(_ urlQueryParams: [URLQueryItem]) {
        guard let redirectUri = urlQueryParams.first(where: { $0.name == "redirect_uri" })?.value else {
            return
        }

        guard let url = URL(string: redirectUri) else {
            return
        }

        UIApplication.shared.open(url)
    }
}
