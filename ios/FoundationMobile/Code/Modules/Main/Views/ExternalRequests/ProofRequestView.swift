import SwiftUI

struct ProofRequestView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var passportManager: PassportManager
    @EnvironmentObject private var verification: FoundationVerificationManager

    let proofParamsUrl: URL
    let onSuccess: () -> Void
    let onDismiss: () -> Void

    @State private var proofParamsResponse: GetProofParamsResponse? = nil
    @State private var isSubmitting = false

    private var hasUniqueness: Bool {
        Int(proofParamsResponse?.data.attributes.timestampUpperBound ?? "") != 0 && proofParamsResponse?.data.attributes.identityCounterUpperBound != 0
    }

    private var citizenship: String {
        guard let mask = proofParamsResponse?.data.attributes.citizenshipMask else { return "" }
        return String(data: Data(hex: mask), encoding: .utf8) ?? ""
    }

    private var birthDate: Date? {
        guard let birthDateUpperBound = proofParamsResponse?.data.attributes.birthDateUpperBound else { return nil }
        let birthDateString = String(data: Data(hex: birthDateUpperBound), encoding: .utf8) ?? ""
        return DateUtil.passportDateFormatter.date(from: birthDateString)
    }

    private var minAge: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    private var selector: QueryProofSelector? {
        if let selectorValue = proofParamsResponse?.data.attributes.selector {
            return QueryProofSelector(decimalString: selectorValue)
        } else {
            return nil
        }
    }

    /// Passport fields the partner would actually receive (the selector's
    /// other bits switch on checks, not disclosures).
    private var revealedFields: [QueryProofField] {
        let disclosures: [QueryProofField] = [
            .name, .documentNumber, .birthDate, .sex, .nationality, .citizenship, .expirationDate,
        ]
        return selector?.enabledFields.filter { disclosures.contains($0) } ?? []
    }

    private var requesterHost: String? {
        guard let callbackURL = proofParamsResponse?.data.attributes.callbackURL else { return nil }
        return URL(string: callbackURL)?.host()
    }

    var body: some View {
        ZStack {
            if proofParamsResponse == nil {
                ProgressView()
                    .tint(FoundationTheme.accent)
                    .padding(.vertical, 200)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(FoundationTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Check what they're asking for before you share.")
                            .font(.system(size: 16))
                            .foregroundColor(FoundationTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Keeps the title clear of the sheet's close button.
                    .padding(.trailing, 32)

                    VStack(alignment: .leading, spacing: 14) {
                        if hasUniqueness {
                            makeCheckRow(
                                title: String(localized: "You're a unique person"),
                                subtitle: String(localized: "Answered yes or no")
                            )
                        }
                        if let minAge {
                            makeCheckRow(
                                title: String(localized: "You're \(minAge) or older"),
                                subtitle: String(localized: "Answered yes or no")
                            )
                        }
                        if !citizenship.isEmpty {
                            makeCheckRow(
                                title: String(localized: "Your nationality is \(Country.fromISOCode(citizenship).flag) \(citizenship)"),
                                subtitle: String(localized: "Answered yes or no")
                            )
                        }
                        if !revealedFields.isEmpty {
                            makeCheckRow(
                                title: revealedFields.map(\.displayName).joined(separator: ", "),
                                subtitle: String(localized: "Shared with them"),
                                systemImage: "eye"
                            )
                        }
                        if !hasUniqueness && minAge == nil && citizenship.isEmpty && revealedFields.isEmpty {
                            makeCheckRow(
                                title: String(localized: "You're a verified person"),
                                subtitle: String(localized: "Answered yes or no")
                            )
                        }
                    }
                    .foundationCard()

                    Text(privacyNote)
                        .font(.system(size: 15))
                        .foregroundColor(FoundationTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        Button(action: generateProof) {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(FoundationTheme.onAccent)
                                }
                                Text(isSubmitting ? "Sharing…" : "Share proof")
                            }
                        }
                        .buttonStyle(FoundationPrimaryButtonStyle())
                        .disabled(isSubmitting)
                        Button("Decline", action: onDismiss)
                            .buttonStyle(FoundationSecondaryButtonStyle())
                            .disabled(isSubmitting)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .task { await loadProofParams() }
    }

    private var title: String {
        // Foundation's own verification (FoundationVerificationManager hands
        // its proof-params URL to this same view) names Foundation, not the
        // verifier host.
        if verification.state == .awaitingProof {
            return String(localized: "Foundation wants a proof")
        }
        if let requesterHost {
            return String(localized: "\(requesterHost) wants a proof")
        }
        return String(localized: "A site wants a proof")
    }

    private var privacyNote: String {
        if revealedFields.contains(.name) || revealedFields.contains(.documentNumber) {
            return String(localized: "They'll see only what's listed above. They won't see your photo or email.")
        }
        return String(localized: "They won't see your name, photo, email or passport number.")
    }

    private func makeCheckRow(title: String, subtitle: String, systemImage: String = "checkmark.circle") -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(FoundationTheme.accent)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(FoundationTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(FoundationTheme.muted)
            }
        }
    }

    @MainActor
    private func loadProofParams() async {
        do {
            proofParamsResponse = try await VerificatorApi.getExternalRequestParams(url: proofParamsUrl)
        } catch {
            reportFailure("Failed to load proof params")
            LoggerUtil.common.error("Failed to load proof params: \(error, privacy: .public)")
            onDismiss()
        }
    }

    /// Behind Home's bell. When this sheet is Foundation's own verification
    /// (started from Home's card), it is a failed verification with Try
    /// again; for a partner site's request it is a plain error entry.
    @MainActor
    private func reportFailure(_ message: String) {
        if FoundationVerificationManager.shared.state == .awaitingProof {
            AppNotificationStore.shared.postVerificationFailure(reason: message, retry: .finishVerification)
        } else {
            AlertManager.shared.emitError(message)
        }
    }

    private func generateProof() {
        Task { @MainActor in
            isSubmitting = true
            defer { isSubmitting = false }

            do {
                guard let passport = passportManager.passport else { throw PassportManagerError.passportNotFound }

                let proof = try await userManager.generateQueryProof(
                    passport: passport,
                    params: proofParamsResponse!.data.attributes
                )

                let response = try await VerificatorApi.sendProof(
                    url: URL(string: proofParamsResponse!.data.attributes.callbackURL)!,
                    userId: proofParamsResponse!.data.id,
                    proof: proof
                )

                // Not the final word, so don't stop here. The verificator uses
                // this one status for two rules, and one of them (another of
                // its own records already holds this passport) goes stale:
                // deleted accounts, test-data resets, a recreated account.
                // Foundation's getL2VerificationStatus reads the proof,
                // tells the two apart, and checks the passport against its
                // own member records. Its answer - success, or its own
                // message behind the bell - is what the member sees.
                if response.data.attributes.status == .uniquenessCheckFailed {
                    LoggerUtil.common.warning("Verificator status \(response.data.attributes.status.rawValue, privacy: .public); deferring to the backend's check")
                    onSuccess()
                    return
                }

                if response.data.attributes.status != .verified {
                    throw VerificatorApiError.proofStatusNotVerified
                }

                AlertManager.shared.emitSuccess("Proof generated successfully")
                onSuccess()
            } catch {
                reportFailure("Failed to generate proof")
                LoggerUtil.common.error("Failed to generate query proof: \(error, privacy: .public)")
                onDismiss()
            }
        }
    }
}

#Preview {
    ZStack {}
        .dynamicSheet(isPresented: .constant(true), title: "Proof Request") {
            ProofRequestView(
                proofParamsUrl: URL(string: "https://api.orgs.app.stage.rarime.com/integrations/verificator-svc/public/proof-params/0x69d9c5f9dd91dbaff7815947e58dade0db8c8d89e1223259399de86bfc9abd")!,
                onSuccess: {},
                onDismiss: {}
            )
            .environmentObject(UserManager())
            .environmentObject(PassportManager())
            .environmentObject(FoundationVerificationManager.shared)
        }
}
