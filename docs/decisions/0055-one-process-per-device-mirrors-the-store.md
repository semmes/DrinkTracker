# 0055 — One process per device mirrors the store: the app

**Status:** proposed — built and verified as far as simulators reach on
2026-09-24; accepted when the owner accepts the cost below and the PR merges ·
**Date:** 2026-09-24 · **Relates to:** ADR-0041 (its 2026-09-15 amendment,
latency 3), ADR-0046 (the complication), ADR-0047 (the phone widget, which
already works this way), ADR-0004 (invariant 5's failure mode); TN3164, TN3163

## Context

On 2026-09-23 the owner was asked what should happen before 1.4 about the one
open item that could affect sync for real users — the watch complication
opening its own CloudKit-mirroring container on the shared store — and chose to
have it investigated and fixed that night. The cost the question named was that
a drink logged from the card's ＋ would reach the phone only once the watch app
next runs. This record states that cost more fully than the question did,
because the investigation found it larger, and the PR stays a draft until the
owner has read it.

**What the complication did.** Phase 0 gave both watch targets the same
entitlements — the App Group, the iCloud container, CloudKit and
`aps-environment` — and SwiftData's `.automatic` mirrors in any process whose
entitlements name a container. The complication opens the store on every
timeline build (`CounterComplication.load`) and on every card ＋
(`LogOneDrinkIntent.perform`), uncached. On a scratch watch simulator on
2026-09-23 its process (`DrinkTrackerWatchWidget`) set up an
`NSCloudKitMirroringDelegate`, registered export, import and setup activities
with the CloudKit scheduler, and tore them down ("Store Removed") within the
same build. The owner's working simulator pair's store holds setup events that
started at the exact second of two card ＋ transactions and never ended. The
watch app mirrors the same store at the same time.

**What Apple says about that.** TN3164 names the case: an app and its
extension that both use `NSPersistentCloudKitContainer` on one shared store can
fail with error 134410, because "you don't control an extension's lifecycle",
and its advice is to "consider having the app in charge of the
synchronization". It also warns about several containers on one store inside a
single process, which a per-build open approaches. The phone already follows
the advice: the home-screen widget holds the App Group alone, and ADR-0047
refused giving it the container for this reason.

**Why it mattered now.** ADR-0041's amendment named this as the one hypothesis
for the owner's cellular evening (2026-09-15, phone and watch out of step for
hours) that lives inside the app. Nothing here shows it was the cause; a
simulator with no iCloud account cannot produce the collision at all, because
every mirroring setup fails first with 134400.

**The options, and why the others lose.**

- **(a) Take the iCloud container, CloudKit and `aps-environment` off the
  complication**, leaving the App Group, exactly as the phone widget is.
- (b) Keep the entitlements and pass `cloudKitDatabase: .none` for extensions
  inside `make()`. A weaker guarantee (a code path, not the OS), and it breaks
  invariant 5's "identical configuration" in letter.
- (c) Both. Buys nothing the CI check below does not.
- (d) Run the card's intent in the watch app's process, so the app writes and
  exports. No documented watchOS route: `LiveActivityIntent` and
  `PushToTalkTransmissionIntent` are not on watchOS, `openAppWhenRun` is
  deprecated, fails in an extension and opens the app, `AudioPlaybackIntent`
  would misdescribe the intent, and nothing documents `supportedModes` moving a
  widget button's intent.
- (e) Read without mirroring but let the ＋ mirror: keeps the collision exactly
  at the moment of a write. Caching the container: moot once nothing mirrors.

## Decision

The complication holds the App Group and nothing else. On each device the app
is the one process that mirrors the store; the phone's widget and the watch's
complication read and write it without mirroring. `make()` is unchanged, so
every process still opens the store with identical configuration and the
entitlement decides who mirrors. `scripts/verify-watch-setup.py` checks it per
target — the phone app and the watch app must hold the container, CloudKit and
`aps-environment`, the phone widget and the complication must hold none of them
— and runs in CI as its own job (`watch-wiring`), so re-adding the capability in
Xcode fails the build rather than quietly mirroring.

## Consequences

**The cost, in full.**

- **A drink logged from the card's ＋ reaches CloudKit only through the watch
  app.** The complication writes it to the watch's store; the watch app's
  mirroring is what exports it. TN3163 documents what schedules an export: a
  context save, or a remote-change notification the running app observes.
  Nothing documented makes the watch app export on launch, and it schedules no
  background refresh; CloudKit's silent push wakes it only when another device
  exports. So on an evening logged only from the card, the drink may stay on
  the watch until the watch app next runs, and possibly until the app's next
  write of its own. **No upper bound is documented.** The phone, the phone's
  widget and Health see the drink only after that.
