package com.rarilabs.rarime.foundation

import android.content.Context
import com.google.firebase.functions.FirebaseFunctionsException
import com.rarilabs.rarime.manager.IdentityManager
import com.rarilabs.rarime.util.ErrorHandler
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.concurrent.atomic.AtomicBoolean
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
    /**
     * Told about every terminal `Failed`, with its message. Production posts
     * it behind Home's bell ("Verification didn't finish", with Try again);
     * the card itself only says the last try didn't finish.
     */
    private val onFailed: (String) -> Unit = {},
    /**
     * Told when the flow reaches `Verified` - the live flow only. A `Verified`
     * that [refreshFromServer] re-learns, or the cache restores, does not call
     * it: the member got the "You're verified" bell entry when it happened, and
     * one per app launch would be noise.
     */
    private val onVerified: () -> Unit = {},
    /**
     * `getMyFounderProfile`, for [refreshFromServer]. The default throws, which
     * [refreshFromServer] treats like any network error (silent, state kept) -
     * so a test that does not care about refresh never needs to stub it.
     */
    private val fetchFounderProfile: suspend () -> FounderProfileResult = {
        throw IllegalStateException("getMyFounderProfile is not wired")
    },
    /**
     * Where "this uid is a verified person" is kept between launches. Null
     * means no persistence at all: production's Hilt constructor passes the
     * SharedPreferences one, tests pass a fake or nothing.
     */
    private val verifiedCache: VerifiedMemberCache? = null,
) {
    @Inject
    constructor(
        @ApplicationContext context: Context,
        functionsService: FoundationFunctionsService,
        authManager: FoundationAuthManager,
        identityManager: IdentityManager,
        notificationStore: AppNotificationStore,
    ) : this(
        startL2Verification = { functionsService.startL2Verification() },
        fetchL2VerificationStatus = { functionsService.getL2VerificationStatus() },
        uidProvider = { authManager.uid.value },
        registrationProofProvider = { identityManager.registrationProof.value },
        terminalFailureMessage = ::firebaseRejectionMessage,
        logError = { message, throwable -> ErrorHandler.logError(TAG, message, throwable) },
        onFailed = { message ->
            notificationStore.postVerificationFailure(
                reason = message,
                retry = AppNotification.Retry.FINISH_VERIFICATION,
            )
        },
        onVerified = { notificationStore.postVerified() },
        fetchFounderProfile = { functionsService.getMyFounderProfile() },
        verifiedCache = SharedPrefsVerifiedMemberCache(context),
    )

    private val _state = MutableStateFlow<VerificationState>(VerificationState.Idle)
    val state: StateFlow<VerificationState> = _state.asStateFlow()

    /**
     * Guards [reset] against [refreshFromServer]'s commit. Everything else in
     * this class runs on the main thread, but `reset()` is also reached from
     * [FoundationAccountDeletionManager], and the check-then-write at the end
     * of a refresh has to be one step with respect to it.
     */
    private val lock = Any()

    /**
     * True while `state` is a `Verified` that came out of [verifiedCache] and
     * the server has not yet confirmed this process. It is the one `Verified`
     * that [refreshFromServer] may still take back: a `Verified` reached
     * through the live flow, or already confirmed by a refresh, is final, as it
     * always was. Without it a cached answer could only ever be cleared by
     * signing out - a member deleted on the web would stay "verified" on this
     * phone forever, because the refresh that should notice would see
     * `Verified` and stand down.
     */
    @Volatile
    private var isVerifiedUnconfirmed = false

    /**
     * Bumped by every [reset]. [refreshFromServer] captures it before its
     * network call and refuses to write if it moved: a sign-out or account
     * deletion landing during the call must win, even when the SAME uid signs
     * straight back in before the answer arrives - a uid comparison alone
     * cannot see that.
     */
    private var resetGeneration = 0

    /** One refresh at a time: a resume and a recomposition can fire together. */
    private val isRefreshing = AtomicBoolean(false)

    init {
        // Home says "verified" on its very first frame of a cold launch,
        // offline included, instead of flashing "Finish verification" until a
        // round trip lands. FirebaseAuth restores `currentUser` synchronously
        // from its own SharedPreferences, so `uidProvider()` is already the
        // signed-in member here.
        restoreFromCacheIfIdle()
    }

    private fun fail(message: String) {
        _state.value = VerificationState.Failed(message)
        onFailed(message)
    }

    /**
     * Every transition INTO `Verified` goes through here, so every one is
     * cached for the next launch. `notify` is true only for the live flow's
     * two endings (a finished poll, the `already_verified_l2` short-circuit).
     */
    private fun verified(memberNumber: Int?, notify: Boolean = true) {
        _state.value = VerificationState.Verified(memberNumber)
        isVerifiedUnconfirmed = false
        uidProvider()?.let { uid -> verifiedCache?.write(VerifiedMemberCache.Entry(uid, memberNumber)) }
        if (notify) onVerified()
    }

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
                // memberNumber now decoded (2026-09-04, scoped re-review
                // finding M-6) - StartL2VerificationResult previously left
                // it null unconditionally even though the backend sends it
                // for exactly this status.
                verified(memberNumber = result.memberNumber)
                return
            }

            val url = result.getProofParamsUrl
            if (url.isNullOrBlank()) {
                fail(MESSAGE_NO_PROOF_PARAMS)
                return
            }
            _state.value = VerificationState.AwaitingProof(url)
        } catch (e: Exception) {
            logError("startL2Verification failed", e)
            fail(terminalFailureMessage(e) ?: MESSAGE_START_FAILED)
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
        fail(message)
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
        synchronized(lock) {
            _state.value = VerificationState.Idle
            isVerifiedUnconfirmed = false
            resetGeneration++
            // The persisted answer describes the departing member too. It is
            // uid-keyed and would never be RESTORED for another uid anyway (see
            // restoreFromCacheIfIdle), but a departed member's uid and number
            // have no business staying on disk.
            verifiedCache?.clear()
        }
    }

    /**
     * Ask the backend, without side effects, whether this member is already
     * verified, and let Home say so.
     *
     * Why this exists: `state` lives in memory only, and `Verified` used to be
     * reachable only through the live flow. So every cold start began at
     * `Idle`, and a member who finished verifying last night found Home back
     * at "Passport checked - Finish verification" the next morning. Called
     * from Home's verify card on every ON_RESUME, which covers both Home
     * appearing and the app returning to the foreground.
     *
     * What it may touch, and what it may not:
     *   - `Idle`, `Failed` and a cache-restored `Verified` only. `Failed` is
     *     terminal - nothing runs behind it - so a server that says "verified"
     *     simply outranks a try that didn't finish.
     *   - Never `Starting`/`AwaitingProof`/`Polling`: a flow in progress owns
     *     its own ending. Nor `NotRegistered`, which only a tap produces.
     *   - Verified: `Verified(memberNumber)`, cached, WITHOUT [onVerified]'s
     *     bell entry.
     *   - Not verified (`not_a_member` included): the cache is dropped, and a
     *     cache-restored `Verified` goes back to `Idle`; `Idle`/`Failed` stay.
     *   - Any error: silent (logged only), state kept.
     *
     * Uses `getMyFounderProfile`, never `startL2Verification`: for anyone not
     * yet l3 the latter CREATES a verification request and resets the verifier
     * row - a side effect no resume may have.
     */
    suspend fun refreshFromServer() {
        restoreFromCacheIfIdle()
        if (!isRefreshable()) return
        val uid = uidProvider() ?: return
        if (!isRefreshing.compareAndSet(false, true)) return
        try {
            val generation = synchronized(lock) { resetGeneration }
            val profile = try {
                fetchFounderProfile()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                logError("getMyFounderProfile failed; keeping the current state", e)
                return
            }
            synchronized(lock) {
                // Anything may have moved during the call: a reset (caught by
                // the generation even if the same uid signed back in), another
                // member signed in (the uid), or a flow the member started by
                // tapping Finish (the state). Any of them makes this answer
                // stale, so it is dropped, not merged.
                if (generation != resetGeneration || uidProvider() != uid || !isRefreshable()) return
                if (profile.isVerifiedPerson) {
                    verified(profile.memberNumber, notify = false)
                } else {
                    verifiedCache?.clear()
                    if (_state.value is VerificationState.Verified && isVerifiedUnconfirmed) {
                        _state.value = VerificationState.Idle
                        isVerifiedUnconfirmed = false
                    }
                }
            }
        } finally {
            isRefreshing.set(false)
        }
    }

    /** The states [refreshFromServer] may overwrite; see there. */
    private fun isRefreshable(): Boolean = when (_state.value) {
        VerificationState.Idle, is VerificationState.Failed -> true
        is VerificationState.Verified -> isVerifiedUnconfirmed
        else -> false
    }

    /**
     * `Idle` -> `Verified` from [verifiedCache], but only when the entry names
     * the uid signed in RIGHT NOW. A mismatch (another member on this device,
     * or no one signed in) restores nothing and leaves the entry alone - only a
     * server answer or [reset] may drop it.
     */
    private fun restoreFromCacheIfIdle() {
        synchronized(lock) {
            if (_state.value != VerificationState.Idle) return
            val entry = verifiedCache?.read() ?: return
            val uid = uidProvider() ?: return
            if (entry.uid != uid) return
            _state.value = VerificationState.Verified(entry.memberNumber)
            isVerifiedUnconfirmed = true
        }
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
                    verified(result.memberNumber)
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
                // member) arrives as a thrown FAILED_PRECONDITION or
                // ALREADY_EXISTS carrying a written-for-humans message - both
                // are terminal, and swallowing either as a retry would discard
                // that message and make the user wait out the full timeout for
                // a generic one instead. See firebaseRejectionMessage below.
                val rejection = terminalFailureMessage(e)
                if (rejection != null) {
                    logError("getL2VerificationStatus rejected", e)
                    if (_state.value !is VerificationState.Polling) return
                    fail(rejection)
                    return
                }
                logError("getL2VerificationStatus failed", e)
            }
            delay(pollIntervalMs)
        }

        if (_state.value !is VerificationState.Polling) return
        fail(MESSAGE_TIMED_OUT)
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
 * "This Firebase uid is a verified person" (and its member number), kept
 * between launches so Home can say so on a cold start before - or without - a
 * network round trip. Mirrors iOS's `VerifiedMemberCache`.
 *
 * A uid and an optional Int; nothing about the passport. It is a display hint,
 * never an authority: [FoundationVerificationManager] restores an entry only
 * for the uid signed in at that moment, drops it on `reset()` (sign-out,
 * account deletion) and the first time the server disagrees, and every
 * Foundation callable re-checks the member server-side regardless.
 */
