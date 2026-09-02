# Building `Identity.xcframework`

`ios/prebuild.sh` produces `ios/Frameworks/Identity.xcframework` from
`dagangilat/rarime-mobile-identity-sdk` (our fork of Rarimo's SDK). It is a
build output — gitignored, never committed.

## Prerequisites

- Go toolchain on `PATH` (`/usr/local/go/bin` and `$HOME/go/bin`, which
  `prebuild.sh` appends to `PATH`).
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

`prebuild.sh` does not invoke the SDK's `build/patch.sh` — the cgo-patching
step only matters if you're calling `gomobile bind` some other way. The
failure actually seen (and fixed) via this script was a Go module conflict:
`gomobile bind`'s internal `go mod tidy` failed with `ambiguous import: found
package github.com/btcsuite/btcd/chaincfg/chainhash in multiple modules`,
caused by the SDK's `go.mod` pinning a `github.com/btcsuite/btcd` version
that still bundled `chaincfg/chainhash` internally, colliding with the
standalone `chaincfg/chainhash` module pulled in transitively via
`go-ethereum`. Fixed by bumping the `replace` directive to a version that
splits `chainhash` out cleanly (`v0.22.3`) — see the SDK fork's own commit
history (`dagangilat/rarime-mobile-identity-sdk`) for the exact change if
this regresses on a future upstream merge.

Do not work around any build failure by stubbing the framework: without the
real `Identity` module the app cannot prove anything.
