import Foundation
import Web3

enum FoundationUrlHosts: String {
    case external
}

enum ExternalRequestTypes: String, Codable {
    case proofRequest = "proof-request"
    case lightVerification = "light-verification"
}

enum ExternalRequests: Equatable {
    case proofRequest(proofParamsUrl: URL, urlQueryParams: [URLQueryItem])
    case lightVerification(verificationParamsUrl: URL, urlQueryParams: [URLQueryItem])
}

class ExternalRequestsManager: ObservableObject {
    static let shared = ExternalRequestsManager()

    @Published private(set) var request: ExternalRequests? = nil

    func handleUrl(_ url: URL) {
        url.path.hasPrefix("/r/") ? handleRefferalCode(url) : handleRarimeUrl(url)
    }

    func handleRarimeUrl(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let params = components.queryItems
        else {
            LoggerUtil.common.error("Invalid app link: \(url.absoluteString, privacy: .public)")
            AlertManager.shared.emitError(.unknown("Invalid app link"))
            return
        }

        if isValidExternalUrl(url) {
            handleExternalRequest(params: params)
            return
        }

        LoggerUtil.common.error("Invalid app link host: \(url.host ?? "nil", privacy: .public)")
    }

    private func handleRefferalCode(_ url: URL) {
        let code = String(url.path.dropFirst(3))
        AppUserDefaults.shared.deferredReferralCode = code
        UserManager.shared.user?.deferredReferralCode = code
        LoggerUtil.common.info("Deferred referral code set: \(code, privacy: .public)")
    }

    private func handleExternalRequest(params: [URLQueryItem]) {
        guard let type = params.first(where: { $0.name == "type" })?.value
        else {
            LoggerUtil.common.error("Invalid external request URL: \(params, privacy: .public)")
            AlertManager.shared.emitError(.unknown("Invalid external request URL"))
            return
        }

        switch type {
        case ExternalRequestTypes.proofRequest.rawValue:
            handleProofRequest(params: params)
        case ExternalRequestTypes.lightVerification.rawValue:
            handleLightVerificationRequest(params: params)
        default:
            LoggerUtil.common.error("Invalid external request type: \(type, privacy: .public)")
        }
    }

    private func handleProofRequest(params: [URLQueryItem]) {
        guard let rawProofParamsUrl = params.first(where: { $0.name == "proof_params_url" })?.value?.removingPercentEncoding,
              let proofParamsUrl = URL(string: rawProofParamsUrl)
        else {
            LoggerUtil.common.error("Invalid proof request URL: \(params, privacy: .public)")
            AlertManager.shared.emitError(.unknown("Invalid proof request URL"))
            return
        }

        if UserManager.shared.registerZkProof == nil {
            LoggerUtil.common.error("Proof requests are not available, passport is not registered")
            AlertManager.shared.emitError(.unknown("Proof requests are not available. Please create your identity first."))
            return
        }

        setRequest(.proofRequest(proofParamsUrl: proofParamsUrl, urlQueryParams: params))
    }

    private func handleLightVerificationRequest(params: [URLQueryItem]) {
        guard let rawProofParamsUrl = params.first(where: { $0.name == "proof_params_url" })?.value?.removingPercentEncoding,
              let proofParamsUrl = URL(string: rawProofParamsUrl)
        else {
            LoggerUtil.common.error("Invalid light verification request URL: \(params, privacy: .public)")
            AlertManager.shared.emitError(.unknown("Invalid light verification request URL"))
            return
        }

        setRequest(.lightVerification(verificationParamsUrl: proofParamsUrl, urlQueryParams: params))
    }

    /// Only this fork's own scheme. Rarimo's `rarime://` scheme and their
    /// `app.rarime.com` universal-link hosts are deliberately NOT honoured:
    /// we do not control their AASA files, so an https link to those hosts
    /// opens RariMe (if installed) rather than this app.
    ///
    /// `internal` rather than `private` so VerificationManagerTests can assert
    /// the allowlist directly - it is the boundary between us and the outside.
    func isValidExternalUrl(_ url: URL) -> Bool {
        url.scheme == "foundationmobile" && url.host == FoundationUrlHosts.external.rawValue
    }

    func setRequest(_ request: ExternalRequests) {
        self.request = request
    }

    /// AD-2: start a proof request from a bare proof-params URL, with no deep
    /// link involved. `startL2Verification` returns this URL alongside a
    /// RariMe deep link; we use the URL and ignore the link.
    func setProofRequest(proofParamsUrl: URL) {
        setRequest(.proofRequest(proofParamsUrl: proofParamsUrl, urlQueryParams: []))
    }

    func resetRequest() {
        request = nil
    }
}
