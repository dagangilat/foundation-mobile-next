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
                // Cap Dynamic Type at xxxLarge (the upper end of the standard
                // control-center slider). Accessibility sizes (AX1-AX5) would
                // break the 48pt-pillar hero layout and the fixed-size
                // typography choices across the app. xxxLarge still noticeably
                // enlarges body + callout text for users who need it.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .onOpenURL { url in
                    Task { await AuthService.shared.handleDeepLink(url: url) }
                }
        }
    }
}
