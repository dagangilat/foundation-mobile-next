# Foundation Mobile

A privacy-preserving identity app for the Foundation governance platform.
Prove you are a unique human with a passport, without revealing who you are.

**This is a fork of [Rarimo](https://github.com/rarimo)'s
[rarime-ios-app](https://github.com/rarimo/rarime-ios-app) and
[rarime-android-app](https://github.com/rarimo/rarime-android-app)**, rebranded
and integrated with Foundation's backend. See NOTICE for upstream attribution.

## License

GPL-3.0 (see LICENSE). The app statically links GPL-3.0 `witnesscalc` and
LGPL-3.0 `rapidsnark` proving libraries; see THIRD_PARTY_LICENSES.md.
This repository is the complete corresponding source.

## Status

This repository is an active fork-and-rebrand in progress. Rarimo's real
iOS and Android application source has been imported (see `ios/` and
`android/`); rebranding and integration with Foundation's backend is
ongoing. The pre-fork native app shell this repo started from is preserved
at `legacy-ios-shell/` for reference during the port and will be removed
once that work completes.

## Building

### iOS

    cd ios && ./prebuild.sh          # builds Identity.xcframework (Go + gomobile)
    open FoundationMobile.xcodeproj

Requires `ios/FoundationMobile/GoogleService-Info.plist` (gitignored) — generate with
`firebase apps:sdkconfig IOS --project foundation-next-app`.

### Android

    cd android && ./gradlew :app:assembleDebug

See docs/android-local-setup.md — `app/google-services.json` and a
`GOOGLE_WEB_KEY` Gradle property are required, and the app builds for
`arm64-v8a` only.

### Before any store upload

    ./scripts/brand-sweep.sh

Both fastlane lanes run this first. A leftover Rarimo string or logo reaching a
store listing is the failure mode this guards.

Neither platform has a real Firebase app registered yet as of this writing —
both `GoogleService-Info.plist` and `google-services.json` are gitignored
local stubs, not the real `foundation-next-app` project. This is a known,
separately-tracked pending item; builds and unit tests are unaffected.

## Staying in sync with upstream

`scripts/import-upstream.sh` pulls the latest changes from Rarimo's
upstream repositories into this fork. After every pull, re-run
`scripts/brand-sweep.sh` — upstream commits can reintroduce Rarimo
branding into files this fork has already rebranded.

## Contributing

This is Foundation's internal fork, developed against Foundation's own
backend. Issues and PRs against upstream Rarimo bugs are best filed on
their repositories directly; issues specific to this fork's rebrand or
Foundation integration can be filed here.
