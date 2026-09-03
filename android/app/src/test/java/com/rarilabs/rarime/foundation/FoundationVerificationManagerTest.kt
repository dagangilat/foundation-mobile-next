package com.rarilabs.rarime.foundation

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
        StartL2VerificationResult("request_created", "rarime://ignored", proofParamsUrl)

    private fun manager(
        start: suspend () -> StartL2VerificationResult = { requestCreated() },
        status: suspend () -> L2VerificationStatusResult = {
            L2VerificationStatusResult("pending", null)
        },
        uid: String? = "uid-1",
        registrationProof: Any? = Any(),
        terminalFailureMessage: (Throwable) -> String? = { null },
        pollLimit: Int = FoundationVerificationManager.POLL_LIMIT,
    ) = FoundationVerificationManager(
        startL2Verification = start,
        fetchL2VerificationStatus = status,
        uidProvider = { uid },
        registrationProofProvider = { registrationProof },
        terminalFailureMessage = terminalFailureMessage,
        pollLimit = pollLimit,
    )

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
        val m = manager(start = { StartL2VerificationResult("already_verified_l2", null, null) })
        m.beginVerification()
        assertEquals(VerificationState.Verified(null), m.state.value)
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
        val m = manager(start = { StartL2VerificationResult("request_created", "deep://link", null) })
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
    fun successStatusesMatchTheBackendVocabulary() {
        // foundation-next functions/founders/passport.js returns member_created
        // / member_upgraded from getL2VerificationStatus - never "verified".
        assertTrue(
            FoundationVerificationManager.TERMINAL_SUCCESS_STATUSES
                .containsAll(listOf("member_created", "member_upgraded")),
        )
    }
}
