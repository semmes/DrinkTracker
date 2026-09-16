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

## Amendment, 2026-09-15 — the reopen clause fired, and the answer is still no

The clause below says to build Phase 7's snapshot "if an evening's use shows
the live number lagging the sitting — minutes, not seconds". **An evening did**
— the owner's phone and watch drifted apart on cellular for hours — and the
answer is still no. That needs saying plainly, because a trigger that fires and
is then declined is a record being rewritten, not a record being followed.

**The owner's ruling was the narrower question:** *"If you can improve the
latency issue, then let's do it. If it cannot be improved don't do it."*

**It cannot be improved on the leg that carries the drink.** The whole public
surface of `NSPersistentCloudKitContainer` in the iOS 26 SDK is schema
initialisation, record and record-ID lookup for a managed object, and three
`can…` permission checks. There is no expedite, no priority, no "push now" and
no "import now"; `ModelConfiguration` and `ModelContainer` expose no handle on
the mirroring container at all. The one platform lever that does force a
transfer is `CKSyncEngine.sendChanges` / `fetchChanges`, and adopting it means
replacing the mirroring stack and taking `CKRecord` identity back into the app
— which is the duplicate hazard this record exists to refuse. So the honest
sentence is not "four to five seconds is close to the floor" (Apple publishes
no floor) but **"there is no API, and the only lever is the thing we refused"**.

**And the snapshot would not have rescued the evening that fired the clause.**
Three facts, each checked rather than reasoned about:

1. **WatchConnectivity has no route to the face.** `DrinkTrackerWatchWidget`
   contains no `WCSession` and cannot; a WC payload is delivered to the *watch
   app*, and the complication is only ever redrawn by
   `WidgetCenter.reloadAllTimelines()` from that app. What was on the owner's
   wrist during a stall is the face, with the app not running.
   `transferCurrentComplicationUserInfo` looks like the exception and is not:
   it is gated on `isComplicationEnabled`, a ClockKit-era property that is
   false for a WidgetKit card, so its budget is zero and it degrades to a plain
   `transferUserInfo`.
2. **`sendMessage` is unavailable exactly when it would be wanted.** It
   requires `isReachable`, which on the watch means the watch app frontmost
   with the display awake. A person logging a drink on the phone is looking at
   the phone. This project also never implements
   `sessionReachabilityDidChange` and never retries, so a send into that window
   is simply lost.
3. **The remaining channels are explicitly not immediate.** Apple's own
   framing for a background transfer is posting a letter: it arrives, and not
   at a time you chose. `updateApplicationContext` — this project's shipped
   channel — is delivered "on next launch" by the header's own words.

**The design defects are independent of all that,** and each would have had to
be solved even if the transport had been sound. The payload's
`standardDrinks: Double` freezes a region lens onto the one figure that must
re-express when the region changes (invariant 3). Its four-hour window is
narrower than the watch's own query floor — the start of the previous day —
and cannot reproduce `SessionPace.currentSession`, which chains across gaps of
up to four hours without bound. Taken literally it feeds `sessionDrinks` and
not `todaysEntries`, so the dots would count a drink the numeral above them
does not. Widened to the numeral to fix that, − would remove a *different,
older, real* drink, because `removableNewest` re-reads the store at execution
time — with a success haptic and no toast, which is the shape ADR-0043
rejected by name. It carries no `healthKitSampleID`, so it strips the guard
ADR-0043 exists for, and no `AlcoholFreeDay`, so it could print a band and a
count under "Recorded as no alcohol today".

**Worth stating: the never-writes-a-row rule was never the binding
constraint.** Nothing proposed went near it. The snapshot fails on its
transport and on its own shape.

**The clause is reworded rather than deleted.** It was written about
wall-clock divergence between two devices nobody was looking at, and the
number it names is one the owner obtained by staring at both at once, which is
a test procedure and not a use. What matters to a reader is how stale the
figure is **at the raise** — see the reopen below.

**What the investigation did leave open, and did not build:** three latencies
that *are* this app's own, none of which the snapshot addresses and none of
which is authorised by a ruling about the four to five seconds. They are
recorded in `CLAUDE.md` for the owner's decision: the watch face's
sixty-second reload floor, the phone having no `.NSPersistentStoreRemoteChange`
observer at all, and the complication opening a second
`NSPersistentCloudKitContainer` on the shared store on every timeline build,
which is the one hypothesis for the cellular evening that lives *inside* this
app.

## Amendment, 2026-09-16 — one of the three open latencies is answered

The 2026-09-15 amendment left three latencies that are this app's own for the
owner. The owner answered their precondition — a card on the watch face and a
widget on the phone's home screen — and then reported the second one on hardware:
the phone has no `.NSPersistentStoreRemoteChange` observer, so a drink that reaches
the phone's store from the watch reloads nothing, and the widget keeps an old
number. It is answered by ADR-0047: the app reloads the widget when a CloudKit
import ends and when the app is left. Not with the watch's remote-change observer,
because on the phone only the app mirrors, so an import-end event cannot be caused
by a reload and needs no floor.

The other two stay open and unbuilt: the watch face's sixty-second reload floor, and
the complication opening a second mirroring container on every timeline build.

The device captures that answered this also correct part of the premise. The drink
the owner saw sync "when I opened the app" was logged in the **watch app** at
17:55:12 and imported by the phone at 17:55:59; the phone widget's ＋ tap had never
reached its intent at all. Where the receiving app was awake, the leg this record is
about took two to three seconds in both directions.

## How to reopen

- **Reworded by the 2026-09-15 amendment, which closed the original clause.**
  The question is not how far two unobserved devices drift apart; it is how
  stale the figure is *at the raise*, which is the only moment a reader is
  there to be misled. So: if raising the wrist within a minute of a drink
  logged on the phone shows the old number for longer than it takes to read
  it, that is the trigger — and the first thing to examine is the complication
  opening a second mirroring container on every timeline build, not a new
  channel. Phase 7's snapshot is refused on its own merits and is not the
  answer to a later firing of this clause; a record of why is in the
  amendment above.
- If duplicates ever appear across the two stores, the cause is a write
  reaching CloudKit by a second path; the fix is to remove the path, not to
  add a dedup pass.
- If the wrist ever needs to *set* the region or the seed, the context becomes
  two-way with the `sentAt` timestamp as the tiebreak, and that is a new
  decision with its own record, not an amendment to this one.
- If Apple ships a supported way to share an App Group's defaults between a
  phone and its watch, the bridge becomes unnecessary and this record's
  "settings, one way" clause is what to retire.
