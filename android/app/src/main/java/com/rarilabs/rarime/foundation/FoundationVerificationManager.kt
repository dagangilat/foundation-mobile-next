package com.rarilabs.rarime.foundation

import com.google.firebase.functions.FirebaseFunctionsException
import com.rarilabs.rarime.manager.IdentityManager
import com.rarilabs.rarime.util.ErrorHandler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The one Foundation verification flow, as a state machine.
 *
 * Mirrors iOS's `FoundationVerificationManager` (Task B8 / AD-2):
 *   1. `startL2Verification` creates a request against this fork's own
 *      verificator-svc instance and returns `getProofParamsUrl`.
 *   2. That URL is handed straight to Rarimo's existing `ExtIntQueryProofHandler`
 *      - the same code path an external QR scan would take. The `deepLink` the
 *      backend also returns is never read; it targets the RariMe app, not us.
 *   3. The handler posts the query proof to verificator-svc.
 *   4. `getL2VerificationStatus` is polled until the member flips to l2.
 *
 * There is deliberately no step 5. The commitment write-back that once followed
 * verification (ProofArtifact / EnclaveSeal / anchorCommitment) was retired
 * backend-side in foundation-next commit 06729e77, so `Verified` is terminal.
 */
sealed interface VerificationState {
    data object Idle : VerificationState

    /**
     * Either signed out, or the passport is not registered on L2 yet. Both are
     * hard preconditions: every Foundation callable runs `requireAuth`, and
     * `ExtIntQueryProofHandlerViewModel.generateQueryProof` throws
     * `NoActiveIdentity` when `identityManager.registrationProof` is null.
     */
    data object NotRegistered : VerificationState

    data object Starting : VerificationState

    /**
     * The proof sheet is up; `ExtIntQueryProofHandler` owns the UI from here.
     *
     * Carries the URL rather than parking it in a side channel: Android has no
     * equivalent of iOS's `ExternalRequestsManager` singleton, so the state
     * itself is how the card learns which URL to hand the handler.
     */
    data class AwaitingProof(val proofParamsUrl: String) : VerificationState

    data object Polling : VerificationState
    data class Verified(val memberNumber: Int?) : VerificationState
    data class Failed(val message: String) : VerificationState
}

