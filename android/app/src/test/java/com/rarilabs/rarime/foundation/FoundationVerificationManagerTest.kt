package com.rarilabs.rarime.foundation

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * State-machine tests for [FoundationVerificationManager].
 *
 * Everything the manager touches is injected as a lambda, so these run as plain
 * JVM tests: no Firebase, no Android framework, no Robolectric. `delay` inside
 * `pollUntilVerified` is virtual under `runTest`, so even the 40-iteration
 * timeout test completes instantly.
 */
class FoundationVerificationManagerTest {

    private val proofParamsUrl = "https://verificator.example/params/abc"

    private fun requestCreated() =
        StartL2VerificationResult("request_created", "rarime://ignored", proofParamsUrl, null)

    private fun manager(
        start: suspend () -> StartL2VerificationResult = { requestCreated() },
        status: suspend () -> L2VerificationStatusResult = {
            L2VerificationStatusResult("pending", null)
        },
        uid: String? = "uid-1",
        registrationProof: Any? = Any(),
        terminalFailureMessage: (Throwable) -> String? = { null },
        pollLimit: Int = FoundationVerificationManager.POLL_LIMIT,
        onVerified: () -> Unit = {},
        fetchProfile: suspend () -> FounderProfileResult = { throw IllegalStateException("offline") },
        cache: VerifiedMemberCache? = null,
        uidProvider: (() -> String?)? = null,
    ) = FoundationVerificationManager(
        startL2Verification = start,
        fetchL2VerificationStatus = status,
        uidProvider = uidProvider ?: { uid },
        registrationProofProvider = { registrationProof },
        terminalFailureMessage = terminalFailureMessage,
        pollLimit = pollLimit,
        onVerified = onVerified,
        fetchFounderProfile = fetchProfile,
        verifiedCache = cache,
    )

    /** SharedPreferences stand-in: the same read/write/clear contract, in memory. */
    private class FakeVerifiedMemberCache(var entry: VerifiedMemberCache.Entry? = null) : VerifiedMemberCache {
        override fun read() = entry
        override fun write(entry: VerifiedMemberCache.Entry) {
            this.entry = entry
        }
        override fun clear() {
            entry = null
        }
    }

    private val verifiedProfile =
        FounderProfileResult(status = "ok", memberNumber = 42, verificationLevel = "l3", passportVerified = true)

    /** Drives a manager to `Polling`, the way the card does. */
    private suspend fun pollingManager(
        status: suspend () -> L2VerificationStatusResult,
        terminalFailureMessage: (Throwable) -> String? = { null },
        pollLimit: Int = FoundationVerificationManager.POLL_LIMIT,
    ): FoundationVerificationManager {
        val m = manager(
            status = status,
            terminalFailureMessage = terminalFailureMessage,
            pollLimit = pollLimit,
        )
        m.beginVerification()
        assertTrue(m.proofRequestSucceeded())
        assertEquals(VerificationState.Polling, m.state.value)
        return m
    }

    @Test
    fun initialStateIsIdle() {
        assertEquals(VerificationState.Idle, manager().state.value)
    }

    @Test
    fun signedOutLandsInNotRegistered() = runTest {
        val m = manager(uid = null)
        m.beginVerification()
        assertEquals(VerificationState.NotRegistered, m.state.value)
    }

    @Test
    fun unregisteredPassportLandsInNotRegistered() = runTest {
        // Rarimo's generateQueryProof throws NoActiveIdentity without a
        // registration proof, so starting the flow at all would be pointless.
        val m = manager(registrationProof = null)
        m.beginVerification()
        assertEquals(VerificationState.NotRegistered, m.state.value)
    }

    @Test
    fun beginVerificationReachesAwaitingProofWithTheParamsUrl() = runTest {
        val m = manager()
        m.beginVerification()
        assertEquals(VerificationState.AwaitingProof(proofParamsUrl), m.state.value)
    }

    @Test
    fun fullHappyPathReachesVerifiedWithTheMemberNumber() = runTest {
        val m = pollingManager(status = { L2VerificationStatusResult("member_created", 1234) })
        m.pollUntilVerified()
        assertEquals(VerificationState.Verified(1234), m.state.value)
    }

