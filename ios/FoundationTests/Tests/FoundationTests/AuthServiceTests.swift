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
}
