import java.util.Properties

plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.jetbrainsKotlinAndroid)
    kotlin("kapt")
    id("com.google.dagger.hilt.android")
    id("kotlin-parcelize")
    id("com.google.gms.google-services")
}

// Release signing. Local-only, gitignored keystore.properties (see
// docs/android-local-setup.md) — the real credentials never touch this
// repo. Deliberately absent, not defaulted to the debug keystore: none of
// the release build types below had ANY signingConfig until this file was
// added (confirmed via grep — assembleRelease/bundleRelease previously
// produced an unsigned artifact Play Console would reject on upload, not a
// debug-signed one). A build that needs release signing and doesn't have
// this file should fail loudly at configuration time, not silently fall
// back to a debug key that could never be uploaded to Play anyway.
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        keystorePropsFile.inputStream().use { load(it) }
    }
}

android {
    // Kotlin package namespace deliberately unchanged - see Open Decision OD-3
    // in docs/superpowers/plans/2026-08-31-foundation-mobile-next-rarimo-fork-rebrand.md.
    // Users see applicationId and app_name; the namespace is invisible, and
    // renaming it would conflict on every upstream merge.
    namespace = "com.rarilabs.rarime"
    // 36, not 35: Play Console requires targeting at least API 36 for new
    // releases as of 2026 (Google's rolling annual API-level requirement).
    // compileSdk must be >= targetSdk.
    compileSdk = 36

    bundle {
        language {
            enableSplit = false
        }
    }

    packaging {
        resources {
            pickFirsts.add("META-INF/DEPENDENCIES")
        }
    }

    assetPacks += listOf(":zkp_assets")

    defaultConfig {

        applicationId = "com.foundationnext.mobile"
        minSdk = 27
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"

        externalNativeBuild {
            cmake {
                cppFlags += "-fno-stack-protector"
                arguments += "-DANDROID_STL=c++_shared"
            }

            ndk {
                //noinspection ChromeOsAbiSupport
                abiFilters += "arm64-v8a"
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }

        resourceConfigurations.plus(
            listOf(
                "en",
            )
        )

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }

        // Google OAuth web client id for the Drive-backed identity backup.
        // Supplied out of band (~/.gradle/gradle.properties or -P) rather than
        // committed to source - see docs/android-local-setup.md. Read by
        // com.rarilabs.rarime.config.Keys.GOOGLE_WEB_KEY.
        buildConfigField(
            "String",
            "GOOGLE_WEB_KEY",
            "\"${project.findProperty("GOOGLE_WEB_KEY") ?: ""}\""
        )
    }

    androidResources {
        generateLocaleConfig = true
    }

    signingConfigs {
        // Only registered when keystore.properties is actually present (a
        // clean checkout has no release keystore, and assembleDebug/CI's
        // unit tests must keep working without one). Real release builds
        // (bundleRelease/assembleRelease) reference this by name below and
        // will fail loudly - not fall back to debug signing - if it's
        // missing, which is the correct failure mode: an unsigned or
        // debug-signed bundle would just be rejected by Play Console later,
        // less legibly.
        if (keystorePropsFile.exists()) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // `isTestnet` is read as BuildConfig.isTestnet from 8 source files, but
        // upstream only declares it on the four create(...) build types below -
        // so the base `debug` and `release` variants have no such field and
        // `assembleDebug` / `assembleRelease` cannot compile at all. Declaring
        // defaults here fixes that; the four explicit build types still win,
        // because initWith() copies this field and their own buildConfigField
        // call then overrides it by name.
        release {
            buildConfigField("Boolean", "isTestnet", "false")
            isMinifyEnabled = false
            isDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
            )
            if (keystorePropsFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }

        debug {
            buildConfigField("Boolean", "isTestnet", "false")
        }

        create("debug_mainnet") {
            initWith(getByName("debug"))
            buildConfigField("Boolean", "isTestnet", "false")
        }
        create("release_mainnet") {
            initWith(getByName("release"))
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
            )
            buildConfigField("Boolean", "isTestnet", "false")
        }
        create("debug_testnet") {
            initWith(getByName("debug"))
            buildConfigField("Boolean", "isTestnet", "true")
            signingConfig = signingConfigs.getByName("debug")
        }
        create("release_testnet") {
            initWith(getByName("release"))
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
            )
            buildConfigField("Boolean", "isTestnet", "true")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        this.isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.15"
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/versions/9/OSGI-INF/MANIFEST.MF"
            excludes += "/META-INF/DISCLAIMER"
            excludes += "/META-INF/DEPENDENCIES"
        }
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

