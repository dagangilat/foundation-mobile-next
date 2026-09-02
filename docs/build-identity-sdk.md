# Building `Identity.xcframework`

`ios/prebuild.sh` produces `ios/Frameworks/Identity.xcframework` from
`dagangilat/rarime-mobile-identity-sdk` (our fork of Rarimo's SDK). It is a
build output — gitignored, never committed.

## Prerequisites

- Go toolchain on `PATH` (`/usr/local/go/bin` and `$HOME/go/bin`, which
  `prebuild.sh` prepends).
- `gomobile` (`go install golang.org/x/mobile/cmd/gomobile@latest` then
  `gomobile init`).
- Xcode command line tools.

## Why a fork, not a pin

The SDK's own `build/patch.sh` patches Go's `cgo` tool using a Rarimo-forked
Go toolchain. That patch exists because real native C code is linked through
CGO — the same GPL-3.0 `witnesscalc` / LGPL-3.0 `rapidsnark` stack the app
links directly on the Swift side. Because that native linkage is part of our
combined work, our GPL-3.0 corresponding-source obligation covers the SDK too,
so we host our own copy rather than depending on upstream availability.

## Run

    cd ios && ./prebuild.sh

Expected tail: `✅ Build completed successfully`, and
`ios/Frameworks/Identity.xcframework` present.

## If the build fails

`gomobile bind` failing on the cgo patch is the known failure mode. Check the
SDK's `build/patch.sh` ran, and that `go env CC` points at the patched
toolchain. Do not work around it by stubbing the framework: without the real
`Identity` module the app cannot prove anything.
