package com.rarilabs.rarime.foundation

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FoundationAuthManagerTest {
    @Test
    fun callableNamesMatchTheBackend() {
        // Guards against a typo silently producing NOT_FOUND at runtime.
        assertEquals("requestSignInCode", FoundationCallables.REQUEST_SIGN_IN_CODE)
        assertEquals("verifySignInCode", FoundationCallables.VERIFY_SIGN_IN_CODE)
        assertEquals("issueAttestationNonce", FoundationCallables.ISSUE_ATTESTATION_NONCE)
        assertEquals("recordMobileAttestation", FoundationCallables.RECORD_MOBILE_ATTESTATION)
        assertEquals("startL2Verification", FoundationCallables.START_L2_VERIFICATION)
        assertEquals("getL2VerificationStatus", FoundationCallables.GET_L2_VERIFICATION_STATUS)
        assertEquals("deleteMyAccount", FoundationCallables.DELETE_MY_ACCOUNT)
    }

    @Test
    fun functionsRegionMatchesDeployment() {
        // Every Foundation callable is deployed to us-east1. A default-region
        // client silently hits us-central1 and 404s.
        assertEquals("us-east1", FoundationCallables.REGION)
    }

    @Test
    fun signedOutStateHasNoUid() = runTest {
        val manager = FoundationAuthManager.forTesting()
        manager.signOut()
        assertNull(manager.uid.value)
    }
}
