package com.rarilabs.rarime.foundation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlayIntegrityServiceTest {
    @Test
    fun nonceIsUrlSafeBase64AsPlayIntegrityRequires() {
        // Play Integrity requires the requestHash/nonce to be URL-safe base64,
        // 16..500 bytes. The server emits base64url nonces already; this
        // asserts we do not re-encode and break that.
        val nonce = "abcDEF-123_xyz456789"
        val prepared = PlayIntegrityService.prepareNonce(nonce)
        assertEquals(nonce, prepared)
        assertTrue(prepared.all { it.isLetterOrDigit() || it == '-' || it == '_' || it == '=' })
        assertTrue(prepared.length in 16..500)
    }

    @Test
    fun rejectsAnEmptyNonce() {
        try {
            PlayIntegrityService.prepareNonce("")
            throw AssertionError("expected an IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            // expected
        }
    }
}
