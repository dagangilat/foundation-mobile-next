package com.rarilabs.rarime.config

import com.rarilabs.rarime.BuildConfig

/**
 * Reconstruction of the file the upstream project gitignores
 * (`/app/src/main/java/com/rarilabs/rarime/config/`), without which that
 * project does not compile as cloned.
 *
 * Task C5 removed the upstream-ecosystem modules, and with them every consumer
 * of the four values that used to be deliberately blank here (the attribution
 * dev key, the genesis referral code, the rewards-programme HMAC key and the
 * light-verification signing key). Those constants are now gone rather than
 * empty: install attribution, the referral/earn programme, the token-rewards
 * HMAC and the light-verification lane no longer exist in this app.
 *
 * NEVER paste the upstream project's values in from their iOS xcconfig. This
 * repository is public and those are their keys.
 */
object Keys {
    /**
     * Play Store application id, surfaced through `IConfig.APP_ID_FIREBASE`.
     * Nothing in the current tree reads `APP_ID_FIREBASE` (it is assigned in
     * BaseConfig.kt and never consumed), so this value is inert today; it
     * matches `android.defaultConfig.applicationId` as set by Task C2.
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
}
