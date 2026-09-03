package com.rarilabs.rarime.foundation

import com.rarilabs.rarime.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AppIdentityTest {
    @Test
    fun applicationIdIsFoundations() {
        assertEquals("com.foundationnext.mobile", BuildConfig.APPLICATION_ID)
    }

    @Test
    fun applicationIdIsNotRarimos() {
        assertFalse(BuildConfig.APPLICATION_ID.contains("rarilabs"))
        assertFalse(BuildConfig.APPLICATION_ID.contains("rarime"))
    }
}
