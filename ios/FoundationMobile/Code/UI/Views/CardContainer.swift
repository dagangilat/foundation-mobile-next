import SwiftUI

struct CardContainer<Content: View>: View {
    var content: () -> Content

    var body: some View {
        // Foundation status-card look (white surface, 12 radius, 1pt border).
        VStack(alignment: .leading, content: content)
            .foundationCard()
    }
}

#Preview {
    VStack {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(String("Wallet")).buttonLarge()
                Text(String("Manage your assets")).body4()
            }
        }
    }
    .frame(height: 300)
    .background(.bgPrimary)
}