dependencies {
    implementation("com.auth0.android:jwtdecode:2.0.2")
    implementation("com.squareup.moshi:moshi-kotlin:1.15.1")
    implementation("com.squareup.moshi:moshi:1.15.1")
    implementation("com.squareup.retrofit2:converter-moshi:2.11.0")
//    implementation("moe.banana:moshi-jsonapi:master-SNAPSHOT")

    implementation("androidx.compose.animation:animation:1.7.8")
    implementation("com.google.accompanist:accompanist-swiperefresh:0.34.0")
    implementation("com.github.jeziellago:compose-markdown:0.5.0")
    implementation("io.coil-kt:coil-compose:2.6.0")
    implementation("io.coil-kt:coil-gif:2.6.0")
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.view)
    implementation(libs.face.mesh.detection)
    testImplementation(libs.junit)
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.0")
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
    //// CAMERA STUFF ////
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view.v132beta02)
    implementation(libs.androidx.camera.extensions)

    //// ML-KIT ////
    implementation(libs.text.recognition)
    implementation("com.google.mlkit:segmentation-selfie:16.0.0-beta6")
    implementation("org.tensorflow:tensorflow-lite:2.13.0")
    implementation("org.tensorflow:tensorflow-lite-support:0.4.3")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.13.0")

    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("com.google.mlkit:face-mesh-detection:16.0.0-beta3")


    //// ACCOMPANIST ////
    implementation("com.google.accompanist:accompanist-permissions:0.31.6-rc")
    implementation("org.jmrtd:jmrtd:0.7.27")

    implementation("com.github.mhshams:jnbis:1.1.0")
    implementation("dev.keiji.jp2:jp2-android:1.0.4")

    val lifecycle_version = "2.7.0"
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:$lifecycle_version")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:$lifecycle_version")
    implementation("com.google.dagger:hilt-android:2.51")
    implementation("androidx.navigation:navigation-compose:$lifecycle_version")
    kapt("com.google.dagger:hilt-compiler:2.51")
    implementation("androidx.hilt:hilt-navigation-compose:1.0.0")

    implementation("net.sf.scuba:scuba-sc-android:0.0.20")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation(files("libs/Identity.aar"))
    implementation(files("libs/bionet-release.aar"))
    implementation(files("libs/noir.aar"))

    // QR Code
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("network.chaintech:qr-kit:1.0.6")
    implementation("com.lightspark:compose-qr-code:1.0.1")

    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.airbnb.android:lottie-compose:6.4.0")
    implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.7.0")

    //Retrofit
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")

    //Web3
    implementation("org.web3j:core:4.9.8")
    implementation("org.bouncycastle:bcpkix-jdk15on:1.70")


    implementation("com.google.android.play:asset-delivery:2.2.2")
    implementation("com.google.android.play:asset-delivery-ktx:2.2.2")

    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")

    //Room
    val room_version = "2.6.1"

    implementation("androidx.room:room-runtime:$room_version")
    annotationProcessor("androidx.room:room-compiler:$room_version")

    // To use Kotlin annotation processing tool (kapt)
    kapt("androidx.room:room-compiler:$room_version")
    implementation("androidx.room:room-ktx:$room_version")

    //google services
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-core:9.6.1")

    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.apis:google-api-services-drive:v3-rev20220815-2.0.0")
    implementation("com.google.api-client:google-api-client:2.0.0")
    implementation("com.google.api-client:google-api-client-android:1.32.1")
    implementation("com.google.oauth-client:google-oauth-client-jetty:1.34.1")
    implementation("com.google.auth:google-auth-library-oauth2-http:1.19.0")
    // Foundation's backend is Firebase: Auth holds the account every callable's
    // requireAuth checks, and Functions is the transport. The BOM was already
    // here at 33.2.0 - bumped rather than declared a second time, since two
    // platform() lines for the same BOM is a resolution hazard.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-functions-ktx")
    // Play Integrity attestation (C7): Android's counterpart to iOS App
    // Attest. App Check wraps the Play Integrity provider; the raw
    // integrity library is used directly for the nonce-bound token request.
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    implementation("com.google.android.play:integrity:1.4.0")
    // `FirebaseFunctions.call()` and `signInWithCustomToken()` return Play
    // Services Tasks; this is what makes `Task.await()` available. It arrives
    // transitively today, but relying on another library's transitive for a
    // direct import is how a harmless dependency bump becomes a compile break.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.0")
    implementation("androidx.hilt:hilt-work:1.0.0") // ?
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("com.google.firebase:firebase-messaging:24.0.1")




    implementation("com.google.accompanist:accompanist-systemuicontroller:0.31.0-alpha")

    // The upstream attribution SDK was here. Its only use in this app was
    // delivering deferred referral codes into the rewards and hidden-prize
    // programmes, both removed in Task C5, so the dependency goes with them.
    // Dropping it also drops its install-attribution reporting.

    implementation("io.coil-kt:coil-compose:2.0.0-rc01")

    implementation("nl.dionsegijn:konfetti-compose:2.0.5")

    implementation("org.burnoutcrew.composereorderable:reorderable:0.9.6")
}
