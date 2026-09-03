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
                            isSheetPresented = false

                            handleRedirect(urlQueryParams)

                            // AD-2: the proof this sheet just posted may be the
                            // one our own startL2Verification asked for, so ask
                            // Foundation's backend when the member flips to l2.
                            // Only the proofRequest path does this -
                            // lightVerification is not part of the L2 flow.
                            Task { await FoundationVerificationManager.shared.pollUntilVerified() }
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
