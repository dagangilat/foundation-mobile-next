import Foundation
import FirebaseAuth

struct Claims: Equatable, Sendable {
    let uid: String
    let email: String?
    let ring: Int?
    let role: String?
    let issuedAt: Date
    let expiresAt: Date
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(Claims)
    }

    @Published private(set) var state: State = .loading

    private var handle: AuthStateDidChangeListenerHandle?

    private init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.apply(user: user)
            }
        }
    }

    private func apply(user: User?) async {
        guard let user else {
            state = .signedOut
            return
        }
        do {
            let token = try await user.getIDTokenResult(forcingRefresh: false)
            let raw = token.claims
            let ring: Int? = (raw["ring"] as? Int) ?? (raw["ring"] as? NSNumber)?.intValue
            let role = raw["role"] as? String
            state = .signedIn(
                Claims(
                    uid: user.uid,
                    email: user.email,
                    ring: ring,
                    role: role,
                    issuedAt: token.issuedAtDate,
                    expiresAt: token.expirationDate
                )
            )
        } catch {
            state = .signedOut
        }
    }

    // MARK: - Email-link sign in

    // Routes through the `resendInviteLink` callable in foundation-global so
    // users get the Foundation-branded Resend email instead of Firebase Auth's
    // unbranded default. The callable also enforces rate limiting + invite
    // gating server-side — properties the client SDK's sendSignInLinkToEmail
    // does not have. Anti-enumeration: the callable returns `sent: false`
    // (not an error) for emails without access, so we surface the same
    // "check your inbox" UI either way. `pendingEmail` still gets stashed in
    // Keychain either way — if the email really has no access, there's no
    // link to consume later, so the stashed value just ages out harmlessly.
    func sendSignInLink(email: String) async throws {
        _ = try await FunctionsService.shared.resendInviteLink(email: email)
        Keychain.setPendingEmail(email)
    }

    enum CompleteResult: Sendable {
        case signedIn
        case noPendingEmail
        case notASignInLink
    }

    @discardableResult
    func completeSignIn(url: URL) async throws -> CompleteResult {
        guard Auth.auth().isSignIn(withEmailLink: url.absoluteString) else {
            return .notASignInLink
        }
        guard let email = Keychain.getPendingEmail() else {
            return .noPendingEmail
        }
        _ = try await Auth.auth().signIn(withEmail: email, link: url.absoluteString)
        Keychain.clearPendingEmail()
        return .signedIn
    }

    func signOut() throws {
        try Auth.auth().signOut()
        AttestationCoordinator.shared.reset()
    }
}
