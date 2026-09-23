import SwiftUI

struct ScanPassportMRZView: View {
    let onNext: (String) -> Void
    let onClose: () -> Void

    @State private var isManualMrzSheetPresented = false

    var body: some View {
        ScanPassportLayoutView(
            currentStep: 0,
            title: "Scan the photo page",
            onClose: onClose
        ) {
            ZStack {
                CameraPermissionView(delay: 0.5, onCancel: onClose) {
                    MRZScanView(onMrzKey: onNext)
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
            Text("Lay your passport flat in good light, with no glare. Keep the photo page inside the frame.")
                .font(.system(size: 16))
                .foregroundColor(FoundationTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
                .padding(.horizontal, FoundationTheme.horizontalPadding)
                .frame(maxWidth: .infinity)
            Spacer()
            VStack(spacing: 8) {
                PassportScanTutorialButton()
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
