#!/usr/bin/env bash
# Store-upload gate built on brand-sweep.sh: fails only on brand hits that are
# NOT in the committed baseline, so a new Rarimo string cannot slip into a
# store build while the known, reviewed residue does not block every upload.
#
# Why a ratchet instead of brand-sweep.sh directly: `brand-sweep.sh android`
# can never pass (Open Decision OD-3 keeps the com.rarilabs.rarime Kotlin
# namespace, which the sweep matches in nearly every file), and the iOS sweep
# still reports code comments and retained infrastructure hosts. Calling the
# raw sweep from fastlane made both upload lanes fail before building.
#
# Baseline entries are "path:matched line" with line numbers stripped, so
# unrelated edits that shift lines do not trip the gate.
#
# Usage: scripts/brand-sweep-ratchet.sh <ios|android> [--update]
set -uo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${1:?usage: $0 <ios|android> [--update]}"
BASELINE="scripts/brand-sweep-baseline/${PLATFORM}.txt"

current=$(./scripts/brand-sweep.sh "$PLATFORM" \
  | grep -E '^[^ ]+:[0-9]+:' \
  | sed -E 's/^([^:]+):[0-9]+:/\1:/' \
  | LC_ALL=C sort -u)

if [ "${2:-}" = "--update" ]; then
  mkdir -p "$(dirname "$BASELINE")"
  printf '%s\n' "$current" | sed '/^$/d' > "$BASELINE"
  echo "brand-sweep-ratchet: baseline for $PLATFORM rewritten ($(wc -l < "$BASELINE" | tr -d ' ') entries)"
  exit 0
fi

new=$(LC_ALL=C comm -23 <(printf '%s\n' "$current" | sed '/^$/d') <(LC_ALL=C sort -u "$BASELINE"))

if [ -n "$new" ]; then
  echo "brand-sweep-ratchet: FAIL - new Rarimo brand hits in $PLATFORM not in $BASELINE:"
  echo "$new"
  echo
  echo "Rebrand them. Only if a hit is reviewed and must stay (infrastructure,"
  echo "namespace), rerun with --update and commit the baseline change."
  exit 1
fi

echo "brand-sweep-ratchet: PASS - no new brand hits in $PLATFORM ($(printf '%s\n' "$current" | sed '/^$/d' | wc -l | tr -d ' ') known, baselined)"
