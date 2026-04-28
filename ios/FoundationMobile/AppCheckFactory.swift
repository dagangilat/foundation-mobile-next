import Foundation
import FirebaseAppCheck
import FirebaseCore

/// Dev-phase: returns a synthetic App Check token immediately so the
/// SDK stops trying to fetch real ones.
///
/// **Why this exists**
///
/// Firebase iOS SDK insists on attempting App Check token fetches for
/// every Auth / Firestore / Functions call. We've tried two approaches
/// to disable it, both of which made things worse:
///
///   1. Returning `nil` from `createProvider`: the SDK still tried to
///      fetch a token (status: "no provider"), and each request hit
///      a 3 s "result accumulator timeout" — adding ~6 s per CF call
///      via two timeouts (ID-token refresh + callable invocation).
///
///   2. Not calling `setAppCheckProviderFactory` at all: the SDK fell
///      back to a default provider that hits
///      `firebaseappcheck.googleapis.com/.../exchangeDeviceCheckToken`,
///      which returns 400 "App not registered" because this project's
///      iOS app isn't enrolled for DeviceCheck. The SDK then retried
///      these failed exchanges, blocking app launch by ~7 s and adding
///      ~12 s to mintToken.
///
/// The fix: register a factory whose provider synchronously returns
/// a fake token with a 1 h expiry. The SDK is happy, never tries to
/// fetch a real one, and every Firebase call goes through immediately
/// with the fake token attached as `x-firebase-appcheck`.
///
/// **Server-side safety**
///
/// All callables on the demo path (mintWebSessionToken, anchorCommitment,
/// claim/heartbeat/release pairing, recordBiometricConsent /
/// checkBiometricConsent, recordTosAcceptance / getTermsOfService /
/// getPrivacyPolicy / checkTosAcceptance, logSession, requestSignInCode /
/// verifySignInCode, App Attest setup callables, submitSupportTicket)
/// explicitly set `enforceAppCheck: false`, so the synthetic token is
/// never validated. Firestore enforcement is also off for this project.
///
/// **Re-enable plan** (post-demo, when App Attest is properly
/// registered in Firebase Console): swap `NoopAppCheckProvider` back
/// to `AppAttestProvider(app: app)` (or `AppCheckDebugProvider(app: app)`
/// for simulator). See git history for the original implementation.
final class NoopAppCheckProvider: NSObject, AppCheckProvider {
    func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
        // Synthesize a token with 1-h expiry. The SDK caches it for
        // that long; on expiry it asks for a new one — at which point
        // we return a fresh synthetic token, again instantly.
        let expiry = Date().addingTimeInterval(3600)
        let token = AppCheckToken(
            token: "noop-dev-token",
            expirationDate: expiry,
        )
        handler(token, nil)
    }
}

final class AppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return NoopAppCheckProvider()
    }
}
