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
    const val DELETE_MY_ACCOUNT = "deleteMyAccount"
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
    /**
     * Set only on the `already_verified_l2` short-circuit (`passport.js:129`
     * returns `{ status, memberNumber }` for that case specifically) - null
     * on every other status. Added 2026-09-04 (scoped re-review finding
     * M-6): this field previously wasn't decoded at all, so an already-verified
     * member saw no member number, even though the server sent one.
     */
    val memberNumber: Int?,
)
data class L2VerificationStatusResult(val status: String, val memberNumber: Int?)

/**
 * `deleteMyAccount`'s real reply shape. Mirrors iOS's `DeleteAccountResult`.
 *
 * The callable (foundation-next `functions/account-deletion.js`) returns
 * whatever `deleteAccount(uid, foundationDataMap, …)` from `@plantagoai/auth`
 * returns, i.e. that package's `DeletionResult`:
 * `{ userId, deletedDocs, anonymizedDocs, retainedDocs, authDeleted,
 *    collections, external, completedAt, dryRun }`.
 *
 * Two of those are deliberately NOT modelled. `collections` is a per-collection
 * `Record<string, { mode, count }>` and `external` a list of provider names -
 * server-side bookkeeping this client has no use for, and modelling them would
 * only create a shape to drift out of sync with.
 *
 * Everything that IS modelled is nullable, and that is a correctness decision
 * rather than defensiveness: by the time this is built the server has already
 * performed an irreversible hard delete, so a decode that threw on an
 * added/renamed/missing field would report a *successful* deletion as a failure
 * and strand the member signed in to an account that no longer exists.
 */
data class DeleteAccountResult(
    val userId: String? = null,
    val deletedDocs: Int? = null,
    val anonymizedDocs: Int? = null,
    val retainedDocs: Int? = null,
    /**
     * Informational only - never gate on it. `deleteAccount()` swallows
     * "user not found" from `auth.deleteUser` and reports `false`, which is
     * exactly what a re-run against an already-deleted account produces.
     */
    val authDeleted: Boolean? = null,
    val completedAt: String? = null,
    /**
     * The live callable never passes `dryRun`, so this is `false` or absent in
     * practice. It is read anyway because `dryRun: true` is the one reply that
     * means "the server reported success and deleted nothing" - the single case
     * where a 200 must not unlock the local erase.
     */
    val dryRun: Boolean? = null,
)

/** The server answered, but said it did not actually delete anything. */
class AccountDeletionNotPerformedException :
    Exception("deleteMyAccount returned dryRun: nothing was deleted")

/**
 * The whole `deleteMyAccount` contract minus the network call, as a pure
 * function so it is unit-testable without Firebase - the same reason
 * `firebaseRejectionMessage` sits outside `FoundationVerificationManager`.
 *
 * Past the callable returning, the server has already run the deletion, so
 * nothing about the *shape* of its answer may be turned into a failure: every
 * field is read tolerantly and an unrecognisable body decodes to all-nulls.
 * The one exception - and the only reason `dryRun` is decoded at all - is the
 * server explicitly reporting that it deleted nothing.
 */
internal fun deleteAccountResultOrThrow(data: Map<*, *>?): DeleteAccountResult {
    val d = data ?: emptyMap<String, Any?>()
    val decoded = DeleteAccountResult(
        userId = d["userId"] as? String,
        deletedDocs = (d["deletedDocs"] as? Number)?.toInt(),
        anonymizedDocs = (d["anonymizedDocs"] as? Number)?.toInt(),
        retainedDocs = (d["retainedDocs"] as? Number)?.toInt(),
        authDeleted = d["authDeleted"] as? Boolean,
        completedAt = d["completedAt"] as? String,
        dryRun = d["dryRun"] as? Boolean,
    )
    if (decoded.dryRun == true) throw AccountDeletionNotPerformedException()
    return decoded
}

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
            memberNumber = (d["memberNumber"] as? Number)?.toInt(),
        )
    }

    /**
     * Hard-delete this member's account, server-side.
     *
     * The callable is `requireAuth`-gated, so this only ever works while the
     * Firebase session is live: callers MUST invoke it BEFORE signing out.
     * See [FoundationAccountDeletionManager], which owns that ordering.
     *
     * Throws only when the deletion genuinely did not happen: a transport /
     * auth / server error out of `call()`, or a `dryRun` reply. A malformed or
     * unexpected response body does NOT throw - see [DeleteAccountResult].
     */
    suspend fun deleteMyAccount(): DeleteAccountResult =
        deleteAccountResultOrThrow(call(FoundationCallables.DELETE_MY_ACCOUNT, emptyMap()))

    suspend fun getL2VerificationStatus(): L2VerificationStatusResult {
        val d = call(FoundationCallables.GET_L2_VERIFICATION_STATUS, emptyMap())
        return L2VerificationStatusResult(
            status = d["status"] as? String ?: "",
            memberNumber = (d["memberNumber"] as? Number)?.toInt(),
        )
    }
}