    @Test
    fun memberUpgradedAlsoCountsAsVerified() = runTest {
        // The backend returns member_upgraded, not member_created, when an
        // existing member moves up to l2.
        val m = pollingManager(status = { L2VerificationStatusResult("member_upgraded", 7) })
        m.pollUntilVerified()
        assertEquals(VerificationState.Verified(7), m.state.value)
    }

    @Test
    fun alreadyVerifiedShortCircuitsWithoutAProofRequest() = runTest {
        val m = manager(start = { StartL2VerificationResult("already_verified_l2", null, null, null) })
        m.beginVerification()
        assertEquals(VerificationState.Verified(null), m.state.value)
    }

    @Test
    fun alreadyVerifiedShortCircuitCarriesTheRealMemberNumber() = runTest {
        // Scoped re-review finding M-6: the backend sends memberNumber
        // alongside already_verified_l2 (passport.js:129), and it must
        // reach VerificationState.Verified, not be dropped to null.
        val m = manager(start = { StartL2VerificationResult("already_verified_l2", null, null, 4242) })
        m.beginVerification()
        assertEquals(VerificationState.Verified(4242), m.state.value)
    }

    @Test
    fun pollingKeepsGoingUntilTheStatusFlips() = runTest {
        var calls = 0
        val m = pollingManager(status = {
            calls++
            if (calls < 3) L2VerificationStatusResult("pending", null)
            else L2VerificationStatusResult("member_created", 9)
        })
        m.pollUntilVerified()
        assertEquals(VerificationState.Verified(9), m.state.value)
        assertEquals(3, calls)
    }

    @Test
    fun startFailureLandsInFailedRatherThanThrowing() = runTest {
        val m = manager(start = { throw IllegalStateException("network down") })
        m.beginVerification()
        assertEquals(
            VerificationState.Failed(FoundationVerificationManager.MESSAGE_START_FAILED),
            m.state.value,
        )
    }

    @Test
    fun missingProofParamsUrlLandsInFailed() = runTest {
        val m = manager(start = { StartL2VerificationResult("request_created", "deep://link", null, null) })
        m.beginVerification()
        assertEquals(
            VerificationState.Failed(FoundationVerificationManager.MESSAGE_NO_PROOF_PARAMS),
            m.state.value,
        )
    }

    @Test
    fun transientPollErrorIsRetriedNotFatal() = runTest {
        var calls = 0
        val m = pollingManager(status = {
            calls++
            if (calls == 1) throw RuntimeException("transient 503")
            L2VerificationStatusResult("member_created", 3)
        })
        m.pollUntilVerified()
        assertEquals(VerificationState.Verified(3), m.state.value)
    }

    @Test
    fun terminalRejectionStopsPollingAndKeepsTheServerMessage() = runTest {
        // A rejected or duplicate passport arrives as a thrown
        // FAILED_PRECONDITION carrying a message written for the user. Treating
        // it as transient would discard that message and make the user wait out
        // the whole two-minute timeout for a generic one.
        var calls = 0
        val rejection = "This passport is already linked to a different member."
        val m = pollingManager(
            status = {
                calls++
                throw IllegalArgumentException(rejection)
            },
            terminalFailureMessage = { it.message },
        )
        m.pollUntilVerified()
        assertEquals(VerificationState.Failed(rejection), m.state.value)
        assertEquals(1, calls)
    }

