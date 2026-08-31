# foundation-mobile

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
