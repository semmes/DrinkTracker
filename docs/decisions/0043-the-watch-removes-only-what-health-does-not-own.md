# 0043 — The watch removes only what Health does not own

**Status:** accepted · **Date:** 2026-09-14 · **Relates to:** PRD invariant 6
(HealthKit is a mirror); ADR-0014 (imported entries are read-only);
ADR-0016's amendment (`HealthKitService.deleteSample` reports retired /
foreign / kept); ADR-0041 (the watch has no HealthKit); ADR-0042;
`docs/tallyist-watch-plan.md` (divergence 3, Phase 3)

## Context

Removing an entry on the phone retires its HealthKit sample
(`DrinkStore.delete`). The watch cannot: the sample was written by the phone
into the phone's Health store, and the watch has neither the entitlement nor,
in general, reach. Deleting the row from the wrist would leave Health holding
a drink that no longer exists — permanently, with no symptom and no repair.
That is exactly why `LogOneDrinkIntent` has no minus and why the home-screen
widget has no minus.

The watch is a full app rather than a short-lived extension, so it has a
better option than no minus at all. The question was what − does when the
newest entry is one Health owns.

**Skip to the next removable entry.** Rejected: skipping silently removes a
drink the user did not point at, and on a screen this size there is no room to
say which one went.

**Delete the row and let the phone tidy Health later.** Rejected: there is
nothing for the phone to tidy from. A deleted row carries no tombstone, and a
Health sample with no row behind it is indistinguishable from a sample the
user wrote in the Health app themselves.

**Unavailable means unavailable.** Chosen. This is an existing shape extended
rather than a new rule: `TodayView`'s minus already refuses to touch mirrors
of another app's data (ADR-0014), and imported entries are already read-only
everywhere. "Some entries cannot be removed here" is established.

The plan and the design both proposed telling the reader with a flat line in
the ≈ line's place while − is unavailable. Built as written, that line would
be up most of the time: the newest entry carries a sample as soon as the
phone has been opened after it was logged, which on a real pair is most of
the day, and the ≈ figure — the wrist's second most important number — would
be gone for the duration.

## Decision

**− is offered when today's newest entry carries no Health sample and is not
a mirror, and is unavailable otherwise.** The rule is
`LoggedDrink.removableNewest(in:on:calendar:)` in the domain package, a pure
function over the day's rows, pinned at tier 1: nothing today, newest with a
sample, newest an import, a watch-logged entry behind an older phone-logged
one, and order independence. The counter re-decides from the store at
execution time, never from a captured snapshot.

**Unavailable is drawn, and explains itself on a touch.** The − disc dims
when the rule says no; a touch on it plays the refusal haptic and shows
"Remove that drink on the phone" in the hint's slot for about two seconds.
The ≈ line stays. This is the one place Phase 3 departs from the design's
text, for the reason above.

In practice the control is there for as long as it is likely to matter. The
entries the watch logs carry no sample until the phone next backfills them, so
a mis-tap corrected in the next minute always has −, and a drink from two
hours ago, once the phone has been opened, does not.

## Consequences

- The wrist can undo its own mistakes and cannot undo the phone's. That
  asymmetry is stated in the hint, not hidden.
- A drink logged on the phone and then removed on the phone never involves
  the watch; CloudKit carries the deletion.
- The rule is one function, tested, and the view holds no copy of it.
- The refusal is silent to a reader who never touches the dimmed control. That
  is the cost of keeping the figure on screen, and it is accepted.

## How to reopen

- If the asymmetry proves annoying in use, the reopen path is a **retirement
  tombstone**: the watch writes an `EntryRetirement` row carrying the entry id
  and the sample id, the phone consumes it on next foreground, deletes the
  sample, and removes both rows. That is a schema version bump, a CloudKit
  console deployment, a migration fixture and a new record type — a lot of
  machinery for a case that may not exist. Do not build it speculatively.
- If the disc's dimmed state is missed on hardware, the reopen is a line in
  the hint slot while unavailable — the design's own proposal — not a change
  to what − does.
