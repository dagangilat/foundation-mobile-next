#!/bin/sh
# Xcode Cloud hook — runs after `git clone`, before xcodebuild.
# foundation-mobile uses CocoaPods for Firebase (SPM + Xcode Cloud's per-org
# GitHub App install requirement is incompatible with consuming public SDKs
# owned by orgs we don't control). Xcode Cloud ships with CocoaPods preinstalled.
#
# Also bootstraps the Rust toolchain + builds MoproSmoke.xcframework from
# mopro-smoke/. Xcode Cloud doesn't ship with Rust, and the xcframework is
# gitignored (10+ MB per arch), so this must run on every clean build or
# xcodebuild will fail with "No such XCFramework".

set -e

echo "foundation-mobile: ci_post_clone.sh — installing CocoaPods dependencies"
cd "$CI_WORKSPACE/ios"
pod install --verbose

echo "foundation-mobile: ci_post_clone.sh — installing Rust toolchain"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
export PATH="$HOME/.cargo/bin:$PATH"

# rust-witness's build script uses w2c2 (WASM-to-C transpiler) which shells out
# to cmake to build its native lib. Xcode Cloud's macOS image historically has
# cmake preinstalled via Homebrew; install defensively if it doesn't.
if ! command -v cmake >/dev/null 2>&1; then
    echo "foundation-mobile: ci_post_clone.sh — installing cmake for rust-witness"
    brew install cmake
fi

echo "foundation-mobile: ci_post_clone.sh — building MoproSmoke.xcframework"
cd "$CI_WORKSPACE/mopro-smoke"
./build-xcframework.sh

# Map Xcode Cloud workflow → FOUNDATION_PROFILE (consumed by
# ios/scripts/select-profile.sh during the build phase).
# Override per-workflow in App Store Connect → Xcode Cloud → Environment.
if [ -z "${FOUNDATION_PROFILE:-}" ]; then
    case "${CI_WORKFLOW:-}" in
        *standardsec*) export FOUNDATION_PROFILE="standardsec" ;;
        *lowsec*)      export FOUNDATION_PROFILE="lowsec-attest" ;;
        *)             export FOUNDATION_PROFILE="hisec-global" ;;
    esac
fi
echo "foundation-mobile: ci_post_clone.sh — FOUNDATION_PROFILE=${FOUNDATION_PROFILE}"

# 2026-04-26 security review M-H-2: hard-fail archive builds that would
# ship App Store with the development App Attest endpoint. Sandbox-CA
# attestations are rejected by the production CBOR verifier in
# @plantagoai/attestation/server, so a mis-archived TestFlight build is
# silent-but-broken — every user gets a verification fail in prod.
#
# Triggered when CI_XCODEBUILD_ACTION=archive (Xcode Cloud sets this on
# distribution workflows). Use FoundationMobile-Release.entitlements
# (which carries `production`) for the Release build configuration.
if [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ]; then
    REL_ENT="$CI_WORKSPACE/ios/FoundationMobile/FoundationMobile-Release.entitlements"
    if [ ! -f "$REL_ENT" ]; then
        echo "foundation-mobile: ci_post_clone.sh — ✗ archive build but FoundationMobile-Release.entitlements is missing"
        exit 1
    fi
    if ! grep -q "<string>production</string>" "$REL_ENT"; then
        echo "foundation-mobile: ci_post_clone.sh — ✗ archive build but Release entitlements does not declare appattest-environment=production"
        exit 1
    fi
    echo "foundation-mobile: ci_post_clone.sh — archive build verified Release entitlements at production"
fi
