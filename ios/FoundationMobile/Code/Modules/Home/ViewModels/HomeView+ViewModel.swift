import Foundation

extension HomeView {
    class ViewModel: ObservableObject {
        // Task B5 removed the token points balance (fetch/create/referral)
        // from this view model together with the Earn module. The home screen
        // no longer talks to the upstream points service on launch.
        @Published var currentWidgetIndex = 0
    }
}
