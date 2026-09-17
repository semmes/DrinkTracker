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
  *(No longer true of the store-mode key since the 2026-09-16 amendment below:
  only the apps' launches write it. The rule for this monitor is unchanged.)*

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

## Amendment, 2026-09-16 — the widget's silent zero, and a retraction

**The defect this record named is closed on the two surfaces that read the store
themselves** — the iPhone's home-screen widget and the watch complication — and it
is **not** closed everywhere. The 2026-08 fix covered a failed *open* in the app (the
in-memory fallback), and watch Phase 6 covered a failed open in the complication; a
failed *fetch* was never covered, and on the app's own `@Query` screens — Today's
hero and the watch counter — it still draws a confident zero, because neither reads
`fetchError`. ADR-0047 lists that as found and not fixed. *(Closed by the later
2026-09-16 amendment below, which also moves the no-alcohol marker's refusal onto
the throwing read.)* The iPhone's
home-screen widget drew `drinkCount: 0` when `SharedModelContainer.make()`
threw, when a fetch failed (`DrinkRepository.drinks(on:)` turns one into an empty
day), and when its App Group did not resolve (`make()` then opens a private empty
store without throwing). It now draws an unavailable state — the drop glyph and
"drinks today", no figure, no ＋ — for all three, and the complication's failed
fetch reaches its unavailable entry too. `DrinkRepository.drinksOrThrow(on:)` and
`isMarkedAlcoholFreeOrThrow(_:)` are the reads that can say they failed; every
other caller keeps the forgiving reads it already depends on. ADR-0047 has the
field report that surfaced it.

**Only the two apps' launches write `storeMode`.** It is the key `isStoreInMemory`
reads — the one release-visible degraded state this record created — and it is
last-writer-wins across every process in the App Group, so it must mean how *this
launch* opened the store. When every open wrote it, an extension opening the store a
second after the app fell back to memory would have erased the warning, and so would
a Siri or Shortcuts intent running in the app's own process. `open()` now records
nothing and returns the mode; `DrinkTrackerApp.init` and `DrinkTrackerWatchApp.init`
write it. The widget reports the rung it opened on in its own diagnostic line.

**Retracted: "a CloudKit-mirrored store opened without CloudKit will still read,
but writes fail silently."** It stood in `make()`'s doc comment, in PRD invariant
5's failure mode and in the README from 6f759f6 (2026-07-31), and it was never
observed. It was written while the widget's one-tap log was failing, and 17853f3
found the real cause four days later: a non-optional `@Parameter` with no default,
which abandoned the tap during resolution, before `perform()` was entered. On
2026-09-16 the simulator's widget extension — which holds no iCloud container and
so opens the store without mirroring — wrote three `DrinkEntry` rows whose
persistent-history transactions name `com.shawnsemmes.DrinkTracker.Widget`, and
the app displayed them. Invariant 5 stands; its failure mode is rewritten to the
risks that are real — two processes disagreeing about the schema, or both managing
sync (TN3164).

## Amendment, 2026-09-16 (later) — the app's own screens stop drawing a read they did not make

The amendment above left the defect open on Today's hero and the watch counter,
which read the store through `@Query` and never asked whether the read worked.
**This closes it there**, after first establishing what the framework offers, since
none of it is documented beyond a declaration.

**What `@Query` exposes: `fetchError`, and nothing else.** `Query.fetchError:
(any Error)?` is declared in `_SwiftData_SwiftUI` (SwiftData's SwiftUI overlay),
available since iOS 17 and watchOS 10, and present in the iOS 26.5 and watchOS
26.5 SDKs on this Mac. There is no status, no retry and no notification. What it
does was measured — on macOS 26 in a hosted SwiftUI view, then in the app itself on
the iOS 26.5 and watchOS 26.5 simulators — with the one failure that can be made on
demand: the store file overwritten under its open connection, which SQLite reports
as "file is not a database" and Core Data as Cocoa error 259.

- **A failed fetch sets it**, on both platforms.
- **It must be read after the query's value.** A query fetches when its value is
  read, and `fetchError` read first answers for the fetch before — nil, on the first
  render over a store that cannot be read. Both orders were measured in one body.
- **A first fetch that fails returns no rows; a later one that fails keeps the rows
  it had.** The confident zero is the first case. The second draws a count from
  before whatever store change asked for the new fetch.
- **It clears when a later fetch succeeds**, and a query fetches again when the
  store changes — a save in this process, including one that fails, or a write from
  another process on the same file — or when the app is relaunched. On macOS and on
  the iOS simulator nothing else re-ran it: not a state change that re-rendered the
  view, and not backgrounding and foregrounding the app over a store whose bytes had
  been put back. On the watchOS simulator a re-render did — a tap on the tile, which
  touches no store, turned the counter unavailable. That is recorded as observed,
  not explained.
- **Some damage never reaches it.** A store file truncated or deleted under its
  connection made Core Data log a disk I/O error and fetch as *empty*, with no throw
  and `fetchError` nil. No read API can tell that from an empty log, and this
  amendment does not claim to catch it.

**Decision.** Today and the watch counter read the `fetchError` of both their
queries — the drinks and the no-alcohol markers — after the values, and while
either is set they draw the unavailable state the widget and the complication
already draw (ADR-0047): the drop glyph where the figure goes and "drinks today",
with no band. They draw nothing that acts on the day or states a fact about it: no
＋ or − (so no Double Tap on the wrist), no plus-mode pill, no "Record no alcohol
today", no "Add specific", no legend, no hint, no session row or switch — and on the
phone no rows beneath, no session card and no Undo bar. A sheet, or the watch's
type picker, already open when the read fails keeps its own save, which fails as
any save on that store does. The reasons are ADR-0047's for the
widget's ＋, plus one of its own: the no-alcohol button is offered on a day that
*looks* empty, which is the one thing a failed read cannot say. **One sentence is
added over the widget's drawing, on both: "Today's drinks couldn't be read."** A
widget is glanced at; these are screens someone opened to act on, and a glyph with
the controls gone and no word reads as a broken app. The same key in the app and
watch catalogs, reviewed under 1.4.3.

Consequences:

- **Recovery is a store change or a relaunch.** Nothing here forces a new read.
  Re-creating the queries on foregrounding would, and is the reopen path below; it is
  not built because nothing observed heals without a write or a relaunch, and a
  forced read of a store that is still failing changes nothing on screen.
- **What the tier-3 pass showed**, on the iPhone 17 Pro simulator over its own
  store: with the store damaged, ＋ left the count at 2 and the timeline read
  `Today ＋ not saved — history unreadable: … Code=259` (ADR-0042's amendment); a
  drink logged through "Add specific" failed to save, the query fetched again, and
  Today drew the unavailable state — rendered in light, dark and
  `accessibility-extra-large`; with the bytes put back, it stayed unavailable
  through a background and a foreground, and a relaunch read the two drinks again
  with nothing added. On the Series 11 (46mm) simulator: ＋ played "Not saved" (the
  breadcrumb names Cocoa 259) and the counter turned unavailable — outlined tile,
  drop glyph, no discs, the sentence — and a relaunch over the restored store read
  and logged normally. Both stores were put back from copies taken before the test.
- **Found and not fixed — the write paths, which want their own change:**
  - `DrinkRepository.saveOrThrow` inserts the drink *before* its two reads (the
    existing entry by id, and the day's markers), and both read through `try?`. On a
    failing store the markers read as none, nothing is deleted, the save fails, and
    the insert stays pending — so the next save that works writes a drink onto a day
    still marked no alcohol, the contradiction ADR-0011 forbids. An edit whose id read
    fails inserts a second row with the same id. The fix is this change's rule applied
    to writes: read first, throw on a failed read, insert only after.
  - `DrinkStore.save` swallows a failed save: the Health sample is already written,
    the log has no row, and the pending insert lands on the next save that works —
    the reader's intent arriving late, or a duplicate of the retry they made meanwhile.
  - The other `@Query` screens — Calendar, History, Trends — do not read `fetchError`.
    On the calendar that includes bulk fill: a failed first fetch shows recorded days
    as blank and offers them, and bulk fill seeds from the same empty query, so under
    the usual-drink seed it would queue a beer at beer's defaults.
- **Not verified:** any of this on hardware; a real I/O failure rather than a
  damaged file; VoiceOver over either state (the simulator tool's accessibility read
  was unavailable in this session); the watch counter on a 40/41/42mm case.

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

On the second 2026-09-16 amendment: if a reader reports Today or the watch counter
stuck on "Today's drinks couldn't be read." after the store has recovered — the log
reads fine after a relaunch — the fix is a new read on foregrounding, by re-creating
the screen's queries, not a write made to provoke one. And if a store ever reads as
empty with no error on a device that had a log, the truncated-file case above is the
first thing to check; no screen can distinguish it, so the evidence is the file.
