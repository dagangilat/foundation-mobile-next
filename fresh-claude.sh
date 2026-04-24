#!/usr/bin/env bash
# Bootstrap a Claude Code CLI session against the
# claude/show-backlog-Woum4 branch in an isolated git worktree, so your
# primary checkout stays untouched.
#
# Usage:
#   bash fresh-claude.sh [/path/to/foundation-mobile]
#
# If no path is given, assumes the current directory is foundation-mobile.

set -euo pipefail

REPO="${1:-$PWD}"
BRANCH="claude/show-backlog-Woum4"

if [[ ! -d "$REPO/.git" ]]; then
    echo "Error: '$REPO' is not a git repository." >&2
    echo "Pass the path to your foundation-mobile clone as the first arg." >&2
    exit 1
fi

REPO=$(cd "$REPO" && pwd)
REPO_NAME=$(basename "$REPO")
WORKTREE="$(dirname "$REPO")/${REPO_NAME}-claude"

echo "[fresh-claude] repo:     $REPO"
echo "[fresh-claude] branch:   $BRANCH"
echo "[fresh-claude] worktree: $WORKTREE"
echo

echo "[fresh-claude] Fetching $BRANCH from origin..."
git -C "$REPO" fetch origin "$BRANCH"

if [[ -d "$WORKTREE" ]]; then
    echo "[fresh-claude] Worktree exists — pulling latest."
    git -C "$WORKTREE" pull --ff-only origin "$BRANCH"
else
    echo "[fresh-claude] Creating worktree..."
    git -C "$REPO" worktree add "$WORKTREE" "$BRANCH"
fi

cd "$WORKTREE"

if [[ ! -f CLAUDE.md ]]; then
    echo "Error: CLAUDE.md not found — branch may be out of sync." >&2
    exit 1
fi
echo "[fresh-claude] CLAUDE.md present ($(wc -l < CLAUDE.md | tr -d ' ') lines)."
echo

# Install CocoaPods via Bundler when the repo pins a version via Gemfile.
# Falls back to system `pod` if no Gemfile. Warns but keeps going on failure
# so the Claude CLI still launches and can help debug from inside.
install_pods() {
    if [[ -f Gemfile ]]; then
        if ! command -v bundle >/dev/null 2>&1; then
            echo "[fresh-claude] Warning: Gemfile present but 'bundle' not installed."
            echo "               Run: sudo gem install bundler"
            return 1
        fi
        echo "[fresh-claude] bundle install..."
        bundle install
        echo "[fresh-claude] bundle exec pod install..."
        (cd ios && bundle exec pod install)
    elif command -v pod >/dev/null 2>&1; then
        echo "[fresh-claude] pod install..."
        (cd ios && pod install)
    else
        echo "[fresh-claude] Warning: neither Bundler nor system pod available."
        echo "               Install CocoaPods: sudo gem install cocoapods"
        return 1
    fi
}

if ! install_pods; then
    echo "[fresh-claude] Pods unresolved — fix in $WORKTREE/ios and re-run"
    echo "               'bundle exec pod install'. Launching Claude anyway."
fi

echo

if ! command -v claude >/dev/null 2>&1; then
    echo "Error: 'claude' CLI not found in PATH." >&2
    echo "Install Claude Code, then 'cd $WORKTREE && claude'." >&2
    exit 1
fi

echo "[fresh-claude] cwd: $(pwd)"
echo "[fresh-claude] Launching Claude CLI (CLAUDE.md will auto-load)..."
echo
exec claude
