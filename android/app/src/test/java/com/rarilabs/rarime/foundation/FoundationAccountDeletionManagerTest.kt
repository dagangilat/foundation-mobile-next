package com.rarilabs.rarime.foundation

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The regression tests for finding I-1.
 *
 * Two things are proven here, and the second is the whole point of the fix:
 *
 *  1. [deleteAccountResultOrThrow] decodes the callable's real reply shape
 *     tolerantly, and treats `dryRun: true` - the server saying it deleted
 *     nothing - as a failure.
 *  2. [FoundationAccountDeletionManager] never lets a local mutation happen
 *     before the server has confirmed the delete. `deleteMyAccount` is
 *     `requireAuth`-gated, so signing out first would make every invocation
 *     fail `unauthenticated` and delete nothing - which is materially what
 *     Android shipped before this change.
 *
 * Everything is a lambda, so these run as plain JVM tests: no Firebase, no
 * Android framework, no Robolectric.
 */
class FoundationAccountDeletionManagerTest {

    // ── deleteAccountResultOrThrow ──────────────────────────────────────────

    /**
     * The real `DeletionResult` from `@plantagoai/auth`'s `deleteAccount()`,
     * as `deleteMyAccount` returns it verbatim. Numbers arrive from the
     * Firebase callable SDK as boxed JSON numbers, hence the `Number` reads in
     * the decoder; `collections` and `external` are present on the wire and
     * deliberately not modelled.
     */
    private fun realisticSuccessBody(): Map<String, Any?> = mapOf(
        "userId" to "uid-1",
        "deletedDocs" to 7.0,
        "anonymizedDocs" to 2.0,
        "retainedDocs" to 0.0,
        "authDeleted" to true,
        "collections" to mapOf("users" to mapOf("mode" to "delete", "count" to 1.0)),
        "external" to listOf("solana"),
        "completedAt" to "2026-09-03T10:00:00.000Z",
        "dryRun" to false,
    )

    @Test
    fun decodesARealisticSuccessResponse() {
        val result = deleteAccountResultOrThrow(realisticSuccessBody())
        assertEquals("uid-1", result.userId)
        assertEquals(7, result.deletedDocs)
        assertEquals(2, result.anonymizedDocs)
        assertEquals(0, result.retainedDocs)
        assertEquals(true, result.authDeleted)
        assertEquals("2026-09-03T10:00:00.000Z", result.completedAt)
        assertEquals(false, result.dryRun)
    }

    @Test
    fun aDryRunReplyIsAFailureNotASuccess() {
        // The one reply that means "the server answered 200 and deleted
        // nothing". Treating it as success would unlock the local erase.
        val body = realisticSuccessBody() + ("dryRun" to true)
        assertThrows(AccountDeletionNotPerformedException::class.java) {
            deleteAccountResultOrThrow(body)
        }
    }

    @Test
    fun anUnrecognisableBodyDecodesRatherThanThrowing() {
        // By the time this runs the server has already performed an
        // irreversible hard delete. A decode that threw on a missing or
        // renamed field would report a SUCCESSFUL deletion as a failure and
        // strand the member signed in to an account that no longer exists.
        val result = deleteAccountResultOrThrow(emptyMap<String, Any?>())
        assertNull(result.userId)
        assertNull(result.deletedDocs)
        assertNull(result.dryRun)

        val fromNull = deleteAccountResultOrThrow(null)
        assertNull(fromNull.deletedDocs)

        val wrongTypes = deleteAccountResultOrThrow(
            mapOf("userId" to 42, "deletedDocs" to "lots", "dryRun" to "yes"),
        )
        assertNull(wrongTypes.userId)
        assertNull(wrongTypes.deletedDocs)
        // A non-boolean dryRun is NOT read as true - only an explicit `true`
        // blocks the delete.
        assertNull(wrongTypes.dryRun)
    }

    @Test
    fun callableNameMatchesTheBackend() {
        assertEquals("deleteMyAccount", FoundationCallables.DELETE_MY_ACCOUNT)
    }

    // ── the ordering invariant ──────────────────────────────────────────────