    @Test
    fun alreadyExistsRejectionStopsPollingAndKeepsTheServerMessageEndToEnd() = runTest {
        // Same shape as terminalRejectionStopsPollingAndKeepsTheServerMessage
        // above, but the injected classifier is `terminalRejectionMessage`
        // itself (composed with a raw "ALREADY_EXISTS" code name) rather than
        // a bare `{ it.message }` stub - this exercises the REAL decision
        // function this fix changed, wired through the real poll loop. A
        // plain FirebaseFunctionsException can't be constructed here (see
        // firebaseRejectionMessage's doc: referencing its Code enum crashes
        // this module's local unit tests), so the thrown exception is a
        // stand-in carrying the message; the code name is supplied directly
        // to the pure classifier, exactly as `firebaseRejectionMessage` would
        // read it off `e.code.name` in production.
        var calls = 0
        val message = "This passport is already linked to another member. A passport belongs to one member, permanently — if this is a mistake, contact support to appeal."
        val m = pollingManager(
            status = {
                calls++
                throw RuntimeException(message)
            },
            terminalFailureMessage = { terminalRejectionMessage(codeName = "ALREADY_EXISTS", message = it.message) },
        )
        m.pollUntilVerified()
        assertEquals(VerificationState.Failed(message), m.state.value)
        assertEquals(1, calls)
    }

    @Test
    fun pollingGivesUpAfterTheLimit() = runTest {
        var calls = 0
        val m = pollingManager(
            status = {
                calls++
                L2VerificationStatusResult("pending", null)
            },
            pollLimit = 5,
        )
        m.pollUntilVerified()
        assertEquals(
            VerificationState.Failed(FoundationVerificationManager.MESSAGE_TIMED_OUT),
            m.state.value,
        )
        assertEquals(5, calls)
    }

    @Test
    fun aForeignProofSuccessIsNotClaimed() = runTest {
        // An externally scanned proof request has nothing to do with this
        // member's L2 status; polling for it would end in a bogus Failed.
        val m = manager()
        assertFalse(m.proofRequestSucceeded())
        assertEquals(VerificationState.Idle, m.state.value)
    }

    @Test
    fun pollingWithoutAClaimedSuccessDoesNothing() = runTest {
        var calls = 0
        val m = manager(status = {
            calls++
            L2VerificationStatusResult("member_created", 1)
        })
        m.beginVerification()
        m.pollUntilVerified()
        assertEquals(0, calls)
        assertEquals(VerificationState.AwaitingProof(proofParamsUrl), m.state.value)
    }

    @Test
    fun dismissingTheSheetReleasesAwaitingProof() = runTest {
        val m = manager()
        m.beginVerification()
        m.proofFlowDismissed()
        assertEquals(VerificationState.Idle, m.state.value)
    }

    @Test
    fun dismissDoesNotClobberAClaimedSuccess() = runTest {
        val m = manager()
        m.beginVerification()
        assertTrue(m.proofRequestSucceeded())
        m.proofFlowDismissed()
        assertEquals(VerificationState.Polling, m.state.value)
    }

    @Test
    fun proofFailureLandsInFailed() = runTest {
        val m = manager()
        m.beginVerification()
        m.proofFlowFailed()
        assertEquals(
            VerificationState.Failed(FoundationVerificationManager.MESSAGE_PROOF_FAILED),
            m.state.value,
        )
    }

    @Test
    fun resetClearsAVerifiedState() = runTest {
        val m = pollingManager(status = { L2VerificationStatusResult("member_created", 5) })
        m.pollUntilVerified()
        assertEquals(VerificationState.Verified(5), m.state.value)
        m.reset()
        assertEquals(VerificationState.Idle, m.state.value)
    }

    @Test
    fun cancellationLeavesStateResumableRatherThanFailed() = runTest {
        // Leaving Home destroys the card's ViewModel and cancels the poller.
        // That must not be mistaken for a backend error: state has to stay on
        // Polling so resumePollingIfInterrupted() can pick it back up.
        val m = pollingManager(status = { throw CancellationException("scope died") })
        var propagated = false
        try {
            m.pollUntilVerified()
        } catch (e: CancellationException) {
            propagated = true
        }
        assertTrue("CancellationException must propagate", propagated)
        assertEquals(VerificationState.Polling, m.state.value)
    }

    @Test
    fun anInterruptedPollCanBeResumed() = runTest {
        var calls = 0
        val m = pollingManager(status = {
            calls++
            if (calls == 1) throw CancellationException("scope died")
            L2VerificationStatusResult("member_created", 11)
        })
        runCatching { m.pollUntilVerified() }
        assertEquals(VerificationState.Polling, m.state.value)

        // A rebuilt ViewModel calls straight back in.
        m.pollUntilVerified()
        assertEquals(VerificationState.Verified(11), m.state.value)
    }

