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
            LoadingView()
        } else {
            switch auth.state {
            case .loading:
                LoadingView()
            case .signedOut:
                SignInView()
            case .signedIn(let claims):
                HomeView(claims: claims)
            }
        }
    }
}
