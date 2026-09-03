import Alamofire
import SwiftUI

struct ImportIdentityView: View {
    @EnvironmentObject private var decentralizedAuthManager: DecentralizedAuthManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var securityManager: SecurityManager
    
    var onNext: () -> Void
    var onBack: () -> Void
    
    @State private var privateKeyHex = ""
    @State private var privateKeyHexError = ""
    
    @State private var isManualBackup = false
    @State private var isImporting = false
    
    var body: some View {
        if isManualBackup {
            manualImportView
        } else {
            backupView
        }
    }
    
    var manualImportView: some View {
        IdentityStepLayoutView(
            title: "Import Identity",
            onBack: {
                userManager.user = nil
                isManualBackup = false
            },
            nextButton: {
                AppButton(
                    text: "Continue",
                    rightIcon: .arrowRight,
                    action: importIdentity
                )
                .controlSize(.large)
                .disabled(isImporting)
            }
        ) {
            VStack {
                VStack(spacing: 20) {
                    AppTextField(
                        text: $privateKeyHex,
                        errorMessage: $privateKeyHexError,
                        placeholder: String(localized: "Your private key")
                    )
                    .onSubmit(importIdentity)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isImporting)
                }
            }
        }
    }
    
    var backupView: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onBack) {
                Image(.arrowLeft)
                    .iconMedium()
                    .foregroundStyle(.textPrimary)
            }
            .padding(.top, 20)
            .padding(.leading, 20)
            VStack(spacing: 32) {
                VStack {
                    Image(.cloud)
                        .square(72)
                        .foregroundStyle(.primaryDarker)
                }
                .padding(40)
                .background(.primaryLighter)
                .clipShape(Circle())
                VStack(spacing: 12) {
                    Text("Restore your account")
                        .h2()
                        .foregroundStyle(.textPrimary)
                    Text("You can restore your account using your iCloud backup or private key")
                        .body3()
                        .foregroundStyle(.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                Spacer()
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        AppButton(
                            text: "Restore with iCloud",
                            action: restoreFromICloud
                        )
                        .controlSize(.large)
                        .disabled(isImporting)
                        AppButton(
                            variant: .quartenary,
                            text: "Restore manually",
                            action: { isManualBackup = true }
                        )
                        .controlSize(.large)
                        .disabled(isImporting)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
            .padding(.bottom, 16)
        }
        .background(.bgPure)
    }
    
    func restoreFromICloud() {
        isImporting = true
        
        Task { @MainActor in
            defer {
                self.isImporting = false
            }
            
            do {
                let isICloudAvailable = try await CloudStorage.shared.isICloudAvailable()
                if !isICloudAvailable {
                    AlertManager.shared.emitError(.unknown(String(localized: "iCloud is not available")))
                    onBack()
                    return
                }
                
                userManager.user = try await User.loadFromCloud()
                
                if userManager.user == nil {
                    AlertManager.shared.emitError(.unknown(String(localized: "No backup found in iCloud")))
                    onBack()
                    return
                }
                
                try userManager.user?.save()
                
                LoggerUtil.common.info("Identity was imported")

                securityManager.disablePasscode()

                onNext()
            } catch {
                LoggerUtil.common.error("Failed to restore from iCloud: \(error, privacy: .public)")
            }
        }
    }
    
    func importIdentity() {
        isImporting = true
        
        Task { @MainActor in
            defer {
                self.isImporting = false
            }
            
            do {
                if try !isValidPrivateKey(privateKeyHex) {
                    privateKeyHexError = String(localized: "Invalid private key")
                    return
                }
                
                guard let privateKey = Data(hex: privateKeyHex) else {
                    privateKeyHexError = String(localized: "Invalid private key")
                    return
                }
                
                try userManager.createFromSecretKey(privateKey)
                try userManager.user?.save()
                
                LoggerUtil.common.info("Identity was imported")

                securityManager.disablePasscode()

                onNext()
            } catch {
                LoggerUtil.common.error("failed to import identity: \(error, privacy: .public)")
            }
        }
    }
}

private func isValidPrivateKey(_ privateKey: String) throws -> Bool {
    let regex = try NSRegularExpression(
        pattern: "^[0-9a-fA-F]{64}$",
        options: .caseInsensitive
    )
    
    return regex.firstMatch(
        in: privateKey,
        options: [],
        range: NSRange(location: 0, length: privateKey.utf16.count)
    ) != nil
}

#Preview {
    ImportIdentityView(onNext: {}, onBack: {})
        .environmentObject(DecentralizedAuthManager.shared)
        .environmentObject(UserManager.shared)
        .environmentObject(SecurityManager.shared)
}
