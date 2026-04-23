package com.foundationmobile.attestation

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest

/**
 * Play Integrity native module.
 *
 * Phase 1 of the mobile flow. Android counterpart to iOS App Attest —
 * proves the request comes from a genuine, unmodified build of our app
 * installed from Play, running on a trustworthy device. Blocks the
 * deepfake camera-injection attack class that OSS liveness pipelines
 * can't defeat on their own.
 *
 * Backend verifies the returned token against Google's public keys
 * (verdict JWS) and binds it to the server-issued nonce.
 */
class PlayIntegrityModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = NAME

  @ReactMethod
  fun isSupported(promise: Promise) {
    // Play Integrity is available on any device with Play Services >= 19.x.
    // We don't probe here — the actual token request surfaces a clear error
    // if the device is missing Play Services.
    promise.resolve(true)
  }

  @ReactMethod
  fun requestIntegrityToken(nonce: String, promise: Promise) {
    val manager = IntegrityManagerFactory.create(reactApplicationContext)
    manager.requestIntegrityToken(
      IntegrityTokenRequest.builder()
        .setNonce(nonce)
        .build()
    )
      .addOnSuccessListener { response -> promise.resolve(response.token()) }
      .addOnFailureListener { ex ->
        promise.reject("E_INTEGRITY", ex.message, ex)
      }
  }

  companion object {
    const val NAME = "PlayIntegrityModule"
  }
}
