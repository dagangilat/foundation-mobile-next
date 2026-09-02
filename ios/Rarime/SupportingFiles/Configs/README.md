# Build configurations

This fork has a **single Firebase/backend tier** (`foundation-next-app`).
Upstream Rarimo shipped genuinely different staging/production backends here;
we do not have a staging tier, so `Development.xcconfig` is a copy of
`Production.xcconfig` differing only in the FCM topic names, so a debug build
cannot receive production pushes.

## Never copy these back from upstream

Upstream's `Development.xcconfig` contains **live Rarimo private keys**
(`LIGHT_SIGNATURE_PRIVATE_KEY`, `JOIN_REWARDS_KEY`) and their AppsFlyer dev key.
This is a public repository. `scripts/brand-sweep.sh` catches the AppsFlyer key
by name; the private keys are guarded by
`RarimeTests/Tests/ConfigTests/FoundationConfigTests.swift`.

## `about:blank`, not `""`, for the stripped Freedom Tool URLs

`FREEDOM_TOOL_RPC_URL`/`WEBSITE_URL`/`API_URL` are set to `"about:blank"`
rather than blanked to `""` like the other stripped keys above. Blanking them
would crash the app at launch: `ConfigManager.FreedomTool` reads each of these
as a non-optional `URL` via `try!`, and `URL(string: "")` returns `nil`.
`"about:blank"` parses successfully and keeps decoding total until Task B5
removes the Polls module (and this struct) entirely.

## Retained Rarimo endpoints — deliberate

`APP_API_URL`, `EVM_RPC_URL`, and the contract addresses still point at
Rarimo's infrastructure. Passport registration is anchored on Rarimo's L2, and
`foundation-next`'s `verificator-svc` validates proofs against that same
registration state. Repointing them means running our own registration relayer
and SMT contracts. See Open Decision OD-5.
