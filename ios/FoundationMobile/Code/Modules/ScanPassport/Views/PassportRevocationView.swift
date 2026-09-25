import SwiftUI

/// Shown mid-registration when the passport is already registered to another
/// identity (another app install or device). One more chip scan signs the
/// chain's challenge, which revokes that registration and moves the passport
/// to this phone.
struct PassportRevocationView: View {
    @EnvironmentObject var passportViewModel: PassportViewModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(FoundationTheme.accent)
                .frame(width: 88, height: 88)
                .background(FoundationTheme.accentTint, in: Circle())
            VStack(spacing: 12) {
                Text("This passport is already registered")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(FoundationTheme.text)
                    .multilineTextAlignment(.center)
                Text("It was registered from another app or device. Scan the chip once more to move it to this phone. The earlier registration will stop working.")
                    .font(.system(size: 16))
                    .foregroundColor(FoundationTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                NFCScanner.scanPassport(
                    passportViewModel.mrzKey ?? AppUserDefaults.shared.lastMRZKey,
                    passportViewModel.revocationChallenge,
                    false,
                    onCompletion: { result in
                        switch result {
                        case .success(let passport):
                            LoggerUtil.common.info("Revocation chip scan succeeded")

                            passportViewModel.revocationPassportPublisher.send(passport)
                            passportViewModel.isUserRevoking = false
                        case .failure(let error):
                            LoggerUtil.common.error("failed to read passport data: \(error.localizedDescription, privacy: .public)")

                            passportViewModel.revocationPassportPublisher.send(completion: .failure(error))

                            passportViewModel.isUserRevoking = false
                        }
                    }
                )
            } label: {
                Label("Scan the chip", systemImage: "wave.3.right")
            }
            .buttonStyle(FoundationPrimaryButtonStyle())
        }
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .padding(.vertical, 20)
        .background(FoundationTheme.bg.ignoresSafeArea())
    }
}

#Preview {
    PassportRevocationView()
        .environmentObject(PassportViewModel())
}
