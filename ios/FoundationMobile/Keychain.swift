import Foundation
import Security

enum Keychain {
    private static let service = "com.foundationglobal.mobile"
    private static let pendingEmailAccount = "pendingSignInEmail"

    static func setPendingEmail(_ email: String) {
        write(account: pendingEmailAccount, value: Data(email.utf8))
    }

    static func getPendingEmail() -> String? {
        guard let data = read(account: pendingEmailAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearPendingEmail() {
        delete(account: pendingEmailAccount)
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
