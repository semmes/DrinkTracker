# 0055 — One process per device mirrors the store: the app

**Status:** accepted by the owner on 2026-09-24, after a test on their iPhone
and watch that did not tell this build from the one before it (Measured on the
owner's devices); the TestFlight device check under Verification still gates
1.4's submission · **Date:** 2026-09-24 · **Relates to:** ADR-0041 (its
2026-09-15 amendment, latency 3), ADR-0046 (the complication), ADR-0047 (the
phone widget, which already works this way), ADR-0004 (invariant 5's failure
mode); TN3164, TN3163

## Context

On 2026-09-23 the owner was asked what should happen before 1.4 about the one
open item that could affect sync for real users — the watch complication
opening its own CloudKit-mirroring container on the shared store — and chose to
have it investigated and fixed that night. The cost the question named was that
a drink logged from the card's ＋ would reach the phone only once the watch app
next runs. This record states that cost more fully than the question did,
because the investigation found it larger, and the PR stayed a draft until the
owner had read it and had it tested on their own devices.

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
  exports. So on an evening logged only from the card, the drink may stay on the
  watch past the watch app's next run. **No upper bound is documented.** The
  phone, the phone's widget and Health see the drink only after that. On the
  owner's devices the card drink tapped on each build with no sync running on
  the watch waited until the owner opened the watch app: 21 minutes 46 seconds
  on this build, the last 20 of them with the app's mirroring set up and its
  import stalled, and 59 seconds on the build before it, where the app was
  opened sooner (Measured on the owner's devices).
- **It may give up a path seen working on hardware.** On 2026-09-15
  a card ＋ was found in the phone's History, with its Health sample, after the
  phone's next foreground. And ADR-0047's Context records the strongest data
  point there is: on 2026-09-16 a card drink written by the complication at
  17:53:56 (the watch's transaction 187) was imported on the phone at 17:53:58
  (the phone's 836), two seconds later, under the old entitlements. Which
  process exported it is not recorded — the complication's own delegate, or a
  watch app that happened to be running — but a two-second export from the card
  is what this change may give up, and this record first read it as the likely
  cost. The test on the owner's devices makes it less likely: on hardware no
  mirroring setup in the watch's store coincided with any of the complication's
  writes, even on the build that entitled it to mirror, so every export seen
  was most likely the watch app's. It does not show that the complication never
  exported, and the TestFlight check below is the one that gates 1.4.
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
so `CloudKitSyncMonitor` there sees every export (any the complication made
were invisible to it; none was seen on hardware).

**Knock-on.**

- `StoreChangeReloader`'s 60-second floor loses its stated cause — the
  complication's own CloudKit bookkeeping writes. It is kept and its comment
  rewritten: no remaining writer has been measured, and shortening it is the
  face's own latency, a separate decision (ADR-0041's latency 1).
- A write by a process that does not mirror, into a store the app on the same
  device actively mirrors (ADR-0004's tier-4 item), has now been seen exported on
  the watch: on this build the watch app sent the complication's writes only once
  it was opened, and a watch-app process the owner did not report opening set
  up mirroring and did not send them for twenty minutes (Measured on the owner's
  devices). On the phone it is still unread: the widget has done it
  since 1.0, its writes were seen landing on a simulator, and SwiftData records
  history for such a writer (the new tier-2 test), but no phone's export of one
  has been read.
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
wrote. The watch app's own setup failed with 134400 on the relaunch above, as it
does on every launch here. The owner's devices, on Xcode builds and CloudKit
Development, recorded no error 134410 in either store's CloudKit events during
the test, and the card drink tapped with no sync running on the watch left only
when the watch app was opened (Measured on the owner's devices). **The device
check**, on a TestFlight build (Production CloudKit and production push, which
the watch's sync has never run on), phone and watch on one account:

1. The shipped complication's entitlements, from the device build
   (`codesign -d --entitlements - …DrinkTrackerWatchWidget.appex`): App Group
   only.
2. Give each of the three triggers its own card drink. For each, force-quit the
   watch app, confirm in a full process listing that it is not running, tap the
   card's ＋, note the time, and list processes again during the wait (on the
   Xcode build a watch-app process appeared within 14 seconds of the 22:47:14
   tap). Leave the first such drink alone for twenty minutes and record whether
   anything sends it; on this change's Xcode build nothing did in 21 minutes,
   which is the cost the owner accepted and not by itself a reason to reopen.
   Then apply one trigger per drink: raise the watch app; with it closed, log a
   drink on the phone (which pushes to the watch); log a drink in the watch app.
   After each, read the phone's Settings → Diagnostics timeline and "Last
   synced" for when that card drink arrived, and watch the phone's History for
   it and its Health sample.
3. The watch-side lines in Console.app from the watch app's process: "Observed
   context save", "Observed remote store notification", "Exporting changes
   since", after each of the three.

If none of the three exports the card's drink promptly, How to reopen applies
before 1.4 is submitted, not after.

## Measured on the owner's devices, 2026-09-24

The owner asked for this change to be tested on their iPhone 15 Pro (iOS 27.0)
and Apple Watch Series 12 (watchOS 27.0), one iCloud account, with Xcode builds,
so CloudKit Development and the APNs sandbox. First the build already on both
devices, main at c7843dd, whose complication holds the iCloud container,
CloudKit and `aps-environment`; then this change's build
(d353351), installed at 22:33. Times are each device's own, read from copies of
the App Group store: persistent history (which process wrote each change) and
both stores' CloudKit events (setup, import, export). The owner tapped; the rest
was remote.

**The build whose complication is entitled to mirror (c7843dd).** Three card ＋
taps:

| Tap | The watch before it | Watch export | Phone import |
|---|---|---|---|
| 22:22:06 | Watch app force-quit by the test at 22:21:12; a mirroring setup at 22:21:33 fits it restarting; no CloudKit event after 22:21:36 | 22:23:05, when the owner opened the watch app | 22:23:08, 62 s |
| 22:23:14 | The owner had just opened the watch app and logged a drink in it (22:23:07); its exports ended at 22:23:09 | 22:23:29 to 22:24:08 | 22:24:09, 54 s |
| 22:27:10 | The watch app's delegate importing since 22:27:06, no setup before it; the import running at the tap (begun 22:27:07) failed at 22:27:11 and another ran at once | 22:27:12 to 22:27:13 | 22:27:13, 3 s |

Times are truncated to the second; the intervals come from the unrounded
times. The phone removed the two 22:23 drinks at 22:26:01. The import that
failed at 22:27:11 ended with error 134419, a code Core Data's public header
does not list; it was not looked into.

**This change's build (d353351).**

- **22:35:43.** The owner recalls tapping the card, but the row was written by
  the watch app's process through the app's own ＋. The card's intent never ran:
  it records "entered (one-drink)" before it opens the store, and nothing was
  recorded. A tap on the card's body, which opens the app, would reconcile the
  two. The watch app exported it at 22:35:43 to 22:35:44, and the phone imported
  it at 22:40:12, when the phone app next came to the foreground.
- **22:45:52 and 22:45:53.** Card ＋, written by the complication, while the
  watch app was resident (it had exported on its own at 22:40:24). The test
  force-quit the watch app at 22:45:59, and these two then waited with the next
  drink.
- **22:47:14.** Card ＋, written by the complication, with the card on screen in
  the Smart Stack and no watch-app process in a full listing at 22:47:00. A
  watch-app process was listed by 22:47:28; at 22:48:55 it set up mirroring and
  began an import, which then made no progress. That it was suspended is
  inferred from the stall: `devicectl` lists no run state. Remote launches of
  the watch app failed from 23:01 to 23:04 while its link was down. The owner
  opened the watch app at about 23:08:59: the import ended at 23:09:00, the
  export ran from 23:09:00 to 23:09:01, and the phone imported all three drinks
  at 23:09:01. **No export for 21 minutes 46 seconds.**

**What it shows.**

- **It did not tell the two builds apart for a card drink with the watch app
  idle.** The matching pair is 22:22:06 on the old build and 22:47:14 on this
  one. Both were card drinks tapped with no sync running on the watch, and both
  waits ended only when the owner opened the watch app: the watch's export
  began 59 seconds and 21 minutes 46 seconds after the tap, and the phone had
  the drinks at 62 seconds and 21 minutes 47 seconds. The difference is when
  the app was opened. The 3-second drink had the watch app's delegate already
  importing, and the 22:23:14 drink had the app used seconds before, so neither
  pairs with a drink on this build.
- **The complication's own mirroring was never seen on hardware.** None of its
  six writes on the old build that day (21:14:12, 21:17:19, 21:17:20, 22:22:06,
  22:23:14, 22:27:10) coincides with a mirroring setup in the watch's store; on
  the simulator pair two did. Every setup during the test fits a watch-app
  process (the event table names no process, so on the old build this rests on
  timing; on this change's build only the app can set one up): four came within
  about 21 seconds of a force-quit, a reopen or the phone app's launch, and the
  22:48:55 one about 90 seconds after its process was first listed (22:47:28).
  So every export seen here is most likely the watch app's. That does not show
  the complication never exports on hardware.
- **The idle card drink on each build waited until the watch app was opened**:
  59 seconds on the old build, where the owner opened it sooner, and 21 minutes
  46 seconds on this one. The test could not show whether the old build's would
  have waited longer, or whether its complication ever exports on its own. On
  this build a resident watch app that had gone quiet held three card drinks
  for over twenty minutes. On the old build a card drink tapped seven seconds
  after the app was used began exporting 15 seconds after the tap, and the
  export itself took 39 seconds. No bound is documented, and none was found.
- **No error 134410** appeared in either store's CloudKit events that night, on
  either build.
- **The phone was not in the foreground throughout.** It was launched remotely
  at 22:34:21 and came back to the foreground at least twice, around 22:35:22
  and 22:40:12, the second time when the owner opened it to check. Its store
  holds one import open from 22:40:39 to 23:09:01, ending within a second of
  the watch's export, which fits a suspended phone app woken by the push. The
  wait measured here is the watch's, not the phone's.

**Also seen, and not explained.** A watch-app start, going by a mirroring
setup or a process listing, came four times when the owner had not reported
opening the app: at 22:21:33, 21 seconds after a
force-quit (not the settings bridge: the watch had received no new context
since 21:20); at 22:34:22, a second after the phone app was launched, which
fits the settings bridge delivering (ADR-0041); at 22:35:27, 21 seconds after
another force-quit and 5 seconds after the phone sent a context, so either, or
someone opening it; and by 22:47:28, just before or after the card's ＋. And the
22:35:43 drink above, written by the app's ＋ when the owner recalls the card.

**How the decision was made.** The owner first declined this change on my
recommendation. The question put to them said merging makes a card drink wait
on the watch until the watch app is opened, 22 minutes here with no upper
bound, and described not merging as keeping "the complication syncing itself,
as now", which the test never showed. Behind the recommendation was a
comparison of mine that set the 21 minutes 46 seconds against the 3-second
drink, the wrong pair; the question did not show it. Told that the test had not
separated the builds, the owner was asked again, and that question still
recommended not merging: an entitlement change just before 1.4, for a collision
no device has shown, adds risk with no measured gain. The owner chose to merge
it against that recommendation. What the decision weighs is the documented
collision, which no device has shown, against a cost this test did not show the
change adds, since the idle card drink on each build waited until the watch app
was opened. The risk of changing entitlements just before 1.4 is part of what
it accepts, and the TestFlight check under Verification is where that risk is
read.

**How it was measured, for next time.**

- **Store copies.** `xcrun devicectl device copy from --device <UDID>
  --domain-type appGroupDataContainer --domain-identifier
  group.com.shawnsemmes.DrinkTracker --source "Library/Application
  Support/default.store" --destination <local path>`, and the same for `-wal`
  and `-shm`. Take all three every time and retry: the watch's link
  drops when the wrist is down, and a store copied without its WAL reads stale.
  Open copies of the copies, because opening one checkpoints its WAL.
- **Reading them.** The writing process is `ATRANSACTION.ZPROCESSIDTS` (with
  `ZAUTHORTS` and `ZBUNDLEIDTS`) joined to `ATRANSACTIONSTRING`; CloudKit
  events are `ANSCKEVENT`, type 0 setup, 1 import, 2 export. Times are seconds
  since 2001-01-01. In SQLite compare them with an integer, not with
  `strftime`'s text, or every row is dropped silently.
- **Breadcrumbs.** The App Group's preferences plist, copied the same way:
  `diagnosticTimeline` and `lastWidgetLog` say whether the card's intent ran,
  `lastWatchContextReceived` when the phone last sent a context, and
  `lastSyncSucceededAt` the watch app's last sync.
- **Processes.** `xcrun devicectl device info processes --device <UDID>` pads
  its lines with trailing spaces and can return a partial or empty list when the
  link drops, so trust only a full listing (hundreds of lines). It gives no run
  state. The watch app restarted within about 21 seconds of two force-quits
  here, and not for over a minute after a third, so take a listing before each
  tap rather than assuming.
- **Screens and taps.** `xcrun devicectl device capture screenshot --device
  <UDID> --destination <file>` shows what the watch shows, so check the card is
  on screen before asking for a tap. `devicectl` has no touch input, so the
  owner taps, and remote launches fail while the link is down. Installs used
  `xcrun devicectl device install app --device <UDID> <path to .app>`, the watch
  app installed on the watch directly.

## How to reopen

- **If the device pass shows a card drink that none of the three triggers under
  Verification exports promptly**, the choices, each its own decision: a
  watch-app background refresh (about four an hour, and only with the
  complication on the active face; a few seconds each; an export inside one is
  not guaranteed); a cue on the card that a drink has not synced; making the
  card's ＋ open the watch app (a product change to ADR-0046); or restoring the
  three entitlement keys and accepting the collision, which is one file.
- If Apple documents a background app-process route for a widget button's
  intent on watchOS, (d) becomes the fix that keeps the export prompt.
- If the owner's out-of-step symptom recurs with this in place, the in-app
  hypothesis is refuted, and ADR-0041's outside causes are what remain.
