#!/bin/sh
set -eu

# Test for assert-profile-consistency.sh (the Part B build-phase guard) and a
# content assertion on the real project.pbxproj (the Part A fix).
#
# Why a shell test, not XCTest: this is build-phase / shell-script logic that
# runs OUTSIDE the app process (Xcode runs it as a build phase before the app
# is even compiled). XCTest exercises Swift inside the built app and has no
# access to the FOUNDATION_PROFILE build-setting env plumbing, so it can't
# faithfully reproduce the divergence. This script drives the real assertion
# script under the same env-var conditions Xcode gives each build configuration,
# plus a cheap grep-based check that the Release config now sets the value.
#
# Run: sh ios/scripts/tests/assert-profile-consistency.test.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCRIPTS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
IOS_ROOT=$(CDPATH= cd -- "$SCRIPTS_DIR/.." && pwd)
ASSERT="${SCRIPTS_DIR}/assert-profile-consistency.sh"
REAL_PBXPROJ="${IOS_ROOT}/FoundationMobile.xcodeproj/project.pbxproj"

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

# Build a throwaway project root with a crafted project.pbxproj so we can drive
# the assertion script via SRCROOT without touching the real project.
make_fixture() {
    # $1 = pbxproj body (lines of FOUNDATION_PROFILE settings, in file order)
    fixture=$(mktemp -d "${TMPDIR:-/tmp}/assert-consistency.XXXXXX")
    mkdir -p "${fixture}/FoundationMobile.xcodeproj"
    printf '%s\n' "$1" > "${fixture}/FoundationMobile.xcodeproj/project.pbxproj"
    echo "$fixture"
}

# Run the assertion script with a given SRCROOT and FOUNDATION_PROFILE env state.
# $1 = SRCROOT, $2 = "unset" or a profile id to export. Echoes the exit code.
run_assert() {
    _srcroot="$1"; _prof="$2"
    if [ "$_prof" = "unset" ]; then
        SRCROOT="$_srcroot" FOUNDATION_PROFILE= sh -c 'unset FOUNDATION_PROFILE; exec "$0"' "$ASSERT" >/dev/null 2>&1 && echo 0 || echo $?
    else
        SRCROOT="$_srcroot" FOUNDATION_PROFILE="$_prof" sh "$ASSERT" >/dev/null 2>&1 && echo 0 || echo $?
    fi
}

# --- Fixtures ---------------------------------------------------------------
# Pre-fix state: Debug sets moma (first in file), Release has NO setting.
PREFIX_BODY='		buildSettings = {
			FOUNDATION_PROFILE = moma;
		};'
prefix_root=$(make_fixture "$PREFIX_BODY")

# Post-fix state: Debug moma first, Release "hisec-global" after it.
POSTFIX_BODY='		Debug buildSettings = {
			FOUNDATION_PROFILE = moma;
		};
		Release buildSettings = {
			FOUNDATION_PROFILE = "hisec-global";
		};'
postfix_root=$(make_fixture "$POSTFIX_BODY")

cleanup() { rm -rf "$prefix_root" "$postfix_root"; }
trap cleanup EXIT

# --- Test 1: pre-fix Release build (env unset) → guard FIRES (catches the bug).
rc=$(run_assert "$prefix_root" unset)
if [ "$rc" -ne 0 ]; then
    pass "guard fires on pre-fix divergence (FOUNDATION_PROFILE unset, pbxproj first value=moma → bundle=hisec-global vs launch=moma), exit=$rc"
else
    fail "guard did NOT fire on the pre-fix divergence (expected non-zero, got 0)"
fi

# --- Test 2: post-fix Release build (Xcode passes FOUNDATION_PROFILE=hisec-global) → PASSES.
rc=$(run_assert "$postfix_root" hisec-global)
if [ "$rc" -eq 0 ]; then
    pass "guard passes on post-fix Release (FOUNDATION_PROFILE=hisec-global → bundle==launch)"
else
    fail "guard fired on a consistent Release build (expected 0, got $rc)"
fi

# --- Test 3: Debug build (Xcode passes FOUNDATION_PROFILE=moma) → PASSES (unaffected).
rc=$(run_assert "$postfix_root" moma)
if [ "$rc" -eq 0 ]; then
    pass "guard passes on Debug (FOUNDATION_PROFILE=moma → bundle==launch)"
else
    fail "guard fired on a consistent Debug build (expected 0, got $rc)"
fi

# --- Test 4 (Part A content assertion): real Release config now sets the value.
# Extract just the Release block of the FoundationMobile app target and confirm
# it contains FOUNDATION_PROFILE = "hisec-global";.
release_block=$(awk '/13B07F951A680F5B00A75B9A \/\* Release \*\/ = \{/{f=1} f{print} f&&/name = Release;/{exit}' "$REAL_PBXPROJ")
if printf '%s\n' "$release_block" | grep -q 'FOUNDATION_PROFILE = "hisec-global";'; then
    pass "Release XCBuildConfiguration sets FOUNDATION_PROFILE = \"hisec-global\";"
else
    fail "Release XCBuildConfiguration is missing FOUNDATION_PROFILE = \"hisec-global\";"
fi

# --- Result -----------------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
    echo "All assert-profile-consistency tests passed."
    exit 0
else
    echo "${failures} test(s) failed."
    exit 1
fi