- **It gives up a path that has been seen working on hardware.** On 2026-09-15
  a card ＋ was found in the phone's History, with its Health sample, after the
  phone's next foreground. And ADR-0047's Context records the strongest data
  point there is: on 2026-09-16 a card drink written by the complication at
  17:53:56 (the watch's transaction 187) was imported on the phone at 17:53:58
  (the phone's 836), two seconds later, under the old entitlements. Which
  process exported it is not recorded — the complication's own delegate, or a
  watch app that happened to be running — but a two-second export from the card
  is what this change may give up, and it should be read as the likely cost,
  not a remote one. The owner's check reported on 2026-09-24 ran on an Xcode
  build of main from before this change (CloudKit Development): drinks logged
  from the card's ＋ and in the watch app showed up in the phone app about 1 to
  2 seconds after it was opened. It is not a baseline for the card's path on
  its own, because the watch app was used too, in an order not recorded, and on
  that build both processes mirrored. An Xcode build of this branch, with the
  watch app force-quit before the card's ＋, would be the like-for-like
  comparison; the device check below is the one that gates 1.4.
- **Import was not costed either.** Before the change the complication also
  registered an import activity. Whether it ever imported a phone drink on its
  own, ahead of the watch app, is unknown; if it did, a face reloaded from the
  complication's own import is a second thing this gives up. The watch app's
  remote-change reload (ADR-0046) remains the documented path.
- **It can reproduce the out-of-step picture by design**, and a reader who sees
  the phone lagging may log the drink again there: a duplicate. Nothing on the
  card says a drink has not left the watch. TN3164's other half, a reminder in
  the extension to open the app, is not drawn (see How to reopen).
- **What does not change:** the watch's own face and counter show the drink at
  once (the intent reloads the face; the counter reads the same store); drinks
  logged in the watch app itself export as before.

**What it buys.** The documented two-process collision is gone from the watch,
the one in-app suspect for the cellular evening with it, and every timeline
build now only reads: no delegate set up and torn down, no scheduler
registration, per build. The watch app becomes the only exporter on the watch,
so `CloudKitSyncMonitor` there sees every export (the complication's were
invisible to it).

**Knock-on.**

- `StoreChangeReloader`'s 60-second floor loses its stated cause — the
  complication's own CloudKit bookkeeping writes. It is kept and its comment
  rewritten: no remaining writer has been measured, and shortening it is the
  face's own latency, a separate decision (ADR-0041's latency 1).
- A write by a process that does not mirror, into a store the app on the same
  device actively mirrors, is unverified on hardware on either device
  (ADR-0004's tier-4 item). The phone widget has done it since 1.0; its writes
  were seen landing on a simulator, and SwiftData records history for such a
  writer (the new tier-2 test), but the export path after it is unobserved.
- After a future schema bump the complication, like the widget, may be the first
  process to open the upgraded store; `SchemaVersions.swift`'s recipe carries
  the device step.

## Verification

On a throwaway Series 12 (46mm, watchOS 27.0) paired with a throwaway iPhone,
with no iCloud account, the card placed in the Smart Stack, 2026-09-23:

- **Signed entitlements, read from the builds' simulated `.xcent` files.**
  Before (main): the complication held `aps-environment`, the iCloud container,
  CloudKit and the App Group. After: the App Group alone. The watch app keeps
  all four.
- **The complication's process, from its own log.** Before: a timeline build set
  up an `NSCloudKitMirroringDelegate`, registered export, import and setup
  activities with the scheduler, and tore them down ("Store Removed"). After: a
  timeline build opened the store (SwiftData's "Store URL" line) and wrote no
  line mentioning CloudKit at all — 1,537 lines of that process, none; no
  read-only or history-tracking warning.
- **The card's ＋ after the change**, tapped in the Smart Stack: the card redrew
  from 2 to 3 with three dots; the store gained the row; its transaction (3)
  names `com.shawnsemmes.DrinkTracker.watchkitapp.Widget` as its bundle, in a
  store carrying the mirroring container's 34 metadata tables; the breadcrumb
  reads "saved (one-drink) · watchkitapp.Widget". The watch app, relaunched,
  showed 3 with the sitting's dots.
- **Tier 2:** `UnmirroredStoreHistoryTests` — a store opened `.automatic` in a
  process with no entitlements records a history transaction for a
  `logOneDrink` write, readable from a second container. It pins the history
  premise only; it passes whether or not any target holds any entitlement.
- **The verifier**, in a scratch copy: the iCloud keys back on the complication,
  `aps-environment` on the phone widget, `aps-environment` off the watch app,
  `aps-environment` off the phone app, and `CloudKitStatusProbe.swift` compiled
  into the complication each fail it;
  the control passes.

**What a simulator cannot show, and so is the gate before 1.4 ships:** the
collision itself (error 134410 — "another instance of this persistent store
actively syncing"), since without an account every setup fails first with
134400; and whether and when the watch app exports a drink the complication
wrote. The watch app's own setup failed with 134400 on the relaunch above, as
it does on every launch here. **The device check**, on a TestFlight build
(Production CloudKit and production push, which the watch's sync has never run
on), phone and watch on one account:

1. The shipped complication's entitlements, from the device build
   (`codesign -d --entitlements - …DrinkTrackerWatchWidget.appex`): App Group
   only.
2. With the watch app force-quit, tap the card's ＋ and note the time. Then,
   separately: raise the watch app; leave it closed and log a drink on the phone
   (which pushes to the watch); and log a drink in the watch app. After each,
   read the phone's Settings → Diagnostics timeline and "Last synced" for when
   the card's drink arrived, and watch the phone's History for it and its
   Health sample.
3. The watch-side lines in Console.app from the watch app's process: "Observed
   context save", "Observed remote store notification", "Exporting changes
   since", after each of the three.

If none of the three exports the card's drink promptly, How to reopen applies
before 1.4 is submitted, not after.

## How to reopen

- **If the device pass shows card drinks lingering for hours**, the choices,
  each its own decision: a watch-app background refresh (about four an hour, and
  only with the complication on the active face; a few seconds each; an export
  inside one is not guaranteed); a cue on the card that a drink has not synced;
  making the card's ＋ open the watch app (a product change to ADR-0046); or
  restoring the three entitlement keys and accepting the collision, which is one
  file.
- If Apple documents a background app-process route for a widget button's
  intent on watchOS, (d) becomes the fix that keeps the export prompt.
- If the owner's out-of-step symptom recurs with this in place, the in-app
  hypothesis is refuted, and ADR-0041's outside causes are what remain.
