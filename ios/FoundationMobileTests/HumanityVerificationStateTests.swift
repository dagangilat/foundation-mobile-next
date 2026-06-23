import XCTest
@testable import FoundationMobile

final class HumanityVerificationStateTests: XCTestCase {
    // Manual-approve path: the only green signal is the user-doc flag
    // (no anchored commitment ever existed). An admin reset flips
    // users/{uid}.humanityVerified=false — the badge MUST demote.
    //
    // Regression guard: the old promote-only latch only ever set the flag
    // true and ignored a false, so a reset left the app green until the
    // user deleted+reinstalled. limor.gilat hit exactly this.
    func testUserDocResetDemotesWhenNoAnchoredCommitment() {
        var state = HumanityVerificationState()
        state.userDocVerified = true            // manually approved
        XCTAssertTrue(state.isVerified)

        state.userDocVerified = false           // admin reset wrote false
        XCTAssertFalse(state.isVerified)
    }

    // Fast-path: the user-doc flag alone paints green on cold launch,
    // before the identity_commitments query round-trips.
    func testUserDocFlagAlonePaintsGreen() {
        var state = HumanityVerificationState()
        state.userDocVerified = true
        XCTAssertTrue(state.isVerified)
    }

    // Authoritative source: an anchored commitment paints green even if
    // the user-doc fast-path flag is absent.
    func testAnchoredCommitmentAlonePaintsGreen() {
        var state = HumanityVerificationState()
        state.commitmentAnchored = true
        XCTAssertTrue(state.isVerified)
    }

    // A real-anchor user being reset: both signals clear → demote.
    func testFullResetDemotes() {
        var state = HumanityVerificationState(userDocVerified: true, commitmentAnchored: true)
        XCTAssertTrue(state.isVerified)

        state.userDocVerified = false
        state.commitmentAnchored = false
        XCTAssertFalse(state.isVerified)
    }

    // Default (fresh launch, nothing observed yet) is not verified.
    func testDefaultIsNotVerified() {
        XCTAssertFalse(HumanityVerificationState().isVerified)
    }
}
