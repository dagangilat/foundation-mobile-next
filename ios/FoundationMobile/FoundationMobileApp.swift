import SwiftUI

@main
struct FoundationMobileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared

    init() {
        // Install the palette named in the baked profile JSON before any
        // view renders. Falls back to `midnight` if the profile omits `theme`.
        Theme.apply(paletteNamed: AppConfig.shared.themePaletteName)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                // System chrome (keyboard, cursors, nav bar) follows the
                // palette brightness; our own surfaces are explicitly colored.
                .preferredColorScheme(Theme.palette.isDark ? .dark : .light)
                // Universal Link no-op handler.
                //
                // The email-link sign-in path was retired on 2026-04-28
                // (see AuthService.swift MARK comment + the architecture
                // review doc). iOS sign-in is now exclusively via the
                // OTP code flow. Leaving onOpenURL in place but empty
                // so that:
                //   1. Any stale email-link tapped from an old invite
                //      that does Universal-Link us into the app
                //      doesn't crash — it just no-ops, the user is on
                //      SignInView, types their email, gets a new code.
                //   2. The associated-domains entitlement
                //      (applinks:foundation-global.com,
                //      applinks:solanavote-devnet.firebaseapp.com)
                //      stays valid — removing the handler would still
                //      leave Universal Links technically "claimed" by
                //      the app at the OS level, just with no in-app
                //      response.
                //
                // If we ever bring back URL-based deep-linking for a
                // different purpose (e.g. share-a-proposal), gate it
                // on the URL path here, NOT the host alone — the
                // earlier defense-in-depth host allowlist was
                // specifically for the email-link attack surface
                // which no longer exists.
                .onOpenURL { _ in /* no-op — see comment above */ }
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
