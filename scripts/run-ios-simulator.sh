#!/usr/bin/env bash
# Build FoundationMobile and launch it in the iOS Simulator.
#
# Known gap: ios/FoundationMobile/GoogleService-Info.plist is still the
# ORIGINAL Rarimo Firebase project (rarime-7e4b9 / Rarilabs.Rarime), not a
# real Foundation registration — Firebase Auth OTP sign-in will not
# complete past the sign-in screen until that's done for real
# (`firebase apps:create`/`apps:sdkconfig` against foundation-next's real
# Firebase project). Everything up to and including sign-in is testable.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17 Pro}"
SCHEME="FoundationMobile"
PROJECT="ios/FoundationMobile.xcodeproj"

echo "==> Booting simulator: $DEVICE"
UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | grep -v "Max" | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
if [ -z "$UDID" ]; then
  echo "No simulator found matching '$DEVICE'. Available devices:"
  xcrun simctl list devices available
  exit 1
fi
xcrun simctl boot "$UDID" 2>/dev/null || echo "  (already booted)"
open -a Simulator

echo "==> Building $SCHEME for $DEVICE"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -skipMacroValidation \
  | xcbeautify 2>/dev/null || xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -skipMacroValidation

echo "==> Locating built .app"
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*FoundationMobile*/Build/Products/Debug*/FoundationMobile.app" -maxdepth 6 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  echo "Could not locate built .app under DerivedData. Search manually:"
  echo "  find ~/Library/Developer/Xcode/DerivedData -name 'FoundationMobile.app'"
  exit 1
fi
echo "  Found: $APP_PATH"

BUNDLE_ID=$(defaults read "$APP_PATH/Info" CFBundleIdentifier 2>/dev/null || plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")
echo "==> Installing ($BUNDLE_ID) and launching"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo "==> Done. Simulator should now show the app."
echo "    Note: Firebase Auth sign-in will not complete (see header comment)."
