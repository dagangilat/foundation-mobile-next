#!/bin/sh
# Xcode Run Script Build Phase. Picks one Foundation security profile and
# bakes its JSON into the app bundle as `foundationmobile.json`. AppConfig.shared
# fails loud at launch if this file is missing or malformed, so do not silently
# fall back here either — bail with a non-zero exit if anything is off.
#
# Set FOUNDATION_PROFILE in the scheme env / xcconfig / Xcode Cloud workflow.
# Default: hisec-global.

set -e

PROFILE="${FOUNDATION_PROFILE:-hisec-global}"

case "$PROFILE" in
  hisec-global|standardsec|lowsec-attest)
    ;;
  *)
    echo "error: unknown FOUNDATION_PROFILE=\"$PROFILE\". valid: hisec-global, standardsec, lowsec-attest" >&2
    exit 1
    ;;
esac

SRC="${SRCROOT}/FoundationMobile/Resources/profiles/${PROFILE}.json"
DST_DIR="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
DST="${DST_DIR}/foundationmobile.json"

if [ ! -f "$SRC" ]; then
  echo "error: profile JSON not found at $SRC" >&2
  exit 1
fi

mkdir -p "$DST_DIR"
cp "$SRC" "$DST"

echo "[select-profile] FOUNDATION_PROFILE=${PROFILE} → ${DST#${BUILT_PRODUCTS_DIR}/}"
