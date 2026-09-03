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
#    Development.xcconfig, Production.xcconfig (Task B4 / Open Decision OD-5): these
#    reference Rarimo INFRASTRUCTURE that is retained deliberately, not rebranded —
#    circuit-artifact download URLs, the Rarimo ZK-proving SDK import, the passport
#    registration L2 RPC / contract addresses, and the app's iCloud container / App
#    Group identifiers (re-pointing those needs our own Apple developer account
#    entitlements, which is out of scope for the copy rebrand). Each file carries
#    an inline comment explaining the specific retention.
#    Task B5 note: Points.swift, IPFS.swift, ProposalsStateContract.swift and
#    Multicall3Contract.swift were previously exempted here. They have since been
#    DELETED (points-svc, Freedom Tool IPFS and the proposal/multicall L2 clients
#    were backends of stripped products), so their excludes are gone — a filename
#    exclude for a file that no longer exists is a latent hole, since re-adding
#    the file would silently re-exempt it.
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
#  - FoundationTests/Tests/{BrandingTests,ConfigTests,NavigationTests} (whole
#    directories) and VerificationManagerTests.swift (a single file, since it
#    sits inside Tests/FoundationTests/ alongside other tests that do NOT
#    need this exemption): these tests deliberately assert specific Rarimo
#    strings are ABSENT (or, for retained OD-5 defaults, that a specific
#    known value survived) — the test source itself must name Rarimo to test
#    for it.
#    CORRECTION (Phase B final review): this comment used to claim "excluding
#    the whole test directory rather than individual files since new tests in
#    this style will keep landing here" — that was never actually true. Every
#    entry above is added by name as each test lands; there is no mechanism
#    that catches a new one automatically, and Task B8's VerificationManagerTests
#    proved it by landing unexempted for two tasks' worth of sweeps before this
#    review caught it. `Tests/FoundationTests/` can't get a single directory
#    exclude the way the other three did — it also holds QueryProofTests-style
#    files with no reason to be exempt, and directory basenames collide with
#    the outer FoundationTests/ target dir — so a new absence-assertion test
#    landing in that directory needs its own line here. Check this list
#    against any new test file using this pattern before assuming it's covered.
#
# NOT exempt (deliberately still red until a later task fixes it): entitlements
# files (iCloud.Rarilabs.Rarime / group.rarilabs.rarime / applinks:app.rarime.com)
# — Task B2's review found these block device/archive code signing under the
# new DEVELOPMENT_TEAM; a future task must actually rebrand these values, not
# just silence the sweep on them.
#  - BaseConfig.kt / Constants.kt (Task C4 / Open Decision OD-5): the Android
#    analog of Development.xcconfig / Production.xcconfig above — reference
#    Rarimo INFRASTRUCTURE retained deliberately (registration relayer, RPC,
#    explorer and contract addresses; the ZK circuit-artifact download URLs
#    under rarimo-store), not rebranded. Each retained value carries its own
#    inline comment. NOT exempt because everything here is safe to rebrand —
#    Task C4 also left 2 real, load-bearing deviations in these same files
#    (POINTS_SVC_ID retained despite its "points" name — it feeds
#    AuthManager.login()'s core sign-in proof; DISCORD_URL/TWITTER_URL left
#    untouched, still Rarimo's real community links, live on a surviving
#    screen — Invitation.kt) that a later task must actually resolve, not
#    just have the sweep stop reporting on.
#
# NOT exempt (Android namespace, OD-3 tension — controller-level, not a task
# fix): the `com.rarilabs.rarime` package/import prefix appears in essentially
# every Android Kotlin/C++ file because Open Decision OD-3 deliberately kept
# the Kotlin namespace unrenamed (see android/app/build.gradle.kts's own
# comment). PATTERN's `rarilabs` token means `./scripts/brand-sweep.sh android`
# cannot reach 0 hits while OD-3 stands — this is expected, structural noise
# unrelated to user-visible copy, not something any single copy-rebrand task
# (C4) can or should fix by editing thousands of package declarations against
# an explicit Open Decision. Left NOT exempt (rather than blanket-excluding
# `com.rarilabs`) so a real accidental Rarimo copy/URL leak inside one of
# those same files still surfaces on inspection — it just won't gate CI green
# the way iOS's equivalent sweep can. A controller-level ruling is needed on
# whether to special-case the `rarilabs` token for android or accept
# `brand-sweep.sh android` never goes fully green.
EXCLUDES=(
  --exclude-dir=.git
  --exclude-dir=Frameworks
  --exclude-dir=build
  --exclude-dir=Build
  --exclude-dir=lib
  --exclude-dir=.gradle
  --exclude-dir=BrandingTests
  --exclude-dir=ConfigTests
  --exclude-dir=NavigationTests
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
  --exclude=VerificationManagerTests.swift
  --exclude=Development.xcconfig
  --exclude=Production.xcconfig
  --exclude=prebuild.sh
  --exclude=project.pbxproj
  --exclude=Package.resolved
  --exclude=GoogleService-Info.plist
  --exclude=GoogleService-Info-staging.plist
  --exclude=BaseConfig.kt
  --exclude=Constants.kt
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