interface VerifiedMemberCache {
    data class Entry(val uid: String, val memberNumber: Int?)

    fun read(): Entry?
    fun write(entry: Entry)
    fun clear()
}

private class SharedPrefsVerifiedMemberCache(context: Context) : VerifiedMemberCache {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun read(): VerifiedMemberCache.Entry? {
        val uid = prefs.getString(KEY_UID, null)?.takeIf { it.isNotEmpty() } ?: return null
        val memberNumber = if (prefs.contains(KEY_MEMBER_NUMBER)) prefs.getInt(KEY_MEMBER_NUMBER, 0) else null
        return VerifiedMemberCache.Entry(uid, memberNumber)
    }

    override fun write(entry: VerifiedMemberCache.Entry) {
        prefs.edit().apply {
            putString(KEY_UID, entry.uid)
            if (entry.memberNumber == null) remove(KEY_MEMBER_NUMBER) else putInt(KEY_MEMBER_NUMBER, entry.memberNumber)
        }.apply()
    }

    // commit, not apply: account deletion restarts the process right after
    // reset(), and an apply() could still be in flight - the same reason
    // AppNotificationStore's storage commits. Skipped when there is nothing to
    // clear, because an unverified member's every resume lands here.
    override fun clear() {
        if (prefs.all.isEmpty()) return
        prefs.edit().clear().commit()
    }

