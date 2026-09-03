import Alamofire
import SwiftUI

private struct WidgetWrapper {
    let widget: HomeWidget
    let card: SnapCarouselCard
}

struct HomeWidgetsView: View {
    @EnvironmentObject private var homeViewModel: HomeView.ViewModel

    @Binding var selectedWidget: HomeWidget?
    let namespaceProvider: (HomeWidget) -> Namespace.ID

    @StateObject private var viewModel = HomeWidgetsViewModel()

    @State private var isCopied = false
    @State private var isManageSheetPresented = false

    var body: some View {
        ZStack(alignment: .trailing) {
            SnapCarouselView(
                index: $homeViewModel.currentWidgetIndex,
                cards: visibleWidgets.map { $0.card },
                spacing: 30,
                trailingSpace: 20,
                bottomContentHeight: 56
            ) {
                AppButton(
                    text: "Manage widgets",
                    leftIcon: .filter3Line,
                    width: 160,
                    action: { isManageSheetPresented = true }
                )
                .controlSize(.large)
            }
            .disabled(selectedWidget != nil)
            .padding(.horizontal, 22)
            VerticalStepIndicator(
                steps: visibleWidgets.count,
                currentStep: homeViewModel.currentWidgetIndex
            )
            .padding(.trailing, 8)
        }
        .dynamicSheet(isPresented: $isManageSheetPresented) {
            ManageWidgetsView(
                selectedWidgets: viewModel.widgets,
                onAdd: { widget in
                    viewModel.addWidget(widget)
                    homeViewModel.currentWidgetIndex = visibleWidgets.count
                },
                onRemove: { widget in
                    viewModel.removeWidget(widget)
                    homeViewModel.currentWidgetIndex = visibleWidgets.count
                }
            )
            .padding(.top, 18)
        }
    }

    private var visibleWidgets: [WidgetWrapper] {
        [
            recoveryWidget,
        ]
        .filter { $0.widget.isVisible }
        .filter { viewModel.widgets.contains($0.widget) }
    }

    private var recoveryWidget: WidgetWrapper {
        WidgetWrapper(
            widget: .recovery,
            card: SnapCarouselCard(action: { selectedWidget = .recovery }) {
                HomeCardView(
                    foregroundGradient: Gradients.greenText,
                    foregroundColor: .invertedDark,
                    topIcon: .foundationMark,
                    bottomIcon: .arrowRightUpLine,
                    imageContent: {
                        Image(.recoveryBg)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                    },
                    title: "Recovery",
                    subtitle: "Method",
                    bottomContent: {
                        Text("Set up a new way to recover your account")
                            .body4()
                            .foregroundStyle(.textSecondary)
                            .frame(maxWidth: 220, alignment: .leading)
                            .padding(.top, 12)
                    },
                    animation: namespaceProvider(.recovery)
                )
            }
        )
    }
}

#Preview {
    HomeWidgetsView(
        selectedWidget: Binding<HomeWidget?>(
            get: { nil },
            set: { _ in }
        ),
        namespaceProvider: { _ in Namespace().wrappedValue }
    )
    .environmentObject(HomeView.ViewModel())
}
