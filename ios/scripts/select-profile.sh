#!/bin/sh
set -eu

# select-profile.sh — choose / bundle the active Foundation Mobile profile.
#
# A "profile" is a white-label edition. Each lives as a single JSON payload in
#   FoundationMobile/Resources/profiles/<id>.json
# and is selected via the Xcode build setting FOUNDATION_PROFILE. That one
# setting drives BOTH build phases: this script (bakes <id>.json into the app
# bundle as foundationmobile.json) and select-launch-logo.sh (swaps the splash
# assets). Release builds leave FOUNDATION_PROFILE unset and fall back to the
# DEFAULT_PROFILE below.
#
# This script runs in two modes:
#
#   1. Xcode build phase (BUILT_PRODUCTS_DIR is set by Xcode)
#        Reads FOUNDATION_PROFILE from the build settings and copies the matching
#        JSON into the compiled app bundle. This is the original behaviour and is
#        preserved byte-for-byte.
#
#   2. Command line (run from a terminal)
#        Lets you inspect and switch the active profile for the next build by
#        editing the FOUNDATION_PROFILE setting in the Xcode project. See --help.

DEFAULT_PROFILE="hisec-global"

# ---------------------------------------------------------------------------
# Locate the project. Under Xcode, SRCROOT points at the ios/ dir. From the CLI
# it's usually empty, so derive it from this script's location (scripts/ lives
# directly under the project root) — making the tool work from any directory.
# ---------------------------------------------------------------------------
if [ -n "${SRCROOT:-}" ]; then
    PROJECT_ROOT="$SRCROOT"
else
    SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
fi

PROFILES_DIR="${PROJECT_ROOT}/FoundationMobile/Resources/profiles"
PBXPROJ="${PROJECT_ROOT}/FoundationMobile.xcodeproj/project.pbxproj"
SETTING="FOUNDATION_PROFILE"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Available profile ids, derived from the JSON files on disk (no hardcoded list
# to drift out of sync). One per line, sorted.
list_profiles() {
    for f in "$PROFILES_DIR"/*.json; do
        [ -e "$f" ] || continue
        basename "$f" .json
    done | sort
}

# Comma-separated profile ids, for one-line messages.
profiles_csv() {
    list_profiles | paste -sd, - | sed 's/,/, /g'
}

# True if $1 is a known profile id.
is_valid_profile() {
    list_profiles | grep -qx -- "$1"
}

# The profile currently selected in the Xcode project (the value of the
# FOUNDATION_PROFILE build setting). Empty if the setting isn't present.
current_profile() {
    [ -f "$PBXPROJ" ] || return 0
    # Xcode quotes values containing characters like '-' (e.g. "tel-aviv"),
    # leaves simple identifiers unquoted (moma) — match either.
    sed -n -E "s/^[[:space:]]*${SETTING}[[:space:]]*=[[:space:]]*\"?([A-Za-z0-9_.-]+)\"?;.*/\1/p" "$PBXPROJ" \
        | head -n1
}

usage() {
    cat <<EOF
select-profile.sh — choose the active Foundation Mobile white-label profile.

USAGE
    scripts/select-profile.sh [<profile>]        Switch the active profile
    scripts/select-profile.sh --list             List available profiles
    scripts/select-profile.sh --current          Print the active profile id
    scripts/select-profile.sh --help             Show this help

ARGUMENTS
    <profile>   A profile id (filename, without .json) from
                FoundationMobile/Resources/profiles/. With no argument, the
                current selection and the available profiles are shown.

OPTIONS
    -l, --list      List available profiles, one per line.
    -c, --current   Print only the currently selected profile id.
    -h, --help      Show this help and exit.

BEHAVIOUR
    Switching updates the ${SETTING} build setting in the Xcode project. The
    change takes effect on the next build, which re-runs this script (to bake
    <profile>.json into the bundle) and select-launch-logo.sh (to swap the
    splash assets). Release builds ignore the setting and use "${DEFAULT_PROFILE}".

EXAMPLES
    scripts/select-profile.sh                 # show current + available
    scripts/select-profile.sh tel-aviv        # build the Tel Aviv edition next
    scripts/select-profile.sh moma            # build the MoMA edition next
    scripts/select-profile.sh --list          # just the ids
    FOUNDATION_PROFILE=moma xcodebuild ...     # one-off override for one build

AVAILABLE PROFILES
$(list_profiles | sed 's/^/    /')
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Mode 1 — Xcode build phase. Detected by Xcode-only env vars. Copies the
# selected profile JSON into the compiled bundle. (Unchanged behaviour.)
# ---------------------------------------------------------------------------
if [ -n "${BUILT_PRODUCTS_DIR:-}" ]; then
    PROFILE="${FOUNDATION_PROFILE:-$DEFAULT_PROFILE}"
    SRC="${PROFILES_DIR}/${PROFILE}.json"
    DST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/foundationmobile.json"

    if [ ! -f "$SRC" ]; then
        echo "error: Foundation profile JSON not found: $SRC" >&2
        echo "error: Valid profiles: $(profiles_csv)" >&2
        exit 1
    fi

    cp "$SRC" "$DST"
    echo "Bundled Foundation profile: $PROFILE → foundationmobile.json"

    # -----------------------------------------------------------------------
    # Brand overlay — FOUNDATION_BRAND is orthogonal to FOUNDATION_PROFILE
    # (the tier). When set and its own profile JSON exists, overlay ONLY that
    # brand's `theme` key on top of the tier JSON already baked into DST above,
    # leaving every tier-specific field (faceMatchSource, document, liveness,
    # etc.) untouched. Empty/unset FOUNDATION_BRAND (the default) is a no-op —
    # today's behaviour is preserved byte-for-byte.
    # -----------------------------------------------------------------------
    BRAND="${FOUNDATION_BRAND:-}"
    if [ -n "$BRAND" ]; then
        BRAND_SRC="${PROFILES_DIR}/${BRAND}.json"
        if [ -f "$BRAND_SRC" ]; then
            if command -v jq >/dev/null 2>&1; then
                TMP_JSON=$(mktemp "${TMPDIR:-/tmp}/select-profile-merge.XXXXXX")
                # Use `+` (shallow merge — right side fully replaces a matching
                # key) rather than `*` (recursive deep-merge). `*` would splice
                # tier-only sub-fields (e.g. a stale nested `asset` key) into
                # the brand's theme wherever the brand's object doesn't name
                # every key the tier's did — this must be a full replacement
                # of `theme`, not a field-by-field merge.
                jq -s '.[0] + {theme: .[1].theme}' "$DST" "$BRAND_SRC" > "$TMP_JSON"
                mv "$TMP_JSON" "$DST"
            else
                python3 - "$DST" "$BRAND_SRC" <<'PYEOF'
import json, sys
dst_path, brand_path = sys.argv[1], sys.argv[2]
with open(dst_path) as f:
    tier = json.load(f)
with open(brand_path) as f:
    brand = json.load(f)
if "theme" in brand:
    tier["theme"] = brand["theme"]
with open(dst_path, "w") as f:
    json.dump(tier, f, indent=2)
PYEOF
            fi
            echo "Brand override: ${BRAND} (theme only)"
        else
            echo "error: Foundation brand JSON not found: $BRAND_SRC" >&2
            echo "error: Valid profiles: $(profiles_csv)" >&2
            exit 1
        fi
    else
        echo "No brand override — using ${PROFILE}'s own branding"
    fi

    exit 0
fi

# ---------------------------------------------------------------------------
# Mode 2 — Command line.
# ---------------------------------------------------------------------------

# Sanity-check the project layout before doing anything else.
[ -d "$PROFILES_DIR" ] || die "profiles directory not found: $PROFILES_DIR"

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    -l|--list)
        list_profiles
        exit 0
        ;;
    -c|--current)
        cur=$(current_profile)
        echo "${cur:-$DEFAULT_PROFILE}"
        exit 0
        ;;
    "")
        # No argument: show status and how to switch.
        cur=$(current_profile)
        echo "Active profile: ${cur:-$DEFAULT_PROFILE (default)}"
        echo "Available:      $(profiles_csv)"
        echo
        echo "Switch with:    scripts/select-profile.sh <profile>"
        echo "Details:        scripts/select-profile.sh --help"
        exit 0
        ;;
    -*)
        die "unknown option: $1 (try --help)"
        ;;
