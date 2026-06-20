#!/bin/sh
set -e

# Per-profile launch-screen asset swap (logo mark + background color).
#
# The launch screen (LaunchScreen.storyboard) renders BEFORE any app code
# runs, from a pre-rendered snapshot, so it can only use assets baked into
# the compiled asset catalog (Assets.car) — it cannot read the profile JSON
# at runtime the way the in-app hero/logo do. The only way to white-label it
# is to swap the source assets BEFORE the asset catalog is compiled. That's
# why this script runs as an EARLY build phase (ahead of the Resources/
# asset-compile phase), separate from select-profile.sh which bakes the JSON
# after compilation.
#
# The storyboard shows a single centered LaunchLogo mark on a full-bleed
# LaunchBackground color. Both are swapped here so the splash matches the
# edition (e.g. MoMA = light bg + MoMA mark; Foundation = midnight bg +
# Foundation mark).
#
# Sources of truth:
#   Resources/launch-logos/<brand>/LaunchLogo{,@2x,@3x}.png
#   Resources/launch-backgrounds/<brand>/Contents.json   (a .colorset payload)
# Convention: <brand> == the active profile id; each falls back to
# "foundation" when a profile ships no brand-specific asset. The committed
# contents of LaunchLogo.imageset and LaunchBackground.colorset match the
# "foundation" brand, so a default build is a byte-identical no-op (git stays
# clean). Building a branded profile (e.g. MoMA) overwrites them; building a
# default profile restores them.

# Locate the project. Under Xcode, SRCROOT points at the ios/ dir. Run from a
# terminal it's empty, so derive it from this script's location (scripts/ lives
# directly under the project root) — letting the tool work from any directory,
# matching select-profile.sh.
if [ -z "${SRCROOT:-}" ]; then
    SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    SRCROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
fi

# Pick the profile. Xcode sets FOUNDATION_PROFILE from the build settings. From
# the CLI it's usually unset, so fall back to the profile currently selected in
# the Xcode project (so a manual run mirrors what the next build would do)
# before finally defaulting to hisec-global.
PROFILE="${FOUNDATION_PROFILE:-}"
if [ -z "$PROFILE" ]; then
    PBXPROJ="${SRCROOT}/FoundationMobile.xcodeproj/project.pbxproj"
    if [ -f "$PBXPROJ" ]; then
        # Xcode quotes hyphenated values (e.g. "tel-aviv"); match quoted or bare.
        PROFILE=$(sed -n -E 's/^[[:space:]]*FOUNDATION_PROFILE[[:space:]]*=[[:space:]]*"?([A-Za-z0-9_.-]+)"?;.*/\1/p' "$PBXPROJ" | head -n1)
    fi
fi
PROFILE="${PROFILE:-hisec-global}"

LOGOS_ROOT="${SRCROOT}/FoundationMobile/Resources/launch-logos"
BACKGROUNDS_ROOT="${SRCROOT}/FoundationMobile/Resources/launch-backgrounds"
IMAGESET="${SRCROOT}/FoundationMobile/Images.xcassets/LaunchLogo.imageset"
COLORSET="${SRCROOT}/FoundationMobile/Images.xcassets/LaunchBackground.colorset"

# --- Launch logo mark ---
BRAND_DIR="${LOGOS_ROOT}/${PROFILE}"
if [ ! -d "$BRAND_DIR" ]; then
    BRAND_DIR="${LOGOS_ROOT}/foundation"
fi

if [ ! -f "${BRAND_DIR}/LaunchLogo.png" ]; then
    echo "error: launch logo source missing: ${BRAND_DIR}/LaunchLogo.png" >&2
    exit 1
fi

cp "${BRAND_DIR}/LaunchLogo.png"     "${IMAGESET}/LaunchLogo.png"
cp "${BRAND_DIR}/LaunchLogo@2x.png"  "${IMAGESET}/LaunchLogo@2x.png"
cp "${BRAND_DIR}/LaunchLogo@3x.png"  "${IMAGESET}/LaunchLogo@3x.png"
echo "Launch logo brand: $(basename "$BRAND_DIR") → LaunchLogo.imageset"

# --- Launch background color ---
BG_DIR="${BACKGROUNDS_ROOT}/${PROFILE}"
if [ ! -d "$BG_DIR" ]; then
    BG_DIR="${BACKGROUNDS_ROOT}/foundation"
fi

if [ ! -f "${BG_DIR}/Contents.json" ]; then
    echo "error: launch background source missing: ${BG_DIR}/Contents.json" >&2
    exit 1
fi

cp "${BG_DIR}/Contents.json" "${COLORSET}/Contents.json"
echo "Launch background brand: $(basename "$BG_DIR") → LaunchBackground.colorset"
