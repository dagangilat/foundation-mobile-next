#!/usr/bin/env bash
# Ship Foundation Mobile to the stores: iOS to TestFlight, Android to Play
# internal testing (as a draft). Thin wrapper over scripts/mobile.sh, which
# owns the real steps (fastlane beta / internal lanes); this adds the shared
# pre-flight, a plan, a confirmation and --dry-run. Run with --help.
#
# Written for macOS with the system bash (3.2), like scripts/mobile.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

DEFAULT_BRANCH="main"
ENV_FILE="$HOME/.foundation-mobile.env"

if [ -t 1 ]; then B=$'\033[1m'; R=$'\033[31m'; Y=$'\033[33m'; N=$'\033[0m'; else B=; R=; Y=; N=; fi
info() { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
warn() { printf '%swarn:%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: scripts/deploy.sh [target ...] [--yes] [--dry-run] [--help]

No target = ship both apps, the way they ship today:
  ios       fastlane beta via `scripts/mobile.sh ios-testflight`: brand-sweep ratchet,
            Identity SDK prebuild, archive the Production scheme with build number
            (latest TestFlight + 1), upload to TestFlight
  android   fastlane internal via `scripts/mobile.sh android-internal`: brand-sweep ratchet,
            clean + signed release bundle with versionCode (highest on Play + 1),
            upload to Play internal testing as a draft (PLAY_RELEASE_STATUS overrides)

Other targets:
  ios-metadata       App Store listing text (scripts/mobile.sh ios-metadata)
  android-metadata   Play listing text + icon (scripts/mobile.sh android-metadata)
  metadata           both of the above

Options:
  --yes, -y    do not ask Deploy? [y/N] (CI=1 does the same)
  --dry-run    print the plan and the commands, run nothing
  --help, -h   this text

There is no CI deploy: android-ci only builds and tests. Store credentials come
from ~/.foundation-mobile.env (see the header of scripts/mobile.sh):
ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH for iOS; PLAY_STORE_JSON_KEY plus
android/keystore.properties for Android. First-time machine setup:
scripts/mobile.sh setup && scripts/mobile.sh firebase (scripts/mobile.sh doctor shows gaps).
EOF
}

DRY_RUN=0
ASSUME_YES=0
TARGETS=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -y|--yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    ios|android|ios-metadata|android-metadata) TARGETS="$TARGETS $1" ;;
    metadata) TARGETS="$TARGETS ios-metadata android-metadata" ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
  shift