    // MARK: - terminalRejectionMessage: which getL2VerificationStatus
    // failures are terminal, not transient. Tested directly against the pure
    // decision function `firebaseRejectionMessage` delegates to, working off
    // a code NAME rather than a real FirebaseFunctionsException - referencing
    // FirebaseFunctionsException.Code in this module's local unit tests
    // crashes at class-load time (its static init calls into
    // android.util.SparseArray, unmocked here), which is also why
    // firebaseRejectionMessage's own doc explains the same indirection.

    @Test
    fun alreadyExistsIsClassifiedAsATerminalRejection() {
        // A duplicate-passport rejection arrives as ALREADY_EXISTS - this is
        // the code the backend actually uses in practice, per passport.js's
        // comment: the lane-doc uniqueness guard is "the ONLY layer that
        // actually rejects a duplicate passport in practice" because the
        // svc-side FAILED_PRECONDITION check "went blind". Before this fix
        // (whole-plan review finding I-2) only FAILED_PRECONDITION was
        // classified terminal, so this real rejection was retried 40x over
        // two minutes and reported as a generic timeout instead of the
        // server's real message.
        val message = "This passport is already linked to another member. A passport belongs to one member, permanently — if this is a mistake, contact support to appeal."
        assertEquals(message, terminalRejectionMessage(codeName = "ALREADY_EXISTS", message = message))
    }

    @Test
    fun failedPreconditionIsStillClassifiedAsATerminalRejection() {
        // The pre-existing terminal code must keep working exactly as before
        // - this fix adds ALREADY_EXISTS alongside it, not in place of it.
        val message = "We couldn't verify that passport. Please try again."
        assertEquals(message, terminalRejectionMessage(codeName = "FAILED_PRECONDITION", message = message))
    }

    @Test
    fun unrelatedFirebaseCodesAreNotClassifiedAsTerminalRejections() {
        assertNull(terminalRejectionMessage(codeName = "UNAVAILABLE", message = "transient 503"))
    }

    @Test
    fun aBlankTerminalMessageFallsBackToTheGenericProofFailedMessage() {
        assertEquals(
            FoundationVerificationManager.MESSAGE_PROOF_FAILED,
            terminalRejectionMessage(codeName = "ALREADY_EXISTS", message = ""),
        )
        assertEquals(
            FoundationVerificationManager.MESSAGE_PROOF_FAILED,
            terminalRejectionMessage(codeName = "ALREADY_EXISTS", message = null),
        )
    }

    @Test
    fun nonFirebaseThrowablesAreNotClassifiedAsTerminalRejections() {
        assertNull(firebaseRejectionMessage(RuntimeException("network down")))
    }

    @Test
    fun successStatusesMatchTheBackendVocabulary() {
        // foundation-next functions/founders/passport.js returns member_created
        // / member_upgraded from getL2VerificationStatus - never "verified".
        assertTrue(
            FoundationVerificationManager.TERMINAL_SUCCESS_STATUSES
                .containsAll(listOf("member_created", "member_upgraded")),
        )
    }

    // --- refreshFromServer / the verified cache ------------------------------
    //
    // The bug these pin: `state` was in memory only, so a member who finished
    // verifying saw Home back at "Passport checked - Finish verification" on
    // the next cold start.

    @Test
    fun refreshUpgradesIdleToVerifiedCachesItAndDoesNotNotify() = runTest {
        val cache = FakeVerifiedMemberCache()
        var notified = 0
        val m = manager(fetchProfile = { verifiedProfile }, cache = cache, onVerified = { notified++ })
        m.refreshFromServer()
        assertEquals(VerificationState.Verified(42), m.state.value)
        assertEquals(VerifiedMemberCache.Entry("uid-1", 42), cache.entry)
        // The member got "You're verified" when it happened; re-learning it on
        // a launch must not post it again.
        assertEquals(0, notified)
    }

