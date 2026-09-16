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

## Amendment, 2026-09-15 — an account is not a transfer

The 2026-08 amendment above split one question into two: what the store was
opened with (`Diagnostics.storeMode`) and whether an iCloud account exists
(`CloudKitStatusProbe`). **It stopped one question short.** Neither of those
says whether a byte has moved, and Settings printed the strongest sentence it
has — "Syncing with iCloud", with a tick, under "Your log follows your iCloud
account across your devices" — on the strength of the second alone.

The owner's evening of 2026-09-15 is what that gap looks like from outside: a
phone and a watch drifted apart for hours on cellular, converging only back on
Wi-Fi, while both said they were in step. Nothing was lost and no bug was found
in the sync path — the causes are all outside the app, and the investigation is
recorded in the handoff — but the app asserted a health it had never verified,
which is the same failure this ADR's first amendment found hiding inside the
diagnostics themselves, one level up.

**So the third question is asked directly.** `CloudKitSyncMonitor` observes
`NSPersistentCloudKitContainer.eventChangedNotification` — a plain
`NotificationCenter` observation, no container handle, no new entitlement,
nothing to poll — and records through `Diagnostics` the last import or export
that completed and the last one that failed. Settings says **"Syncing with
iCloud"** with the tick only once something has actually moved, and **"Signed
in to iCloud"** with a plain cloud otherwise; the footnote under it says the
log is on this device and that iCloud will keep trying on its own. Diagnostics
gains **Last synced** and **Last sync failure**, and the watch's debug line
carries the same.

Three rules the shape depends on:

- **It records and never acts.** Nothing here retries, forces or schedules a
  transfer. The transfers are the system's to schedule and this project sets no
  networking policy at all — no `NSPersistentCloudKitContainerOptions`, no
  `CKOperation.Configuration`, no `allowsCellularAccess` — so a monitor that
  intervened would be making the same unearned claim it exists to retire.
- **A successful *setup* is not a byte moved.** Setup means the mirroring
  delegate started, which `storeMode` already claims; only `.import` and
  `.export` count as having synced.
- **Only the two apps start it.** The widget extension and the complication
  open containers of their own and would write the same breadcrumb from a
  different process — the store-mode key already has that problem, which is why
  the watch counter takes `isStoreInMemory` by init rather than reading it back.

What follows from it:

- The strong sentence is true for the first time, and a stall is now legible:
  it reads as an old date beside a healthy account, which is exactly the shape
  of the owner's evening and was unreadable before.
- **This fixes nothing about the stall itself**, and nothing in the app can.
  It makes the next one visible and stops the app claiming otherwise meanwhile.
- The monitor only hears events while a process is alive, so a device that sat
  closed all day reports its last transfer, not its last opportunity. That is
  the honest reading of what it knows, and the reason the row says "Last
  synced" rather than anything about now.
- A healthy device that has genuinely never synced reads "Signed in to iCloud"
  until its first transfer completes. On a fresh install that is seconds; on a
  device that cannot reach CloudKit it is the point.
- The failure string is a `localizedDescription` from Core Data and is not
  copy this project controls. It is confined to Diagnostics, which is
  test-build only.

## How to reopen

If Tier 4 testing shows the no-CloudKit rung corrupts or silently drops writes on a
previously-mirrored store, the fallback should fail closed instead — surface the
failure and keep the app read-only — rather than write into a store it cannot write
to. That would be a stronger reason to revisit than any argument from first
principles here.

On the 2026-09-15 amendment: if a TestFlight build — which mirrors to CloudKit
Production over real APNs, rather than the Development database and the sandbox
an Xcode install gets — shows stalls that a device setting does not explain,
the record this amendment adds is the evidence to reopen with, and the first
thing to weigh is whether the app should say anything more specific than that
nothing has moved. It should not gain a retry: that was refused above and the
refusal does not depend on what the record shows.
