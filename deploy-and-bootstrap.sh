#!/usr/bin/env bash
# Ship Track C+D server-side + run mobile device bootstrap.
#
# Two modes for the server side, plus the mobile bootstrap:
#   Default   — deploy claude/server-track-c-d-staging via a throwaway git
#               worktree (leaves your main-branch WIP untouched), then run
#               bootstrap-device-build.sh on the mobile side
#   --push    — push the staging branch to origin instead of deploying
#               locally (you open a PR + deploy later), then run bootstrap
#   --push-only / --deploy-only / --bootstrap-only — narrower modes
#
# Assumes foundation-global lives next to this repo (override via GLOBAL_REPO
# env var). Uses scripts/deploy-functions.sh per the memory rule that bare
# `firebase deploy` breaks on the file:../../shared deps.

set -euo pipefail

MOBILE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GLOBAL="${GLOBAL_REPO:-$(cd "$MOBILE/../foundation-global" 2>/dev/null && pwd || true)}"
BRANCH="claude/server-track-c-d-staging"
TARGETS="functions:anchorCommitment,functions:resendInviteLink"

MODE=deploy
RUN_BOOTSTRAP=1
for a in "$@"; do
    case "$a" in
        --push)           MODE=push ;;
        --push-only)      MODE=push; RUN_BOOTSTRAP=0 ;;
        --deploy-only)    MODE=deploy; RUN_BOOTSTRAP=0 ;;
        --bootstrap-only) MODE=none; RUN_BOOTSTRAP=1 ;;
        -h|--help)        sed -n '1,15p' "$0"; exit 0 ;;
        *) echo "usage: $0 [--push|--push-only|--deploy-only|--bootstrap-only]" >&2; exit 1 ;;
    esac
done

log()  { printf '[ship] %s\n' "$*"; }
fail() { printf '[ship] ERROR: %s\n' "$*" >&2; exit 1; }

[ -n "${GLOBAL:-}" ] && [ -d "$GLOBAL/.git" ] \
    || fail "foundation-global not found (set GLOBAL_REPO env var)"

log "global:  $GLOBAL"
log "mobile:  $MOBILE"
log "branch:  $BRANCH"
log "mode:    $MODE; bootstrap: $([ "$RUN_BOOTSTRAP" = 1 ] && echo yes || echo no)"

push_branch() {
    log "pushing $BRANCH to origin"
    git -C "$GLOBAL" rev-parse --verify "$BRANCH" >/dev/null \
        || fail "branch $BRANCH not found in $GLOBAL"
    git -C "$GLOBAL" push origin "$BRANCH"
    log "pushed. Open a PR on GitHub before merging to main."
}

deploy_via_worktree() {
    git -C "$GLOBAL" rev-parse --verify "$BRANCH" >/dev/null \
        || fail "branch $BRANCH not found in $GLOBAL"
    WT="${GLOBAL}-staging-deploy-$$"
    log "creating throwaway worktree $WT"
    git -C "$GLOBAL" worktree add "$WT" "$BRANCH" >/dev/null
    trap "git -C '$GLOBAL' worktree remove --force '$WT' 2>/dev/null || true" EXIT

    # .env is gitignored — copy from main so ENFORCE_APP_CHECK=true ships
    if [ -f "$GLOBAL/functions/.env" ]; then
        cp "$GLOBAL/functions/.env" "$WT/functions/.env"
        log "copied functions/.env from main worktree"
    else
        log "WARNING: $GLOBAL/functions/.env missing — deploy may lack env vars"
    fi

    log "running scripts/deploy-functions.sh $TARGETS (2-5 min)"
    (cd "$WT" && ./scripts/deploy-functions.sh "$TARGETS")

    git -C "$GLOBAL" worktree remove --force "$WT"
    trap - EXIT
    log "deployed. Watch Cloud Logging → anchorCommitment / issueAttestationNonce"
    log "for {\"verifications\":{\"app\":\"VALID\",\"auth\":\"VALID\"}}."
}

case "$MODE" in
    push)   push_branch ;;
    deploy) deploy_via_worktree ;;
    none)   : ;;
esac

if [ "$RUN_BOOTSTRAP" = 1 ]; then
    [ -x "$MOBILE/bootstrap-device-build.sh" ] \
        || fail "bootstrap-device-build.sh missing at $MOBILE"
    log "calling bootstrap-device-build.sh"
    bash "$MOBILE/bootstrap-device-build.sh"
fi

log "all done."
