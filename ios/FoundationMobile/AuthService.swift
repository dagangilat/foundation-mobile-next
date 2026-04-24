import Foundation
import FirebaseAuth
import FirebaseFunctions

// Maps raw Firebase Auth + Functions errors to user-facing copy. Firebase's
// localizedDescription is often cryptic ("The action code is invalid. This
// can happen if the code is malformed, expired, or has already been used.")
// — the friendlier strings here pair a plain explanation with a concrete
// next step the user can take. Unknown errors fall back to a generic message
// rather than leaking SDK internals.
enum AuthCopy {
    static func friendly(_ error: Error) -> String {
        let ns = error as NSError

        if ns.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .invalidActionCode, .expiredActionCode:
                return "This sign-in link expired or was already used. Request a new one below."
            case .invalidEmail:
                return "That doesn't look like a valid email address."
            case .userDisabled:
                return "This account has been disabled. Please contact a Foundation admin."
            case .networkError:
                return "No connection. Check your network and try again."
            case .tooManyRequests:
                return "Too many attempts — please wait a minute and try again."
            default:
                break
            }
        }

        if ns.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: ns.code) {
            switch code {
            case .resourceExhausted:
                return "Too many sign-in requests for this email. Please wait a few minutes."
            case .invalidArgument:
                return "That doesn't look like a valid email address."
            case .unavailable, .deadlineExceeded:
                return "Service unavailable. Check your connection and try again."
            case .internal:
                return "Something went wrong on our side. Please try again."
            default:
                break
            }
        }

        return "Couldn't complete that action. Please try again."
    }
}

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

    // True while a Universal Link is being consumed end-to-end. RootView reads
    // this to show LoadingView("Signing you in…") instead of SignInView while
    // the network round-trip completes, so the user doesn't see the form flash
    // up between the tap and the HomeView transition.
    @Published private(set) var isCompletingSignIn: Bool = false

    // Last deep-link failure message, if any. SignInView surfaces this as an
    // error card so users whose link opened on a fresh install / expired link /
    // was reused aren't left staring at an empty form. Cleared when the user
    // edits the email field or successfully re-sends.
    @Published var deepLinkError: String? = nil

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

    // Entry point for Universal Links (FoundationMobileApp .onOpenURL). Wraps
    // completeSignIn with the published UI state — sets isCompletingSignIn
    // while the network call runs, and writes a user-visible deepLinkError on
    // any failure mode so SignInView can surface it. Non-sign-in URLs are
    // ignored silently (iOS routes unrelated deep links here too).
    func handleDeepLink(url: URL) async {
        guard Auth.auth().isSignIn(withEmailLink: url.absoluteString) else { return }
        isCompletingSignIn = true
        deepLinkError = nil
        defer { isCompletingSignIn = false }
        do {
            let result = try await completeSignIn(url: url)
            switch result {
            case .signedIn, .notASignInLink:
                break
            case .noPendingEmail:
                // The pendingEmail was stashed in Keychain on the device that
                // requested the link. If the link opened on a different device
                // or after a fresh install, we have no email to complete with.
                deepLinkError = "This link was sent from another device or install. Request a new link here to sign in on this device."
            }
        } catch {
            deepLinkError = AuthCopy.friendly(error)
        }
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
    }
}
