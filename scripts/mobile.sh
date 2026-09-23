#!/usr/bin/env bash
# One entry point for everything Foundation Mobile needs on the release Mac:
# toolchain setup, Firebase registration, running on simulators and devices,
# and store uploads. Each command is safe to re-run; it skips what is done.
#
#   scripts/mobile.sh doctor            what is installed / configured / missing
#   scripts/mobile.sh setup             install toolchains, SDKs, emulator, gems
#   scripts/mobile.sh firebase          register both apps, fetch config files,
#                                       GOOGLE_WEB_KEY, Android SHA fingerprints
#   scripts/mobile.sh ios-sim [name]    build + launch in the iOS Simulator
#   scripts/mobile.sh ios-device        build + install + launch on a USB iPhone
#   scripts/mobile.sh ios-create-app    create the App Store Connect record
#   scripts/mobile.sh ios-testflight    archive Production + upload to TestFlight
#   scripts/mobile.sh ios-metadata      upload App Store listing text
#   scripts/mobile.sh android-emulator  boot the emulator, install, launch
#   scripts/mobile.sh android-device    install + launch on a USB Android phone
#   scripts/mobile.sh android-bundle N  signed release .aab with versionCode N
#   scripts/mobile.sh android-internal  build + upload to Play internal testing
#   scripts/mobile.sh android-metadata  upload Play store listing text
#   scripts/mobile.sh backup-keys DIR   copy the Android upload key somewhere safe
#
# Secrets never live in the repo. Put them in ~/.foundation-mobile.env, which
# every command sources if present:
#   export ASC_KEY_ID=...            # App Store Connect API key (App Manager)
#   export ASC_ISSUER_ID=...
#   export ASC_KEY_PATH=$HOME/keys/AuthKey_XXXX.p8
#   export PLAY_STORE_JSON_KEY=$HOME/keys/play-service-account.json
#   export FASTLANE_APPLE_ID=you@example.com   # only for ios-create-app
#   export PLAY_APP_SIGNING_SHA256=AB:CD:...   # Play Console > App integrity
#
# Written for macOS on Apple Silicon with the system bash (3.2).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP_ID="com.foundationnext.mobile"
TEAM_ID="F9F26FQW95"
FIREBASE_PROJECT="${FIREBASE_PROJECT:-foundation-next-app}"
IOS_PROJECT="ios/FoundationMobile.xcodeproj"
IOS_PLIST="ios/FoundationMobile/GoogleService-Info.plist"
ANDROID_JSON="android/app/google-services.json"
GRADLE_PROPS="$HOME/.gradle/gradle.properties"

# Keep in step with android/app/build.gradle.kts and .github/workflows/android-ci.yml.
ANDROID_PACKAGES=(
  "platform-tools"
  "emulator"
  "platforms;android-36"
  "build-tools;36.0.0"
  "ndk;25.1.8937393"
  "cmake;3.22.1"
)
# arm64 only: the app ships arm64-v8a native code, which Apple Silicon runs natively.
AVD_IMAGE="system-images;android-35;google_apis_playstore;arm64-v8a"
AVD_NAME="FoundationPixel"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ENV_FILE="$HOME/.foundation-mobile.env"
# fastlane and its gems install here instead of Homebrew Ruby's shared gem
# directory, which can hold root-owned files from an earlier `sudo gem install`
# (bundle install then fails with "Permission denied ... plugins/rdoc_plugin.rb").
export BUNDLE_PATH="${BUNDLE_PATH:-$HOME/.foundation-mobile/gems}"
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

# ---------------------------------------------------------------- helpers

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; N=$'\033[0m'; else B=; G=; R=; Y=; N=; fi
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '%serror:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

brew_prefix() { if has brew; then brew --prefix; else echo /opt/homebrew; fi; }

# Homebrew, Go and Homebrew Ruby on PATH for this process, whether or not the
# user's shell profile has been updated yet.
load_paths() {
  local p; p="$(brew_prefix)"
  [ -x "$p/bin/brew" ] && eval "$("$p/bin/brew" shellenv)"
  export PATH="$p/opt/ruby/bin:$HOME/go/bin:$PATH"
  local gem_bin
  gem_bin="$(find "$p/lib/ruby/gems" -mindepth 2 -maxdepth 2 -name bin -type d 2>/dev/null | sort | tail -1 || true)"
  [ -n "$gem_bin" ] && export PATH="$gem_bin:$PATH"
  export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
}

