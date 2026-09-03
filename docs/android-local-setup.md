# Android local setup

`android/` is a fork of `rarime-android-app`, which **does not compile as
cloned**: upstream gitignores
`app/src/main/java/com/rarilabs/rarime/config/`, so `Keys.kt` — which
`BaseConfig.kt` imports — is absent from their repository. This fork commits its
own reconstruction of that file (Foundation's values, several deliberately
empty). You do not need to obtain anything from Rarimo.

## Toolchain

- **JDK 21** (what this fork's builds have been verified with; the Kotlin/Java
  compile target is 17). The wrapper pins Gradle 8.4, which cannot run on
  JDK 22+. If your default `java` is newer, export a supported one for every
  Gradle invocation, e.g.

      export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

- **Android SDK** — platform 35 and build-tools 35.0.0. Point Gradle at it with
  `ANDROID_HOME`, or write `sdk.dir=<path>` into `android/local.properties`
  (gitignored).

- **Android NDK** — the app builds `librarime.so` from
  `app/src/main/cpp/CMakeLists.txt`, linking the GPL-3.0 witnesscalc and
  LGPL-3.0 rapidsnark shared objects. It also needs cmake 3.22.1. The ABI
  filter is `arm64-v8a` only, so an x86_64 emulator will not run it — use a
  physical arm64 device or an arm64 emulator image.

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
| `debug`           | `true`      | `assembleDebug`           |
| `release`         | `false`     | `assembleRelease`         |
| `debug_testnet`   | `true`      | `assembleDebug_testnet`   |
| `debug_mainnet`   | `false`     | `assembleDebug_mainnet`   |
| `release_testnet` | `true`      | `assembleRelease_testnet` |
| `release_mainnet` | `false`     | `assembleRelease_mainnet` |

Upstream declares `isTestnet` only on the four `*_testnet` / `*_mainnet` types,
which means the base `debug` and `release` variants have no such field and
cannot compile at all — eight source files read `BuildConfig.isTestnet`. This
fork adds defaults to the two base types (`debug` → testnet, `release` →
mainnet) so the conventional `assembleDebug` works; the four explicit types
still override them.

## Build

    export JAVA_HOME=<a JDK 17 or 21>
    export ANDROID_HOME=<your Android SDK>
    cd android && ./gradlew :app:assembleDebug

Output: `android/app/build/outputs/apk/debug/app-debug.apk` (~340 MB — it
carries the ZK proving assets).
