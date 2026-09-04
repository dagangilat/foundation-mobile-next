package com.rarilabs.rarime.foundation.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Scoped re-review finding M-5: `verifySignInCode` throws `failed-precondition`
 * with a real, per-reason message ("Sign-in code expired...", "Wrong code.
 * N attempts left.", etc. - see foundation-next `functions/index.js`). This
 * pins that [signInErrorMessage] actually surfaces it instead of discarding
 * it for the generic fallback string every catch block used to show
 * regardless of the real reason.
 */
class SignInErrorMessageTest {
    private val fallback = "Generic fallback."

    @Test
    fun surfacesTheRealMessageForAFailedPrecondition() {
        assertEquals(
            "Sign-in code expired. Request a new one.",
            signInErrorMessage(
                codeName = "FAILED_PRECONDITION",
                message = "Sign-in code expired. Request a new one.",
                fallback = fallback,
            ),
        )
    }

    @Test
    fun fallsBackToTheGenericMessageForAnUnrelatedCode() {
        // e.g. UNAVAILABLE (transient network) - not a considered rejection,
        // the real message (if any) isn't written for the user.
        assertEquals(
            fallback,
            signInErrorMessage(codeName = "UNAVAILABLE", message = "network blip", fallback = fallback),
        )
    }

    @Test
    fun fallsBackWhenTheFailedPreconditionHasNoMessage() {
        assertEquals(
            fallback,
            signInErrorMessage(codeName = "FAILED_PRECONDITION", message = null, fallback = fallback),
        )
    }

    @Test
    fun fallsBackWhenTheFailedPreconditionMessageIsBlank() {
        assertEquals(
            fallback,
            signInErrorMessage(codeName = "FAILED_PRECONDITION", message = "   ", fallback = fallback),
        )
    }
}
