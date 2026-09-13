# Phase 0 — prompt for Claude Code

Paste the block below into a Claude Code session started in `~/DrinkTracker`.
It covers everything Phase 0 needs that does not require the Xcode GUI, and it
stops cleanly at the boundary rather than guessing past it.

Later phases start a session in `~/DrinkTracker-watch` instead, on that phase's
branch, with the phase's own section of `docs/tallyist-watch-plan.md` pasted in.

---

```
You are setting up Phase 0 of the Apple Watch build for Tallyist. I am the
lead on this; you are executing a defined scope. Read before you act, and stop
at the boundary I set rather than working around it.

READ FIRST, in this order:
  1. CLAUDE.md — process, commit trailers, the Mac sync gotchas.
  2. docs/watch-phase-0-runbook.md — this task, step by step. It is the
     authority. Where this prompt and the runbook disagree, the runbook wins.
  3. docs/tallyist-watch-plan.md — "Where this lives" and "Phase 0" only.
     Skip the later phases; they are not this session.

CONTEXT YOU NEED:
  The watch app lives in THIS repo and THIS Xcode project. It is a target, not
  a product: watchOS ships embedded inside the iOS app bundle, one App Store
  record, one archive. Do not propose a separate repo.

  A previous remote session left residue in .git that it could not delete, and
  left six untracked files in the working tree. Both are expected and both are
  yours to clear in steps 1 and 2.

DO THESE, IN ORDER. Stop and report if any step does not behave as described.

  1. Clear the self-test residue. Runbook step 0. A stale .git/index.lock
     blocks every commit and blocks the sync LaunchAgent's fast-forward, so
     this is first. Confirm afterwards that `git worktree list` shows only
     ~/DrinkTracker, `git branch` has no wt-selftest, and `git status` runs
     clean.

  2. Get the plans and scaffolding onto a branch. Runbook step 1, branch
     `claude/watch-plans`. Commit, push, open a DRAFT PR. This is what releases
     the sync agent, which refuses to pull while the clone is dirty.
     Do not merge it yourself; tell me when CI is green.

  3. Create the worktree:
         ./scripts/watch-worktree.sh claude/watch-phase-0
     Expect ~/DrinkTracker-watch on that branch, the main clone untouched on
     main, and the verifier to run at the end. Read its output.

  4. In the worktree, add the product contract as a submodule at contract/
     (runbook step 5), and add `submodules: recursive` to every
     actions/checkout@v5 in .github/workflows/ci.yml. Commit that on
     claude/watch-phase-0.

  5. Run `python3 scripts/verify-watch-setup.py` in the worktree and give me
     the output verbatim. The watch-target checks SHOULD read PENDING at this
     point. Nothing should read FAIL.

HARD STOPS — do not cross these, and do not ask me to let you:

  · Do NOT create, edit, or generate DrinkTracker.xcodeproj/project.pbxproj.
    The two watch targets are made in the Xcode GUI, by me, because the
    template gets WKApplication, WKCompanionAppBundleIdentifier, the Embed
    Watch Content phase and the widget's NSExtension plist right, and a
    hand-written watchOS target is a large diff that fails as an unopenable
    project rather than as a build error.
  · Do NOT copy anything out of docs/watch-scaffold/ yet. Those folders do not
    exist until Xcode makes them, and Xcode's template will not merge with
    files already sitting there.
  · Do NOT touch DrinkTracker/ or Shared/ in this session. No phone-app code
    changes belong in Phase 0.
  · Do NOT add .watchOS to Package.swift or add the CI watch job. Those are
    Phase 1.
  · Do NOT rebase or squash. Merge commits only — a rebase-merge once rewrote
    committer identities here.
  · Commit trailers end with `Co-Authored-By: Claude <noreply@anthropic.com>`
    and the session link. Never put a model identifier in anything pushed;
    CLAUDE.md is explicit about this.

WHEN YOU FINISH, report back with:
  · The verifier output, verbatim.
  · The PR URL for claude/watch-plans and its CI status.
  · A checklist of exactly what I now need to do in Xcode, pulled from runbook
    step 3 — the two targets, every build setting with its value, the Shared/
    target-membership ticks, and the shared scheme. Written so I can work
    through it without re-reading the runbook.
  · Anything in the runbook that did not match what you actually found.

If something is ambiguous, say so and stop. I would rather answer a question
than unpick a guess.
```
