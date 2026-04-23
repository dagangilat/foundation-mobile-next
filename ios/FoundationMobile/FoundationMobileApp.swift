import SwiftUI

@main
struct FoundationMobileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    Task {
                        do {
                            _ = try await AuthService.shared.completeSignIn(url: url)
                        } catch {
                            // Keep silent — the UI stays on SignInView and the
                            // user can re-send the link. No PII in logs.
                        }
                    }
                }
        }
    }
}
