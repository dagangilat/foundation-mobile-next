# Android local setup

`android/` is a fork of `rarime-android-app`, which **does not compile as
cloned**: upstream gitignores
`app/src/main/java/com/rarilabs/rarime/config/`, so `Keys.kt` — which
`BaseConfig.kt` imports — is absent from their repository. This fork commits its
own reconstruction of that file (Foundation's values, several deliberately
empty). You do not need to obtain anything from Rarimo.

**Shortcut:** `scripts/mobile.sh` automates this page: `setup` (JDK, SDK,
NDK, CMake, emulator), `firebase` (config file, `GOOGLE_WEB_KEY`, SHA
fingerprints), `android-emulator`, `android-device`, `android-bundle`,
`android-internal`, `android-metadata`, and `doctor`.

## Toolchain

- **JDK 21** (what this fork's builds have been verified with; the Kotlin/Java
  compile target is 17). The wrapper pins Gradle 8.4, which cannot run on
  JDK 22+. If your default `java` is newer, export a supported one for every
  Gradle invocation, e.g.

      export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

- **Android SDK** — platform 36 and build-tools 36.0.0 (Play requires
  targetSdk 36 for new releases). Point Gradle at it with
  `ANDROID_HOME`, or write `sdk.dir=<path>` into `android/local.properties`
  (gitignored).

- **Android NDK** — the app builds `librarime.so` from
  `app/src/main/cpp/CMakeLists.txt`, linking the GPL-3.0 witnesscalc and
  LGPL-3.0 rapidsnark shared objects. It also needs cmake 3.22.1. The ABI
  filter is `arm64-v8a` only, so an x86_64 emulator will not run it — use a
  physical arm64 device or an arm64 emulator image. On an Apple Silicon Mac,
  Android Studio's default emulator images are arm64 and work.

## What you also need locally

1. **`app/google-services.json`** — gitignored, never committed. Generate it
   from the Firebase project once the Android app is registered there:

       firebase apps:create ANDROID "Foundation Mobile Android" \
         --package-name com.foundationnext.mobile --project foundation-next-app
       firebase apps:sdkconfig ANDROID --project foundation-next-app \
         --out android/app/google-services.json

   The package name Firebase keys on is the **applicationId**, not the Kotlin
   namespace — register `com.foundationnext.mobile` even though the source
   package stays `com.rarilabs.rarime`. Registration requires real access to
   the `foundation-next-app` Firebase project; it has **not** been done yet
   (the same outstanding gap as the iOS `GoogleService-Info.plist`).

2. **`GOOGLE_WEB_KEY`** — the OAuth web client id used by the Drive-backed
   identity backup. Take the `client_id` whose `client_type` is `3` from the
   generated `google-services.json`, and put it in `~/.gradle/gradle.properties`:

       GOOGLE_WEB_KEY=<...>.apps.googleusercontent.com

   It reaches Kotlin as `BuildConfig.GOOGLE_WEB_KEY`, which
   `config.Keys.GOOGLE_WEB_KEY` returns. Unset, it is the empty string: the
   project still builds, but Drive-backed backup will not work.

## Build variants

Six build types exist. Four are the real product variants and set
`BuildConfig.isTestnet` explicitly:

| Build type        | `isTestnet` | Assemble task             |
| ----------------- | ----------- | ------------------------- |
| `debug`           | `false`     | `assembleDebug`           |
| `release`         | `false`     | `assembleRelease`         |
| `debug_testnet`   | `true`      | `assembleDebug_testnet`   |
| `debug_mainnet`   | `false`     | `assembleDebug_mainnet`   |
| `release_testnet` | `true`      | `assembleRelease_testnet` |
| `release_mainnet` | `false`     | `assembleRelease_mainnet` |

Upstream declares `isTestnet` only on the four `*_testnet` / `*_mainnet` types,
which means the base `debug` and `release` variants have no such field and
cannot compile at all — eight source files read `BuildConfig.isTestnet`. This
fork adds defaults to the two base types (both mainnet) so the conventional
`assembleDebug` works; the four explicit types still override them. Use
`debug_testnet` for a testnet build.

## Build

    export JAVA_HOME=<a JDK 17 or 21>
    export ANDROID_HOME=<your Android SDK>
    cd android && ./gradlew :app:assembleDebug

Output: `android/app/build/outputs/apk/debug/app-debug.apk` (~340 MB — it
carries the ZK proving assets).

## Android Studio

Open the `android/` folder (not the repo root). Then set **Settings > Build,
Execution, Deployment > Build Tools > Gradle > Gradle JDK** to the bundled
**jbr-21**, since the pinned Gradle 8.4 cannot run on JDK 22+. In **SDK Manager**
install Android 16 (API 36), Build-Tools 36.0.0, NDK (Side by side), and
CMake 3.22.1. Pick the `debug` build variant and run on an arm64 emulator or a
phone with USB debugging on.

## Release signing

`bundleRelease` / `assembleRelease` sign with the upload key described by
`android/keystore.properties` (gitignored):

    storeFile=upload-keystore.jks
    storePassword=...
    keyAlias=...
    keyPassword=...

`storeFile` is resolved relative to `android/`. Without this file the release
build types have no signing config and fail. Back up the keystore and its
passwords outside the repo; losing them means asking Play support to reset
the upload key.

## Play Console upload

The first bundle for a new app has to be uploaded in Play Console by hand
(already done for Internal testing). After that:

    export PLAY_STORE_JSON_KEY=$HOME/keys/play-service-account.json
    cd android && bundle install && bundle exec fastlane internal

The service account needs **Release** permissions on the app (Play Console >
Users and permissions). The lane runs the brand-sweep ratchet, sets versionCode
to the highest code on any track + 1, builds the signed release bundle, and
uploads it to Internal testing as a draft release. Roll it out from Play Console,
or set `PLAY_RELEASE_STATUS=completed` once the app has been published.

For a local bundle with a specific code: `./gradlew :app:bundleRelease -PVERSION_CODE=5`.
