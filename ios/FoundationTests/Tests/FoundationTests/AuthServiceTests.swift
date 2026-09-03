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
}
