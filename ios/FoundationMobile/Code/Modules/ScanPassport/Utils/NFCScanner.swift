import CoreNFC
import NFCPassportReader
import OpenSSL
import SwiftUI

class NFCScanner {
    /// Whether this device can read an NFC chip at all. False on devices
    /// without NFC (and in the Simulator). iOS has no user-facing NFC switch,
    /// so unlike Android there is no "NFC is off" case to check for.
    static var isReadingAvailable: Bool {
        NFCTagReaderSession.readingAvailable
    }

    private static let customDisplayMessage: (NFCViewDisplayMessage) -> String? = { displayMessage in
        // Forked from NFCViewDisplayMessage
        func drawProgressBar(_ progress: Int) -> String {
            let itemsCount = (progress / 20)
            let full = String(repeating: "🟢 ", count: itemsCount)
            let empty = String(repeating: "⚪️ ", count: 5 - itemsCount)
            return "\(full)\(empty)"
        }
        
        let message: LocalizedStringResource?
        switch displayMessage {
        case .requestPresentPassport:
            message = "Hold your iPhone near an NFC enabled passport.\n"
        case .authenticatingWithPassport(let progress):
            message = "Authenticating with passport...\n\n\(drawProgressBar(progress))"
        case .activeAuthentication:
            message = "Authenticating with passport..."
        case .readingDataGroupProgress(let dataGroup, let progress):
            message = "Reading passport data (\(dataGroup.getName()))...\n\n\(drawProgressBar(progress))"
        case .error(let tagError):
            switch tagError {
            case .TagNotValid: message = "Tag not valid."
            case .MoreThanOneTagFound: message = "More than 1 tag was found. Please present only 1 tag."
            case .ConnectionError: message = "Connection error. Please try again."
            case .InvalidMRZKey: message = "MRZ Key not valid for this document."
            case .ResponseError(let reason, let sw1, let sw2):
                message = "Sorry, there was a problem reading the passport. \(reason). Error codes: [0x\(sw1), 0x\(sw2)]"
            default: message = "Sorry, there was a problem reading the passport. Please try again"
            }
        case .successfulRead:
            message = "Passport read successfully"
        }
        
        return message == nil ? nil : String(localized: message!)
    }
    
    static func scanPassport(
        _ mrzKey: String,
        _ challenge: Data,
        _ useExtendedMode: Bool = true,
        onCompletion: @escaping (Result<Passport, Error>) -> Void
    ) {
        // Callers check `isReadingAvailable` first and show
        // `NFCUnavailableCard`; this is the backstop, so the reader never
        // starts a session this device can't run.
        guard isReadingAvailable else {
            onCompletion(.failure(NFCScannerError.nfcNotAvailable))
            return
        }

        Task { @MainActor in
            var tags: [DataGroupId] = [.DG1, .DG15, .SOD]
            
            #if PRODUCTION
                tags.append(.DG2)
            #endif
            
            do {
                let nfcPassport = try await PassportReader()
                    .readPassport(
                        mrzKey: mrzKey,
                        tags: tags,
                        useExtendedMode: useExtendedMode,
                        customDisplayMessage: customDisplayMessage,
                        activeAuthenticationChallenge: [UInt8](challenge)
                    )
                
                guard let passport = Passport.fromNFCPassportModel(nfcPassport) else { throw NFCScannerError.passportReadingFailed }
                
                onCompletion(.success(passport))
            } catch {
                onCompletion(.failure(error))
            }
        }
    }
}

enum NFCScannerError: Error {
    case passportReadingFailed
    /// This device can't read NFC chips (`NFCScanner.isReadingAvailable`).
    case nfcNotAvailable
    
    var localizedDescription: String {
        switch self {
        case .passportReadingFailed:
            return "Passport reading failed"
        case .nfcNotAvailable:
            return String(localized: "This phone can't read passport chips")
        }
    }
}

/// Shown instead of a chip scan when this device can't read NFC chips
/// (`NFCScanner.isReadingAvailable` is false). Mirrors Android's
/// `NfcUnavailableCard`, minus its "Turn on NFC" case: iOS has no NFC switch.
struct NFCUnavailableCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(FoundationTheme.dangerIcon)
                .frame(width: 40, height: 40)
                .background(FoundationTheme.dangerTint, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("This phone can't read passport chips")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(FoundationTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Passport verification needs NFC, and this phone doesn't have it. Use a phone with NFC to verify.")
                    .font(.system(size: 15))
                    .foregroundColor(FoundationTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foundationCard(padding: 18)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NFCUnavailableCard()
        .padding(24)
        .background(FoundationTheme.bg)
}
