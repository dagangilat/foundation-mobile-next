import Foundation
import Security

enum Keychain {
    /// Namespaces every item this app stores. MUST be this fork's bundle id:
    /// using the live app's identifier would share the keychain with live
    /// Foundation Mobile.
    static let serviceIdentifier = "com.foundationnext.mobile"
    private static var service: String { serviceIdentifier }
    private static let pendingEmailAccount = "pendingSignInEmail"
    private static let pendingEmailIssuedAtAccount = "pendingSignInEmailIssuedAtMs"
    private static let attestKeyIdAccount = "appAttestKeyId"

    /// 30 minutes. After this window the stashed email is considered stale
    /// and rejected on completeSignIn. 2026-04-26 security review M-H-1:
    /// without a TTL a Keychain entry from a failed/abandoned attempt sits
    /// indefinitely, and any later email link that lands on the same
    /// device gets paired with the stale email. Email-link sign-in has no
    /// second factor; cap the replay window.
    static let pendingEmailTtlMs: Int64 = 30 * 60 * 1000

    static func setPendingEmail(_ email: String) {
        write(account: pendingEmailAccount, value: Data(email.utf8))
        let issuedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        write(account: pendingEmailIssuedAtAccount, value: Data(String(issuedAtMs).utf8))
    }

    /// Returns the pending email only if it was stashed within the TTL.
    /// A stale entry is opportunistically cleared so it can't haunt a
    /// later sign-in attempt.
    static func getPendingEmail() -> String? {
        guard let data = read(account: pendingEmailAccount),
              let email = String(data: data, encoding: .utf8) else {
            return nil
        }
        guard let issuedAtData = read(account: pendingEmailIssuedAtAccount),
              let issuedAtStr = String(data: issuedAtData, encoding: .utf8),
              let issuedAtMs = Int64(issuedAtStr) else {
            // Legacy entry without a timestamp (pre-M-H-1 fix); refuse it
            // and clear so a fresh sendSignInLink stamps a new TTL.
            clearPendingEmail()
            return nil
        }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if nowMs - issuedAtMs > pendingEmailTtlMs {
            clearPendingEmail()
            return nil
        }
        return email
    }

    static func clearPendingEmail() {
        delete(account: pendingEmailAccount)
        delete(account: pendingEmailIssuedAtAccount)
    }

    // App Attest keys are bound to the device + this bundle id. Persist the
    // keyId after a successful attestation so subsequent launches skip the
    // generateKey → attestKey round-trip and use `generateAssertion` instead.
    static func setAttestedKeyId(_ keyId: String) {
        write(account: attestKeyIdAccount, value: Data(keyId.utf8))
    }

    static func getAttestedKeyId() -> String? {
        guard let data = read(account: attestKeyIdAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearAttestedKeyId() {
        delete(account: attestKeyIdAccount)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func write(account: String, value: Data) {
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = value
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