esac

# Switch the active profile.
PROFILE="$1"

if ! is_valid_profile "$PROFILE"; then
    echo "error: unknown profile: $PROFILE" >&2
    echo "error: Valid profiles: $(profiles_csv)" >&2
    exit 1
fi

[ -f "$PBXPROJ" ] || die "Xcode project not found: $PBXPROJ"

if [ -z "$(current_profile)" ]; then
    die "$SETTING is not set in the project; add it to the Debug build settings first."
fi

PREVIOUS=$(current_profile)
if [ "$PREVIOUS" = "$PROFILE" ]; then
    echo "Already on profile: $PROFILE (no change)"
    exit 0
fi

# Quote the value the way Xcode would: bare for simple identifiers, quoted for
# anything with special characters (notably the '-' in hisec-global, tel-aviv,
# san-francisco, lowsec-attest). Writing it pre-normalized keeps Xcode from
# re-churning the line on next open.
case "$PROFILE" in
    *[!A-Za-z0-9_.]*) NEW_VALUE="\"${PROFILE}\"" ;;
    *)                NEW_VALUE="$PROFILE" ;;
esac

# In-place edit, with a temp file so a failure can't corrupt the project. The
# match tolerates an existing quoted or unquoted value.
TMP=$(mktemp "${TMPDIR:-/tmp}/select-profile.XXXXXX")
trap 'rm -f "$TMP"' EXIT
sed -E "s/(${SETTING}[[:space:]]*=[[:space:]]*)\"?[A-Za-z0-9_.-]+\"?;/\1${NEW_VALUE};/" "$PBXPROJ" > "$TMP"
cat "$TMP" > "$PBXPROJ"

echo "Switched profile: $PREVIOUS → $PROFILE"
echo "Build (or ⌘B in Xcode) to apply — re-bakes the JSON and swaps the splash assets."
