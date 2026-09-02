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
#  - NOTICE / THIRD_PARTY_LICENSES.md / LICENSE / README.md: attribution and
#    fork-provenance text MUST name Rarimo (this repo's own top-level docs,
#    not user-facing app copy)
#  - .git, build outputs
#  - CircuitData.swift, ZKUtils.swift, CloudStorage.swift, NotificationManager.swift,
#    Points.swift, IPFS.swift, ProposalsStateContract.swift, Multicall3Contract.swift,
#    Development.xcconfig, Production.xcconfig (Task B4 / Open Decision OD-5): these
#    reference Rarimo INFRASTRUCTURE that is retained deliberately, not rebranded —
#    circuit-artifact download URLs, the Rarimo ZK-proving SDK import, points-svc /
#    IPFS / L2 contract endpoints, and the app's iCloud container / App Group
#    identifiers (re-pointing those needs our own Apple developer account
#    entitlements, which is out of scope for the copy rebrand). Each file carries
#    an inline comment explaining the specific retention.
#  - prebuild.sh: clones the upstream identity-SDK fork by its real repo name
#    (Task A4) — a build script argument, not shipped app copy.
#  - project.pbxproj / Package.resolved: SPM dependency declarations naming real
#    upstream git remotes (e.g. rarimo/NFCPassportReader) that must stay accurate
#    for the build to resolve — not user-facing copy. Bundle id / team / display
#    name / scheme identifiers in project.pbxproj were already rebranded in
#    Task B2; residual hits here are exclusively dependency URLs.
#  - GoogleService-Info.plist: gitignored, locally-varying dev artifact, never
#    committed — not something this sweep (which gates committed source) needs
#    to check.
#  - FoundationTests/Tests/{BrandingTests,ConfigTests}: these tests deliberately
#    assert specific Rarimo strings are ABSENT (or, for retained OD-5 defaults,
#    that a specific known value survived) — the test source itself must name
#    Rarimo to test for it. Excluding the whole test directory rather than
#    individual files since new tests in this style will keep landing here.
#
# NOT exempt (deliberately still red until a later task fixes it): entitlements
# files (iCloud.Rarilabs.Rarime / group.rarilabs.rarime / applinks:app.rarime.com)
# — Task B2's review found these block device/archive code signing under the
# new DEVELOPMENT_TEAM; a future task must actually rebrand these values, not
# just silence the sweep on them.
EXCLUDES=(
  --exclude-dir=.git
  --exclude-dir=Frameworks
  --exclude-dir=build
  --exclude-dir=Build
  --exclude-dir=lib
  --exclude-dir=.gradle
  --exclude-dir=BrandingTests
  --exclude-dir=ConfigTests
  --exclude=NOTICE
  --exclude=THIRD_PARTY_LICENSES.md
  --exclude=LICENSE
  --exclude=README.md
  --exclude='*.a'
  --exclude='*.so'
  --exclude=CircuitData.swift
  --exclude=ZKUtils.swift
  --exclude=CloudStorage.swift
  --exclude=NotificationManager.swift
  --exclude=Points.swift
  --exclude=IPFS.swift
  --exclude=ProposalsStateContract.swift
  --exclude=Multicall3Contract.swift
  --exclude=Development.xcconfig
  --exclude=Production.xcconfig
  --exclude=prebuild.sh
  --exclude=project.pbxproj
  --exclude=Package.resolved
  --exclude=GoogleService-Info.plist
  --exclude=GoogleService-Info-staging.plist
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
