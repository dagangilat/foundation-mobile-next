import SwiftUI

// Minimum-duration splash: even when auth resolves in <100ms (warm launch,
// cached session), LoadingView shows for MIN_SPLASH_MS so the user gets a
// proper branded "opening" moment — the three-pillar hero fades in over the
// dark UILaunchScreen and lingers long enough to register before the app
// content takes over.
private let MIN_SPLASH_MS: UInt64 = 900

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
            try? await Task.sleep(nanoseconds: MIN_SPLASH_MS * 1_000_000)
            minSplashElapsed = true
        }
    }

    @ViewBuilder
    private var content: some View {
        if !minSplashElapsed {
            LoadingView()
        } else {
            switch auth.state {
            case .loading:
                LoadingView()
            case .signedOut:
                // While a Universal Link is being consumed, keep LoadingView
                // on screen with a contextual message instead of flashing the
                // SignInView form for the ~1s network round-trip.
                if auth.isCompletingSignIn {
                    LoadingView(message: "Signing you in…")
                } else {
                    SignInView()
                }
            case .signedIn(let claims):
                HomeView(claims: claims)
            }
        }
    }
}
