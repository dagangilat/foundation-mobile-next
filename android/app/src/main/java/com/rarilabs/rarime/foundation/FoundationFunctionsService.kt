package com.rarilabs.rarime.foundation

import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Names and region of Foundation's Cloud Functions. Kept as constants so a
 * unit test can assert them without a network call - a typo here surfaces as
 * a runtime NOT_FOUND, which is expensive to diagnose on device.
 */
object FoundationCallables {
    const val REGION = "us-east1"
    const val REQUEST_SIGN_IN_CODE = "requestSignInCode"
    const val VERIFY_SIGN_IN_CODE = "verifySignInCode"
    const val ISSUE_ATTESTATION_NONCE = "issueAttestationNonce"
    const val RECORD_MOBILE_ATTESTATION = "recordMobileAttestation"
    const val START_L2_VERIFICATION = "startL2Verification"
    const val GET_L2_VERIFICATION_STATUS = "getL2VerificationStatus"
}

data class SignInCodeResult(val status: String, val sent: Boolean)
data class VerifyCodeResult(val customToken: String, val uid: String)
data class AttestationNonce(val nonce: String, val expiresAtMs: Long)
data class RecordAttestationResult(val accepted: Boolean, val credentialId: String?)
data class StartL2VerificationResult(
    val status: String,
    /** Ignored on purpose - see AD-2. Decoded so the shape stays honest. */
    val deepLink: String?,
    val getProofParamsUrl: String?,
)
data class L2VerificationStatusResult(val status: String, val memberNumber: Int?)

@Singleton
class FoundationFunctionsService @Inject constructor() {

    private val functions: FirebaseFunctions
        get() = FirebaseFunctions.getInstance(FoundationCallables.REGION)

    private suspend fun call(name: String, data: Map<String, Any?>): Map<*, *> {
        val result = functions.getHttpsCallable(name).call(data).await()
        // getData(), not the `.data` synthetic property: HttpsCallableResult
        // also has a private field named `data`, which shadows the accessor.
        @Suppress("UsePropertyAccessSyntax")
        return result.getData() as? Map<*, *> ?: emptyMap<String, Any?>()
    }

    suspend fun requestSignInCode(email: String): SignInCodeResult {
        val d = call(FoundationCallables.REQUEST_SIGN_IN_CODE, mapOf("email" to email))
        return SignInCodeResult(
            status = d["status"] as? String ?: "",
            sent = d["sent"] as? Boolean ?: false,
        )
    }

    suspend fun verifySignInCode(email: String, code: String): VerifyCodeResult {
        val d = call(
            FoundationCallables.VERIFY_SIGN_IN_CODE,
            mapOf("email" to email, "code" to code),
        )
        return VerifyCodeResult(
            customToken = d["customToken"] as? String
                ?: error("verifySignInCode returned no customToken"),
            uid = d["uid"] as? String ?: "",
        )
    }

    suspend fun issueAttestationNonce(): AttestationNonce {
        val d = call(FoundationCallables.ISSUE_ATTESTATION_NONCE, emptyMap())
        return AttestationNonce(
            nonce = d["nonce"] as? String ?: error("no nonce"),
            expiresAtMs = (d["expiresAtMs"] as? Number)?.toLong() ?: 0L,
        )
    }

    /**
     * Android attestation wire shape, per @plantagoai/attestation's
     * RecordAttestationRequest: { platform: 'android', token }.
     */
    suspend fun recordMobileAttestation(nonce: String, token: String): RecordAttestationResult {
        val d = call(
            FoundationCallables.RECORD_MOBILE_ATTESTATION,
            mapOf(
                "nonce" to nonce,
                "attestation" to mapOf("platform" to "android", "token" to token),
            ),
        )
        return RecordAttestationResult(
            accepted = d["accepted"] as? Boolean ?: false,
            credentialId = d["credentialId"] as? String,
        )
    }

    suspend fun startL2Verification(): StartL2VerificationResult {
        val d = call(FoundationCallables.START_L2_VERIFICATION, emptyMap())
        return StartL2VerificationResult(
            status = d["status"] as? String ?: "",
            deepLink = d["deepLink"] as? String,
            getProofParamsUrl = d["getProofParamsUrl"] as? String,
        )
    }

    suspend fun getL2VerificationStatus(): L2VerificationStatusResult {
        val d = call(FoundationCallables.GET_L2_VERIFICATION_STATUS, emptyMap())
        return L2VerificationStatusResult(
            status = d["status"] as? String ?: "",
            memberNumber = (d["memberNumber"] as? Number)?.toInt(),
        )
    }
}
