#!/usr/bin/env bash
# Pull upstream Rarimo changes into the fork.
#
# IMPORTANT: after every pull, run scripts/brand-sweep.sh. Upstream commits
# reintroduce Rarimo branding into files this fork has rebranded; the sweep
# is what catches it. See spec section 3: "merging their updates means
# re-checking rebranded surfaces each time."
set -euo pipefail

usage() { echo "usage: $0 {ios|android|both}"; exit 2; }

pull_ios() {
  git remote get-url upstream-ios >/dev/null 2>&1 || \
    git remote add upstream-ios https://github.com/rarimo/rarime-ios-app.git
  git fetch upstream-ios
  git subtree pull --prefix=ios upstream-ios main --squash
}

pull_android() {
  git remote get-url upstream-android >/dev/null 2>&1 || \
    git remote add upstream-android https://github.com/rarimo/rarime-android-app.git
  git fetch upstream-android
  git subtree pull --prefix=android upstream-android main --squash
}

case "${1:-}" in
  ios)     pull_ios ;;
  android) pull_android ;;
  both)    pull_ios; pull_android ;;
  *)       usage ;;
esac

echo
echo "Upstream pulled. Now run:  ./scripts/brand-sweep.sh"