    @Test
    fun theLiveFlowStillNotifiesAndCaches() = runTest {
        val cache = FakeVerifiedMemberCache()
        var notified = 0
        val m = manager(
            start = { StartL2VerificationResult("already_verified_l2", null, null, 7) },
            cache = cache,
            onVerified = { notified++ },
        )
        m.beginVerification()
        assertEquals(VerificationState.Verified(7), m.state.value)
        assertEquals(1, notified)
        assertEquals(VerifiedMemberCache.Entry("uid-1", 7), cache.entry)
    }

    @Test
    fun refreshUpgradesAFailedTry() = runTest {
        val m = manager(start = { throw IllegalStateException("down") }, fetchProfile = { verifiedProfile })
        m.beginVerification()
        assertTrue(m.state.value is VerificationState.Failed)
        m.refreshFromServer()
        assertEquals(VerificationState.Verified(42), m.state.value)
    }

    @Test
    fun refreshNeverTouchesAFlowInProgressNorAsks() = runTest {
        var asked = 0
        val fetch: suspend () -> FounderProfileResult = { asked++; verifiedProfile }

        val awaiting = manager(fetchProfile = fetch)
        awaiting.beginVerification()
        awaiting.refreshFromServer()
        assertEquals(VerificationState.AwaitingProof(proofParamsUrl), awaiting.state.value)

        val polling = manager(fetchProfile = fetch)
        polling.beginVerification()
        assertTrue(polling.proofRequestSucceeded())
        polling.refreshFromServer()
        assertEquals(VerificationState.Polling, polling.state.value)

        val notRegistered = manager(fetchProfile = fetch, registrationProof = null)
        notRegistered.beginVerification()
        notRegistered.refreshFromServer()
        assertEquals(VerificationState.NotRegistered, notRegistered.state.value)

        assertEquals(0, asked)
    }

    @Test
    fun refreshErrorIsSilentAndKeepsStateAndCache() = runTest {
        val cache = FakeVerifiedMemberCache(VerifiedMemberCache.Entry("uid-1", 7))
        val m = manager(fetchProfile = { throw IllegalStateException("offline") }, cache = cache)
        assertEquals(VerificationState.Verified(7), m.state.value)
        m.refreshFromServer()
        assertEquals(VerificationState.Verified(7), m.state.value)
        assertEquals(VerifiedMemberCache.Entry("uid-1", 7), cache.entry)

        val idle = manager(fetchProfile = { throw IllegalStateException("offline") })
        idle.refreshFromServer()
        assertEquals(VerificationState.Idle, idle.state.value)
    }

    @Test
    fun notVerifiedLeavesIdleAndClearsTheCache() = runTest {
        // Another uid's entry, so it is not restored at construction.
        val cache = FakeVerifiedMemberCache(VerifiedMemberCache.Entry("uid-other", 1))
        val m = manager(fetchProfile = { FounderProfileResult(status = "not_a_member") }, cache = cache)
        m.refreshFromServer()
        assertEquals(VerificationState.Idle, m.state.value)
        assertNull(cache.entry)
    }

    @Test
    fun notVerifiedTakesBackACacheRestoredVerified() = runTest {
        // A member deleted on the web must not stay "verified" on this phone.
        val cache = FakeVerifiedMemberCache(VerifiedMemberCache.Entry("uid-1", 7))
        val m = manager(
            fetchProfile = { FounderProfileResult(status = "ok", verificationLevel = "l1", passportVerified = false) },
            cache = cache,
        )
        assertEquals(VerificationState.Verified(7), m.state.value)
        m.refreshFromServer()
        assertEquals(VerificationState.Idle, m.state.value)
        assertNull(cache.entry)
    }

    @Test
    fun notVerifiedLeavesALiveVerifiedAlone() = runTest {
        val m = manager(
            start = { StartL2VerificationResult("already_verified_l2", null, null, 3) },
            fetchProfile = { FounderProfileResult(status = "not_a_member") },
        )
        m.beginVerification()
        m.refreshFromServer()
        assertEquals(VerificationState.Verified(3), m.state.value)
    }

