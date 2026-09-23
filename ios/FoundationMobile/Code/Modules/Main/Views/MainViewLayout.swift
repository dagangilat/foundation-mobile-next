import SwiftUI

struct MainViewLayout<Content: View>: View {
    @ViewBuilder var content: Content

    // The bottom tab bar (NavBarView) is unhooked: Foundation's Home is the
    // single root screen, with Profile and QR scan opened from it.
    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(MainView.ViewModel())
        .environmentObject(PassportViewModel())
        .environmentObject(FoundationVerificationManager.shared)
        .environmentObject(PassportManager())
        .environmentObject(UserManager())
        .environmentObject(ConfigManager())
        .environmentObject(NotificationManager())
        .environmentObject(ExternalRequestsManager())
}
