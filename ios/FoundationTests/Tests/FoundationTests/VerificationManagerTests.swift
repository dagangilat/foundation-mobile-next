import XCTest
@testable import FoundationMobile

final class VerificationManagerTests: XCTestCase {
    func testUrlAllowlistAcceptsFoundationSchemeOnly() {
        let m = ExternalRequestsManager.shared

        XCTAssertTrue(m.isValidExternalUrl(
            URL(string: "foundationmobile://external?type=proof-request")!))
        // Rarimo's own hosts must no longer be honoured: we do not own their
        // AASA files, and a universal link to app.rarime.com opens RariMe.
        XCTAssertFalse(m.isValidExternalUrl(
            URL(string: "rarime://external?type=proof-request")!))
        XCTAssertFalse(m.isValidExternalUrl(
            URL(string: "https://app.rarime.com/external?type=proof-request")!))
    }

    func testProofRequestCanBeSetFromABareParamsUrl() {
        // AD-2: the fork never parses a deep link on the primary path - it
        // feeds getProofParamsUrl straight into the existing proof flow.
        let m = ExternalRequestsManager.shared
        m.resetRequest()
        let url = URL(string: "https://verificator.example.run.app/integrations/verificator-svc/light/v2/public/proof-params/abc")!
        m.setProofRequest(proofParamsUrl: url)

        guard case .proofRequest(let got, _)? = m.request else {
            return XCTFail("expected a proofRequest")
        }
        XCTAssertEqual(got, url)
        m.resetRequest()
    }

    // FoundationVerificationManager is @MainActor, so both its init and
    // `state` are main-actor-isolated; a nonisolated sync test body cannot
    // touch either. This is the only deviation from the brief's verbatim test.
    @MainActor
    func testStateStartsIdle() {
        XCTAssertEqual(FoundationVerificationManager().state, .idle)
    }

    // MARK: - .awaitingProof must not be terminal

    /// The Cancel button, the sheet's X, swipe-to-dismiss, a proof-params load
    /// failure, a failed uniqueness check and any generateProof error all end
    /// the same way: the sheet closes without onSuccess ever running. Before
    /// this fix that left `.awaitingProof` set forever, and
    /// FoundationVerifyCardView.isBusy kept the Home verify card disabled and
    /// showing "Working…" for the rest of the app process.
    @MainActor
    func testProofSheetDismissalReleasesAwaitingProof() {
        let m = FoundationVerificationManager(state: .awaitingProof)
        m.proofSheetDismissed()
        XCTAssertEqual(m.state, .idle)
    }

    /// The ordering hazard, in one test: a real success claims `.polling`
    /// synchronously, and the dismissal that immediately follows it (the sheet
    /// closing is what onSuccess does next) must NOT throw that away.
    @MainActor
    func testSuccessSurvivesTheDismissalThatFollowsIt() {
        let m = FoundationVerificationManager(state: .awaitingProof)

        XCTAssertTrue(m.proofRequestSucceeded())
        XCTAssertEqual(m.state, .polling)

        // ExternalRequestsView sets isSheetPresented = false right after, and
        // its .onChange hook lands here.
        m.proofSheetDismissed()
        XCTAssertEqual(m.state, .polling, "a claimed success must not be reset by its own dismissal")
    }

    /// Dismissal must leave every other state alone - it is a release valve
    /// for `.awaitingProof` only, not a general reset.
    @MainActor
    func testProofSheetDismissalLeavesOtherStatesAlone() {
        for state in Self.statesOtherThanAwaitingProof {
            let m = FoundationVerificationManager(state: state)
            m.proofSheetDismissed()
            XCTAssertEqual(m.state, state, "dismissal must not disturb \(state)")
        }
    }

    // MARK: - a success that is not ours must not start a poll

    /// `ProofRequestView` is shared with the external QR-scan path
    /// (NavBarView -> ScanQRView -> handleRarimeUrl -> handleProofRequest).
    /// A success there is nothing to do with this member's L2 status, and
    /// polling getL2VerificationStatus for it would burn ~2 minutes before
    /// landing in a bogus .failed("taking longer than expected").
    @MainActor
    func testProofSuccessIsNotClaimedUnlessWeAskedForIt() {
        for state in Self.statesOtherThanAwaitingProof {
            let m = FoundationVerificationManager(state: state)
            XCTAssertFalse(m.proofRequestSucceeded(), "must not claim a success from \(state)")
            XCTAssertEqual(m.state, state, "a rejected claim must not disturb \(state)")
        }
    }

    /// Defence in depth behind the check above: the loop itself refuses to run
    /// unless proofRequestSucceeded() put us in `.polling`. Awaits the call in
    /// full - a stray invocation has to return immediately and touch no
    /// network, so if the guard were gone this would spend ~2 minutes calling
    /// FunctionsService and then land in .failed.
    @MainActor
    func testPollUntilVerifiedNoOpsOutsidePolling() async {
        for state in Self.statesOtherThanPolling {
            let m = FoundationVerificationManager(state: state)
            let started = ContinuousClock.now
            await m.pollUntilVerified()
            XCTAssertEqual(m.state, state, "pollUntilVerified must not run from \(state)")
            XCTAssertLessThan(
                started.duration(to: .now), .seconds(1),
                "pollUntilVerified must return without a network round-trip from \(state)"
            )
        }
    }

    // MARK: - reset() detaches the state from a departing member

    /// Delete Account / Sign Out must not leave the departing member's
    /// verification state standing. The concrete leak: a `.verified` that
    /// survives account deletion shows the NEXT person to use the device as a
    /// verified member having performed zero verification of their own.
    ///
    /// Unlike `proofSheetDismissed()`, this is unconditional - it must clear
    /// EVERY state, not just `.awaitingProof`.
    @MainActor
    func testResetReturnsEveryStateToIdle() {
        for state in Self.allStates {
            let m = FoundationVerificationManager(state: state)
            m.reset()
            XCTAssertEqual(m.state, .idle, "reset() must clear \(state)")
        }
    }

    /// `pollUntilVerified` runs for up to two minutes across `await`s, and it
    /// is the one writer that could stamp a stale result back over the `.idle`
    /// a `reset()` just established. Entering it from a non-`.polling` state
    /// (which is what a mid-flight reset leaves behind) must be a no-op, with
    /// no network round-trip - the same guarantee
    /// `testPollUntilVerifiedNoOpsOutsidePolling` asserts, restated here from
    /// the reset's point of view because the in-loop re-checks are what make it
    /// hold for a reset that lands *after* the loop has already started.
    @MainActor
    func testResetMidPollLeavesTheStateIdle() async {
        let m = FoundationVerificationManager(state: .polling)
        m.reset()
        XCTAssertEqual(m.state, .idle)

        let started = ContinuousClock.now
        await m.pollUntilVerified()

        XCTAssertEqual(m.state, .idle, "a poll must not resurrect the departed member's state")
        XCTAssertLessThan(started.duration(to: .now), .seconds(1))
    }

    private static let allStates: [VerificationState] = [
        .idle, .notRegistered, .starting, .awaitingProof, .polling,
        .verified(memberNumber: 42), .failed("nope"),
    ]

    private static let statesOtherThanAwaitingProof: [VerificationState] = [
        .idle, .notRegistered, .starting, .polling, .verified(memberNumber: 42), .failed("nope"),
    ]

    private static let statesOtherThanPolling: [VerificationState] = [
        .idle, .notRegistered, .starting, .awaitingProof, .verified(memberNumber: 42), .failed("nope"),
    ]
}
