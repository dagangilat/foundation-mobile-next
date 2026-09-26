import Foundation
import LocalAuthentication

class FaceIdAuth {
    static let shared = FaceIdAuth()

    func authenticate(
        onSuccess: @escaping () -> Void,
        onFailure: @escaping () -> Void,
        onNotAvailable: @escaping () -> Void
    ) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Enable Face ID Authentication"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                if success {
                    onSuccess()
                } else {
                    onFailure()
                }
            }
        } else {
            onNotAvailable()
        }
    }

    enum DeviceOwnerResult {
        case success
        /// Cancelled, failed, or the prompt was invalidated.
        case failure
        /// The phone has no passcode, so there is nothing to ask for.
        case noPasscode
    }

    /// Asks for the phone's own unlock: Face ID or Touch ID, falling back to
    /// the passcode. The completion runs on the main actor. Invalidating the
    /// returned context cancels a prompt that is still showing.
    @discardableResult
    func authenticateDeviceOwner(
        reason: String,
        completion: @escaping @MainActor (DeviceOwnerResult) -> Void
    ) -> LAContext {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let isPasscodeNotSet = error?.domain == LAErrorDomain
                && error?.code == LAError.Code.passcodeNotSet.rawValue
            Task { @MainActor in
                completion(isPasscodeNotSet ? .noPasscode : .failure)
            }
            return context
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            Task { @MainActor in
                completion(success ? .success : .failure)
            }
        }
        return context
    }
}