done
[ -n "$TARGETS" ] || TARGETS=" ios android"
has() { case " $TARGETS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

ask() {
  if [ "$ASSUME_YES" = "1" ] || [ -n "${CI:-}" ]; then return 0; fi
  [ -t 0 ] || { warn "no terminal to ask on; pass --yes to continue."; return 1; }
  local reply; printf '%s [y/N] ' "$1"; read -r reply || reply=""
  case "$reply" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}

IOS_VERSION="$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/p' ios/FoundationMobile.xcodeproj/project.pbxproj 2>/dev/null | head -1)"
ANDROID_VERSION="$(sed -n 's/.*versionName = "\([^"]*\)".*/\1/p' android/app/build.gradle.kts 2>/dev/null | head -1)"

STEPS=""; CMDS=""
add() { STEPS="$STEPS
  - $1"; CMDS="$CMDS
  $2"; }
has ios && add "iOS ${IOS_VERSION:-?} -> TestFlight (com.foundationnext.mobile, team F9F26FQW95; fresh archive)" "scripts/mobile.sh ios-testflight"
has android && add "Android ${ANDROID_VERSION:-?} -> Play internal testing, ${PLAY_RELEASE_STATUS:-draft} (fresh clean bundle)" "scripts/mobile.sh android-internal"
has ios-metadata && add "App Store listing text (ios/fastlane/metadata)" "scripts/mobile.sh ios-metadata"
has android-metadata && add "Play listing text + icon (android/fastlane/metadata/android)" "scripts/mobile.sh android-metadata"

print_plan() {
  printf '\n%sDeploy plan%s  commit %s on %s\n%s\n\nCommands:%s\n\n' "$B" "$N" \
    "$(git rev-parse --short HEAD 2>/dev/null || echo '?')" \
    "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')" "$STEPS" "$CMDS"
}

if [ "$DRY_RUN" = "1" ]; then
  print_plan
  echo "(dry run: nothing was checked or deployed)"
  exit 0
fi

# ── Pre-flight ───────────────────────────────────────────────────────
if { has ios || has ios-metadata; } && [ "$(uname -s)" != "Darwin" ]; then die "iOS targets need macOS with Xcode."; fi
missing=""
command -v git >/dev/null 2>&1 || missing="$missing git"
if has ios; then command -v xcodebuild >/dev/null 2>&1 || missing="$missing xcodebuild"; fi
[ -z "$missing" ] || die "missing:$missing -> run: scripts/mobile.sh setup (toolchains, Android SDK, fastlane gems); Xcode from the App Store"

# Same credential checks mobile.sh makes, done up front so nothing half-ships.
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"
if has ios || has ios-metadata; then
  if [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_ISSUER_ID:-}" ] || [ ! -f "${ASC_KEY_PATH:-/nonexistent}" ]; then die "App Store Connect API key not set: put ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH in $ENV_FILE (see scripts/mobile.sh header)"; fi
fi
if has ios; then
  [ -f ios/FoundationMobile/GoogleService-Info.plist ] || die "ios/FoundationMobile/GoogleService-Info.plist missing - run: scripts/mobile.sh firebase"
fi
if has android || has android-metadata; then
  [ -f "${PLAY_STORE_JSON_KEY:-/nonexistent}" ] || die "PLAY_STORE_JSON_KEY not set to a file: put it in $ENV_FILE (see scripts/mobile.sh header)"
fi
if has android; then
  [ -f android/app/google-services.json ] || die "android/app/google-services.json missing - run: scripts/mobile.sh firebase"
  [ -f android/keystore.properties ] || die "android/keystore.properties missing (release signing key; see docs/android-local-setup.md)"
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  git fetch origin --quiet 2>/dev/null || warn "git fetch failed; comparing against the last-known origin."
  problems=""
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [ "$branch" = "$DEFAULT_BRANCH" ] || problems="$problems
  - on branch '$branch', not '$DEFAULT_BRANCH'"
  [ -z "$(git status --porcelain)" ] || problems="$problems
  - working tree has uncommitted changes (they WILL be built and shipped)"
  behind="$(git rev-list --count "HEAD..origin/$DEFAULT_BRANCH" 2>/dev/null || echo 0)"
  [ "$behind" = "0" ] || problems="$problems
  - HEAD is $behind commit(s) behind origin/$DEFAULT_BRANCH"
  if [ -n "$problems" ]; then
    warn "git state:$problems"
    ask "Continue anyway?" || die "aborted."
  fi
fi

print_plan
ask "Deploy?" || die "aborted."

# ── Deploy ───────────────────────────────────────────────────────────
DONE=""; FAILED=""
step_run() { # step_run <label> <mobile.sh command>
  info "$1"
  if scripts/mobile.sh "$2"; then DONE="$DONE
  - $1"; else FAILED="$FAILED
  - $1"; fi
}
has ios && step_run "iOS -> TestFlight" ios-testflight
has android && step_run "Android -> Play internal" android-internal
has ios-metadata && step_run "App Store listing" ios-metadata
has android-metadata && step_run "Play listing" android-metadata

printf '\n%sShipped:%s%s\n' "$B" "$N" "${DONE:-
  (nothing)}"
if has ios; then
  [ -f ios/build/FoundationMobile.ipa ] && echo "  ipa: ios/build/FoundationMobile.ipa"
  echo "  TestFlight (processing takes a few minutes): https://appstoreconnect.apple.com/apps"
fi
if has android; then
  [ -f android/app/build/outputs/bundle/release/app-release.aab ] && echo "  aab: android/app/build/outputs/bundle/release/app-release.aab"
  echo "  Play Console > Internal testing > Review release > Start rollout: https://play.google.com/console"
fi
if [ -n "$FAILED" ]; then
  printf '\n%sFailed:%s%s\n' "$R" "$N" "$FAILED" >&2
  exit 1
fi
