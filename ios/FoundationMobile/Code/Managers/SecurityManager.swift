import Foundation

enum SecurityItemState: Int {
    case unset, enabled, disabled
}

class SecurityManager: ObservableObject {
    static let shared = SecurityManager()

    @Published var passcodeState: SecurityItemState {
        didSet {
            AppUserDefaults.shared.passcodeState = passcodeState.rawValue
        }
    }

    @Published var faceIdState: SecurityItemState {
        didSet {
            AppUserDefaults.shared.faceIdState = faceIdState.rawValue
        }
    }

    @Published private(set) var passcode: String

    @Published var isPasscodeCorrect: Bool

    init() {
        let passcodeState = SecurityItemState(rawValue: AppUserDefaults.shared.passcodeState)!
        let faceIdState = SecurityItemState(rawValue: AppUserDefaults.shared.faceIdState)!

        let passcodeBytes = (try? AppKeychain.getValue(.passcode) ?? Data()) ?? Data()

        self.passcode = passcodeBytes.utf8
        // Same rule as `rearmPasscodeLock()` below, spelled out here because a
        // stored property cannot be initialised by calling an instance method.
        // If you change one, change the other.
        self.isPasscodeCorrect = passcodeState != .enabled
        self.passcodeState = passcodeState
        self.faceIdState = faceIdState
    }

    /// Put the passcode gate back the way a cold launch would leave it.
    ///
    /// `isPasscodeCorrect` is the flag `AppView` reads to choose between
    /// `MainView` and `LockScreenView`, and until this existed it was only ever
    /// set to `false` in `init` - i.e. only at a cold launch. Nothing in the
    /// sign-out path touched it, so mid-session it stayed `true` from the
    /// departing member's unlock: person A taps Sign Out, hands the still-warm
    /// device to person B, B signs in with their own email, and `AppView` walks
    /// them straight into `MainView` holding A's local Rarimo passport identity
    /// - now bound to B's Foundation uid. Sign Out and Delete Account both call
    /// this so that stops being possible.
    ///
    /// The `passcodeState != .enabled` form rather than a bare `false` is the
    /// point: a device with no passcode configured must not be pushed at a lock
    /// screen it could never satisfy.
    func rearmPasscodeLock() {
        isPasscodeCorrect = passcodeState != .enabled
    }

    func enablePasscode(_ newPasscode: String) {
        passcodeState = .enabled

        passcode = newPasscode
        try? AppKeychain.setValue(.passcode, newPasscode.data(using: .utf8) ?? Data())
    }

    func disablePasscode() {
        passcodeState = .disabled
        disableFaceId()
        try? AppKeychain.removeValue(.passcode)
    }

    func enableFaceId() {
        faceIdState = .enabled
    }

    func disableFaceId() {
        faceIdState = .disabled
    }

    func reset() {
        passcodeState = .unset
        faceIdState = .unset
        passcode = ""
        isPasscodeCorrect = true
        try? AppKeychain.removeValue(.passcode)
    }
}