    companion object {
        private const val PREFS_NAME = "foundation_verified_member"
        private const val KEY_UID = "uid"
        private const val KEY_MEMBER_NUMBER = "memberNumber"
    }
}

/**
 * A `FAILED_PRECONDITION` or `ALREADY_EXISTS` from a Foundation callable is a
 * considered, terminal rejection whose message is written for the user (see
 * `getL2VerificationStatus` / `upsertMemberWithLaneTx` in foundation-next
 * `functions/founders/passport.js`). Everything else - network blips,
 * transient 5xx - is worth another poll.
 *
 * Two distinct codes land here:
 *   - FAILED_PRECONDITION: failed_verification / uniqueness_check_failed
 *     (the svc-side check).
 *   - ALREADY_EXISTS: the lane-doc uniqueness guard (`members.js`'s
 *     `credentialClaimError`) rejecting a duplicate passport - found
 *     2026-09-03 (whole-plan review finding I-2) to be the ONE that
 *     actually fires in practice, because the svc-side check above "went
 *     blind" (see the passport.js comment: every verification-link re-POST
 *     resets verify_users and wipes nullifiers, so uniqueness_check_failed
 *     no longer fires). Before this fix only FAILED_PRECONDITION was
 *     classified terminal, so a real duplicate-passport rejection was
 *     retried 40x over two minutes and reported as a generic timeout
 *     instead of the server's real, specific rejection message.
 *
 * Delegates the actual decision to `terminalRejectionMessage(codeName:)`
 * below rather than comparing `e.code` to the `Code` enum constants
 * directly: `FirebaseFunctionsException.Code`'s static initializer calls
 * into `android.util.SparseArray`, which is unmocked (and this module
 * deliberately does not set `testOptions.unitTests.isReturnDefaultValues`,
 * see `logError`'s doc above) - so simply *referencing* a `Code` constant
 * crashes a plain JVM unit test with "SparseArray.get not mocked" before any
 * test body even runs. Working off `e.code.name` (a stable string on this
 * gRPC canonical-status enum) never touches the enum's companion, so the
 * classification is directly unit-testable without Robolectric or an
 * instrumented test.
 */
internal fun firebaseRejectionMessage(throwable: Throwable): String? {
    val e = throwable as? FirebaseFunctionsException ?: return null
    return terminalRejectionMessage(codeName = e.code.name, message = e.message)
}

/**
 * Pure decision, factored out of [firebaseRejectionMessage] so it is testable
 * without ever class-loading `FirebaseFunctionsException.Code` - see that
 * function's doc for why that class load itself crashes local unit tests.
 */
internal fun terminalRejectionMessage(codeName: String, message: String?): String? {
    if (codeName !in TERMINAL_REJECTION_CODE_NAMES) return null
    return message?.takeIf { it.isNotBlank() }
        ?: FoundationVerificationManager.MESSAGE_PROOF_FAILED
}

/** `.name` of the two terminal [FirebaseFunctionsException.Code] constants. */
internal val TERMINAL_REJECTION_CODE_NAMES = setOf("FAILED_PRECONDITION", "ALREADY_EXISTS")
