#!/bin/sh
set -e

# Per-profile launch-screen logo swap.
#
# The launch screen (LaunchScreen.storyboard) renders BEFORE any app code
# runs, from a pre-rendered snapshot, so it can only use images baked into
# the compiled asset catalog (Assets.car) — it cannot read the profile JSON
# at runtime the way the in-app hero/logo do. The only way to white-label it
# is to swap the source PNGs in LaunchLogo.imageset BEFORE the asset catalog
# is compiled. That's why this script runs as an EARLY build phase (ahead of
# the Resources/asset-compile phase), separate from select-profile.sh which
# bakes the JSON after compilation.
#
# Source of truth: Resources/launch-logos/<brand>/LaunchLogo{,@2x,@3x}.png.
# Convention: <brand> == the active profile id; falls back to "foundation"
# when a profile ships no brand-specific launch logo. The committed contents
# of LaunchLogo.imageset match the "foundation" brand, so a default build is
# a byte-identical no-op (git stays clean). Building a branded profile (e.g.
# mDL-NYC-MoMA) overwrites the imageset PNGs; building a default profile
# restores them.

PROFILE="${FOUNDATION_PROFILE:-hisec-global}"
LOGOS_ROOT="${SRCROOT}/FoundationMobile/Resources/launch-logos"
IMAGESET="${SRCROOT}/FoundationMobile/Images.xcassets/LaunchLogo.imageset"

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
