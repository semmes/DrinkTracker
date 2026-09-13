# Working in the watch target

Copy this to `DrinkTrackerWatch/CLAUDE.md` once Xcode has created the folder.
Claude Code reads nested CLAUDE.md files, so this is what keeps a session
inside the watch app instead of wandering the phone app.

---

## Before anything else

1. `docs/tallyist-watch-plan.md` — find the phase you are on and read only that
   phase, plus "Rules that survive to the wrist" and "Architecture".
2. `docs/tallyist-1.2-spec.md` — "Project constraints". They are App Review
   claims, not preferences.

## Scope

Yours: `DrinkTrackerWatch/`, `DrinkTrackerWatchWidget/`, and new pure functions
in `DrinkTrackerCore`.

Not yours without saying why first: anything in `DrinkTracker/` or `Shared/`.
Those are the phone app and the code all four targets compile. A change there
is a change to a shipping app that just cleared App Review.

**Never edit `project.pbxproj`.** The targets already exist and these folders
are synchronized groups, so a file written here joins the target automatically.
There is no Swift toolchain in a remote session, so a project-file edit cannot
be verified and a broken one is unopenable on the owner's Mac.

## The three that are easy to get wrong

- **No `Timer`, no one-second `TimelineView`.** Live relative time is
  `Text(_:style:.relative)`; anything that must recompute goes in a 60-second
  `TimelineView`. A one-second wakeup on a watch is a battery complaint in a
  review.
- **Every count is `.privacySensitive()`.** A watch face is public and
  Always-On keeps the app legible when the wrist drops. See "What the wrist
  exposes".
- **Asset catalog symbols, not SF Symbols.** The drink glyphs are
  `Image("tally.beer")`, never `Image(systemName:)`, which renders nothing.

## Verifying

CI is the only compile check. Say that in commit messages rather than claiming
local verification. Before committing a phase:

    python3 scripts/verify-watch-setup.py

Then branch → draft PR → CI green → merge. Merge commits only, never rebase.
Commit trailers end with `Co-Authored-By: Claude <noreply@anthropic.com>` and
the session link. No model identifiers in anything pushed.
