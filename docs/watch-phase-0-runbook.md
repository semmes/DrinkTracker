# Watch Phase 0 — runbook

**Done, 2026-09-14.** Steps 0 to 2 and 5 ran as written (PRs #92 and #93).
Steps 3, 4, 6 and 7 did not: the owner created the watch app target with
Xcode's template and then asked Claude to do the rest, so the target's rename
and settings, the complication target, the scheme, the entitlements, the icon
and the catalogs were written directly into the project file in a local session
and verified by building both schemes and launching the watch app on a paired
simulator. What deviated from the steps below — the four template settings the
other targets do not set, the inert background-modes setting, the `CLAUDE.md`
that a synchronized folder copies into the bundle — is recorded at the head of
Phase 0 in `docs/tallyist-watch-plan.md` and in CLAUDE.md's 2026-09-14
handoff. The steps stay here as the record of the GUI route.

Everything that has to happen before the first Claude Code watch session. About
thirty minutes, most of it in Xcode.

Read `docs/tallyist-watch-plan.md` first; this is the click-by-click version of
its Phase 0, plus the repo plumbing around it.

---

## Step 0 — clear the self-test residue (30 seconds, do this first)

A worktree self-test run from a remote Cowork session left files behind that it
could not delete. **A stale `.git/index.lock` blocks every commit and blocks
`sync-main.sh`'s fast-forward**, so nothing else works until this runs:

```bash
cd ~/DrinkTracker
rm -f .git/index.lock
rm -f .git/refs/heads/wt-selftest .git/refs/heads/wt-selftest.lock
rm -rf .git/worktrees/wt-selftest
git worktree prune
git worktree list          # expect only ~/DrinkTracker
git branch                 # expect no wt-selftest
git status                 # should now work normally
```

Nothing in your working tree is touched by any of that. It is all inside
`.git/`, and all of it was created by the self-test, not by your work.

---

## Step 1 — get the plans committed so the sync agent resumes

`sync-main.sh` refuses to pull while the clone has uncommitted changes, and it
notifies you that it has paused. Right now there are untracked files in `docs/`
and `scripts/`, so it is paused and will stay paused until this lands.

```bash
cd ~/DrinkTracker
git switch -c claude/watch-plans
git add docs/tallyist-watch-plan.md \
        docs/tallyist-health-pairing-plan.md \
        docs/watch-phase-0-runbook.md \
        docs/watch-scaffold/ \
        scripts/watch-worktree.sh \
        scripts/verify-watch-setup.py
git commit -m "Add the watch and health pairing plans, and Phase 0 scaffolding"
git push -u origin claude/watch-plans
```

Then the usual: draft PR, CI green, merge. Once merged, `git switch main` in
the clone and the agent takes it from there.

**Until you switch back to `main`, the agent stays idle** and says so ("on
'claude/watch-plans', watching 'main' — leaving it alone"). That is the agent
working correctly, not a fault.

---

## Step 2 — make the worktree

```bash
cd ~/DrinkTracker
./scripts/watch-worktree.sh claude/watch-phase-0
```

That creates `~/DrinkTracker-watch` on branch `claude/watch-phase-0`, initialises
submodules there, and runs the verifier. **This is the folder to add in Claude
Code.** The main clone stays on `main` and untouched, which is what keeps the
sync agent running while you work.

For later phases, the same command with a different branch moves the same
folder:

```bash
./scripts/watch-worktree.sh claude/watch-phase-3
```

One worktree, many phases. Do not make a second one.

Two rules that matter more than they look:

- **Open `DrinkTracker.xcodeproj` from the worktree, not the clone.** Two Xcode
  windows on two checkouts of the same project is how an edit lands in the one
  you are not building.
- `main` can never be checked out in the worktree. Git enforces it, and that is
  deliberate: the clone holds `main` so the agent has something to watch.

---

## Step 3 — create the targets in Xcode

In the **worktree's** project.

### Target A — the watch app

File → New → Target → watchOS → **App**. Modern single-target watch app, not
the legacy app-plus-extension pair.

| Field | Value |
|---|---|
| Product Name | `DrinkTrackerWatch` |
| Bundle Identifier | `$(BUNDLE_ID_PREFIX).DrinkTracker.watchkitapp` |
| Interface | SwiftUI |
| Include Notification Scene | **No** |
| Embed in Application | DrinkTracker |

Then in Build Settings for the new target:

| Setting | Value |
|---|---|
| `WATCHOS_DEPLOYMENT_TARGET` | `26.0` |
| `TARGETED_DEVICE_FAMILY` | `4` |
| `MARKETING_VERSION` | must equal the other three targets |
| `CURRENT_PROJECT_VERSION` | must equal the other three targets |
| `INFOPLIST_KEY_CFBundleDisplayName` | `Tallyist` |
| `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` | `$(BUNDLE_ID_PREFIX).DrinkTracker` |
| `INFOPLIST_KEY_UIBackgroundModes` | `remote-notification` |

Frameworks and Dependencies: add **DrinkTrackerCore** only. Not ComponentsKit.

### Target B — the complication

File → New → Target → watchOS → **Widget Extension**, embedded in
`DrinkTrackerWatch`. Uncheck Include Configuration Intent.

| Field | Value |
|---|---|
| Product Name | `DrinkTrackerWatchWidget` |
| Bundle Identifier | `$(BUNDLE_ID_PREFIX).DrinkTracker.watchkitapp.Widget` |
| Package dependency | DrinkTrackerCore only |

### Both targets

- **Shared/** — select all six files (`AppGroup.swift`, `AppSettings.swift`,
  `DrinkEntry.swift`, `DrinkRepository.swift`, `LogDrinkIntent.swift`,
  `SchemaVersions.swift`) and tick both new targets in the File Inspector's
  Target Membership. They are individual file references, not a synchronized
  group, which is why this is manual.
- **Scheme** — Product → Scheme → Manage Schemes, tick **Shared** on
  `DrinkTrackerWatch`. CI cannot build a scheme it cannot see.
- **App icon** — the watch target needs its own `AppIcon` set. A single 1024pt
  PNG is enough; `scripts/make-app-icon.py` already writes one.

### Confirm the floor before you commit to it

`WATCHOS_DEPLOYMENT_TARGET = 26.0` drops older watches. Check App Store
Connect → Analytics for your users' watchOS versions first. Lowering a floor
after shipping means auditing every API the watch code has used.

---

## Step 4 — copy the scaffold in

Once Xcode has created the two folders:

```bash
cd ~/DrinkTracker-watch
cp docs/watch-scaffold/DrinkTrackerWatch.entitlements        DrinkTrackerWatch/
cp docs/watch-scaffold/DrinkTrackerWatchWidget.entitlements  DrinkTrackerWatchWidget/
cp docs/watch-scaffold/DrinkTrackerWatch-CLAUDE.md           DrinkTrackerWatch/CLAUDE.md
```

Then in Xcode, set `CODE_SIGN_ENTITLEMENTS` for each target to the file you
just copied in. Do **not** add capabilities through the Signing & Capabilities
tab first: Xcode writes its own entitlements file with hardcoded identifiers,
and invariant 4 says these derive from `BUNDLE_ID_PREFIX`.

`docs/watch-scaffold/ci-build-watch.yml` goes into `.github/workflows/ci.yml`
in Phase 1, not now.

---

## Step 5 — wire the contract submodule

Not about the watch, but this is the cheapest moment for it, and the Android
port wants it too.

```bash
cd ~/DrinkTracker-watch
git submodule add https://github.com/semmes/tallyist-product.git contract
git commit -m "Add product contract submodule"
```

Add `submodules: recursive` to every `actions/checkout@v5` in `ci.yml`.

Expect one or two vector mismatches the first time the iOS suite runs against
`contract/vectors/session.json`. Those are places where the spec and the
shipped code already disagree. Finding them now, before a second and third
platform inherit the disagreement, is the point.

---

## Step 6 — verify

```bash
cd ~/DrinkTracker-watch
python3 scripts/verify-watch-setup.py
```

Everything that was PENDING for the watch targets should now be PASS, except
the Phase 1 items (`DrinkTrackerCore` watchOS platform, the CI job). Nothing
should be FAIL.

The checks that matter most, and what each one is protecting:

| Check | Why |
|---|---|
| `MARKETING_VERSION` agrees across targets | App Store validation rejects an embedded target whose version disagrees with its host |
| iOS app embeds the watch app | without the Embed Watch Content phase the watch app does not ship at all |
| Bundle ids nest correctly | `…DrinkTracker.watchkitapp` must be the iOS id plus that suffix |
| Bundle ids derive from `BUNDLE_ID_PREFIX` | invariant 4; a literal does not fail the build, it silently splits the store |
| Entitlements complete and derived | CloudKit is the watch's only data path |
| No HealthKit entitlement on the watch | the watch writes no Health data by design |
| No ComponentsKit on watch targets | app target only |
| `Shared/` compiled into every target | four targets now, not three |
| Sync agent free to run | main clone clean and on `main` |

---

## Step 7 — commit and open the PR

```bash
cd ~/DrinkTracker-watch
git add -A
git commit -m "Add watchOS app and complication targets"
git push -u origin claude/watch-phase-0
```

Project file on its own branch with nothing else in it, so the diff is
reviewable and a later bisect can isolate it. Draft PR, CI green, merge. Then
Phase 1 starts with `./scripts/watch-worktree.sh claude/watch-phase-1`.
