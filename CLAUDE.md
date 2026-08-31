# foundation-mobile-next

> **This is `foundation-mobile-next`, a fork of `dagangilat/foundation-mobile`**
> created 2026-08-31 for the Rarimo fork-and-rebrand identity work. See
> `foundation-next`'s
> `docs/superpowers/specs/2026-08-30-foundation-rarimo-consolidation-design.md`
> §3 for the full design — this repo forks and rebrands `rarime-ios-app`
> as Foundation Mobile, accepting the GPL-3.0 source-disclosure obligation
> its proving stack carries. Isolated from live `foundation-mobile` —
> different GitHub repo, different bundle identifiers, different Firebase
> app registration (still under the `foundation-next-app` project). Not
> user-facing branding; internal identifier only.
>
> **Local setup gap found during bootstrap (2026-08-31):** the Xcode
> project's Resources build phase unconditionally bundles TWO gitignored
> plist files — `ios/FoundationMobile/GoogleService-Info.plist` (the one
> Task 3 of the bootstrap plan registers) AND
> `ios/FoundationMobile/GoogleService-Info-staging.plist`. Both must exist
> locally or the build fails at the Resources copy step. This fork has no
> real staging tier, so the fix is to duplicate the registered plist under
> the staging filename (same `foundation-next-app` project, same content) —
> not to register a second Firebase app. A fresh clone will hit a build
> failure here until this is done:
> `cp ios/FoundationMobile/GoogleService-Info.plist ios/FoundationMobile/GoogleService-Info-staging.plist`

## Known live-identity remnants (deferred to the Rarimo rebrand plan)

This bootstrap plan's scope is deliberately narrow: it only covers the
Xcode-project bundle ID and the Firebase app registration. It does NOT do a
full rebrand — that's a separate, later plan that forks and rebrands
Rarimo's actual `rarime-ios-app` source. The items below are other places
in the codebase that still reference LIVE Foundation Mobile's identity
(bundle ID, Firebase/ASC records, live domains). They are known, deferred
gaps, not oversights — fixing them piecemeal here would be redone work once
the rebrand plan touches these same files, so they are documented instead
of fixed.

1. **Do not run `fastlane beta` (or any fastlane lane) in this fork** until
   the Rarimo rebrand plan repoints its identifiers. This is the most
   important item — it can silently undo this plan's isolation work.
   `ios/fastlane/Fastfile`'s `beta` lane calls `update_code_signing_settings`
   with the LIVE bundle ID (`com.foundationglobal.mobile`) and then uploads
   to the LIVE App Store Connect record via `upload_to_testflight`. Running
   it in this fork would rewrite the app target's bundle ID back to the live
   value (reverting this plan's Task 2 change) and upload a build to live
   Foundation Mobile's actual ASC listing.
2. `ios/scripts/add-test-target.rb:24` hardcodes
   `PRODUCT_BUNDLE_IDENTIFIER = 'com.foundationglobal.mobile.tests'`.
   Re-running this script would revert half of the Task 2 bundle-ID change
   (the test target's ID). Don't run it in this fork without first
   checking/fixing that line.
3. `ios/FoundationMobile/DeploymentConfig.swift`'s `defaultDeployment`
   hardcodes `webUrl: "https://foundation-global.com"` (live production),
   used whenever `AppConfig.shared.deployments` is nil — which it will be on
   this fresh project with no seeded config. Firebase/Firestore calls ARE
   correctly isolated (they resolve from the registered
   `GoogleService-Info.plist`, pointing at `foundation-next-app`), but the
   app's web-surface default is NOT isolated.
4. Both `ios/FoundationMobile/FoundationMobile.entitlements` and
   `ios/FoundationMobile/FoundationMobile-Release.entitlements` still
   declare `com.apple.developer.associated-domains` (`applinks:`) entries
   for live domains — `foundation-global.com` and its `voice.`, `share.`,
   and `market.` subdomains, plus `solanavote-devnet.firebaseapp.com`. Not
   a security hole (Apple validates against the domain owner's actual AASA
   file, which won't list this fork's app ID, so the links just silently
   fail rather than working against live data) — noted here so nobody is
   confused when universal links don't work in this fork.
