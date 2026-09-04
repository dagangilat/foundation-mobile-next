import FirebaseAuth
import FirebaseFunctions
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
        // cold launch. `Auth` is registered `.alwaysEager`, so its keychain
        // restore is STARTED at `FirebaseApp.configure()`, not guaranteed
        // complete — `currentUser` reads whatever that restore has produced
        // so far. It's usually already landed by the time the scene body
        // evaluates, closing the flash; if it hasn't, this read is just nil
        // and behavior degrades to the listener-only path, never worse.
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
        registerDeviceAttestationIfNeeded()
    }

    /// Register this device's App Attest key against the uid that just signed
    /// in. This is the app's ONLY caller of `AttestationService` — without it
    /// the whole subsystem (`issueAttestationNonce`, `recordMobileAttestation`,
    /// the Keychain keyId) is dead code and no member ever gets a server-side
    /// device credential.
    ///
    /// Deliberately fire-and-forget, and deliberately AFTER
    /// `markIDTokenJustRefreshed()`: attestation is a nicety layered on a
    /// successful sign-in, never a precondition for one, so it must not be able
    /// to delay or fail the sign-in the user is waiting on. A failure is logged
    /// and dropped — the same "follow-on write, not a gate" posture
    /// `FoundationVerificationManager` takes with its own non-fatal callables.
    ///
    /// Guarded on the same condition `AttestationService.generateAssertion`
    /// uses for its self-heal branch (`Keychain.getAttestedKeyId() == nil`), so
    /// an already-attested device doesn't repeat the
    /// nonce → generateKey → attestKey round-trip on every sign-in.
    /// `signOut()` clears that keyId, so the next member to sign in on this
    /// device does get their own registration.
    private func registerDeviceAttestationIfNeeded() {
        guard Keychain.getAttestedKeyId() == nil else { return }
        Task {
            // Checked before the first network call. `attestDeviceEndToEnd()`
            // issues a server nonce BEFORE `generateKey()` gets the chance to
            // throw `.unsupported`, so on the Simulator or any device without
            // App Attest an unguarded call burns a callable round-trip on a
            // result that cannot succeed.
            guard await AttestationService.shared.isSupported else { return }
            do {
                _ = try await AttestationService.shared.attestDeviceEndToEnd()
            } catch {
                LoggerUtil.common.error(
                    "device attestation registration failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        uid = nil
        isSignedIn = false
        Keychain.clearPendingEmail()
        // The App Attest keyId is device-bound but the credential it registers
        // server-side is uid-bound. Leaving it behind would make the NEXT
        // member to sign in on this device pass straight through
        // `registerDeviceAttestationIfNeeded()`'s guard and never register at
        // all, inheriting a keyId that names someone else's credential.
        Keychain.clearAttestedKeyId()
        Task { await FunctionsService.shared.invalidateIDTokenCache() }
    }

    enum AuthError: Error { case noPendingEmail }

    /// `verifySignInCode` (foundation-next functions/index.js:3083-3096) throws
    /// `failed-precondition` with a real, specific, written-for-humans message
    /// per reason ("No sign-in code on file...", "Sign-in code expired...",
    /// "Too many wrong attempts...", "Wrong code. N attempts left."). Before
    /// 2026-09-04 (scoped re-review finding M-5) `SignInView.verify()` caught
    /// every error identically and showed a fixed generic string, discarding
    /// that message - so an expired code or a lockout was mis-reported to the
    /// user as an indistinguishable typo. Mirrors
    /// `FoundationVerificationManager.terminalRejectionMessage(for:)`'s exact
    /// shape and reasoning.
    ///
    /// `requestSignInCode` (behind `SignInView.sendCode()`) has no such path
    /// today - it only throws `invalid-argument` for a malformed email, plus
    /// rate-limiting. Wiring `sendCode()` to this same classifier is a safe
    /// no-op now and means a future per-reason `requestSignInCode` message
    /// surfaces automatically, without a matching client change.
    nonisolated static func signInErrorMessage(for error: Error, fallback: String) -> String {
        let ns = error as NSError
        guard ns.domain == FunctionsErrorDomain,
              ns.code == FunctionsErrorCode.failedPrecondition.rawValue else { return fallback }
        let description = ns.localizedDescription
        return description.isEmpty ? fallback : description
    }
}
