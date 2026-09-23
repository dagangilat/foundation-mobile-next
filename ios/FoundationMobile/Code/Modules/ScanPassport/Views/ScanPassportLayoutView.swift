import SwiftUI

struct ScanPassportLayoutView<Content: View>: View {
    let currentStep: Int
    let title: LocalizedStringResource
    let onPrevious: (() -> Void)?
    let onClose: () -> Void

    var steps: Int = 2

    @ViewBuilder let content: Content

    init(
        currentStep: Int,
        title: LocalizedStringResource,
        onPrevious: (() -> Void)? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.currentStep = currentStep
        self.title = title
        self.onPrevious = onPrevious
        self.onClose = onClose
        self.content = content()
    }

    /// The passport flow as the user sees it: photo page, chip, then the
    /// proof being built (shown on Home's status card).
    private static let displayedStepCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 0) {
                    FoundationBackHeader("Verify", onBack: onPrevious ?? onClose)
                    if onPrevious != nil {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(FoundationTheme.muted)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("Close"))
                        .padding(.trailing, -12)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(FoundationTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Step \(currentStep + 1) of \(Self.displayedStepCount)")
                        .font(.system(size: 16))
                        .foregroundColor(FoundationTheme.muted)
                }
            }
            .padding(.horizontal, FoundationTheme.horizontalPadding)
            .padding(.bottom, 24)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
        .background(FoundationTheme.bg.ignoresSafeArea())
    }
}

#Preview {
    ScanPassportLayoutView(
        currentStep: 0,
        title: LocalizedStringResource("Scan your Passport", table: "preview"),
        onClose: {}
    ) {
        Rectangle()
            .fill(.black)
            .frame(height: 300)
        Spacer()
    }
}
