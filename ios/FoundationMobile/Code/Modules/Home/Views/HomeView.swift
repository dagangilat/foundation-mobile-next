import SwiftUI

private enum HomeRoute: String, Hashable {
    case notifications
}

struct HomeView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var mainViewModel: MainView.ViewModel
    @EnvironmentObject private var passportManager: PassportManager

    @StateObject var viewModel = ViewModel()

    @State private var path: [HomeRoute] = []
    @State private var selectedWidget: HomeWidget? = nil
    @State private var isOnboardingPresented = false

    @Namespace private var recoveryNamespace

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .notifications:
                        NotificationsView(onBack: { path.removeLast() })
                            .environment(\.managedObjectContext,
                                         notificationManager.pushNotificationContainer.viewContext)
                            .navigationBarBackButtonHidden()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch selectedWidget {
            case .recovery:
                RecoveryMethodView(
                    animation: namespace(for: .recovery),
                    onClose: { selectedWidget = nil }
                )

            default:
                mainLayoutContent
            }

            HomeOnboardingView(
                isPresented: isOnboardingPresented,
                onComplete: {
                    isOnboardingPresented = false
                    AppUserDefaults.shared.isHomeOnboardingCompleted = true
                }
            )
            .transition(.identity)
            .zIndex(1)
        }
        .animation(
            .interpolatingSpring(stiffness: 100, damping: 15),
            value: selectedWidget
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isOnboardingPresented = !AppUserDefaults.shared.isHomeOnboardingCompleted
            }
        }
    }

    @ViewBuilder
    private var mainLayoutContent: some View {
        MainViewLayout {
            VStack(spacing: 0) {
                header
                HomeWidgetsView(
                    selectedWidget: $selectedWidget,
                    namespaceProvider: namespace
                )
                .environmentObject(viewModel)
            }
            .background(.bgPrimary)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Hi")
                    .h3()
                    .foregroundStyle(.textPrimary)

                if let passport = passportManager.passport {
                    Text(passport.displayedFirstName.capitalized.components(separatedBy: " ").first ?? "")
                        .additional3()
                        .foregroundStyle(.textSecondary)
                } else {
                    Text("Stranger")
                        .additional3()
                        .foregroundStyle(.textSecondary)
                }
            }

            #if DEVELOPMENT
            Text("Development")
                .caption2()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.warningLighter, in: Capsule())
                .foregroundStyle(Color.warningDark)
            #endif

            Spacer()

            ZStack {
                Button {
                    path.append(.notifications)
                } label: {
                    Image(.notification2Line)
                        .iconMedium()
                        .foregroundStyle(.textPrimary)
                }

                if notificationManager.unreadNotificationsCounter > 0 {
                    Text(verbatim: "\(notificationManager.unreadNotificationsCounter)")
                        .overline3()
                        .foregroundStyle(.baseWhite)
                        .frame(width: 16, height: 16)
                        .background(Color.errorMain, in: Circle())
                        .overlay { Circle().stroke(Color.invertedLight, lineWidth: 2) }
                        .offset(x: 7, y: -8)
                }
            }
        }
        .zIndex(1)
        .padding([.top, .horizontal], 20)
        .padding(.bottom, 16)
        .background(Color.bgPrimary)
    }

    private func namespace(for key: HomeWidget) -> Namespace.ID {
        switch key {
        case .recovery: return recoveryNamespace
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(MainView.ViewModel())
        .environmentObject(PassportManager())
        .environmentObject(NotificationManager())
        .environmentObject(ConfigManager())
}
