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
                // Intentionally no scenePhase observer for pair release.
                // Triggering on .inactive/.background fires on every
                // brief flicker (control center, notifications, swipe
                // gestures) and would tear down the desktop session
                // every time the user glances at something else. The
                // 90-second heartbeat-stale sweep + scheduled
                // cleanupStalePairings handles real "app went away"
                // cases reliably (now that the composite indexes
                // for pairing_sessions are deployed). Explicit
                // sign-out fires its own release inside
                // AuthService.signOut, before the auth header is
                // gone.
        }
    }
}
