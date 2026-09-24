import SwiftUI

/// The scan tutorial entry on the photo-page step, in Foundation's style:
/// a white card with a brand-gradient play tile (the hero's mesh colours).
struct FoundationScanTutorialCard: View {
    @State private var isTutorialPresented = false

    var body: some View {
        Button(action: { isTutorialPresented = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [FoundationTheme.brandFill, FoundationTheme.brandCyan, FoundationTheme.meshBlobs[2]],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FoundationTheme.accent)
                        .offset(x: 1)
                        .frame(width: 34, height: 34)
                        .background(FoundationTheme.surface, in: Circle())
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Watch how to scan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FoundationTheme.text)
                    Text("A short video: the photo page, then the chip.")
                        .font(.system(size: 14))
                        .foregroundColor(FoundationTheme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FoundationTheme.muted)
            }
            .foundationCard(padding: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Watch how to scan your passport"))
        .dynamicSheet(isPresented: $isTutorialPresented, fullScreen: true) {
            PassportScanTutorialView(onStart: { isTutorialPresented = false })
        }
    }
}

struct PassportScanTutorialView: View {
    @EnvironmentObject private var passportViewModel: PassportViewModel
    
    let onStart: () -> Void
    
    @State private var currentStep = PassportTutorialStep.removeCase.rawValue
    
    var body: some View {
        TabView(selection: $currentStep) {
            ForEach(PassportTutorialStep.allCases, id: \.self) { step in
                PassportScanTutorialStep(
                    step: step,
                    isUSA: passportViewModel.isUSA,
                    action: onStart,
                    currentStep: $currentStep
                )
                .tag(step.rawValue)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentStep)
    }
}

private struct PassportScanTutorialStep: View {
    let step: PassportTutorialStep
    let isUSA: Bool
    let action: () -> Void
    @Binding var currentStep: Int
    
    init(
        step: PassportTutorialStep,
        isUSA: Bool = false,
        action: @escaping () -> Void,
        currentStep: Binding<Int>
    ) {
        self.step = step
        self.isUSA = isUSA
        self.action = action
        self._currentStep = currentStep
    }
    
    private var isLastStep: Bool {
        step == PassportTutorialStep.allCases.last
    }
    
    private var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    var body: some View {
        VStack(spacing: 32) {
            LoopVideoPlayer(url: step.video(isUSA))
                .aspectRatio(362 / 404, contentMode: .fill)
                .frame(height: 404)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 14)
            
            VStack(alignment: .leading, spacing: 16) {
                Text(step.title)
                    .h2()
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(step.text)
                    .body3()
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: 100)
            Spacer()
            HorizontalDivider()
            HStack {
                if isLastStep {
                    AppButton(text: step.buttonText, rightIcon: .arrowRight) {
                        action()
                    }
                } else {
                    HorizontalStepIndicator(steps: PassportTutorialStep.allCases.count, currentStep: step.rawValue)
                    Spacer()
                    AppButton(text: step.buttonText, rightIcon: .arrowRight, width: nil) {
                        currentStep += 1
                    }
                }
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 16)
        .padding(.horizontal, 24)
    }
}

#Preview {
    FoundationScanTutorialCard()
        .environmentObject(PassportViewModel())
}
