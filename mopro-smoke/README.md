# mopro-smoke

Sprint-0 toolchain smoke test for Phase 3 (NFC + ZK). Its job is to answer one question:

> Can we ship a Rust crate through UniFFI as an iOS `.xcframework` that links and runs on both simulator and device, built from Xcode Cloud?

The real Phase 3 integration will swap `uniffi` for [`mopro-ffi`](https://github.com/zkmopro/mopro), which layers Circom proof generation on top of the same UniFFI scaffolding. If this smoke is green, the MOPRO swap is a `Cargo.toml` change, not a toolchain rework.

If it's red (UniFFI can't cross-compile, xcframework won't embed, bindgen output won't link, Xcode Cloud can't install a Rust toolchain in `ci_post_clone.sh`), we learn early and fall back to the WASM-in-JavaScriptCore path documented in the architecture doc.

## Prereqs (macOS only)

```sh
# Rust + iOS targets
brew install rustup-init && rustup-init -y
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# Xcode command-line tools (for xcodebuild -create-xcframework + lipo)
xcode-select --install
```

## Build

```sh
./mopro-smoke/build-xcframework.sh
```

Outputs (both `.gitignore`d, regenerated per build):
- `ios/Frameworks/MoproSmoke.xcframework`
- `ios/FoundationMobile/Generated/MoproSmoke.swift`

## Wire into Xcode (one-time)

1. In Xcode, drag `ios/Frameworks/MoproSmoke.xcframework` into the project navigator under `FoundationMobile`. In the target's **General** tab, add it to **Frameworks, Libraries, and Embedded Content** with **Embed & Sign**.
2. Drag `ios/FoundationMobile/Generated/MoproSmoke.swift` into the target.
3. **Build Settings → Other Swift Flags** → add `-D MOPRO_LINKED` so `MoproSmokeBridge` swaps its stub for the real call.

## Smoke expectations

Once linked, the `MoproSmokeBridge.hello()` call should return something like:

```
mopro-smoke v0.1.0 — UniFFI toolchain green. Next step: swap uniffi for mopro-ffi.
```

That string appears in `HomeView`'s MOPRO status row on the signed-in home screen.

If that renders on a physical device running a Xcode-Cloud-built IPA, the smoke test is green and Track B (Phase 3) is unblocked.

## Xcode Cloud integration (second-stage smoke)

After the local build is green, add a `rustup install` + `build-xcframework.sh` step to `ios/ci_scripts/ci_post_clone.sh` so the xcframework is produced on every cloud build. Keep the xcframework out of git — it's a 10+ MB static lib per arch.
