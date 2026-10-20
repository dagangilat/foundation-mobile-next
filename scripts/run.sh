#!/usr/bin/env bash
# Run Foundation Mobile locally. Default: build and launch in the iOS
# Simulator (no phone, no store, nothing shipped). Thin wrapper over
# scripts/mobile.sh, which owns the real steps. Run with --help.
#
# Written for macOS with the system bash (3.2), like scripts/mobile.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF2'
Usage: scripts/run.sh [mode] [simulator name] [--help]

Modes:
  ios-sim [name]     (default) build + launch in the iOS Simulator (default "iPhone 17 Pro").
                     Passport NFC and proving need a real phone.
  ios-device         build + install + launch on a USB iPhone
  android-emulator   boot the FoundationPixel emulator, install debug, launch
  android-device     install debug + launch on a USB Android phone
  test               Android debug build + unit tests (what android-ci runs)
  doctor             what is installed / configured / missing (scripts/mobile.sh doctor)

The app talks to the real foundation-next-app Firebase project in every mode;
there is no emulator backend for it. First-time machine setup:
scripts/mobile.sh setup && scripts/mobile.sh firebase.
EOF2
}

MODE="ios-sim"
ARGS=""
case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  "") ;;
  ios-sim|ios-device|android-emulator|android-device|test|doctor) MODE="$1"; shift; ARGS="${1:-}" ;;
  *) usage >&2; die "unknown mode: $1" ;;
esac

case "$MODE" in
  ios-sim)
    [ "$(uname -s)" = "Darwin" ] || die "the iOS Simulator needs macOS; try: scripts/run.sh android-emulator"
    command -v xcrun >/dev/null 2>&1 || die "Xcode command line tools not found - install Xcode, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    if [ -n "$ARGS" ]; then exec scripts/mobile.sh ios-sim "$ARGS"; else exec scripts/mobile.sh ios-sim; fi
    ;;
  ios-device|android-emulator|android-device|doctor)
    exec scripts/mobile.sh "$MODE"
    ;;
  test)
    [ -f android/app/google-services.json ] || die "android/app/google-services.json missing - run: scripts/mobile.sh firebase"
    export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    # JDK 21 for Gradle (same lookup as scripts/mobile.sh).
    if [ -z "${JAVA_HOME:-}" ]; then
      studio="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
      brewjdk="$( (brew --prefix 2>/dev/null || echo /opt/homebrew) )/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
      if [ -x "$studio/bin/java" ] && "$studio/bin/java" -version 2>&1 | grep -q '"21'; then export JAVA_HOME="$studio"
      elif [ -x "$brewjdk/bin/java" ]; then export JAVA_HOME="$brewjdk"
      fi
    fi
    command -v java >/dev/null 2>&1 || [ -n "${JAVA_HOME:-}" ] || die "JDK 21 not found - run: scripts/mobile.sh setup"
    grep -qs '^sdk.dir=' android/local.properties || [ -d "$ANDROID_HOME" ] || die "Android SDK not found at $ANDROID_HOME - run: scripts/mobile.sh setup"
    cd android && exec ./gradlew :app:assembleDebug :app:testDebugUnitTest
    ;;
esac
