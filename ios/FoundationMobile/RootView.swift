import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
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
