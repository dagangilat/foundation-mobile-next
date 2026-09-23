# iOS: run, TestFlight and App Store

Everything here runs on a Mac with current Xcode. There is no hosted iOS CI
in this repo; the Mac is the build and release machine.

**Shortcut:** `scripts/mobile.sh` automates the steps below: `setup`,
`firebase`, `ios-sim`, `ios-device`, `ios-create-app`, `ios-testflight`,
`ios-metadata`, and `doctor` to see what is missing. The manual steps are
documented here for when you need them.

## One-time setup

1. **Tools:** Xcode, Go (`brew install go`), gomobile
   (`go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init`),
   Ruby with Bundler for fastlane.
2. **Identity SDK:** `cd ios && ./prebuild.sh` builds `Frameworks/Identity.xcframework`
   from `dagangilat/rarime-mobile-identity-sdk`. Re-run after SDK changes.
3. **Firebase:** put `ios/FoundationMobile/GoogleService-Info.plist` in place
   (gitignored). Generate it with
   `firebase apps:sdkconfig IOS --project foundation-next-app` once the iOS app
   (`com.foundationnext.mobile`) is registered there. Without a real one,
   sign-in cannot complete.

## Simulator

    scripts/run-ios-simulator.sh "iPhone 17 Pro"

or open `ios/FoundationMobile.xcodeproj`, pick scheme **FoundationMobile** and a
simulator, and Run.

The ZK prover libraries in `ios/Frameworks` are device-only and are linked only
for `iphoneos`, so on the simulator the UI and sign-in work but passport NFC
reading and proof generation do not. Test those on a phone.

## Physical iPhone

1. Connect the phone, tap **Trust**, and turn on **Settings > Privacy &
   Security > Developer Mode** (the phone restarts).
2. In Xcode, select the phone as the run destination and Run the
   **FoundationMobile** scheme.
3. Automatic signing (team `F9F26FQW95`) registers the device and creates the
   App ID capabilities on first run, including App Group
   `group.com.foundationnext.mobile` and iCloud container
   `iCloud.com.foundationnext.mobile`. If Xcode reports a capability error,
   open **Signing & Capabilities** for both targets and let it fix the issue.

## TestFlight upload

First, once: create the app in App Store Connect (**Apps > + > New App**,
bundle ID `com.foundationnext.mobile`, SKU of your choice).

Ship the **Production** scheme. **FoundationMobile** archives the Development
configuration (debug badge and options) and must not be uploaded.

### A. Xcode GUI (simplest for the first upload)
1. Scheme **Production**, destination **Any iOS Device (arm64)**.
2. **Product > Archive**, then in Organizer **Distribute App > App Store
   Connect > Upload**.
3. Bump **Build** (CURRENT_PROJECT_VERSION) before each new upload of the same
   version.

### B. fastlane (repeatable)
Create an App Store Connect API key (**Users and Access > Integrations > App
Store Connect API**, role App Manager) and download the `.p8`. Then:

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=$HOME/keys/AuthKey_XXXXXXXXXX.p8
cd ios && bundle install && bundle exec fastlane beta
```

The `beta` lane runs the brand-sweep ratchet, rebuilds the Identity SDK, sets
the build number to the latest TestFlight build + 1, archives **Production**
with automatic signing (xcodebuild creates the distribution certificate and
profiles through the API key), and uploads to TestFlight. It does not modify
the project file.

## TestFlight testers
- **Internal** (up to 100 App Store Connect users): available as soon as the
  build finishes processing.
- **External** (up to 10,000 by email or public link): the first build of each
  version goes through Beta App Review.

## App Store release
Store text, privacy answers and review notes are drafted in `docs/store/`.
Before submitting:
- Set the price to **Free** (Pricing and Availability).
- Fill in App Privacy, age rating, screenshots, and privacy policy and support URLs.
- Give review a demo account and notes (reviewers cannot scan a passport; a
  screen recording of the NFC flow helps).
- Resolve Open Decision OD-2 (GPL-3.0 and the App Store EULA; see
  `docs/app-store-review-notes.md`).
