#!/bin/sh
# Xcode Cloud hook — runs after `git clone`, before xcodebuild.
# foundation-mobile uses CocoaPods for Firebase (SPM + Xcode Cloud's per-org
# GitHub App install requirement is incompatible with consuming public SDKs
# owned by orgs we don't control). Xcode Cloud ships with CocoaPods preinstalled.

set -e

echo "foundation-mobile: ci_post_clone.sh — installing CocoaPods dependencies"
cd "$CI_WORKSPACE/ios"
pod install --verbose
