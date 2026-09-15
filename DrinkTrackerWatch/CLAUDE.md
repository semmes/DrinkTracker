# Working in the watch target

Claude Code reads nested CLAUDE.md files, so this is what keeps a session
inside the watch app instead of wandering the phone app.

---

## Before anything else

1. `docs/tallyist-watch-plan.md` — find the phase you are on and read only that
   phase, plus "Rules that survive to the wrist" and "Architecture".
2. `docs/tallyist-1.2-spec.md` — "Project constraints". They are App Review
   claims, not preferences.
3. `docs/design/watch/README.md` — the owner's design for phases 3 to 6, and
   the answers to its five open questions (recorded at its end).

## Scope

Yours: `DrinkTrackerWatch/`, `DrinkTrackerWatchWidget/`, and new pure functions
in `DrinkTrackerCore`.

Not yours without saying why first: anything in `DrinkTracker/` or `Shared/`.
Those are the phone app and the code all four targets compile. A change there
is a change to a shipping app that just cleared App Review.

**The project file.** These two folders are synchronized groups, so a file
written here joins its target automatically and no phase after Phase 1 should
need `project.pbxproj` for its own files. (Phase 3 touched it once, to compile
a new `Shared/` file — `DayIntensity+Legend.swift` — into the watch app: a
`Shared/` membership, inside the rule below.) Editing it is allowed only in a **local** session
with the toolchain, only for what the plan names (Phase 1's package links and
`Shared/` memberships), and only verified the way Phase 0 was: `plutil -lint`,
`xcodebuild -list`, both schemes built for their simulators, and
`scripts/verify-watch-setup.py` green. A remote session never touches it — it
cannot verify the edit, and a broken project fails as unopenable on the
owner's Mac rather than as a build error.

## The three that are easy to get wrong

- **No `Timer`, no one-second `TimelineView`.** Live relative time is
  `Text(_:style:.relative)`; anything that must recompute goes in a 60-second
  `TimelineView`. A one-second wakeup on a watch is a battery complaint in a
  review.
- **Every count is `.privacySensitive()`.** A watch face is public and
  Always-On keeps the app legible when the wrist drops. See "What the wrist
  exposes" in the plan.
- **Asset catalog symbols, not SF Symbols.** The drink glyphs are
  `Image("tally.beer")`, never `Image(systemName:)`, which renders nothing.
  They reach these targets through the shared catalog Phase 1 creates.

## Verifying

A local session has Xcode 26.6 and the watch simulators: run the gates rather
than repeating the remote-session caveat. A remote session has no Swift
toolchain, so CI is its only compile check — say so in commit messages rather
than claiming local verification. Before committing a phase:

    python3 scripts/verify-watch-setup.py

Then branch → draft PR → CI green → merge. Merge commits only, never rebase.
Commit trailers end with `Co-Authored-By: Claude <noreply@anthropic.com>` and
the session link. No model identifiers in anything pushed.
