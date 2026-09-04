package com.rarilabs.rarime.foundation

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Android's counterpart to iOS App Attest. Rarimo's apps ship no platform
 * attestation (spec section 3); this is added work, not inherited.
 *
 * The server side is NOT ready: @plantagoai/attestation's verifyPlayIntegrity
 * (shared/packages/attestation/src/server.ts) is an unimplemented stub that
 * throws - recordMobileAttestation maps that to HttpsError("unimplemented"),
 * so a call from here today always fails server-side. Confirmed live via
 * the mobile-fork-rebrand plan's final review (finding I-4, 2026-09-04) -
 * this class's own client-side logic is correct and complete; the gap is
 * entirely server-side, blocked on real Play Console app registration this
 * fork doesn't have yet. See progress.md's I-4 ruling for the full context.
 * The call below is written correctly and will start working once that
 * backend lands - nothing here needs to change for that.
 */
@Singleton
class PlayIntegrityService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val functionsService: FoundationFunctionsService,
) {
    /**
     * Requests an integrity verdict bound to the server-issued nonce, then
     * posts it. The nonce binds the verdict to this one request, which is what
     * stops a captured verdict being replayed.
     */
    suspend fun attestDeviceEndToEnd(): RecordAttestationResult {
        val nonce = functionsService.issueAttestationNonce()
        val token = requestToken(nonce.nonce)
        return functionsService.recordMobileAttestation(nonce.nonce, token)
    }

    suspend fun requestToken(nonce: String): String {
        val prepared = prepareNonce(nonce)
        val manager = IntegrityManagerFactory.create(context)
        val response = manager
            .requestIntegrityToken(
                IntegrityTokenRequest.builder().setNonce(prepared).build()
            )
            .await()
        return response.token()
    }

    companion object {
        /**
         * The server emits base64url-encoded nonces already, so we pass them
         * through unchanged - re-encoding would break the binding the server
         * checks. Validation only.
         */
        fun prepareNonce(nonce: String): String {
            require(nonce.isNotEmpty()) { "nonce must not be empty" }
            require(nonce.length in 16..500) {
                "Play Integrity requires a 16..500 character nonce, got ${nonce.length}"
            }
            require(nonce.all { it.isLetterOrDigit() || it == '-' || it == '_' || it == '=' }) {
                "nonce must be URL-safe base64"
            }
            return nonce
        }
    }
}
