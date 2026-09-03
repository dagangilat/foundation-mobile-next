import XCTest
@testable import FoundationMobile

/// `SecurityManager.isPasscodeCorrect` is the flag `AppView` reads to choose
/// between `MainView` and `LockScreenView`. Before `rearmPasscodeLock()` it was
/// only ever armed in `SecurityManager.init`, i.e. only at a cold launch, so a
/// mid-session sign-out left it standing `true` from the departing member's own
/// unlock. These cover the rule that closes that.
///
/// `passcodeState` is written straight rather than through `enablePasscode()`
/// so no Keychain entry is created; the `didSet` still persists to
/// `AppUserDefaults`, so the original value is restored in `tearDown` - a
/// leaked `.enabled` would leave every later `SecurityManager()` in this
/// process (and every later run on the same simulator) starting locked.
final class SecurityManagerTests: XCTestCase {
    private var originalPasscodeState: Int!

    override func setUp() {
        super.setUp()
        originalPasscodeState = AppUserDefaults.shared.passcodeState
    }

    override func tearDown() {
        AppUserDefaults.shared.passcodeState = originalPasscodeState
        super.tearDown()
    }

    /// The regression itself: person A unlocks, taps Sign Out, hands the device
    /// to person B. Without the re-arm, `isPasscodeCorrect` is still `true`
    /// from A's unlock and B's sign-in lands straight in `MainView` holding A's
    /// local Rarimo identity.
    func testRearmLocksAgainWhenAPasscodeIsEnabled() {
        let manager = SecurityManager()
        manager.passcodeState = .enabled
        manager.isPasscodeCorrect = true

        manager.rearmPasscodeLock()

        XCTAssertFalse(
            manager.isPasscodeCorrect,
            "signing out with a passcode enabled must put the lock screen back in front of the next member"
        )
    }

    /// The other half of the rule, and the reason it is not a bare `false`: a
    /// device with no passcode configured must not be pushed at a lock screen
    /// it could never satisfy.
    func testRearmDoesNotLockWhenNoPasscodeIsConfigured() {
        for state in [SecurityItemState.unset, .disabled] {
            let manager = SecurityManager()
            manager.passcodeState = state
            manager.isPasscodeCorrect = false

            manager.rearmPasscodeLock()

            XCTAssertTrue(
                manager.isPasscodeCorrect,
                "\(state) has no passcode to enter - re-arming must not strand the user at a lock screen"
            )
        }
    }

    /// `rearmPasscodeLock()` must land in exactly the same place a cold launch
    /// does, since that is the whole claim being made about it. Stated as its
    /// own test because `init` deliberately duplicates the expression (a stored
    /// property cannot be initialised by calling an instance method), and this
    /// is what catches the two drifting apart.
    func testRearmMatchesWhatAColdLaunchWouldProduce() {
        for state in [SecurityItemState.unset, .enabled, .disabled] {
            AppUserDefaults.shared.passcodeState = state.rawValue
            let coldLaunched = SecurityManager()

            let warm = SecurityManager()
            warm.passcodeState = state
            warm.isPasscodeCorrect = !coldLaunched.isPasscodeCorrect
            warm.rearmPasscodeLock()

            XCTAssertEqual(
                warm.isPasscodeCorrect, coldLaunched.isPasscodeCorrect,
                "re-arming from \(state) must match SecurityManager.init"
            )
        }
    }

    /// The delete-account ordering question, settled by a test rather than by
    /// reading: `signOutOfFoundation()` re-arms and `securityManager.reset()`
    /// runs immediately after it. `reset()` winning is correct there - it
    /// clears the passcode outright, so there is nothing left to gate on, and
    /// leaving `isPasscodeCorrect == false` would strand the device at a lock
    /// screen with no passcode that opens it.
    func testResetAfterRearmLeavesTheGateOpen() {
        let manager = SecurityManager()
        manager.passcodeState = .enabled
        manager.rearmPasscodeLock()
        XCTAssertFalse(manager.isPasscodeCorrect)

        manager.reset()

        XCTAssertEqual(manager.passcodeState, .unset)
        XCTAssertTrue(
            manager.isPasscodeCorrect,
            "a reset passcode leaves no lock screen to satisfy - the delete path must not end up behind one"
        )
    }
}
