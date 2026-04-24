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

echo "foundation-mobile: ci_post_clone.sh — building MoproSmoke.xcframework"
cd "$CI_WORKSPACE/mopro-smoke"
./build-xcframework.sh
