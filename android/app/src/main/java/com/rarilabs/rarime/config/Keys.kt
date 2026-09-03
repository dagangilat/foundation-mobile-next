package com.rarilabs.rarime.config

import com.rarilabs.rarime.BuildConfig

/**
 * Reconstruction of the file upstream gitignores
 * (`/app/src/main/java/com/rarilabs/rarime/config/`), without which
 * `rarime-android-app` does not compile. Every member here is read somewhere in
 * BaseConfig.kt, PointsManager.kt or PointsToken.kt.
 *
 * Values are Foundation's, not Rarimo's. Four are deliberately empty because
 * the features that consume them are stripped in Task C5:
 *   - APPSFLYER_DEV_KEY   -> AppsFlyer removed; a non-empty value here would
 *                            attribute our installs to Rarimo's account.
 *   - genesisReferralCode -> the referral/Earn programme is removed.
 *   - joinProgram         -> the RMO rewards HMAC key; rewards are removed.
 *   - lightVerificationSKHex -> the light-verification lane is removed.
 *
 * NEVER paste Rarimo's values in from their iOS xcconfig. This repository is
 * public and those are their keys.
 *
 * Note: this is `com.rarilabs.rarime.config.Keys`. It is unrelated to
 * `org.web3j.crypto.Keys`, which RarimoContractManager/StableCoinContractManager
 * import explicitly for `createEcKeyPair()`.
 */
object Keys {
    /** AppsFlyer attribution. Stripped in Task C5 - empty makes it a no-op. */
    const val APPSFLYER_DEV_KEY: String = ""

    /**
     * Play Store application id, surfaced through `IConfig.APP_ID_FIREBASE`.
     * Nothing in the current tree reads `APP_ID_FIREBASE` (it is assigned in
     * BaseConfig.kt and never consumed), so this value is inert today; it is
     * set to the fork's intended applicationId, which Task C2 will also apply
     * to `android.defaultConfig.applicationId` (still `com.rarilabs.rarime`
     * until then).
     */
    const val APP_ID: String = "com.foundationnext.mobile"

    /**
     * Google OAuth web client id, used by the Drive-backed identity backup in
     * the Recovery module. Supplied by the `GOOGLE_WEB_KEY` Gradle property
     * (see docs/android-local-setup.md), not hardcoded here - take the
     * `client_id` whose `client_type` is 3 from `app/google-services.json`.
     * Empty when the property is unset, which is fine for building.
     */
    const val GOOGLE_WEB_KEY: String = BuildConfig.GOOGLE_WEB_KEY

    /** Referral programme - stripped in Task C5. */
    const val genesisReferralCode: String = ""

    /**
     * Light-verification signing key. Foundation's L2 lane uses the full query
     * proof, not the light path, so this stays empty; LightProofHandler is
     * removed in Task C5.
     */
    const val lightVerificationSKHex: String = ""

    /**
     * RMO rewards HMAC key - the rewards programme is stripped in Task C5.
     * Until C5 lands, PointsManager.kt's `joinRewardProgram` and
     * `verifyPassport` feed this into HmacUtil.kt's `hmacSha256`, which
     * builds a BouncyCastle `HMac(SHA256Digest())` from a `KeyParameter` -
     * not `SecretKeySpec`. That
     * accepts a zero-length key without throwing: an empty value here does
     * NOT crash at runtime. It silently produces a syntactically-valid but
     * semantically-meaningless HMAC signature, which then gets sent to
     * Rarimo's points service as if it were a real signature. `""` is still
     * the correct value - Foundation doesn't have Rarimo's real key - but
     * the safety here comes entirely from Task C5 deleting these call sites,
     * not from the empty key being inert on its own.
     */
    const val joinProgram: String = ""
}
