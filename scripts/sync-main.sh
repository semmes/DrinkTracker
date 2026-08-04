#!/usr/bin/env bash
#
# Fast-forwards this clone to origin/main when it falls behind, and says so.
#
# Written to be safe to run unattended, which means it refuses more often than it
# acts. It will not touch anything if you have uncommitted work, if you are on a
# branch other than the one it watches, or if the update is not a clean
# fast-forward. In those cases it explains itself and exits 0 — a watcher that
# fails loudly every minute is a watcher you turn off.
#
#   ./scripts/sync-main.sh              # check once, pull if behind
#   ./scripts/sync-main.sh --watch      # keep checking every SYNC_INTERVAL seconds
#
# Environment:
#   SYNC_BRANCH    branch to track   (default: main)
#   SYNC_INTERVAL  seconds in --watch (default: 60)
#   SYNC_QUIET     set to 1 to suppress macOS notifications

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${SYNC_BRANCH:-main}"
INTERVAL="${SYNC_INTERVAL:-60}"

cd "$REPO_ROOT" || exit 1

say() { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*"; }

notify() {
  [ "${SYNC_QUIET:-0}" = "1" ] && return 0
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1 || true
}

sync_once() {
  if ! git fetch --quiet origin "$BRANCH" 2>/dev/null; then
    say "could not reach origin — will try again"
    return 0
  fi

  local local_sha remote_sha
  local_sha="$(git rev-parse HEAD)"
  remote_sha="$(git rev-parse "origin/$BRANCH")"
  [ "$local_sha" = "$remote_sha" ] && return 0

  # Behind, but only act if it is safe to.
  local current
  current="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$current" != "$BRANCH" ]; then
    say "on '$current', watching '$BRANCH' — leaving it alone"
    return 0
  fi

  if [ -n "$(git status --porcelain)" ]; then
    say "uncommitted changes present — not pulling, nothing of yours will be touched"
    notify "Tallyist sync paused" "You have uncommitted changes. Commit or stash, then it resumes."
    return 0
  fi

  # --ff-only: if history diverged, stop rather than invent a merge commit.
  if ! git merge --ff-only "origin/$BRANCH" --quiet 2>/dev/null; then
    say "cannot fast-forward — your branch has diverged from origin/$BRANCH"
    notify "Tallyist sync stopped" "Local history diverged from $BRANCH. Needs a look."
    return 0
  fi

  local subject changed structural
  subject="$(git log -1 --format='%s')"
  changed="$(git diff --name-only "$local_sha" "$remote_sha")"
  say "updated to $(git rev-parse --short HEAD) — $subject"

  # Xcode reads the project file once and caches it. When the pbxproj or the
  # package pins move underneath an open project, Xcode can keep showing the old
  # target list until it is reopened — so this is worth calling out rather than
  # letting it look like the build is wrong.
  structural=""
  echo "$changed" | grep -q 'project.pbxproj\|Package.resolved\|xcscheme' && structural=" · close and reopen the project in Xcode"

  notify "Tallyist updated" "$subject${structural}"
  [ -n "$structural" ] && say "project structure changed —${structural#* · }"
  return 0
}

if [ "${1:-}" = "--watch" ]; then
  say "watching origin/$BRANCH every ${INTERVAL}s — ctrl-C to stop"
  while true; do
    sync_once
    sleep "$INTERVAL"
  done
else
  sync_once
fi
