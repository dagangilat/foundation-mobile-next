package com.rarilabs.rarime.foundation

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [AppNotificationStore]: the list behind Home's bell. Plain JVM tests: the
 * storage is an in-memory string, the clock and ids are counters.
 */
class AppNotificationStoreTest {

    private class MemoryStorage(var json: String? = null) : AppNotificationStorage {
        override fun read(): String? = json
        override fun write(json: String?) {
            this.json = json
        }
    }

    private var now = 1_000L
    private var nextId = 0

    private fun store(storage: AppNotificationStorage = MemoryStorage()) = AppNotificationStore(
        storage = storage,
        clock = { now++ },
        newId = { "id-${nextId++}" },
    )

    @Test
    fun startsEmpty() {
        val s = store()
        assertTrue(s.entries.value.isEmpty())
        assertFalse(s.entries.value.hasUnreadErrors)
    }

    @Test
    fun newestFirstAndUnread() {
        val s = store()
        s.postError("first")
        s.postPassportChecked()
        s.postVerificationFailure("chip read failed", AppNotification.Retry.SCAN_PASSPORT)

        val entries = s.entries.value
        assertEquals(
            listOf(
                AppNotification.Type.VERIFICATION_FAILED,
                AppNotification.Type.PASSPORT_CHECKED,
                AppNotification.Type.ERROR,
            ),
            entries.map { it.type },
        )
        assertTrue(entries.all { !it.isRead })
        assertEquals(AppNotification.Retry.SCAN_PASSPORT, entries.first().retry)
        assertTrue(entries.hasUnreadErrors)
        assertTrue(entries.hasUnreadVerificationFailure)
    }

    @Test
    fun onlyUnreadErrorsLightTheDot() {
        val s = store()
        s.postPassportChecked()
        s.postVerified()
        assertFalse(s.entries.value.hasUnreadErrors)
        assertFalse(s.entries.value.hasUnreadVerificationFailure)
    }

    @Test
    fun markAllReadClearsTheDotButKeepsEntries() {
        val s = store()
        s.postError("boom")
        s.postVerificationFailure("timed out", AppNotification.Retry.FINISH_VERIFICATION)
        s.markAllRead()

        assertEquals(2, s.entries.value.size)
        assertTrue(s.entries.value.all { it.isRead })
        assertFalse(s.entries.value.hasUnreadErrors)
        assertFalse(s.entries.value.hasUnreadVerificationFailure)
    }

    @Test
    fun sameUnreadEntryMovesUpInsteadOfStacking() {
        val s = store()
        s.postError("offline")
        s.postPassportChecked()
        s.postError("offline")

        val entries = s.entries.value
        assertEquals(2, entries.size)
        assertEquals(AppNotification.Type.ERROR, entries.first().type)
        assertEquals("id-0", entries.first().id)
    }

    @Test
    fun sameEntryAfterReadingIsNew() {
        val s = store()
        s.postError("offline")
        s.markAllRead()
        s.postError("offline")

        val entries = s.entries.value
        assertEquals(2, entries.size)
        assertFalse(entries.first().isRead)
        assertTrue(entries.last().isRead)
    }

    @Test
    fun cappedAtFiftyDroppingTheOldest() {
        val s = store()
        repeat(AppNotificationStore.MAX_ENTRIES + 5) { s.postError("error $it") }

        val entries = s.entries.value
        assertEquals(AppNotificationStore.MAX_ENTRIES, entries.size)
        assertEquals("error 54", entries.first().message)
        assertEquals("error 5", entries.last().message)
    }

    @Test
    fun longMessagesAreCut() {
        val s = store()
        s.postError("x".repeat(2_000))
        assertTrue(s.entries.value.first().message.length <= 601)
    }

    @Test
    fun survivesARelaunch() {
        val storage = MemoryStorage()
        val first = store(storage)
        first.postVerificationFailure("uniqueness check failed", AppNotification.Retry.FINISH_VERIFICATION)
        first.postPassportChecked()
        first.markAllRead()
        first.postError("offline")

        val relaunched = store(storage)
        assertEquals(first.entries.value, relaunched.entries.value)
    }

    @Test
    fun clearEmptiesTheListAndStorage() {
        val storage = MemoryStorage()
        val s = store(storage)
        s.postError("boom")
        s.clear()

        assertTrue(s.entries.value.isEmpty())
        assertNull(storage.json)
        assertTrue(store(storage).entries.value.isEmpty())
    }

    @Test
    fun unreadableStorageStartsEmpty() {
        assertTrue(store(MemoryStorage("not json")).entries.value.isEmpty())
        assertTrue(store(MemoryStorage("[{\"id\":\"a\",\"type\":\"NOT_A_TYPE\"}]")).entries.value.isEmpty())
    }

    @Test
    fun verificationManagerReportsFailuresAndSuccess() = runTest {
        val failures = mutableListOf<String>()
        var verified = 0
        val failing = FoundationVerificationManager(
            startL2Verification = { throw IllegalStateException("offline") },
            fetchL2VerificationStatus = { L2VerificationStatusResult("pending", null) },
            uidProvider = { "uid-1" },
            registrationProofProvider = { Any() },
            terminalFailureMessage = { null },
            onFailed = { failures += it },
            onVerified = { verified++ },
        )
        failing.beginVerification()
        assertEquals(listOf(FoundationVerificationManager.MESSAGE_START_FAILED), failures)
        assertEquals(0, verified)

        val already = FoundationVerificationManager(
            startL2Verification = {
                StartL2VerificationResult(
                    FoundationVerificationManager.STATUS_ALREADY_VERIFIED, null, null, 7,
                )
            },
            fetchL2VerificationStatus = { L2VerificationStatusResult("pending", null) },
            uidProvider = { "uid-1" },
            registrationProofProvider = { Any() },
            onFailed = { failures += it },
            onVerified = { verified++ },
        )
        already.beginVerification()
        assertEquals(1, verified)
        assertEquals(1, failures.size)
    }
}
