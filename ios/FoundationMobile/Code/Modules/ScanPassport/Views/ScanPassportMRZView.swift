import SwiftUI

struct ScanPassportMRZView: View {
    let onNext: (String) -> Void
    let onClose: () -> Void

    @State private var isManualMrzSheetPresented = false
    @StateObject private var mrzViewModel = MRZScanView.ViewModel()

    var body: some View {
        ScanPassportLayoutView(
            currentStep: 0,
            title: "Scan the photo page",
            onClose: onClose
        ) {
            ZStack {
                CameraPermissionView(delay: 0.5, onCancel: onClose) {
                    MRZScanView(viewModel: mrzViewModel, onMrzKey: onNext)
                }
                .frame(maxWidth: .infinity, maxHeight: 305)
                Image(.passportFrame)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 228)
            }
            .frame(maxWidth: .infinity)
            .background(FoundationTheme.scanBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, FoundationTheme.horizontalPadding)
            Text("Lay your passport open at the photo page, flat in good light with no glare. Hold your phone about 30 cm (a foot) above it so the picture is sharp. It scans by itself, or tap Capture.")
                .font(.system(size: 16))
                .foregroundColor(FoundationTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
                .padding(.horizontal, FoundationTheme.horizontalPadding)
                .frame(maxWidth: .infinity)
            Spacer()
            VStack(spacing: 12) {
                if mrzViewModel.captureFailed {
                    Text("Couldn't read the two lines of letters and <<< at the bottom of the photo page. Hold the phone a little further away until those lines look sharp on screen, keep them in the frame without glare, and tap Capture again.")
                        .font(.system(size: 14))
                        .foregroundColor(FoundationTheme.danger)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                Button {
                    Task { await mrzViewModel.capture() }
                } label: {
                    if mrzViewModel.isCapturing {
                        ProgressView()
                            .tint(FoundationTheme.onAccent)
                    } else {
                        Label("Capture", systemImage: "camera.viewfinder")
                    }
                }
                .buttonStyle(FoundationPrimaryButtonStyle())
                .disabled(mrzViewModel.currentFrame == nil || mrzViewModel.isCapturing)
                FoundationScanTutorialCard()
                Button("Enter details manually") { isManualMrzSheetPresented = true }
                    .buttonStyle(FoundationTextButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: FoundationTheme.buttonHeight)
                    .dynamicSheet(isPresented: $isManualMrzSheetPresented, title: "Enter details manually") {
                        MrzFormView(onSubmitted: { mrzKey in
                            LoggerUtil.common.info("MRZ filled manually")
                            onNext(mrzKey)
                        })
                    }
            }
            .padding(.horizontal, FoundationTheme.horizontalPadding)
            .animation(.easeInOut(duration: 0.2), value: mrzViewModel.captureFailed)
        }
    }
}

#Preview {
    ScanPassportMRZView(
        onNext: { _ in },
        onClose: {}
    )
    .environmentObject(PassportViewModel())
}
