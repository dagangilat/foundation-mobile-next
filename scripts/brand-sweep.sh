#!/usr/bin/env bash
# Fails if any user-visible Rarimo brand token survives in the forked source.
# Every rebrand task in docs/superpowers/plans/2026-08-31-foundation-mobile-next-rarimo-fork-rebrand.md
# uses this as its red/green gate.
#
# Usage: scripts/brand-sweep.sh [path ...]     (default: ios android)
set -uo pipefail

ROOTS=("$@")
if [ ${#ROOTS[@]} -eq 0 ]; then ROOTS=(ios android); fi

# Case-insensitive brand tokens that must not appear in shipped source.
# NOTE: `\b` is a GNU-grep extension and does NOT work in macOS BSD grep, so the
# RMO token is written with explicit non-letter boundaries. Without this the
# gate would pass locally on a Mac and fail in CI (ubuntu) — or worse, silently
# miss RMO locally.
PATTERN='rarime|rarimo|rarilabs|freedomtool|appsflyer|(^|[^A-Za-z])RMO([^A-Za-z]|$)'

# Paths intentionally exempt:
#  - Frameworks/ and cpp/lib/: upstream GPL binaries, named by their own project
#  - NOTICE / THIRD_PARTY_LICENSES.md: attribution MUST name Rarimo
#  - .git, build outputs
#  - CircuitData.swift, ZKUtils.swift, CloudStorage.swift, NotificationManager.swift
#    (Task B4 / Open Decision OD-5): these reference Rarimo INFRASTRUCTURE that is
#    retained deliberately, not rebranded — circuit-artifact download URLs, the
#    Rarimo ZK-proving SDK import, and the app's iCloud container / App Group
#    identifiers (re-pointing those needs our own Apple developer account
#    entitlements, which is out of scope for the copy rebrand). Each file carries
#    an inline comment explaining the specific retention.
EXCLUDES=(
  --exclude-dir=.git
  --exclude-dir=Frameworks
  --exclude-dir=build
  --exclude-dir=Build
  --exclude-dir=lib
  --exclude-dir=.gradle
  --exclude=NOTICE
  --exclude=THIRD_PARTY_LICENSES.md
  --exclude='*.a'
  --exclude='*.so'
  --exclude=CircuitData.swift
  --exclude=ZKUtils.swift
  --exclude=CloudStorage.swift
  --exclude=NotificationManager.swift
)

hits=$(grep -rniE "$PATTERN" "${EXCLUDES[@]}" "${ROOTS[@]}" 2>/dev/null)

if [ -n "$hits" ]; then
  echo "brand-sweep: FAIL — residual Rarimo brand tokens found:"
  echo "$hits"
  echo
  echo "brand-sweep: $(echo "$hits" | wc -l | tr -d ' ') occurrence(s)"
  exit 1
fi

echo "brand-sweep: PASS — no residual Rarimo brand tokens under: ${ROOTS[*]}"
exit 0
