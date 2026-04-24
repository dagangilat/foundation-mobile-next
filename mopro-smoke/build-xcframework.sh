#!/usr/bin/env bash
# Builds mopro-smoke into an iOS .xcframework for drag-drop into Xcode.
# Must run on macOS with Xcode, rustup, and cmake installed.
#
#   brew install rustup-init cmake && rustup-init -y
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
#   ./mopro-smoke/build-xcframework.sh
#
# Outputs:
#   ios/Frameworks/MoproSmoke.xcframework        (gitignored, ~10+ MB/arch)
#   ios/FoundationMobile/Generated/MoproSmoke.swift (gitignored, uniffi-bindgen)
#   ios/FoundationMobile/Resources/circuits/
#     multiplier2_final.zkey                     (gitignored, copy of test-vector)
#
# After a successful build, in Xcode:
#   1. Drag ios/Frameworks/MoproSmoke.xcframework into the project navigator
#      under FoundationMobile → add to target's "Embed & Sign Frameworks".
#   2. Drag ios/FoundationMobile/Generated/MoproSmoke.swift into the target.
#   3. Build Settings → Other Swift Flags → add "-D MOPRO_LINKED" so
#      MoproSmokeBridge switches from the stub to the real call.
#
# cmake is required because rust-witness's build script invokes w2c2, a
# WASM-to-C transpiler that pulls in a cmake-built native lib at compile time.

set -euo pipefail

cd "$(dirname "$0")"

CRATE_NAME=mopro_smoke
FRAMEWORK_NAME=MoproSmoke
ZKEY_SRC="test-vectors/circom/multiplier2_final.zkey"
ZKEY_DEST_DIR="../ios/FoundationMobile/Resources/circuits"

if [[ ! -f "${ZKEY_SRC}" ]]; then
    echo "[mopro-smoke] ERROR: ${ZKEY_SRC} missing. Commit 235abc5 seeds it"
    echo "from http://ci-keys.zkmopro.org/multiplier2_final.zkey — if this is a"
    echo "partial checkout, run: git checkout ${ZKEY_SRC}"
    exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
    echo "[mopro-smoke] ERROR: cmake not in PATH. rust-witness's build script"
    echo "needs it to transpile the Circom witness WASM. Run: brew install cmake"
    exit 1
fi

echo "[mopro-smoke] Installing iOS Rust targets (no-op if present)..."
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

echo "[mopro-smoke] Building static libs for device + simulator targets..."
cargo build --release --target aarch64-apple-ios -p mopro_smoke
cargo build --release --target aarch64-apple-ios-sim -p mopro_smoke
cargo build --release --target x86_64-apple-ios -p mopro_smoke

echo "[mopro-smoke] Fusing simulator architectures with lipo..."
mkdir -p target/universal-sim
lipo -create \
    target/aarch64-apple-ios-sim/release/lib${CRATE_NAME}.a \
    target/x86_64-apple-ios/release/lib${CRATE_NAME}.a \
    -output target/universal-sim/lib${CRATE_NAME}.a

echo "[mopro-smoke] Generating Swift bindings via uniffi-bindgen..."
rm -rf target/uniffi-swift
mkdir -p target/uniffi-swift
cargo run --bin uniffi-bindgen -p mopro-smoke-bindgen-tool -- \
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
# uniffi-bindgen 0.29 emits `<module_name>.swift` where module_name comes from
# uniffi.toml (= "MoproSmoke"). If that ever changes, the drop target below
# must track it — the pbxproj references FoundationMobile/Generated/MoproSmoke.swift.
cp target/uniffi-swift/MoproSmoke.swift "$GEN_DIR/MoproSmoke.swift"

echo "[mopro-smoke] Staging zkey into iOS bundle resources..."
mkdir -p "${ZKEY_DEST_DIR}"
cp "${ZKEY_SRC}" "${ZKEY_DEST_DIR}/multiplier2_final.zkey"

echo
echo "[mopro-smoke] OK"
echo "  ${OUT_FW}"
echo "  ios/FoundationMobile/Generated/MoproSmoke.swift"
echo "  ${ZKEY_DEST_DIR}/multiplier2_final.zkey"
echo
echo "Drag the xcframework into Xcode (Embed & Sign), add the generated .swift"
echo "to the target, and add '-D MOPRO_LINKED' to Other Swift Flags."
