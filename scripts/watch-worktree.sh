#!/usr/bin/env bash
#
# Creates or re-points the watch worktree: one folder, many phases.
#
#   ./scripts/watch-worktree.sh                  # default, claude/watch-phase-0
#   ./scripts/watch-worktree.sh claude/watch-phase-3   # move it to that branch
#   WT_PATH=~/some/where ./scripts/watch-worktree.sh
#
# One long-lived worktree rather than one per phase, deliberately: Claude Code
# and Xcode both want a stable folder, and accumulating sibling directories is
# how a pbxproj edit ends up in the checkout you are not building.
#
# Safe by construction. It refuses rather than acts whenever the answer is not
# obvious: uncommitted work in the worktree, a branch already checked out
# somewhere else, or a request for 'main' (which lives in the main clone and
# must stay there, or the sync LaunchAgent stops watching anything).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${1:-claude/watch-phase-0}"
WT_PATH="${WT_PATH:-$(dirname "$REPO_ROOT")/DrinkTracker-watch}"
BASE="${WT_BASE:-main}"

cd "$REPO_ROOT" || exit 1

die()  { printf '\n  %s\n\n' "$*" >&2; exit 1; }
say()  { printf '  %s\n' "$*"; }

[ "$BRANCH" = "$BASE" ] && die "Refusing to put '$BASE' in a worktree.
  The main clone holds it, and sync-main.sh only acts on the branch it watches.
  Pass a phase branch instead, e.g. claude/watch-phase-1."

# A stale lock blocks every write git is about to attempt, with a confusing
# error. Say so plainly instead.
for lock in .git/index.lock .git/HEAD.lock; do
  [ -e "$lock" ] && die "Stale $lock in the main clone.
  Nothing can commit until it goes. Remove it, then run this again:
      rm -f $REPO_ROOT/$lock"
done

if git worktree list --porcelain | grep -qx "worktree $WT_PATH"; then
  say "Worktree exists at $WT_PATH"
  cd "$WT_PATH" || die "…but the path is unreadable. Try: git worktree prune"

  if [ -n "$(git status --porcelain)" ]; then
    die "Uncommitted work in the worktree. Commit or stash it there first:
      cd $WT_PATH && git status"
  fi

  current="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$current" = "$BRANCH" ]; then
    say "Already on $BRANCH"
  elif git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git switch "$BRANCH" || die "Could not switch. Is $BRANCH checked out elsewhere?"
    say "Switched to $BRANCH"
  else
    git switch -c "$BRANCH" "$BASE" || die "Could not create $BRANCH from $BASE."
    say "Created $BRANCH from $BASE"
  fi
else
  say "Creating worktree at $WT_PATH on $BRANCH"
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$WT_PATH" "$BRANCH" || die "worktree add failed."
  else
    git worktree add -b "$BRANCH" "$WT_PATH" "$BASE" || die "worktree add failed."
  fi
  cd "$WT_PATH" || die "Created, but cannot enter $WT_PATH"
fi

# A worktree does not inherit submodule contents. Without this the contract is
# an empty directory and the vector tests fail for a reason that looks like a
# code bug.
if [ -f .gitmodules ]; then
  say "Initialising submodules"
  git submodule update --init --recursive || say "  (submodule init reported a problem)"
fi

printf '\n'
say "Worktree ready:  $WT_PATH"
say "Branch:          $(git rev-parse --abbrev-ref HEAD)"
say "Main clone:      $REPO_ROOT (untouched, still on $BASE)"
printf '\n'
say "Point Claude Code at $WT_PATH."
say "Open DrinkTracker.xcodeproj from there, not from the main clone."
printf '\n'

if [ -x scripts/verify-watch-setup.py ] || [ -f scripts/verify-watch-setup.py ]; then
  python3 scripts/verify-watch-setup.py
fi
