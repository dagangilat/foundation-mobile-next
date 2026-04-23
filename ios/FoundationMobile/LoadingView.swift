import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.brandGreen)
            Text("Checking sign-in…")
                .font(.callout)
                .foregroundStyle(Theme.muted)
        }
    }
}
