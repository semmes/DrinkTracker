# 0004 — The CloudKit fallback keeps the App Group; a totally failed store degrades to memory

**Status:** accepted · **Date:** 2026-08 · **Relates to:** PRD invariants 4 and 5

## Context

`DrinkTrackerApp.init()` used to carry its own fallback: if
`SharedModelContainer.make()` threw, it opened a `ModelContainer` with
`cloudKitDatabase: .none` **and no `groupContainer`**.

Two things were wrong with that.

1. **It dropped the App Group.** The fallback wrote to the app's private container,
   so the widget — which reads the group store — could never see anything the app
   logged. Silent, and indistinguishable from the widget being broken.
2. **Only the app had it.** `QuickLogProvider.currentEntry()` and `LogDrinkIntent`
   call `make()` too, and on failure the widget just shows zero. So one iCloud
   failure put the app on a private store and the widget on no store — the exact
   divergence `SharedModelContainer` exists to prevent.

Separately, the fallback used `try!`, so if it also threw the app crashed at launch
with nothing recorded.

## Decision

**The CloudKit fallback moves inside `SharedModelContainer.make()`,** so both
targets take the same ladder. It keeps the App Group container and gives up only
the mirroring:

> Losing sync is a degradation. Losing the widget is a broken feature.

**A total failure — both configurations throwing — degrades to an in-memory store
rather than crashing.** The app launches, and nothing logged in that session
persists.

**Every rung is recorded.** `Diagnostics.recordStoreMode` writes which
configuration actually opened, and Settings → Diagnostics shows it.

## Consequences

- Both degraded states are now *observable* instead of silent. That was the real
  defect: losing CloudKit looks exactly like "nothing has synced yet", and losing
  the store looks like an empty log.
- In-memory over `fatalError` is a genuine trade, and it is the weaker half of this
  decision. A crash tells the user something is wrong immediately; in-memory lets
  them log drinks that quietly evaporate — in a *tracking* app, which is the sharp
  edge. It wins on the grounds that a launch crash is unrecoverable from the user's
  side and offers them no route to their existing log, while this state is at least
  visible and leaves the app usable. Reaching it at all means both a mirrored and a
  local open failed, which is a deeply broken device rather than an ordinary
  no-iCloud case.
- **Residual gap:** the Diagnostics section is `#if DEBUG`, so in a release build
  the in-memory state is still invisible to the user. A release-visible indicator
  needs a copy decision — Settings' factual "Apple Health" status row is the
  obvious model — and is deliberately not made here. Tracked in PRD §8.
- **Unverified (Tier 4):** whether a store that was previously CloudKit-mirrored
  reopens cleanly with `cloudKitDatabase: .none`. Both processes now run the same
  ladder so they agree at any given moment, but two processes opening while iCloud
  availability changes could still land on different rungs. Needs a device.

## Amendment, 2026-08 — the fallback fires less often than this assumed

**A simulator run showed the central assumption here was wrong.** This ADR was
written as though `SharedModelContainer.make()` would *throw* when iCloud is
unavailable, and the whole ladder was designed around catching that.

It doesn't. With no iCloud account signed in, `ModelContainer(…)` with
`cloudKitDatabase: .automatic` **succeeds**. The container is returned, the store
opens, and `NSCloudKitMirroringDelegate` fails afterwards, asynchronously, on its
own schedule:

```
Failed to set up CloudKit integration for store: …
Error Domain=NSCocoaErrorDomain Code=134400
  "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)."
```

That error never reaches the `catch`. Consequences:

- **The no-CloudKit rung effectively never fires** for the ordinary "not signed
  into iCloud" case — the one it was written for. It remains correct for a genuine
  container-creation failure, which is rarer than assumed.
- **`Diagnostics.storeMode` was reporting a wish, not a fact.** It said
  `shared + CloudKit` while nothing synced, because it is written at open time and
  the answer doesn't exist yet. Reworded to `shared, CloudKit requested`.
- Everything looked healthy while sync was dead — the exact class of silent failure
  the diagnostics exist to surface, hiding inside the diagnostics themselves.

The fix is not more fallback logic. It is asking the question directly:
`CloudKitStatusProbe` calls `CKContainer.accountStatus()` on launch and on each
foreground, and Settings shows it as **iCloud sync** next to **Store mode**. The two
are separate facts and are now displayed as such.

The decision itself stands — keep the App Group, give up only mirroring, record
every rung. Only the claim about *when* the ladder runs was wrong, and it was wrong
because it was reasoned about rather than observed. It sat in the repository as
settled for several commits before a five-minute run disproved it, which is the
argument for Tier 3 and Tier 4 in PRD §4 stated better than the PRD states it.

## How to reopen

If Tier 4 testing shows the no-CloudKit rung corrupts or silently drops writes on a
previously-mirrored store, the fallback should fail closed instead — surface the
failure and keep the app read-only — rather than write into a store it cannot write
to. That would be a stronger reason to revisit than any argument from first
principles here.
