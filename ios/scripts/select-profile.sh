#!/bin/sh
set -e

PROFILE="${FOUNDATION_PROFILE:-hisec-global}"
SRC="${SRCROOT}/FoundationMobile/Resources/profiles/${PROFILE}.json"
DST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/foundationmobile.json"

if [ ! -f "$SRC" ]; then
    echo "error: Foundation profile JSON not found: $SRC" >&2
    echo "error: Valid profiles: hisec-global, standardsec, lowsec-attest, mDL-NYC-MoMA" >&2
    exit 1
fi

cp "$SRC" "$DST"
echo "Bundled Foundation profile: $PROFILE → foundationmobile.json"
