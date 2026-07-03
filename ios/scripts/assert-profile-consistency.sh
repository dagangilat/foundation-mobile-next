#!/bin/sh
set -eu

# assert-profile-consistency.sh — build-time guard against profile divergence.
#
# Two build phases white-label the app from a single FOUNDATION_PROFILE setting:
#   select-profile.sh      bakes Resources/profiles/<id>.json into the bundle
#                          as foundationmobile.json (the app's feature/security
#                          config), and
#   select-launch-logo.sh  swaps the LaunchScreen logo + background assets.
# If the two ever resolve FOUNDATION_PROFILE to DIFFERENT ids, an Archive ships
# one edition's content behind another edition's launch screen (the exact bug
# that a Release config missing FOUNDATION_PROFILE produced: bundle=hisec-global,
# launch screen=moma).
#
# This script runs as the LAST build phase (after both of the above) and
# INDEPENDENTLY re-derives what each of them would resolve to, given the current
# FOUNDATION_PROFILE env var and project state, then fails the build if they
# diverge. It deliberately does NOT touch either existing script — pure
# defense-in-depth so a future config that unsets FOUNDATION_PROFILE, or a drift
# in one script's default, fails loudly at build time instead of silently
# shipping a mismatched Archive.
#
# The two resolution rules below are kept in hand-sync with the scripts:
#   select-profile.sh:      PROFILE="${FOUNDATION_PROFILE:-hisec-global}"
#   select-launch-logo.sh:  FOUNDATION_PROFILE, else first FOUNDATION_PROFILE
#                           value found in project.pbxproj, else hisec-global.

DEFAULT_PROFILE="hisec-global"

# Locate the project root the same way both scripts do: SRCROOT under Xcode,
# else derived from this script's location (scripts/ sits under the ios/ root).
if [ -n "${SRCROOT:-}" ]; then
    PROJECT_ROOT="$SRCROOT"
else
    SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
fi
PBXPROJ="${PROJECT_ROOT}/FoundationMobile.xcodeproj/project.pbxproj"

# --- Re-derive select-profile.sh's resolution (its Xcode build-phase mode). ---
PROFILE_JSON="${FOUNDATION_PROFILE:-$DEFAULT_PROFILE}"

# --- Re-derive select-launch-logo.sh's resolution. ---
LAUNCH_LOGO="${FOUNDATION_PROFILE:-}"
if [ -z "$LAUNCH_LOGO" ] && [ -f "$PBXPROJ" ]; then
    # Matches quoted or bare values; head -n1 mirrors the script picking the
    # FIRST FOUNDATION_PROFILE line in the file (the divergence trap).
    LAUNCH_LOGO=$(sed -n -E 's/^[[:space:]]*FOUNDATION_PROFILE[[:space:]]*=[[:space:]]*"?([A-Za-z0-9_.-]+)"?;.*/\1/p' "$PBXPROJ" | head -n1)
fi
LAUNCH_LOGO="${LAUNCH_LOGO:-$DEFAULT_PROFILE}"

if [ "$PROFILE_JSON" != "$LAUNCH_LOGO" ]; then
    echo "error: Foundation profile divergence — the app bundle and the launch screen would ship different editions." >&2
    echo "error:   select-profile.sh      would bake:  ${PROFILE_JSON}.json (foundationmobile.json)" >&2
    echo "error:   select-launch-logo.sh  would brand: ${LAUNCH_LOGO} (launch logo + background)" >&2
    echo "error: Set FOUNDATION_PROFILE explicitly in this build configuration" >&2
    echo "error: (e.g. FOUNDATION_PROFILE = \"${DEFAULT_PROFILE}\";) so both build phases receive the same value." >&2
    exit 1
fi

echo "Foundation profile consistency OK: ${PROFILE_JSON} (bundle == launch screen)"