# JDK 21 for Gradle 8.4 (it cannot run on 22+): Android Studio's bundled JBR,
# else Homebrew's openjdk@21.
java_home() {
  local studio="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  local brewjdk
  brewjdk="$(brew_prefix)/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  if [ -x "$studio/bin/java" ] && "$studio/bin/java" -version 2>&1 | grep -q '"21'; then echo "$studio"
  elif [ -x "$brewjdk/bin/java" ]; then echo "$brewjdk"
  else return 1; fi
}
use_java() {
  JAVA_HOME="$(java_home)" || die "JDK 21 not found - run: scripts/mobile.sh setup"
  export JAVA_HOME
}

sdkmanager_bin() {
  local c
  for c in "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
           "$(brew_prefix)/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
avdmanager_bin() { local s; s="$(sdkmanager_bin)" || return 1; echo "$(dirname "$s")/avdmanager"; }

bundle_exec() { (cd "$1" && shift && bundle exec "$@"); }

# The Android upload keystore described by android/keystore.properties.
keystore_prop() { sed -n "s/^$1=//p" android/keystore.properties 2>/dev/null | head -1; }
# storeFile is resolved by Gradle relative to android/ unless absolute.
keystore_path() {
  local f; f="$(keystore_prop storeFile)"
  case "$f" in /*) echo "$f" ;; "") echo "" ;; *) echo "android/$f" ;; esac
}

sha256_of() { # keystore alias storepass
  keytool -list -v -keystore "$1" -alias "$2" -storepass "$3" 2>/dev/null \
    | awk '/SHA256:/ {print $2; exit}' || true
}

# Firebase CLI JSON: the appId of the app registered for APP_ID on a platform.
# Anything the CLI prints before the JSON (update notices) is dropped.
firebase_app_id() { # IOS|ANDROID
  firebase apps:list "$1" --project "$FIREBASE_PROJECT" --json 2>/dev/null \
    | sed -n '/^{/,$p' \
    | jq -r --arg id "$APP_ID" \
        '.result[]? | select(.bundleId == $id or .packageName == $id or .namespace == $id) | .appId' 2>/dev/null \
    | head -1 || true
}

# The appId in an existing config file, if that file is for APP_ID in
# FIREBASE_PROJECT. Covers an app the list call does not return.
config_app_id() { # IOS|ANDROID
  if [ "$1" = IOS ]; then
    [ -f "$IOS_PLIST" ] || return 0
    [ "$(plutil -extract BUNDLE_ID raw -o - "$IOS_PLIST" 2>/dev/null || true)" = "$APP_ID" ] || return 0
    [ "$(plutil -extract PROJECT_ID raw -o - "$IOS_PLIST" 2>/dev/null || true)" = "$FIREBASE_PROJECT" ] || return 0
    plutil -extract GOOGLE_APP_ID raw -o - "$IOS_PLIST" 2>/dev/null || true
  else
    [ -f "$ANDROID_JSON" ] || return 0
    jq -r --arg id "$APP_ID" --arg p "$FIREBASE_PROJECT" \
      'select(.project_info.project_id == $p) | .client[]?
       | select(.client_info.android_client_info.package_name == $id)
       | .client_info.mobilesdk_app_id' "$ANDROID_JSON" 2>/dev/null | head -1 || true
  fi
}

# Find the app for APP_ID on a platform, creating it if the project has none.
# On failure, show what the project holds and the reason Firebase gave.
ensure_firebase_app() { # IOS|ANDROID
  local id
  id="$(firebase_app_id "$1")"
  [ -n "$id" ] || id="$(config_app_id "$1")"
  if [ -z "$id" ]; then
    local flag=--bundle-id name="Foundation Mobile iOS"
    [ "$1" = ANDROID ] && { flag=--package-name; name="Foundation Mobile Android"; }
    if firebase apps:create "$1" "$name" "$flag" "$APP_ID" --project "$FIREBASE_PROJECT" >&2; then
      id="$(firebase_app_id "$1")"
    else
      firebase_failure "$1"
    fi
  fi
  [ -n "$id" ] || die "could not find or create the $1 app in $FIREBASE_PROJECT"
  echo "$id"
}

firebase_failure() { # IOS|ANDROID
  {
    echo
    echo "$1 apps already in $FIREBASE_PROJECT:"
    firebase apps:list "$1" --project "$FIREBASE_PROJECT" 2>&1 | sed 's/^/    /' || true
    if [ -f firebase-debug.log ]; then
      echo "Firebase's reason (from firebase-debug.log):"
      grep -Eo '"message": *"[^"]*"|HTTP Error: [0-9]+[^"]*' firebase-debug.log | tail -3 | sed 's/^/    /' || true
    fi
    echo "Common causes:"
    echo "  - PERMISSION_DENIED / 403: your Google account needs the Owner, Editor or Firebase Admin role on $FIREBASE_PROJECT."
    echo "  - ALREADY_EXISTS / 409: $APP_ID is registered in another Firebase project, or was deleted here in the last 30 days"
    echo "    (restore it under Project settings > General > Your apps, or remove it from the other project)."
  } >&2
  die "Firebase refused to create the $1 app; paste the lines above into the thread"
}

# Write a platform's Firebase config file. apps:sdkconfig --out will not
# overwrite without an interactive prompt, so any previous file is moved to
# ~/.foundation-mobile-backup (outside the repo, where it cannot be committed).
fetch_sdkconfig() { # IOS|ANDROID appId outfile
  if [ -f "$3" ]; then
    mkdir -p "$HOME/.foundation-mobile-backup"
    mv "$3" "$HOME/.foundation-mobile-backup/$(basename "$3").$(date +%Y%m%d%H%M%S)"
  fi
  firebase apps:sdkconfig "$1" "$2" --project "$FIREBASE_PROJECT" --out "$3" >/dev/null
  [ -s "$3" ] || die "firebase apps:sdkconfig wrote nothing to $3"
}

# ---------------------------------------------------------------- doctor

cmd_doctor() {
  load_paths
  step "Mac toolchain"
  if xcodebuild -version >/dev/null 2>&1; then ok "$(xcodebuild -version | head -1)"; else bad "Xcode (install from the App Store, then: sudo xcode-select -s /Applications/Xcode.app)"; fi
  local t
  for t in brew go gomobile ruby bundle firebase jq; do
    if has "$t"; then ok "$t"; else bad "$t (scripts/mobile.sh setup)"; fi
  done
  if java_home >/dev/null; then ok "JDK 21 ($(java_home))"; else bad "JDK 21 (scripts/mobile.sh setup)"; fi
  if xcrun simctl list runtimes 2>/dev/null | grep -q '^iOS'; then ok "iOS Simulator runtime"; else bad "iOS Simulator runtime (scripts/mobile.sh setup)"; fi

  step "Android SDK ($ANDROID_HOME)"
  local pkg dir
  for pkg in "${ANDROID_PACKAGES[@]}" "$AVD_IMAGE"; do
    dir="$ANDROID_HOME/$(echo "$pkg" | tr ';' '/')"
    if [ -d "$dir" ]; then ok "$pkg"; else bad "$pkg (scripts/mobile.sh setup)"; fi
  done
  if [ -d "$HOME/.android/avd/$AVD_NAME.avd" ]; then ok "emulator $AVD_NAME"; else bad "emulator $AVD_NAME (scripts/mobile.sh setup)"; fi

  step "Project configuration"
  if [ -d ios/Frameworks/Identity.xcframework ]; then ok "Identity.xcframework"; else bad "Identity.xcframework (built by: scripts/mobile.sh ios-sim)"; fi
  if [ -f "$IOS_PLIST" ] && grep -q "$APP_ID" "$IOS_PLIST"; then ok "$IOS_PLIST"; else bad "$IOS_PLIST for $APP_ID (scripts/mobile.sh firebase)"; fi
  if [ -f "$ANDROID_JSON" ] && grep -q "$APP_ID" "$ANDROID_JSON"; then ok "$ANDROID_JSON"; else bad "$ANDROID_JSON (scripts/mobile.sh firebase)"; fi
  if grep -qs '^GOOGLE_WEB_KEY=..*' "$GRADLE_PROPS"; then ok "GOOGLE_WEB_KEY"; else bad "GOOGLE_WEB_KEY in $GRADLE_PROPS (scripts/mobile.sh firebase)"; fi
  if [ -f android/keystore.properties ] && [ -f "$(keystore_path)" ]; then ok "Android upload keystore"; else bad "android/keystore.properties + keystore (release builds only)"; fi

  step "Release credentials (~/.foundation-mobile.env)"
  if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -f "${ASC_KEY_PATH:-/nonexistent}" ]; then ok "App Store Connect API key"; else warn "App Store Connect API key (needed for ios-testflight)"; fi
  if [ -f "${PLAY_STORE_JSON_KEY:-/nonexistent}" ]; then ok "Play service-account key"; else warn "Play service-account key (needed for android-internal)"; fi

  step "Connected devices"
  local iphones
  iphones="$(ios_devices || true)"
  if [ -n "$iphones" ]; then ok "iPhone: $(echo "$iphones" | cut -f2 | paste -sd, -)"; else warn "no iPhone connected"; fi
  if has adb && adb devices | sed 1d | grep -q 'device$'; then ok "Android: $(adb devices | sed 1d | awk '$2=="device"{print $1}' | paste -sd, -)"; else warn "no Android device or emulator connected"; fi

  step "Still manual (see the release guide)"
  echo "  - Firebase console: App Check (App Attest + Play Integrity), APNs key upload"
  echo "  - Store consoles: listing text, privacy forms, screenshots, submit for review"
}

# ---------------------------------------------------------------- setup

cmd_setup() {
  step "Xcode"
  xcodebuild -version >/dev/null 2>&1 || die "Xcode missing or not selected. Install it from the App Store, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  ok "$(xcodebuild -version | head -1)"
  if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    echo "  Finishing Xcode first-launch setup (asks for your password)..."
    sudo xcodebuild -license accept
    sudo xcodebuild -runFirstLaunch
  fi
  if ! xcrun simctl list runtimes 2>/dev/null | grep -q '^iOS'; then
    echo "  Downloading the iOS Simulator runtime (several GB)..."
    xcodebuild -downloadPlatform iOS
  fi
  ok "iOS Simulator runtime"

  step "Homebrew"
  if ! has brew && [ ! -x "$(brew_prefix)/bin/brew" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  load_paths
  ok "$(brew --version | head -1)"

  step "Command-line tools (go, ruby, jq, firebase, JDK 21, Android SDK tools)"
  brew install go ruby jq firebase-cli openjdk@21
  brew install --cask android-commandlinetools
  if [ ! -d "/Applications/Android Studio.app" ]; then
    brew install --cask android-studio
  fi
  load_paths
  ok "done"

  step "gomobile (builds the identity SDK)"
  has gomobile || go install golang.org/x/mobile/cmd/gomobile@latest
  go install golang.org/x/mobile/cmd/gobind@latest
  gomobile init
  ok "gomobile"

  step "Ruby gems (bundler + fastlane for both apps)"
  has bundle || gem install bundler --no-document
  (cd ios && bundle install)
  (cd android && bundle install)
  ok "fastlane"

  step "Android SDK packages into $ANDROID_HOME"
  use_java
  local sdkm; sdkm="$(sdkmanager_bin)" || die "sdkmanager not found after install"
  mkdir -p "$ANDROID_HOME"
  yes | "$sdkm" --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
  "$sdkm" --sdk_root="$ANDROID_HOME" --install "${ANDROID_PACKAGES[@]}" "$AVD_IMAGE"
  if ! grep -qs '^sdk.dir=' android/local.properties; then
    echo "sdk.dir=$ANDROID_HOME" >> android/local.properties
  fi
  ok "SDK packages"

  step "Emulator $AVD_NAME"
  if [ ! -d "$HOME/.android/avd/$AVD_NAME.avd" ]; then
    local avdm; avdm="$(avdmanager_bin)"
    # Newer device profiles first; older cmdline-tools lack pixel_8.
    echo no | ANDROID_SDK_ROOT="$ANDROID_HOME" "$avdm" create avd -n "$AVD_NAME" -k "$AVD_IMAGE" -d pixel_8 --force 2>/dev/null \
      || echo no | ANDROID_SDK_ROOT="$ANDROID_HOME" "$avdm" create avd -n "$AVD_NAME" -k "$AVD_IMAGE" -d pixel_6 --force
  fi
  ok "$AVD_NAME"

  step "Shell profile"
  # shellcheck disable=SC2016 # written literally into the profile
  local line='export PATH="$HOME/go/bin:$PATH"' profile="$HOME/.zprofile"
  grep -qsF "$line" "$profile" || echo "$line" >> "$profile"
  ok "go/bin on PATH in $profile"

  printf '\n%sSetup complete.%s Next: scripts/mobile.sh firebase\n' "$G" "$N"
}

# ---------------------------------------------------------------- firebase

cmd_firebase() {
  load_paths
  has firebase || die "firebase CLI missing - run: scripts/mobile.sh setup"
  has jq || die "jq missing - run: scripts/mobile.sh setup"
  step "Firebase login"
  firebase projects:list --json >/dev/null 2>&1 || firebase login
  ok "logged in; project $FIREBASE_PROJECT"

  step "iOS app"
  local ios_id
  ios_id="$(ensure_firebase_app IOS)"
  fetch_sdkconfig IOS "$ios_id" "$IOS_PLIST"
  ok "$IOS_PLIST ($ios_id)"

  step "Android app"
  local and_id
  and_id="$(ensure_firebase_app ANDROID)"

  step "Android SHA-256 fingerprints (Google sign-in for Drive backup, Play Integrity)"
  use_java
  local shas="" s
  if [ ! -f "$HOME/.android/debug.keystore" ]; then
    mkdir -p "$HOME/.android"
    "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$HOME/.android/debug.keystore" -storepass android \
      -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
  fi
  PATH="$JAVA_HOME/bin:$PATH"
  s="$(sha256_of "$HOME/.android/debug.keystore" androiddebugkey android)"; [ -n "$s" ] && shas="$shas $s"
  if [ -f android/keystore.properties ]; then
    s="$(sha256_of "$(keystore_path)" "$(keystore_prop keyAlias)" "$(keystore_prop storePassword)")"
    [ -n "$s" ] && shas="$shas $s"
  fi
  [ -n "${PLAY_APP_SIGNING_SHA256:-}" ] && shas="$shas $PLAY_APP_SIGNING_SHA256"
  local existing
  existing="$(firebase apps:android:sha:list "$and_id" --project "$FIREBASE_PROJECT" 2>/dev/null | tr 'a-f' 'A-F' || true)"
  for s in $shas; do
    if echo "$existing" | tr -d ':' | grep "$(echo "$s" | tr -d ':' | tr 'a-f' 'A-F')" >/dev/null; then
      ok "already registered: $s"
    else
      # The API takes bare hex; keytool prints colon-separated uppercase.
      firebase apps:android:sha:create "$and_id" "$(echo "$s" | tr -d ':' | tr 'A-F' 'a-f')" --project "$FIREBASE_PROJECT" >/dev/null
      ok "registered: $s"
    fi
  done
  [ -z "${PLAY_APP_SIGNING_SHA256:-}" ] && warn "Play app signing key not added: copy its SHA-256 from Play Console > App integrity, set PLAY_APP_SIGNING_SHA256 in $ENV_FILE and re-run"

  # Re-fetch after the fingerprints so the OAuth clients they create are included.
  fetch_sdkconfig ANDROID "$and_id" "$ANDROID_JSON"
  ok "$ANDROID_JSON ($and_id)"

  step "GOOGLE_WEB_KEY (Drive backup)"
  local web
  web="$(jq -r '[.client[]?.oauth_client[]? | select(.client_type == 3) | .client_id][0] // empty' "$ANDROID_JSON")"
  if [ -n "$web" ]; then
    mkdir -p "$(dirname "$GRADLE_PROPS")"; touch "$GRADLE_PROPS"
    grep -v '^GOOGLE_WEB_KEY=' "$GRADLE_PROPS" > "$GRADLE_PROPS.tmp" || true
    echo "GOOGLE_WEB_KEY=$web" >> "$GRADLE_PROPS.tmp"
    mv "$GRADLE_PROPS.tmp" "$GRADLE_PROPS"
    ok "written to $GRADLE_PROPS"
  else
    warn "no web OAuth client yet: enable Google under Authentication > Sign-in method in the Firebase console, then re-run"
  fi

  step "Left for the Firebase console (no CLI for these)"
  echo "  - App Check: register App Attest (iOS) and Play Integrity (Android):"
  echo "    https://console.firebase.google.com/project/$FIREBASE_PROJECT/appcheck"
  echo "  - Cloud Messaging: upload your APNs .p8 key (team $TEAM_ID):"
  echo "    https://console.firebase.google.com/project/$FIREBASE_PROJECT/settings/cloudmessaging"
  echo "  - After the first simulator/emulator launch, add the App Check debug token it logs."
}

# ---------------------------------------------------------------- iOS

ensure_identity_sdk() {
  if [ ! -d ios/Frameworks/Identity.xcframework ]; then
    step "Building Identity.xcframework (first time only)"
    load_paths
    (cd ios && ./prebuild.sh)
  fi
}
ensure_ios_config() {
  [ -f "$IOS_PLIST" ] || die "$IOS_PLIST missing - run: scripts/mobile.sh firebase"
}

# Connected physical iPhones as "udid<TAB>name" lines.
ios_devices() {
  xcrun xctrace list devices 2>/dev/null \
    | awk '/^== Devices ==/{on=1; next} /^==/{on=0} on' \
    | grep -E '\([0-9]+(\.[0-9]+)*\) \([0-9A-Fa-f-]+\)$' \
    | sed -E 's/^(.*) \(([0-9.]+)\) \(([0-9A-Fa-f-]+)\)$/\3	\1/' || true
}

cmd_ios_sim() {
  ensure_ios_config
  ensure_identity_sdk
  ./scripts/run-ios-simulator.sh "${1:-iPhone 17 Pro}"
  echo "  Passport NFC and proving do not run on the simulator; use: scripts/mobile.sh ios-device"
}

cmd_ios_device() {
  ensure_ios_config
  ensure_identity_sdk
  local udid="${IOS_DEVICE_ID:-}" name
  if [ -z "$udid" ]; then
    udid="$(ios_devices | head -1 | cut -f1)"
    name="$(ios_devices | head -1 | cut -f2)"
    [ -n "$udid" ] || die "no iPhone found. Connect it by USB, unlock it, tap Trust, and turn on Settings > Privacy & Security > Developer Mode."
  fi
  step "Building for ${name:-$udid} (automatic signing, team $TEAM_ID)"
  xcodebuild build \
    -project "$IOS_PROJECT" -scheme FoundationMobile \
    -destination "platform=iOS,id=$udid" \
    -derivedDataPath build/ios-device \
    -allowProvisioningUpdates -skipMacroValidation \
    | { if has xcbeautify; then xcbeautify; else cat; fi; }
  local app
  app="$(find build/ios-device/Build/Products -maxdepth 2 -name FoundationMobile.app -path '*iphoneos*' | head -1)"
  [ -n "$app" ] || die "built app not found under build/ios-device"
  step "Installing and launching"
  xcrun devicectl device install app --device "$udid" "$app"
  xcrun devicectl device process launch --device "$udid" "$APP_ID" \
    || warn "installed, but launch failed. If the phone says Untrusted Developer: Settings > General > VPN & Device Management > trust, then open the app."
  ok "running on ${name:-$udid}"
}

cmd_ios_create_app() {
  load_paths
  [ -n "${FASTLANE_APPLE_ID:-}" ] || die "set FASTLANE_APPLE_ID (your Apple ID email) in $ENV_FILE"
  local name="${1:-Foundation}"
  step "Creating App Store Connect record \"$name\" for $APP_ID (Apple ID login + 2FA prompt)"
  bundle_exec ios fastlane produce \
    --username "$FASTLANE_APPLE_ID" --app_identifier "$APP_ID" --team_id "$TEAM_ID" \
    --app_name "$name" --sku foundation-mobile --language English --platform ios
}

cmd_ios_testflight() {
  load_paths
  ensure_ios_config
  [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -f "${ASC_KEY_PATH:-/nonexistent}" ] \
    || die "App Store Connect API key not configured - see the header of this script ($ENV_FILE)"
  bundle_exec ios fastlane beta
}

cmd_ios_metadata() {
  load_paths
  [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -f "${ASC_KEY_PATH:-/nonexistent}" ] \
    || die "App Store Connect API key not configured - see the header of this script ($ENV_FILE)"
  bundle_exec ios fastlane metadata
}

# ---------------------------------------------------------------- Android

ensure_android_config() {
  [ -f "$ANDROID_JSON" ] || die "$ANDROID_JSON missing - run: scripts/mobile.sh firebase"
  grep -qs '^sdk.dir=' android/local.properties || echo "sdk.dir=$ANDROID_HOME" >> android/local.properties
}

android_launch() { # serial
  adb -s "$1" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
}

android_install() { # serial
  use_java
  step "Building and installing debug on $1"
  (cd android && ANDROID_SERIAL="$1" ./gradlew :app:installDebug)
  android_launch "$1"
  ok "running on $1 (App Check debug token: adb logcat | grep -i 'debug token')"
}

cmd_android_emulator() {
  load_paths
  ensure_android_config
  local serial
  serial="$(adb devices | sed 1d | awk '$1 ~ /^emulator-/ && $2=="device"{print $1; exit}')"
  if [ -z "$serial" ]; then
    [ -d "$HOME/.android/avd/$AVD_NAME.avd" ] || die "emulator $AVD_NAME missing - run: scripts/mobile.sh setup"
    step "Booting $AVD_NAME"
    nohup "$ANDROID_HOME/emulator/emulator" -avd "$AVD_NAME" -netdelay none -netspeed full >/tmp/foundation-emulator.log 2>&1 &
    local tries=0
    until serial="$(adb devices | sed 1d | awk '$1 ~ /^emulator-/{print $1; exit}')"; [ -n "$serial" ]; do
      tries=$((tries + 1)); [ "$tries" -lt 90 ] || die "emulator did not start (see /tmp/foundation-emulator.log)"
      sleep 2
    done
    until [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
    ok "booted $serial"
  fi
  android_install "$serial"
}

cmd_android_device() {
  load_paths
  ensure_android_config
  local serial="${ANDROID_SERIAL:-}"
  [ -n "$serial" ] || serial="$(adb devices | sed 1d | awk '$1 !~ /^emulator-/ && $2=="device"{print $1; exit}')"
  if [ -z "$serial" ]; then
    adb devices | sed 1d | grep -q unauthorized && die "phone connected but not authorized: accept 'Allow USB debugging?' on the phone"
    die "no Android phone found. Settings > About phone > tap Build number 7 times, then Developer options > USB debugging, and connect by USB."
  fi
  android_install "$serial"
}

cmd_android_bundle() {
  load_paths
  ensure_android_config
  use_java
  [ -f android/keystore.properties ] || die "android/keystore.properties missing (release signing)"
  local code="${1:-}"
  [ -n "$code" ] || die "pass a versionCode higher than any uploaded to Play, e.g.: scripts/mobile.sh android-bundle 3 (or use android-internal, which picks it)"
  (cd android && ./gradlew :app:bundleRelease -PVERSION_CODE="$code")
  ok "android/app/build/outputs/bundle/release/app-release.aab (versionCode $code)"
}

cmd_android_internal() {
  load_paths
  ensure_android_config
  use_java
  [ -f "${PLAY_STORE_JSON_KEY:-/nonexistent}" ] || die "PLAY_STORE_JSON_KEY not configured - see the header of this script ($ENV_FILE)"
  bundle_exec android fastlane internal
  echo "  Uploaded as a draft: Play Console > Internal testing > Review release > Start rollout."
}

cmd_android_metadata() {
  load_paths
  [ -f "${PLAY_STORE_JSON_KEY:-/nonexistent}" ] || die "PLAY_STORE_JSON_KEY not configured - see the header of this script ($ENV_FILE)"
  bundle_exec android fastlane metadata
}

cmd_backup_keys() {
  local dest="${1:-}"
  [ -n "$dest" ] || die "usage: scripts/mobile.sh backup-keys <directory outside the repo, e.g. iCloud Drive>"
  [ -f android/keystore.properties ] || die "android/keystore.properties not found"
  local store; store="$(keystore_path)"
  [ -f "$store" ] || die "$store not found"
  local out; out="$dest/foundation-mobile-upload-key-$(date +%Y%m%d)"
  mkdir -p "$out"
  cp "$store" android/keystore.properties "$out/"
  chmod 600 "$out"/*
  ok "copied to $out (keep it private: it holds the keystore passwords)"
}

# ---------------------------------------------------------------- main

usage() { sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-}" in
  doctor)            cmd_doctor ;;
  setup)             cmd_setup ;;
  firebase)          cmd_firebase ;;
  ios-sim)           shift; cmd_ios_sim "$@" ;;
  ios-device)        cmd_ios_device ;;
  ios-create-app)    shift; cmd_ios_create_app "$@" ;;
  ios-testflight)    cmd_ios_testflight ;;
  ios-metadata)      cmd_ios_metadata ;;
  android-emulator)  cmd_android_emulator ;;
  android-device)    cmd_android_device ;;
  android-bundle)    shift; cmd_android_bundle "$@" ;;
  android-internal)  cmd_android_internal ;;
  android-metadata)  cmd_android_metadata ;;
  backup-keys)       shift; cmd_backup_keys "$@" ;;
  ""|-h|--help|help) usage ;;
  *) usage; die "unknown command: $1" ;;
esac
