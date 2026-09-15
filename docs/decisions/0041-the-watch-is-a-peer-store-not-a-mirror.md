# 0041 — The watch is a peer store, not a mirror

**Status:** accepted · **Date:** 2026-09-14 · **Relates to:** PRD invariants 1,
3, 4 and 5; ADR-0002 (region is a display lens); ADR-0023 (the counter seed);
ADR-0004 (a failed store degrades to memory); `docs/tallyist-watch-plan.md`
("Architecture", "The two bridges", Phases 1, 2 and 7)

## Context

The Apple Watch app (the 1.4 train's first feature) needs the user's log on the
wrist and needs to add to it with the phone out of range. There were two
shapes for that.

**A mirror.** The watch keeps no store of its own; the phone sends it what to
show over WatchConnectivity, and a tap on the wrist sends a request back for
the phone to write. Simple to reason about — one store, one writer — and
useless the moment the phone is in a coat on the other side of the bar, which
is the moment this product exists for.

**A peer.** The watch keeps its own SwiftData store in its own App Group,
mirrored through the same private CloudKit database the phone's store mirrors
to. This is precisely the arrangement two iPhones on one iCloud account
already have today: SwiftData's mirroring reconciles them, and
`DrinkRepository.saveOrThrow` is already idempotent by `entryID`, so a row
arriving twice overwrites in place. It needs no new merge logic and no new
record type. Its cost is latency — CloudKit between two devices is typically
seconds and occasionally much worse — and the whole of that cost lands on the
one number a person glances at *during* the sitting it describes.

Two things that are true of the phone are not true of a paired watch, and both
had to be decided rather than inherited.

First, **the region and the counter seed are per device by construction.**
`AppSettings` keeps them in the App Group defaults and deliberately not in
iCloud, because two people can share an iCloud account and the region is about
the device's owner. A paired watch is the same person on the same wrist. If
the values do not cross, the wrist computes US standard drinks for a UK user
(invariant 3, silently) and its ＋ can log a different drink than the phone's
＋ (invariant 1, the one-tap rule's own wording: one tap "cannot mean different
things in the widget and the app"). So they must cross — but only these two.
`showsSessionPace` and the appearance preference stay per device: they change
what is *shown*, not what is *computed*, and the watch has no light mode to
share an appearance with anyway.

Second, **WatchConnectivity is the obvious way to make the live number fast,
and the dangerous way.** If the phone sent the watch its recent entries and
the watch *wrote* them, both devices would export the same drink to CloudKit
under two different record names — `DrinkEntry` cannot carry
`@Attribute(.unique)` (CloudKit forbids it) and SwiftData assigns its own
record identity — and that is a duplicate the product could neither detect nor
repair. The same channel that makes the number fast is the one that can
corrupt the log.

## Decision

The watch is a **peer store**: its own SwiftData store in its own App Group
container, opened through the one `SharedModelContainer.make()` ladder every
process uses (invariant 5), mirrored through the user's private CloudKit
database, which is the **only** path a row travels. The App Group and iCloud
container identities are derived from the bundle identifier for all four
processes by `BundleIdentity` (invariant 4, pinned at tier 1).

WatchConnectivity carries **settings, one way, phone to watch**: a
`WatchContext` of the phone's effective region, its counter seed and a
timestamp, sent as an application context (latest value wins, delivered when
the watch is next reachable) on session activation, on every foregrounding of
the phone app, and whenever either value changes. The watch writes the two
values into its own App Group defaults under the keys `AppSettings` owns, so
every reader on the wrist — the counter, and the complication through the same
nonisolated readers the home-screen widget uses — sees them with no code of
its own. **An unreadable or missing payload decodes to nothing and the watch
keeps what it has**, never the default; the codec is in the domain package and
tier-1 tested.

**This channel never writes a row.** Not now, not behind a flag. If the
live-session bridge the plan keeps as optional Phase 7 is ever built, it
carries a display snapshot that the watch unions with its own rows *in
memory*, keyed by `entryID`, and renders — so that when CloudKit delivers the
real rows the union is a no-op.

## Consequences

- **Latency is CloudKit's.** Measured on the owner's iPhone and watch on
  2026-09-14, with the phone nearby: a drink logged on the phone appears on the
  wrist about four to five seconds later. That is the first measurement of the
  number Phase 7 exists for, and by the plan's own criterion it argues the
  bridge may not be needed. The decision waits for an evening's use.
- **A watch that has never received a context computes in the US.** That is
  what the phone itself does with no region chosen, so the arithmetic agrees;
  Phase 3's counter says the region has not been set yet rather than printing
  a figure as if it had, and `Diagnostics.lastWatchContextReceived` is how it
  knows.
- **The mirror is one-way.** The watch cannot set the region or the seed; there
  is nowhere on the wrist to do so, and a two-way mirror would need a
  tiebreak. If that ever changes it is its own decision.
- **The bridge is silent.** Application contexts have no delivery receipt, so
  the phone records what it last sent and the watch what it last applied in
  the App Group defaults, and both debug surfaces show them. A tester who sees
  the wrong region on the wrist can tell whether the phone sent or the watch
  received.
- **Removing a drink the phone has already backfilled into Health is not
  possible from the wrist** (the plan's divergence 3, ADR-0043 when Phase 3
  lands): the watch has no HealthKit, and a peer store cannot retire a sample
  another device wrote. A peer store makes that a stated limit rather than a
  silent leak.
- **Two stores mean two copies of the log on the user's devices**, which is
  already true of two iPhones and is what "the log follows your iCloud
  account" has always meant.

## How to reopen

- If an evening's use shows the live number lagging the sitting — minutes, not
  seconds — build Phase 7's snapshot exactly as this record describes it: a
  display-only union in memory, never a write. The measured four to five
  seconds is the number to beat before that is worth its code.
- If duplicates ever appear across the two stores, the cause is a write
  reaching CloudKit by a second path; the fix is to remove the path, not to
  add a dedup pass.
- If the wrist ever needs to *set* the region or the seed, the context becomes
  two-way with the `sentAt` timestamp as the tiebreak, and that is a new
  decision with its own record, not an amendment to this one.
- If Apple ships a supported way to share an App Group's defaults between a
  phone and its watch, the bridge becomes unnecessary and this record's
  "settings, one way" clause is what to retire.