    private fun manager(
        calls: MutableList<String>,
        delete: suspend () -> DeleteAccountResult = {
            calls += "deleteMyAccount"
            DeleteAccountResult(userId = "uid-1", deletedDocs = 7)
        },
    ) = FoundationAccountDeletionManager(
        deleteMyAccount = delete,
        signOut = { calls += "signOut" },
        resetVerification = { calls += "resetVerification" },
    )

    @Test
    fun onSuccessTheServerCallRunsFirstAndEveryLocalStepFollows() = runTest {
        val calls = mutableListOf<String>()
        val outcome = manager(calls).deleteAccount { calls += "eraseLocalState" }

        // The order IS the fix. deleteMyAccount is requireAuth-gated: any
        // sign-out ahead of it makes it fail `unauthenticated` and delete
        // nothing at all.
        assertEquals(
            listOf("deleteMyAccount", "signOut", "resetVerification", "eraseLocalState"),
            calls,
        )
        assertTrue(outcome is DeletionOutcome.Deleted)
        assertEquals(7, (outcome as DeletionOutcome.Deleted).result.deletedDocs)
    }

    @Test
    fun aFailedServerCallLeavesEverythingLocalUntouched() = runTest {
        val calls = mutableListOf<String>()
        val m = manager(calls) {
            calls += "deleteMyAccount"
            throw IllegalStateException("unauthenticated")
        }

        val outcome = m.deleteAccount { calls += "eraseLocalState" }

        // The state that must never exist is a device that believes the
        // account is gone while the server still holds the data. So: no
        // sign-out, no verification reset, no local erase - and an error the
        // user can actually see.
        assertEquals(listOf("deleteMyAccount"), calls)
        assertEquals(emptyList<String>(), calls.drop(1))
        assertTrue(outcome is DeletionOutcome.Failed)
        assertEquals(
            FoundationAccountDeletionManager.MESSAGE_DELETE_FAILED,
            (outcome as DeletionOutcome.Failed).message,
        )
    }

    @Test
    fun aDryRunReplyAlsoLeavesEverythingLocalUntouched() = runTest {
        // Same invariant, reached through the other failure door: the call
        // itself succeeded, but the server said it deleted nothing.
        val calls = mutableListOf<String>()
        val m = manager(calls) {
            calls += "deleteMyAccount"
            deleteAccountResultOrThrow(mapOf("userId" to "uid-1", "dryRun" to true))
        }

        val outcome = m.deleteAccount { calls += "eraseLocalState" }

        assertEquals(listOf("deleteMyAccount"), calls)
        assertTrue(outcome is DeletionOutcome.Failed)
    }

    @Test
    fun cancellationBeforeTheServerAnswersIsNotReportedAsAFailure() = runTest {
        val calls = mutableListOf<String>()
        val m = manager(calls) {
            calls += "deleteMyAccount"
            throw CancellationException("caller went away")
        }

        assertThrows(CancellationException::class.java) {
            kotlinx.coroutines.runBlocking { m.deleteAccount { calls += "eraseLocalState" } }
        }
        // Nothing local happened, and cancellation stays cooperative rather
        // than surfacing to the user as "couldn't delete your account".
        assertEquals(listOf("deleteMyAccount"), calls)
    }

    @Test
    fun theLocalHalfCompletesEvenWhenTheCallerIsCancelledMidErase() = runTest {
        // Once the server has deleted the account, the local half MUST finish
        // even if the Profile screen is popped off the back stack. A
        // cancellation landing here would leave exactly the forbidden state:
        // account gone server-side, device still signed in holding the
        // departed member's local identity. Hence NonCancellable.
        val calls = mutableListOf<String>()
        val eraseStarted = CompletableDeferred<Unit>()
        val m = manager(calls)

        val job = launch {
            m.deleteAccount {
                calls += "eraseLocalState:start"
                eraseStarted.complete(Unit)
                // Stands in for the real erase's ~1s restart grace period,
                // which is when a cancellation would realistically land.
                delay(1_000L)
                calls += "eraseLocalState:finish"
            }
        }

        eraseStarted.await()
        job.cancel()
        job.join()

        assertEquals(
            listOf(
                "deleteMyAccount",
                "signOut",
                "resetVerification",
                "eraseLocalState:start",
                "eraseLocalState:finish",
            ),
            calls,
        )
    }
}
