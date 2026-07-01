import SwiftUI

struct WalletDocumentScanView: View {
    let profile: DocumentProfile
    let onScanTap: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text("Hold your iPhone near the credential holder's iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Apple will prompt to present the \(profile.displayName).")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Start Reading", action: onScanTap)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}