    @Test
    fun cacheIsRestoredOnlyForTheSignedInUid() {
        val cache = FakeVerifiedMemberCache(VerifiedMemberCache.Entry("uid-1", 7))
        assertEquals(VerificationState.Verified(7), manager(cache = cache).state.value)
        assertEquals(VerificationState.Idle, manager(cache = cache, uid = "uid-2").state.value)
        assertEquals(VerificationState.Idle, manager(cache = cache, uid = null).state.value)
        // A mismatch restores nothing but leaves the entry for its own member.
        assertEquals(VerifiedMemberCache.Entry("uid-1", 7), cache.entry)
    }

    @Test
    fun resetClearsTheCache() {
        val cache = FakeVerifiedMemberCache(VerifiedMemberCache.Entry("uid-1", 7))
        val m = manager(cache = cache)
        m.reset()
        assertEquals(VerificationState.Idle, m.state.value)
        assertNull(cache.entry)
    }

    @Test
    fun aResetDuringTheCallDropsTheAnswer() = runTest {
        // Sign-out landing while the profile read is in flight must win, even
        // though the same uid is still reported afterwards.
        val cache = FakeVerifiedMemberCache()
        lateinit var m: FoundationVerificationManager
        m = manager(fetchProfile = { m.reset(); verifiedProfile }, cache = cache)
        m.refreshFromServer()
        assertEquals(VerificationState.Idle, m.state.value)
        assertNull(cache.entry)
    }

    @Test
    fun aUidChangeDuringTheCallDropsTheAnswer() = runTest {
        val cache = FakeVerifiedMemberCache()
        var uid: String? = "uid-1"
        val m = manager(
            fetchProfile = { uid = "uid-2"; verifiedProfile },
            cache = cache,
            uidProvider = { uid },
        )
        m.refreshFromServer()
        assertEquals(VerificationState.Idle, m.state.value)
        assertNull(cache.entry)
    }

    @Test
    fun refreshWithoutASignedInUidDoesNothing() = runTest {
        var asked = 0
        val m = manager(uid = null, fetchProfile = { asked++; verifiedProfile })
        m.refreshFromServer()
        assertEquals(VerificationState.Idle, m.state.value)
        assertEquals(0, asked)
    }

    @Test
    fun verifiedPersonRuleMatchesTheBackendShortCircuit() {
        assertTrue(FounderProfileResult(status = "ok", passportVerified = true).isVerifiedPerson)
        assertTrue(FounderProfileResult(status = "ok", verificationLevel = "l3").isVerifiedPerson)
        assertTrue(
            FounderProfileResult(status = "ok", verificationLevel = "l3", passportVerified = false).isVerifiedPerson,
        )
        assertFalse(
            FounderProfileResult(status = "ok", verificationLevel = "l1", passportVerified = false).isVerifiedPerson,
        )
        assertFalse(FounderProfileResult(status = "ok").isVerifiedPerson)
        assertFalse(FounderProfileResult(status = "not_a_member").isVerifiedPerson)
    }

    @Test
    fun profileDecodeReadsTheRealShapeAndToleratesDrift() {
        val full = founderProfileResultFrom(
            mapOf(
                "status" to "ok",
                "memberNumber" to 1234L,
                "foundingCohort" to "alpha",
                "verificationLevel" to "l3",
                "verified" to true,
                "passportVerified" to true,
                "passports" to listOf(mapOf("ref" to "ab12", "status" to "active")),
            ),
        )
        assertEquals(1234, full.memberNumber)
        assertTrue(full.isVerifiedPerson)

        assertFalse(founderProfileResultFrom(mapOf("status" to "not_a_member")).isVerifiedPerson)
        assertFalse(founderProfileResultFrom(null).isVerifiedPerson)

        val drifted = founderProfileResultFrom(
            mapOf("status" to "ok", "memberNumber" to "1234", "passportVerified" to true),
        )
        assertNull(drifted.memberNumber)
        assertTrue(drifted.isVerifiedPerson)
    }
}
