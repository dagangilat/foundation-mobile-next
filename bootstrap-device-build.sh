#!/usr/bin/env bash
# Prepare a freshly-merged claude-branch worktree for an on-device iPhone
# build. One-time-per-clone bootstrap; idempotent, safe to re-run.
#
# Steps:
#   1. cmake        — rust-witness build-dep (brew install if missing)
#   2. xcframework  — mopro-smoke/build-xcframework.sh (Rust → xcframework
#                     → generated MoproSmoke.swift → multiplier2 zkey copy)
#   3. pods         — bundle install + pod install (homebrew Ruby, not
#                     system 2.6 which is too old for modern Bundler)
#   4. xcode        — open FoundationMobile.xcworkspace so you can ⌘R
#
# Usage:
#   bash bootstrap-device-build.sh
#
# Requires: macOS, homebrew, homebrew Ruby, Xcode + command-line-tools.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$REPO_ROOT"

log() { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

log "repo: $REPO_ROOT"

# Homebrew Ruby first on PATH — system Ruby 2.6 can't install modern ffi,
# and the old Bundler 1.17.2 shipped with it calls String#untaint which
# Ruby 3.2+ removed. Homebrew Ruby (/opt/homebrew/opt/ruby) ships 4.x.
if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
    export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
else
    fail "/opt/homebrew/opt/ruby/bin not found. Run: brew install ruby"
fi

# ───────────────────────────── 1/4 cmake ─────────────────────────────
log "1/4 — cmake"
if command -v cmake >/dev/null 2>&1; then
    log "      cmake $(cmake --version | head -1 | awk '{print $3}') already installed"
else
    log "      installing cmake via brew…"
    brew install cmake
fi

# ─────────────────────── 2/4 xcframework (slow) ──────────────────────
log "2/4 — mopro-smoke/build-xcframework.sh (takes 5-15 min on cold build)"
[ -x mopro-smoke/build-xcframework.sh ] \
    || fail "mopro-smoke/build-xcframework.sh missing or not executable"
(cd mopro-smoke && ./build-xcframework.sh)

# Sanity: did the xcframework + generated binding + zkey land?
[ -d ios/Frameworks/MoproSmoke.xcframework ] \
    || fail "ios/Frameworks/MoproSmoke.xcframework missing after build — check build-xcframework.sh output"
[ -f ios/FoundationMobile/Generated/MoproSmoke.swift ] \
    || fail "ios/FoundationMobile/Generated/MoproSmoke.swift missing — uniffi-bindgen may have emitted at a different path"
[ -f ios/FoundationMobile/Resources/circuits/multiplier2_final.zkey ] \
    || fail "ios/FoundationMobile/Resources/circuits/multiplier2_final.zkey missing — build-xcframework.sh's zkey copy step failed"

# ─────────────────────────── 3/4 pods ────────────────────────────────
log "3/4 — bundle install + pod install"
[ -f Gemfile ] || fail "Gemfile not found at repo root"

# If Gemfile.lock was generated with Bundler 1.x, modern Bundler
# downgrades to 1.17.2 which crashes on Ruby 3.2+ (`untaint` removed).
# Detecting "BUNDLED WITH\n   1.x" and regenerating sidesteps it.
if [ -f Gemfile.lock ] && grep -A1 'BUNDLED WITH' Gemfile.lock | grep -qE '^[[:space:]]+1\.'; then
    log "      stale Bundler-1.x Gemfile.lock detected — regenerating"
    rm -f Gemfile.lock
fi

bundle install
(cd ios && bundle exec pod install)

# ────────────────────────── 4/4 xcode ────────────────────────────────
log "4/4 — opening FoundationMobile.xcworkspace"
open ios/FoundationMobile.xcworkspace

cat <<'EOF'

[bootstrap] done.

Next — in Xcode:
  1. Destination → your iPhone 13 (not simulator — App Attest won't work there)
  2. ⌘R
  3. Sign in, then on HomeView verify in order:
       · "App Attest — device attested"      (Phase 1)
       · "multiplier2: ok (1)"                (Sprint 0)
       · tap "Verify humanity" → Capture     (Phase 2)
          → commitment hash renders on return

If you want to test App Check enforcement on simulator first:
  • add -FIRDebugEnabled launch arg (user scheme only, not shared)
  • ⌘R on simulator → copy debug UUID from Xcode console
  • register UUID at Firebase console → App Check → Apps → debug tokens

EOF
