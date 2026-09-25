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
        VStack(alignment: .leading, spacing: 24) {
            FoundationBackHeader(onBack: onBack)
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "icloud")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(FoundationTheme.accent)
                    .frame(width: 64, height: 64)
                    .background(FoundationTheme.accentTint, in: Circle())
                    .padding(.bottom, 8)
                Text("Restore your ID")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(FoundationTheme.text)
                Text("Restore from your iCloud backup, or paste your private key.")
                    .font(.system(size: 16))
                    .foregroundColor(FoundationTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Button(action: restoreFromICloud) {
                    HStack(spacing: 8) {
                        if isImporting {
                            ProgressView()
                                .tint(FoundationTheme.onAccent)
                        }
                        Text("Restore with iCloud")
                    }
                }
                .buttonStyle(FoundationPrimaryButtonStyle())
                .disabled(isImporting)
                Button("Use my private key") { isManualBackup = true }
                    .buttonStyle(FoundationTextButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: FoundationTheme.buttonHeight)
                    .disabled(isImporting)
            }
        }
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FoundationTheme.bg.ignoresSafeArea())
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
                // Keys copied from other apps often carry a "0x" prefix,
                // spaces or a line break.
                var keyHex = privateKeyHex.filter { !$0.isWhitespace }
                if keyHex.lowercased().hasPrefix("0x") { keyHex = String(keyHex.dropFirst(2)) }
                
                if try !isValidPrivateKey(keyHex) {
                    privateKeyHexError = String(localized: "Invalid private key")
                    return
                }
                
                guard let privateKey = Data(hex: keyHex) else {
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