@Singleton
class FoundationVerificationManager internal constructor(
    private val startL2Verification: suspend () -> StartL2VerificationResult,
    private val fetchL2VerificationStatus: suspend () -> L2VerificationStatusResult,
    private val uidProvider: () -> String?,
    private val registrationProofProvider: () -> Any?,
    /**
     * Maps a throwable from the status poll to a user-facing message when it is
     * a *terminal rejection*, or null when it is a transient blip worth
     * retrying. Injected rather than hardcoded so the poll loop's most
     * important branch is testable without constructing a Firebase exception.
     */
    private val terminalFailureMessage: (Throwable) -> String? = ::firebaseRejectionMessage,
    /**
     * Indirection for the same reason as `FoundationAuthManager.authProvider`:
     * `ErrorHandler.logError` calls `android.util.Log`, which throws
     * "not mocked" in a plain JVM unit test, and this module does not set
     * `testOptions.unitTests.isReturnDefaultValues`. The default no-ops so the
     * error paths - the ones most worth testing - stay reachable off-device.
     */
    private val logError: (String, Throwable?) -> Unit = { _, _ -> },
    private val pollIntervalMs: Long = POLL_INTERVAL_MS,
    private val pollLimit: Int = POLL_LIMIT,
) {
    @Inject
    constructor(
        functionsService: FoundationFunctionsService,
        authManager: FoundationAuthManager,
        identityManager: IdentityManager,
    ) : this(
        startL2Verification = { functionsService.startL2Verification() },
        fetchL2VerificationStatus = { functionsService.getL2VerificationStatus() },
        uidProvider = { authManager.uid.value },
        registrationProofProvider = { identityManager.registrationProof.value },
        terminalFailureMessage = ::firebaseRejectionMessage,
        logError = { message, throwable -> ErrorHandler.logError(TAG, message, throwable) },
    )

    private val _state = MutableStateFlow<VerificationState>(VerificationState.Idle)
    val state: StateFlow<VerificationState> = _state.asStateFlow()

    /**
     * Ask the backend for proof parameters and hand them to Rarimo's flow.
     *
     * Ends in `AwaitingProof` on the happy path - never in `Verified`, except
     * for the `already_verified_l2` short-circuit, which is the one case where
     * no proof is needed at all.
     */
    suspend fun beginVerification() {
        if (uidProvider() == null || registrationProofProvider() == null) {
            _state.value = VerificationState.NotRegistered
            return
        }
        _state.value = VerificationState.Starting
        try {
            val result = startL2Verification()

            if (result.status == STATUS_ALREADY_VERIFIED) {
                // memberNumber is null on purpose: StartL2VerificationResult
                // (Task C6) does not decode the memberNumber the backend sends
                // alongside this status. Cosmetic today - the card renders the
                // membership, not the number. See the C8 report.
                _state.value = VerificationState.Verified(memberNumber = null)
                return
            }

            val url = result.getProofParamsUrl
            if (url.isNullOrBlank()) {
                _state.value = VerificationState.Failed(MESSAGE_NO_PROOF_PARAMS)
                return
            }
            _state.value = VerificationState.AwaitingProof(url)
        } catch (e: Exception) {
            logError("startL2Verification failed", e)
            _state.value = VerificationState.Failed(
                terminalFailureMessage(e) ?: MESSAGE_START_FAILED,
            )
        }
    }

    /**
     * Claim the success the proof sheet just reported, **synchronously**.
     *
     * Returns false - and the caller must then not poll - when the proof that
     * succeeded is not the one `beginVerification()` asked for, e.g. an
     * externally scanned proof request. Polling `getL2VerificationStatus` for
     * such a proof would burn two minutes and end in a bogus `Failed`.
     */
    fun proofRequestSucceeded(): Boolean {
        if (_state.value !is VerificationState.AwaitingProof) return false
        _state.value = VerificationState.Polling
        return true
    }

    /**
     * The proof sheet closed without succeeding - cancel, back, a params load
     * failure. Without this reset `AwaitingProof` is terminal and the home card
     * stays disabled showing "Working…" for the rest of the process.
     *
     * A real success has already moved to `Polling`, so this is a no-op there.
     */
    fun proofFlowDismissed() {
        if (_state.value !is VerificationState.AwaitingProof) return
        _state.value = VerificationState.Idle
    }

    /** The proof sheet reported a hard failure. */
    fun proofFlowFailed(message: String = MESSAGE_PROOF_FAILED) {
        if (_state.value !is VerificationState.AwaitingProof) return
        _state.value = VerificationState.Failed(message)
    }

    /**
     * Return to the starting state, unconditionally.
     *
     * `state` describes ONE Foundation member identity. When that identity
     * stops being this device's - sign-out, account deletion - the state has to
     * go with it, or the next person to use the device inherits a `Verified`
     * they never earned.
     */
    fun reset() {
        _state.value = VerificationState.Idle
    }

    /**
     * Poll until the member flips to l2.
     *
     * The `Polling` guard is re-checked before every write, not just at entry:
     * this loop lives for up to two minutes across suspension points, and
     * `reset()` can land in any of them. Without the re-checks this loop is the
     * one writer that could stamp a stale `Verified` back over the `Idle` a
     * reset just established, for the NEXT user of the device.
     */
    suspend fun pollUntilVerified() {
        if (_state.value !is VerificationState.Polling) return

        repeat(pollLimit) {
            if (_state.value !is VerificationState.Polling) return
            try {
                val result = fetchL2VerificationStatus()
                if (result.status in TERMINAL_SUCCESS_STATUSES) {
                    if (_state.value !is VerificationState.Polling) return
                    _state.value = VerificationState.Verified(result.memberNumber)
                    return
                }
            } catch (e: CancellationException) {
                // The caller's scope died (see resumePollingIfInterrupted). That
                // is not a backend error and must not be logged as one, nor run
                // through terminalFailureMessage - rethrow so cancellation stays
                // cooperative and `state` is left on Polling to be resumed.
                throw e
            } catch (e: Exception) {
                // A rejection (bad passport, passport already linked to another
                // member) arrives as a thrown FAILED_PRECONDITION carrying a
                // written-for-humans message - it is terminal, and swallowing it
                // as a retry would discard that message and make the user wait
                // out the full timeout for a generic one instead.
                val rejection = terminalFailureMessage(e)
                if (rejection != null) {
                    logError("getL2VerificationStatus rejected", e)
                    if (_state.value !is VerificationState.Polling) return
                    _state.value = VerificationState.Failed(rejection)
                    return
                }
                logError("getL2VerificationStatus failed", e)
            }
            delay(pollIntervalMs)
        }

        if (_state.value !is VerificationState.Polling) return
        _state.value = VerificationState.Failed(MESSAGE_TIMED_OUT)
    }

    companion object {
        private const val TAG = "FoundationVerification"

        /**
         * verificator-svc terminates the proof server-side, so the flip is
         * usually seconds. 3s x 40 = a two-minute ceiling, matching iOS.
         * Rarimo has no status-poll loop of its own to borrow a convention
         * from - its `delay()` calls are all UI and animation timers.
         */
        const val POLL_INTERVAL_MS = 3_000L
        const val POLL_LIMIT = 40

        /** `startL2Verification` short-circuit for an already-l2 member. */
        const val STATUS_ALREADY_VERIFIED = "already_verified_l2"

        /**
         * What `getL2VerificationStatus` actually returns on success, read from
         * foundation-next `functions/founders/passport.js`: `member_created`
         * for a new member, `member_upgraded` for one moving up to l2. It never
         * returns "verified" - the two extra strings are accepted defensively
         * so a backend rename cannot silently strand the poller. iOS checks for
         * "verified"/"already_verified_l2" only and would therefore always time
         * out; see the C8 report.
         */
        val TERMINAL_SUCCESS_STATUSES = setOf(
            "member_created",
            "member_upgraded",
            "verified",
            STATUS_ALREADY_VERIFIED,
        )

        const val MESSAGE_NO_PROOF_PARAMS = "The server didn't return proof parameters."
        const val MESSAGE_START_FAILED = "We couldn't start the passport check. Please try again."
        const val MESSAGE_PROOF_FAILED = "We couldn't complete the passport check. Please try again."
        const val MESSAGE_TIMED_OUT =
            "The check is taking longer than expected. Please try again."
    }
}

/**
 * A `FAILED_PRECONDITION` from a Foundation callable is a considered, terminal
 * rejection whose message is written for the user (see
 * `getL2VerificationStatus` in foundation-next `functions/founders/passport.js`).
 * Everything else - network blips, transient 5xx - is worth another poll.
 */
internal fun firebaseRejectionMessage(throwable: Throwable): String? {
    val e = throwable as? FirebaseFunctionsException ?: return null
    if (e.code != FirebaseFunctionsException.Code.FAILED_PRECONDITION) return null
    return e.message?.takeIf { it.isNotBlank() }
        ?: FoundationVerificationManager.MESSAGE_PROOF_FAILED
}
