#!/usr/bin/env bash
# Builds mopro-smoke into an iOS .xcframework for drag-drop into Xcode.
# Must run on macOS with Xcode and rustup installed.
#
#   brew install rustup-init && rustup-init -y
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
#   ./mopro-smoke/build-xcframework.sh
#
# Outputs (both gitignored; regenerated per build):
#   ios/Frameworks/MoproSmoke.xcframework
#   ios/FoundationMobile/Generated/MoproSmoke.swift
#
# After a successful build, in Xcode:
#   1. Drag ios/Frameworks/MoproSmoke.xcframework into the project navigator
#      under FoundationMobile → add to target's "Embed & Sign Frameworks".
#   2. Drag ios/FoundationMobile/Generated/MoproSmoke.swift into the target.
#   3. Build Settings → Other Swift Flags → add "-D MOPRO_LINKED" so
#      MoproSmokeBridge switches from the stub to the real call.

set -euo pipefail

cd "$(dirname "$0")"

CRATE_NAME=mopro_smoke
FRAMEWORK_NAME=MoproSmoke

echo "[mopro-smoke] Installing iOS Rust targets (no-op if present)..."
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

echo "[mopro-smoke] Building static libs for device + simulator targets..."
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

echo "[mopro-smoke] Fusing simulator architectures with lipo..."
mkdir -p target/universal-sim
lipo -create \
    target/aarch64-apple-ios-sim/release/lib${CRATE_NAME}.a \
    target/x86_64-apple-ios/release/lib${CRATE_NAME}.a \
    -output target/universal-sim/lib${CRATE_NAME}.a

echo "[mopro-smoke] Generating Swift bindings via uniffi-bindgen..."
rm -rf target/uniffi-swift
mkdir -p target/uniffi-swift
cargo run --bin uniffi-bindgen -- \
    generate \
    --library target/aarch64-apple-ios/release/lib${CRATE_NAME}.a \
    --language swift \
    --config ./uniffi.toml \
    --out-dir target/uniffi-swift

# xcframework expects a single module.modulemap alongside headers.
cp target/uniffi-swift/*FFI.modulemap target/uniffi-swift/module.modulemap

echo "[mopro-smoke] Assembling xcframework..."
OUT_FW="../ios/Frameworks/${FRAMEWORK_NAME}.xcframework"
mkdir -p ../ios/Frameworks
rm -rf "$OUT_FW"
xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/lib${CRATE_NAME}.a \
    -headers target/uniffi-swift \
    -library target/universal-sim/lib${CRATE_NAME}.a \
    -headers target/uniffi-swift \
    -output "$OUT_FW"

echo "[mopro-smoke] Copying generated Swift binding into the iOS target..."
GEN_DIR=../ios/FoundationMobile/Generated
mkdir -p "$GEN_DIR"
cp target/uniffi-swift/MoproSmoke.swift "$GEN_DIR/MoproSmoke.swift"

echo
echo "[mopro-smoke] OK"
echo "  ${OUT_FW}"
echo "  ios/FoundationMobile/Generated/MoproSmoke.swift"
echo
echo "Drag the xcframework into Xcode (Embed & Sign), add the generated .swift"
echo "to the target, and add '-D MOPRO_LINKED' to Other Swift Flags."
