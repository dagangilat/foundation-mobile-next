import FirebaseFunctions
import XCTest
@testable import FoundationMobile

// `AuthService` is `@MainActor`-isolated, so the whole case has to be too —
// otherwise `AuthService()` is a "call to main actor-isolated initializer in a
// synchronous nonisolated context" error even in Swift 5 language mode.
@MainActor
final class AuthServiceTests: XCTestCase {
    func testKeychainRoundTripsPendingEmail() {
        Keychain.clearPendingEmail()
        XCTAssertNil(Keychain.getPendingEmail())
        Keychain.setPendingEmail("member@example.com")
        XCTAssertEqual(Keychain.getPendingEmail(), "member@example.com")
        Keychain.clearPendingEmail()
        XCTAssertNil(Keychain.getPendingEmail())
    }

    func testKeychainRoundTripsAttestedKeyId() {
        Keychain.clearAttestedKeyId()
        XCTAssertNil(Keychain.getAttestedKeyId())
        Keychain.setAttestedKeyId("key-abc-123")
        XCTAssertEqual(Keychain.getAttestedKeyId(), "key-abc-123")
        Keychain.clearAttestedKeyId()
    }

    func testKeychainServiceIsThisForksBundleId() {
        // Guards against porting the live app's keychain service identifier,
        // which would share the keychain group with live Foundation Mobile.
        XCTAssertEqual(Keychain.serviceIdentifier, "com.foundationnext.mobile")
    }

    func testSignedOutStateHasNoUid() {
        let auth = AuthService()
        auth.signOut()
        XCTAssertNil(auth.uid)
        XCTAssertFalse(auth.isSignedIn)
    }

    /// The App Attest keyId is device-bound, but the credential it registers
    /// server-side is uid-bound. Leaving it in the Keychain across a sign-out
    /// makes the NEXT member to sign in on this device pass straight through
    /// `registerDeviceAttestationIfNeeded()`'s `getAttestedKeyId() == nil`
    /// guard, so they never register a credential of their own and instead
    /// hold a keyId naming someone else's.
    func testSignOutClearsTheAttestedKeyId() {
        Keychain.setAttestedKeyId("key-from-the-previous-member")
        XCTAssertNotNil(Keychain.getAttestedKeyId())

        AuthService().signOut()

        XCTAssertNil(
            Keychain.getAttestedKeyId(),
            "sign-out must not leave the departing member's attested keyId behind"
        )
    }

    /// The same guarantee for the pending-email entry, which is the other half
    /// of the identity a sign-out has to leave behind. Stated as its own test
    /// because `signOut()` is the delete-account flow's only eraser of either.
    func testSignOutClearsThePendingEmail() {
        Keychain.setPendingEmail("previous-member@example.com")
        XCTAssertNotNil(Keychain.getPendingEmail())

        AuthService().signOut()

        XCTAssertNil(Keychain.getPendingEmail())
    }

    // MARK: - signInErrorMessage: which requestSignInCode/verifySignInCode
    // rejections surface their real, per-reason backend message instead of
    // a generic fallback. Added 2026-09-04 (scoped re-review finding M-5,
    // "9 minors" pass) - mirrors
    // `FoundationVerificationManager.terminalRejectionMessage(for:)`'s test
    // shape exactly, same fixture domain/code construction.

    /// The real shape `verifySignInCode` throws for e.g. an expired code:
    /// `failed-precondition` with a specific, written-for-humans message.
    /// Before this fix `SignInView` discarded it for a fixed generic string.
    func testFailedPreconditionSurfacesTheRealMessage() {
        let message = "Sign-in code expired. Request a new one."
        let error = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.failedPrecondition.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        XCTAssertEqual(
            AuthService.signInErrorMessage(for: error, fallback: "fallback"),
            message
        )
    }

    /// A transient/unrelated code (network blip, etc.) isn't a considered
    /// rejection - the real message, if any, isn't written for the user, so
    /// this must fall back to the generic string rather than surface it.
    func testUnrelatedCodeFallsBackToTheGenericMessage() {
        let unavailable = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.unavailable.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "transient 503"]
        )
        XCTAssertEqual(
            AuthService.signInErrorMessage(for: unavailable, fallback: "fallback"),
            "fallback"
        )

        struct SomeOtherError: Error {}
        XCTAssertEqual(
            AuthService.signInErrorMessage(for: SomeOtherError(), fallback: "fallback"),
            "fallback"
        )
    }

    /// An explicitly blank description is the closest real-world analog to
    /// Android's `signInErrorMessage`'s "message is blank" case - guards the
    /// `description.isEmpty` fallback branch actually fires rather than
    /// surfacing an empty string to the user.
    func testFailedPreconditionWithBlankMessageFallsBack() {
        let error = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.failedPrecondition.rawValue,
            userInfo: [NSLocalizedDescriptionKey: ""]
        )
        XCTAssertEqual(
            AuthService.signInErrorMessage(for: error, fallback: "fallback"),
            "fallback"
        )
    }
}
