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
    private static var displayedStepCount: Int { 3 }

    /// The "Step n of 3" line, replaced by the 3-part stepper. Kept, hidden.
    private static var showsStepCountLine: Bool { false }

    /// The close (X) button beside Back. The guided flow's screens only go
    /// back (to the step's explainer), so it is hidden; kept for reuse.
    private static var showsCloseButton: Bool { false }

    private var stage: PassportVerifyStage {
        PassportVerifyStage(rawValue: currentStep) ?? .photoPage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 0) {
                    FoundationBackHeader("Verify", onBack: onPrevious ?? onClose)
                    if Self.showsCloseButton && onPrevious != nil {
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
                    if Self.showsStepCountLine {
                        Text("Step \(currentStep + 1) of \(Self.displayedStepCount)")
                            .font(.system(size: 16))
                            .foregroundColor(FoundationTheme.muted)
                    }
                }
                PassportVerifyStepper(current: stage)
            }
            .padding(.horizontal, FoundationTheme.horizontalPadding)
            .padding(.bottom, 18)
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
