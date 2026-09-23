import SwiftUI

struct ProfileRouteLayout<Content: View>: View {
    let title: String
    let onBack: () -> Void

    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            FoundationBackHeader(LocalizedStringKey(title), onBack: onBack)
            content()
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FoundationTheme.bg.ignoresSafeArea())
    }
}

#Preview {
    ProfileRouteLayout(
        title: "Profile Route Title",
        onBack: {}
    ) {
        VStack {
            CardContainer {
                Text(String("Profile Route Content"))
            }
        }
    }
}
