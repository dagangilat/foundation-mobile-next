import MessageUI
import SwiftUI

struct WaitlistPassportView: View {
    @EnvironmentObject var passportManager: PassportManager

    let onNext: () -> Void
    let onCancel: () -> Void

    @State private var isChecked = false
    @State private var isSending = false
    @State private var isExporting = false
    @State private var isCopied = false

    var country: Country {
        passportManager.passportCountry
    }
    
    var serializedPassport: Data {
        return (try? passportManager.passport?.serialize()) ?? Data()
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppIconButton(icon: .closeFill, action: onCancel)
                .padding([.top, .trailing], 20)
            VStack(spacing: 28) {
                Text(country.flag)
                    .h2()
                    .frame(width: 88, height: 88)
                    .background(.bgComponentPrimary, in: Circle())
                    .foregroundStyle(.textPrimary)
                VStack(spacing: 8) {
                    Text("Waitlist passport")
                        .h3()
                        .foregroundStyle(.textPrimary)
                    Text(country.name)
                        .body4()
                        .foregroundStyle(.textSecondary)
                }
                HorizontalDivider()
                VStack(alignment: .leading, spacing: 24) {
                    Text("Become an ambassador")
                        .h4()
                    Text("If you would like to enroll your country in the early phase, we will need your consent to share some data.")
                        .body4()
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 12) {
                        AppCheckbox(checked: $isChecked)
                        Text("By checking this box, you are agreeing to share the data groups of the passport and the government signature")
                            .body5()
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(.textSecondary)
                    }
                }
                .foregroundStyle(.textPrimary)
                Spacer()
                VStack(spacing: 8) {
                    AppButton(
                        text: "Continue",
                        rightIcon: .arrowRight,
                        action: {
                            if isChecked {
                                isSending = true
                            } else {
                                onNext()
                            }
                        }
                    )
                    .controlSize(.large)
                    .disabled(isSending)
                    AppButton(
                        variant: .quartenary,
                        text: "Cancel",
                        action: onCancel
                    )
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 140)
        }
        .onChange(of: isSending) { isSending in
            if !isSending {
                onNext()
            }
        }
        .dynamicSheet(isPresented: $isSending, fullScreen: true) {
            if MFMailComposeViewController.canSendMail() {
                MailView(
                    subject: "Passport from: \(UIDevice.modelName)",
                    attachment: (try? passportManager.passport?.serialize()) ?? Data(),
                    fileName: "passport.json",
                    isShowing: $isSending,
                    result: .constant(nil)
                )
            } else {
                savePassportDataView
            }
        }
    }
    
    var savePassportDataView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(spacing: 16) {
                Image(.identificationCard)
                    .square(44)
                    .frame(width: 88, height: 88)
                    .background(.bgComponentPrimary, in: Circle())
                    .foregroundStyle(.textPrimary)
                Text("Save your passport data")
                    .h4()
                    .foregroundStyle(.textPrimary)
                Text("Your passport data will be saved on your device. You can share it with us to expedite the support of your passport.")
                    .body4()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
                    .foregroundStyle(.textSecondary)
                HorizontalDivider()
                VStack(alignment: .leading, spacing: 16) {
                    Text("HOW TO SHARE")
                        .overline2()
                        .foregroundStyle(.textSecondary)
                    Text("1. Save passport data on your device")
                        .body4()
                        .foregroundStyle(.textPrimary)
                    Text("2. Send the saved file to the email address below")
                        .body4()
                        .foregroundStyle(.textPrimary)
                    HStack(spacing: 8) {
                        Text(ConfigManager.shared.general.feedbackEmail)
                            .body3()
                            .foregroundStyle(.textPrimary)
                        Image(isCopied ? .check : .copySimple).iconMedium()
                    }
                    .onTapGesture {
                        if isCopied { return }
                        UIPasteboard.general.string = ConfigManager.shared.general.feedbackEmail
                        isCopied = true
                        FeedbackGenerator.shared.impact(.medium)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            isCopied = false
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.bgComponentPrimary)
                    .foregroundStyle(.textPrimary)
                    .cornerRadius(8)
                    Text("3. When we support your country, you will be notified in the app")
                        .body4()
                        .foregroundStyle(.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            Spacer()
            AppButton(
                text: "Save to files",
                rightIcon: .arrowRight,
                action: { isExporting = true }
            )
            .controlSize(.large)
            .fileExporter(
                isPresented: $isExporting,
                document: JSONDocument(serializedPassport),
                contentType: .json,
                defaultFilename: "passport.json"
            ) { result in
                switch result {
                case .success:
                    LoggerUtil.common.info("Passport data saved")
                    onNext()
                case .failure(let error):
                    LoggerUtil.common.error("Failed to save passport data: \(error, privacy: .public)")
                }
            }
        }
        .padding(.top, 80)
        .padding(.bottom, 20)
        .padding(.horizontal, 24)
    }
    
}

#Preview {
    WaitlistPassportView(onNext: {}, onCancel: {})
        .environmentObject(PassportViewModel())
}
