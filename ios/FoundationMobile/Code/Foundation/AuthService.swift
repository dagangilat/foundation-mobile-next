import FirebaseAuth
import Foundation

/// Foundation's member identity, distinct from Rarimo's local identity secret.
///
/// The two coexist deliberately: `UserManager`/`DecentralizedAuthManager` own the
/// locally-generated identity that proves the passport, while this owns the
/// Firebase uid that names the Foundation member. Every Foundation callable runs
/// `requireAuth`, so without a uid there is nothing to call.
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var uid: String?
    @Published private(set) var isSignedIn: Bool = false

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // Seed synchronously from the SDK's already-restored session BEFORE
        // attaching the listener. Firebase dispatches the first
        // state-did-change callback asynchronously, so a listener-only
        // initialisation reports `isSignedIn == false` for the first turn of
        // the run loop and AppView flashes SignInView on every signed-in
        // cold launch. `currentUser` is populated synchronously from the
        // keychain-backed session by `FirebaseApp.configure()`, so reading it
        // here is the flash-free path.
        let restored = Auth.auth().currentUser
        uid = restored?.uid
        isSignedIn = restored != nil

        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            // Firebase calls this on the main thread, but the closure itself is
            // not main-actor-isolated. Hop explicitly, and carry only the uid
            // (a String) across rather than the non-Sendable `User`.
            let uid = user?.uid
            Task { @MainActor in
                self?.uid = uid
                self?.isSignedIn = uid != nil
            }
        }
    }

    /// Ask the server to email a 6-digit code. Stores the email so the
    /// verify step can be resumed after a cold launch.
    func sendCode(to email: String) async throws {
        _ = try await FunctionsService.shared.requestSignInCode(email: email)
        Keychain.setPendingEmail(email)
    }

    /// Exchange the code for a Firebase custom token and sign in.
    func submitCode(_ code: String) async throws {
        guard let email = Keychain.getPendingEmail() else {
            throw AuthError.noPendingEmail
        }
        let result = try await FunctionsService.shared.verifySignInCode(email: email, code: code)
        // Whatever ID-token freshness window survived from a prior session is
        // stale the moment we swap users. Invalidate BEFORE signing in so an
        // interleaved callable can't observe the old window against the new
        // user, then mark fresh after — signIn produces a fresh ID token as a
        // side effect, so the next mutating call can skip a round-trip.
        await FunctionsService.shared.invalidateIDTokenCache()
        try await Auth.auth().signIn(withCustomToken: result.customToken)
        Keychain.clearPendingEmail()
        await FunctionsService.shared.markIDTokenJustRefreshed()
    }

    func signOut() {
        try? Auth.auth().signOut()
        uid = nil
        isSignedIn = false
        Keychain.clearPendingEmail()
        Task { await FunctionsService.shared.invalidateIDTokenCache() }
    }

    enum AuthError: Error { case noPendingEmail }
}
