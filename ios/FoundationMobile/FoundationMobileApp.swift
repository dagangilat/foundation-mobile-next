import SwiftUI

@main
struct FoundationMobileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared
    @Environment(\.scenePhase) private var scenePhase

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
                .onChange(of: scenePhase) { newPhase in
                    // Desktop pairing tears down whenever the app stops being
                    // active. iOS does not reliably call applicationWillTerminate;
                    // backgrounding is the latest signal we can trust before
                    // the OS evicts us.
                    if newPhase != .active {
                        PairingCoordinator.shared.suspendOnLifecycleEvent()
                    }
                }
        }
    }
}
