import XCTest
import FirebaseFunctions
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

    // MARK: - terminalRejectionMessage: which getL2VerificationStatus
    // failures are terminal, not transient

    /// A duplicate-passport rejection arrives as `already-exists` - this is
    /// the code the backend actually uses in practice, per passport.js's
    /// comment: the lane-doc uniqueness guard is "the ONLY layer that
    /// actually rejects a duplicate passport in practice" because the
    /// svc-side `failed-precondition` check "went blind". Before this fix
    /// (whole-plan review finding I-2) only `.failedPrecondition` was
    /// classified terminal, so this real rejection was retried 40x over two
    /// minutes and reported as a generic timeout instead of the server's
    /// real message.
    func testAlreadyExistsIsClassifiedAsATerminalRejection() {
        let message = "This passport is already linked to another member. A passport belongs to one member, permanently — if this is a mistake, contact support to appeal."
        let error = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.alreadyExists.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        XCTAssertEqual(
            FoundationVerificationManager.terminalRejectionMessage(for: error),
            message
        )
    }

    /// The pre-existing terminal code (C8's fix) must keep working exactly as
    /// before - this fix adds `.alreadyExists` alongside it, not in place of
    /// it.
    func testFailedPreconditionIsStillClassifiedAsATerminalRejection() {
        let message = "We couldn't verify that passport. Please try again."
        let error = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.failedPrecondition.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        XCTAssertEqual(
            FoundationVerificationManager.terminalRejectionMessage(for: error),
            message
        )
    }

    /// Everything else - a transient network blip, an unrelated Functions
    /// error code, a non-Functions error - must NOT be classified terminal,
    /// or pollUntilVerified would stop retrying failures worth retrying.
    func testUnrelatedErrorsAreNotClassifiedAsTerminalRejections() {
        let unavailable = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.unavailable.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "transient 503"]
        )
        XCTAssertNil(FoundationVerificationManager.terminalRejectionMessage(for: unavailable))

        struct SomeOtherError: Error {}
        XCTAssertNil(FoundationVerificationManager.terminalRejectionMessage(for: SomeOtherError()))
    }

    // MARK: - isTerminalSuccess: which getL2VerificationStatus status values
    // end the poll with .verified. Added 2026-09-04 (scoped re-review finding
    // N-2): "member_created"/"member_upgraded" were the exact strings this
    // poller had wrong until 2026-09-03 (it only recognized "verified", which
    // the backend never returns), so this is the platform that most needed a
    // pin against real backend vocabulary, not least - Android already has 8
    // equivalent cases.

    func testRealBackendSuccessStatusesAreTerminal() {
        XCTAssertTrue(FoundationVerificationManager.isTerminalSuccess("member_created"))
        XCTAssertTrue(FoundationVerificationManager.isTerminalSuccess("member_upgraded"))
        XCTAssertTrue(FoundationVerificationManager.isTerminalSuccess("already_verified_l2"))
    }

    /// The backend never actually returns this - kept as a defensive floor
    /// against a future rename silently stranding the poller, matching
    /// Android's identical inclusion of "verified" in its own accepted set.
    func testVerifiedIsAcceptedDefensively() {
        XCTAssertTrue(FoundationVerificationManager.isTerminalSuccess("verified"))
    }

    /// Non-terminal statuses ("pending", "request_created") and anything
    /// unrecognized must NOT be classified success, or pollUntilVerified
    /// would stop polling before the member actually reaches l2.
    func testNonTerminalStatusesAreNotClassifiedSuccess() {
        for status in ["pending", "request_created", "", "MEMBER_CREATED", "bogus-future-status"] {
            XCTAssertFalse(
                FoundationVerificationManager.isTerminalSuccess(status),
                "\(status) must not be classified as terminal success"
            )
        }
    }

    // MARK: - refreshFromServer / the verified cache
    //
    // The bug these pin: `state` was in memory only, so a member who finished
    // verifying saw Home back at "Passport checked - Finish verification" on
    // the next launch. Every test below runs against a throwaway UserDefaults
    // suite, a fixed uid and a canned getMyFounderProfile answer - never
    // Firebase, never `.standard`.

    private func makeCache() -> VerifiedMemberCache {
        let suite = "VerificationManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return VerifiedMemberCache(defaults: defaults)
    }

    private static let verifiedProfile = FounderProfileResult(
        status: "ok", memberNumber: 42, verificationLevel: "l3", passportVerified: true
    )

    private struct Offline: Error {}

    /// A reference cell, so a `@Sendable` `MainActor.run` body can change what
    /// the manager's injected closures see (a captured `var` cannot be).
    private final class Box<Value> {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    @MainActor
    func testRefreshUpgradesIdleToVerifiedAndCachesIt() async {
        let cache = makeCache()
        let m = FoundationVerificationManager(
            cache: cache, currentUid: { "uid-a" }, fetchProfile: { Self.verifiedProfile }
        )
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .verified(memberNumber: 42))
        XCTAssertEqual(cache.read(), VerifiedMemberCache.Entry(uid: "uid-a", memberNumber: 42))
    }

    /// The member got "You're verified" in the bell when it happened; a launch
    /// that merely re-learns it must not post it again.
    @MainActor
    func testRefreshDoesNotRepostTheVerifiedNotification() async {
        let before = AppNotificationStore.shared.entries.count
        let m = FoundationVerificationManager(
            cache: makeCache(), currentUid: { "uid-a" }, fetchProfile: { Self.verifiedProfile }
        )
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .verified(memberNumber: 42))
        XCTAssertEqual(AppNotificationStore.shared.entries.count, before)
    }

    @MainActor
    func testRefreshUpgradesAFailedTry() async {
        let m = FoundationVerificationManager(
            state: .failed("nope"), cache: makeCache(),
            currentUid: { "uid-a" }, fetchProfile: { Self.verifiedProfile }
        )
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .verified(memberNumber: 42))
    }

    /// A flow in progress owns the state; a background read must not stamp
    /// over it, and must not even ask.
    @MainActor
    func testRefreshNeverTouchesAFlowInProgress() async {
        for state: VerificationState in [.notRegistered, .starting, .awaitingProof, .polling] {
            var asked = false
            let m = FoundationVerificationManager(
                state: state, cache: makeCache(), currentUid: { "uid-a" },
                fetchProfile: { asked = true; return Self.verifiedProfile }
            )
            await m.refreshFromServer()
            XCTAssertEqual(m.state, state, "refreshFromServer must not touch \(state)")
            XCTAssertFalse(asked, "refreshFromServer must not call the server from \(state)")
        }
    }

    @MainActor
    func testRefreshErrorKeepsTheStateAndTheCache() async {
        let cache = makeCache()
        cache.write(.init(uid: "uid-a", memberNumber: 7))
        let m = FoundationVerificationManager(
            cache: cache, currentUid: { "uid-a" }, fetchProfile: { throw Offline() }
        )
        XCTAssertEqual(m.state, .verified(memberNumber: 7), "the cache is restored at init")
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .verified(memberNumber: 7))
        XCTAssertEqual(cache.read(), VerifiedMemberCache.Entry(uid: "uid-a", memberNumber: 7))

        let failed = FoundationVerificationManager(
            state: .failed("nope"), cache: makeCache(),
            currentUid: { "uid-a" }, fetchProfile: { throw Offline() }
        )
        await failed.refreshFromServer()
        XCTAssertEqual(failed.state, .failed("nope"))
    }

    @MainActor
    func testNotVerifiedLeavesIdleAndFailedAndClearsTheCache() async {
        let notMember = FounderProfileResult(status: "not_a_member")
        for state: VerificationState in [.idle, .failed("nope")] {
            let cache = makeCache()
            // Another uid's entry, so init does not restore it.
            cache.write(.init(uid: "uid-other", memberNumber: 1))
            let m = FoundationVerificationManager(
                state: state, cache: cache, currentUid: { "uid-a" }, fetchProfile: { notMember }
            )
            await m.refreshFromServer()
            XCTAssertEqual(m.state, state)
            XCTAssertNil(cache.read())
        }
    }

    /// A cached `.verified` is a hint until the server confirms it: a member
    /// deleted on the web must not stay "verified" on this phone forever.
    @MainActor
    func testNotVerifiedTakesBackACacheRestoredVerified() async {
        let cache = makeCache()
        cache.write(.init(uid: "uid-a", memberNumber: 7))
        let m = FoundationVerificationManager(
            cache: cache, currentUid: { "uid-a" },
            fetchProfile: { FounderProfileResult(status: "ok", memberNumber: 7, verificationLevel: "l1", passportVerified: false) }
        )
        XCTAssertEqual(m.state, .verified(memberNumber: 7))
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .idle)
        XCTAssertNil(cache.read())
    }

    /// A `.verified` this session reached itself is final, as before.
    @MainActor
    func testNotVerifiedLeavesALiveVerifiedAlone() async {
        let m = FoundationVerificationManager(
            state: .verified(memberNumber: 3), cache: makeCache(), currentUid: { "uid-a" },
            fetchProfile: { FounderProfileResult(status: "not_a_member") }
        )
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .verified(memberNumber: 3))
    }

    /// The cache must never cross accounts: another uid's entry, or no one
    /// signed in, restores nothing.
    @MainActor
    func testCacheIsRestoredOnlyForTheSameUid() {
        let cache = makeCache()
        cache.write(.init(uid: "uid-a", memberNumber: 7))

        XCTAssertEqual(
            FoundationVerificationManager(cache: cache, currentUid: { "uid-a" }).state,
            .verified(memberNumber: 7)
        )
        XCTAssertEqual(FoundationVerificationManager(cache: cache, currentUid: { "uid-b" }).state, .idle)
        XCTAssertEqual(FoundationVerificationManager(cache: cache, currentUid: { nil }).state, .idle)
    }

    @MainActor
    func testResetClearsTheCache() {
        let cache = makeCache()
        cache.write(.init(uid: "uid-a", memberNumber: 7))
        let m = FoundationVerificationManager(cache: cache, currentUid: { "uid-a" })
        m.reset()
        XCTAssertEqual(m.state, .idle)
        XCTAssertNil(cache.read())
    }

    /// Sign-out (reset) landing while the profile read is in flight must win,
    /// even though the same uid is still reported afterwards.
    @MainActor
    func testResetDuringTheAwaitDropsTheAnswer() async {
        let cache = makeCache()
        let holder = Box<FoundationVerificationManager?>(nil)
        let m = FoundationVerificationManager(
            cache: cache, currentUid: { "uid-a" },
            fetchProfile: {
                await MainActor.run { holder.value?.reset() }
                return Self.verifiedProfile
            }
        )
        holder.value = m
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .idle)
        XCTAssertNil(cache.read())
    }

    /// A different member signed in during the await: the answer was about
    /// the previous one and must be dropped.
    @MainActor
    func testUidChangeDuringTheAwaitDropsTheAnswer() async {
        let cache = makeCache()
        let uid = Box("uid-a")
        let m = FoundationVerificationManager(
            cache: cache, currentUid: { uid.value },
            fetchProfile: {
                await MainActor.run { uid.value = "uid-b" }
                return Self.verifiedProfile
            }
        )
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .idle)
        XCTAssertNil(cache.read())
    }

    @MainActor
    func testRefreshWithoutASignedInUidDoesNothing() async {
        var asked = false
        let m = FoundationVerificationManager(
            cache: makeCache(), currentUid: { nil },
            fetchProfile: { asked = true; return Self.verifiedProfile }
        )
        await m.refreshFromServer()
        XCTAssertEqual(m.state, .idle)
        XCTAssertFalse(asked)
    }

    // MARK: - FounderProfileResult: which answers mean "verified person"

    func testProfileVerifiedPersonRule() {
        XCTAssertTrue(FounderProfileResult(status: "ok", passportVerified: true).isVerifiedPerson)
        XCTAssertTrue(FounderProfileResult(status: "ok", verificationLevel: "l3").isVerifiedPerson)
        XCTAssertTrue(FounderProfileResult(status: "ok", verificationLevel: "l3", passportVerified: false).isVerifiedPerson)
        XCTAssertFalse(FounderProfileResult(status: "ok", verificationLevel: "l1", passportVerified: false).isVerifiedPerson)
        XCTAssertFalse(FounderProfileResult(status: "ok").isVerifiedPerson)
        XCTAssertFalse(FounderProfileResult(status: "not_a_member").isVerifiedPerson)
        XCTAssertFalse(FounderProfileResult(status: nil, verificationLevel: "l3", passportVerified: true).isVerifiedPerson)
    }

    /// The real reply carries a whole dashboard; only four fields are read,
    /// and a field that drifts type must not sink the rest.
    func testProfileDecodesTheRealShapeAndToleratesDrift() throws {
        let json = """
        {"status":"ok","memberNumber":1234,"foundingCohort":"alpha","verificationLevel":"l3",
         "verified":true,"passportVerified":true,"passports":[{"ref":"ab12","status":"active","addedAt":null}],
         "wallet":{"balance":0}}
        """
        let full = try JSONDecoder().decode(FounderProfileResult.self, from: Data(json.utf8))
        XCTAssertEqual(full.memberNumber, 1234)
        XCTAssertTrue(full.isVerifiedPerson)

        let notMember = try JSONDecoder().decode(FounderProfileResult.self, from: Data(#"{"status":"not_a_member"}"#.utf8))
        XCTAssertFalse(notMember.isVerifiedPerson)

        let drifted = try JSONDecoder().decode(
            FounderProfileResult.self,
            from: Data(#"{"status":"ok","memberNumber":"1234","passportVerified":true}"#.utf8)
        )
        XCTAssertNil(drifted.memberNumber)
        XCTAssertTrue(drifted.isVerifiedPerson)
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
