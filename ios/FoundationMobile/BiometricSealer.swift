import Foundation
import LocalAuthentication
import Security

// Biometric-bound sealing of high-value artifacts. The key lives in the
// Secure Enclave with kSecAttrAccessControl=.biometryCurrentSet — Face ID
// (or Touch ID) is mandatory for every signing operation, and the key
// is automatically invalidated by the OS if the biometric set changes
// (new face enrolled, factory reset, biometric reset by user). This is
// what "sealing with face recognition, including decoding it back with
// the same biometrics" means in practice: the *only* human who can
// reproduce a signature is the one whose face is currently enrolled
// on the device.
//
// What this seal proves, in addition to App Attest:
//   - The user explicitly authorized THIS artifact (Face ID prompt at
//     signing time = an act of consent the user can't predate).
//   - The biometric set used to sign matches the set that was current
//     at first enrollment (otherwise the key is invalidated by the OS
//     and SecKeyCreateSignature returns errSecAuthFailed).
//   - Co-presence of the legitimate user with the device — App Attest
//     proves device authenticity, this proves human authenticity for
//     the specific action.
//
// Where it's wired:
//   - CaptureCoordinator.submitAnchor signs commitment.hashHex (see
//     EnclaveSeal.Commitment.commitmentHashHex). The signature + public
//     key flow as sidecar fields on the anchorCommitment payload.
//
// Re-enrollment: if signing throws errSecAuthFailed (-25293) or
// errSecAuthCanceled, the caller should treat it as a key-invalidation
// signal, delete the keychain entry, and prompt the user to re-enroll
// on the next sealing attempt.

enum BiometricSealError: Error {
    case unavailable               // Device has no biometrics enrolled at all
    case keyGenerationFailed(String)
    case publicKeyExtractionFailed
    case signingFailed(String)
    case userCancelled             // User dismissed the Face ID prompt
    case keyInvalidated            // Biometrics changed — re-enroll needed
}

@MainActor
final class BiometricSealer {
    static let shared = BiometricSealer()

    // Keychain application tag for the seal key. Bumping the version
    // suffix forces re-generation (use sparingly — invalidates user's
    // prior seals).
    private let keyTag = Data("com.foundation.biometric-seal-key.v1".utf8)

    /// True if Face ID / Touch ID is available AND a biometric is
    /// enrolled. Callers should respect this before offering biometric-
    /// gated UI; an unavailable device either skips sealing (unattested
    /// degraded path) or hard-blocks (standard tier with strict policy).
    var isAvailable: Bool {
        let context = LAContext()
        var err: NSError?
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &err
        )
    }

    /// Returns the SEC1 / X9.63 uncompressed-point representation of
    /// the seal public key, base64-encoded. Generates the key on first
    /// call. The server-side verifier (forthcoming) takes this exact
    /// format and reconstructs an ECDSA P-256 public key.
    func publicKeyBase64() throws -> String {
        let key = try ensureKeyExists()
        guard let pub = SecKeyCopyPublicKey(key) else {
            throw BiometricSealError.publicKeyExtractionFailed
        }
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(pub, &error) as Data? else {
            throw BiometricSealError.publicKeyExtractionFailed
        }
        return data.base64EncodedString()
    }

    /// ECDSA-P256 sign `payload` using the biometric-bound key. Signing
    /// triggers a Face ID / Touch ID prompt — the returned signature is
    /// proof the user authorized THIS exact payload at THIS moment.
    /// `prompt` is the user-facing reason string ("Authorize humanity
    /// commitment", etc.).
    ///
    /// Returns the base64-encoded DER ECDSA signature
    /// (`.ecdsaSignatureMessageX962SHA256` — the algorithm hashes the
    /// payload internally, so callers pass raw bytes, not a hash).
    func sign(payload: Data, prompt: String) async throws -> String {
        let key = try ensureKeyExists()

        // Pinning the LAContext lets us pre-evaluate biometrics if
        // future call sites want to batch sign multiple payloads under
        // a single Face ID prompt. For now each sign call gets its own
        // implicit prompt via the SecKey's accessControl.
        let context = LAContext()
        context.localizedReason = prompt

        return try await withCheckedThrowingContinuation { cont in
            // SecKeyCreateSignature blocks on the biometric prompt;
            // dispatch off the main thread so the SwiftUI render loop
            // doesn't stall waiting for the user to look at the camera.
            DispatchQueue.global(qos: .userInteractive).async {
                var error: Unmanaged<CFError>?
                let signature = SecKeyCreateSignature(
                    key,
                    .ecdsaSignatureMessageX962SHA256,
                    payload as CFData,
                    &error
                )
                if let signature = signature as Data? {
                    cont.resume(returning: signature.base64EncodedString())
                    return
                }
                let nsError = error?.takeRetainedValue() as Error?
                let mapped = Self.mapSignError(nsError)
                cont.resume(throwing: mapped)
            }
        }
    }

    /// Force-delete the keychain key. Use after detecting an
    /// invalidated key (biometric set changed) to allow regeneration on
    /// the next call.
    func resetKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private

    private func ensureKeyExists() throws -> SecKey {
        if let existing = lookupKey() {
            return existing
        }
        return try generateKey()
    }

    private func lookupKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let result = item else { return nil }
        // SecItemCopyMatching returns a SecKey here (matching
        // kSecReturnRef + kSecClassKey); the cast is safe.
        return (result as! SecKey)
    }

    private func generateKey() throws -> SecKey {
        // Refuse to even create the key if the device has no enrolled
        // biometrics — there's nothing to bind it to. Caller should
        // surface a "set up Face ID first" affordance.
        guard isAvailable else {
            throw BiometricSealError.unavailable
        }
        guard
            let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage, .biometryCurrentSet],
                nil
            )
        else {
            throw BiometricSealError.keyGenerationFailed("access control")
        }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessControl as String: access,
            ],
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let msg = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "unknown"
            throw BiometricSealError.keyGenerationFailed(msg)
        }
        return key
    }

    nonisolated private static func mapSignError(_ error: Error?) -> BiometricSealError {
        guard let ns = error as NSError? else {
            return .signingFailed("unknown")
        }
        // LocalAuthentication / Security framework error codes — map
        // the ones callers should react to specifically; everything
        // else falls through as a generic signingFailed.
        if ns.code == errSecUserCanceled {
            return .userCancelled
        }
        if ns.code == errSecAuthFailed {
            // Includes "biometry has changed" → key is now invalid in
            // the Secure Enclave. Caller should call resetKey() and
            // retry to re-enroll.
            return .keyInvalidated
        }
        return .signingFailed(ns.localizedDescription)
    }
}
