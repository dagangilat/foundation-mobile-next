import SwiftUI

// Minimum-duration splash from AppConfig. Even when auth resolves in <100ms
// (warm launch, cached session), LoadingView shows for at least this long so
// the user gets a proper branded opening moment.

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @State private var minSplashElapsed = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            content
                .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.25), value: minSplashElapsed)
        .animation(.easeOut(duration: 0.25), value: auth.state)
        .task {
            try? await Task.sleep(nanoseconds: AppConfig.shared.splash.minDurationMs * 1_000_000)
            minSplashElapsed = true
        }
    }

    @ViewBuilder
    private var content: some View {
        if !minSplashElapsed {
            // Same .id as the auth.state == .loading branch below so SwiftUI
            // preserves view identity across the minSplashElapsed flip. Without
            // this, the LoadingView at position-A (splash window) is torn
            // down and rebuilt at position-B (auth-still-loading) when the
            // splash timer fires — IndeterminateBar.onAppear runs again,
            // sweepOffset resets to -1 (offscreen), .task's startedAt
            // re-anchors, and the splash looks frozen from ~minDurationMs
            // until auth resolves.
            LoadingView()
                .id("foundation-loading-splash")
        } else {
            switch auth.state {
            case .loading:
                LoadingView()
                    .id("foundation-loading-splash")
            case .signedOut:
                SignInView()
            case .signedIn(let claims):
                HomeView(claims: claims)
            }
        }
    }
}
