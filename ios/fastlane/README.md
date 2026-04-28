fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios produce_app

```sh
[bundle exec] fastlane ios produce_app
```

Create the App Store Connect app entry (one-time).

### ios deliver_metadata

```sh
[bundle exec] fastlane ios deliver_metadata
```

Push metadata (description, privacy URL, keywords, icon, screenshots) to ASC.

Does NOT upload a binary — use :beta or :release for that.

### ios certs

```sh
[bundle exec] fastlane ios certs
```

Fetch or create the Apple Distribution certificate via the ASC API.

Idempotent — uses the existing cert if one is already in keychain.

Run once before :beta if the keychain only has Apple Development.

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build a signed IPA and upload to TestFlight.

Intended to run from Xcode Cloud or locally with a dev cert configured.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
