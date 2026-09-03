package com.rarilabs.rarime.foundation

import com.rarilabs.rarime.util.ErrorHandler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/** What [FoundationAccountDeletionManager.deleteAccount] decided. */
sealed interface DeletionOutcome {
    /** The server confirmed the delete and every local step has run. */
    data class Deleted(val result: DeleteAccountResult) : DeletionOutcome

    /** Nothing was touched locally. [message] is written for the user. */
    data class Failed(val message: String) : DeletionOutcome
}

/**
 * "Delete account", in the only order that can be correct.
 *
 * Mirrors iOS's `ProfileView.deleteAccount()` / `eraseLocalAccountState()`
 * (Tasks B11+B12). It exists as its own class rather than as a method on
 * `ProfileViewModel` for one reason: the ordering below is the entire fix, and
 * a `@HiltViewModel` that pulls in `DriveBackupManager`, `PassportManager` and
 * an Android `Context` cannot be constructed in a plain JVM unit test. Every
 * collaborator here is a lambda, exactly like [FoundationVerificationManager],
 * so `deleteAccountRunsBeforeSignOut` is a real assertion rather than a hope.
 *
 * ### The invariant
 *
 * `deleteMyAccount` is `requireAuth`-gated server-side, so it has to run while
 * the Firebase session is still live: calling it after [signOut] would fail
 * `unauthenticated` on every single invocation and delete nothing at all.
 *
 * Before this class existed, Android's "Delete profile" did not call it at all.
 * It cleared `SecureSharedPrefsManager`, dropped the notification table and
 * restarted the process - and because that returns the app to onboarding, the
 * UI looked like the deletion had worked. The Firebase session survived
 * untouched. The next person to set the device up would scan their own
 * passport, tap Verify, and have `startL2Verification` answer
 * `already_verified_l2` for the PREVIOUS member's still-signed-in uid -
 * verified without a single check of their own, while the server still held
 * every byte the dialog promised to erase.
 *
 * So every local mutation is gated behind the server answering. If the call
 * throws we keep the Firebase session, keep the verification state, keep every
 * stored preference, and say so. The state that must never exist is the
 * opposite one: a device that believes the account is gone while the server
 * still holds the data.
 */
@Singleton
class FoundationAccountDeletionManager internal constructor(
    private val deleteMyAccount: suspend () -> DeleteAccountResult,
    private val signOut: () -> Unit,
    private val resetVerification: () -> Unit,
    /**
     * Indirection for the same reason as [FoundationVerificationManager]'s:
     * `ErrorHandler.logError` calls `android.util.Log`, which throws
     * "not mocked" in a plain JVM unit test. The default no-ops so the failure
     * path - the one most worth testing - stays reachable off-device.
     */
    private val logError: (String, Throwable?) -> Unit = { _, _ -> },
) {
    @Inject
    constructor(
        functionsService: FoundationFunctionsService,
        authManager: FoundationAuthManager,
        verificationManager: FoundationVerificationManager,
    ) : this(
        deleteMyAccount = { functionsService.deleteMyAccount() },
        signOut = { authManager.signOut() },
        resetVerification = { verificationManager.reset() },
        logError = { message, throwable -> ErrorHandler.logError(TAG, message, throwable) },
    )

    /**
     * @param eraseLocalState the caller's local wipe - on Android that is
     *   `SecureSharedPrefsManager.clearAllData()`, the notification table, and
     *   the process restart. Passed in rather than injected because it needs an
     *   Android `Context`; taken as a parameter rather than run by the caller
     *   afterwards so that the "only after the server confirmed" gate lives
     *   here, under test, instead of in a ViewModel that cannot be tested.
     *   It never runs on the failure path.
     */
    suspend fun deleteAccount(eraseLocalState: suspend () -> Unit): DeletionOutcome {
        val result = try {
            deleteMyAccount()
        } catch (e: CancellationException) {
            // The caller's scope died before the server answered. Nothing local
            // has been touched, and this is not a backend error - rethrow so
            // cancellation stays cooperative rather than surfacing to the user
            // as a failed deletion.
            throw e
        } catch (e: Exception) {
            logError("deleteMyAccount failed", e)
            return DeletionOutcome.Failed(MESSAGE_DELETE_FAILED)
        }

        // Past this line the server has already deleted the account, so the
        // local half MUST complete even if the caller's scope is torn down
        // (Profile popped off the back stack, activity finished). A
        // cancellation landing here would leave precisely the forbidden state:
        // account gone server-side, device still signed in with the departed
        // member's local identity intact. iOS gets this for free - its `Task {}`
        // is unstructured and outlives the view - Android does not.
        withContext(NonCancellable) {
            // The Foundation member identity goes FIRST among the local steps,
            // and before `eraseLocalState`'s own restart delay:
            // `FirebaseAuth.signOut()` persists through `SharedPreferences`
            // (its own file, separate from this app's - which is why
            // `SecureSharedPrefsManagerImpl.clearAllData()` cannot reach it and
            // does not need to), and `Runtime.exit(0)` does not drain
            // `QueuedWork`. The ~1s grace period inside `eraseLocalState` is
            // the only margin that write gets.
            signOut()
            // Drops any `Verified`/in-flight state that described the departing
            // member, so the next person on this device cannot inherit it.
            resetVerification()
            eraseLocalState()
        }

        return DeletionOutcome.Deleted(result)
    }

    companion object {
        private const val TAG = "FoundationAccountDeletion"

        /**
         * Deliberately NOT "nothing was changed": the callable drops the Solana
         * wallet, the Storage objects and the path-keyed docs before the
         * data-map sweep runs, so a throw can leave a partially deleted account
         * server-side. Retrying is the right advice - every one of those helpers
         * tolerates already-missing data - but promising an untouched server
         * would be a lie. Copy matches iOS verbatim.
         */
        const val MESSAGE_DELETE_FAILED = "Couldn't delete your account. Please try again."
    }
}
