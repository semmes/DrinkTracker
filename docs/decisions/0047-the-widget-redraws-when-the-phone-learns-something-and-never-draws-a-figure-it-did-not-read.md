# 0047 — The home-screen widget redraws when the phone learns something, and never draws a figure it did not read

**Status:** accepted · **Date:** 2026-09-16 · **Relates to:** ADR-0004, ADR-0041, ADR-0046; PRD invariants 4 and 5

## Context

The owner, on real hardware (Xcode-installed builds, iPhone 15 Pro on iOS
26.6.1 and a paired watch), reported: *"I then ran the widget on my phone as a
test and it did not sync, I needed to open the app for it to sync. When I
swiped the app closed and it went back to the widget, the widget showed 0 on my
phone and when i opened the app it showed 1 drink which matches my watch. When
I logged a drink in the phone app, the widget then registered two drink and the
watch updated."* Asked whether the widget changed to 1 for a moment after the
tap: *"It stayed at 0 the whole time."*

The reading of that report that seemed obvious — the widget's ＋ wrote a drink
the widget process could not sync — was **wrong**, and so was the first
hypothesis built on it (two containers on one store in one process; about 2,200
probe reads on this Mac never reproduced a failure). What settled it was each
device's own record, copied off both devices through Xcode and read with
`sqlite3`. The rows are quoted here because the copies were temporary.

**The phone's App Group preferences** held
`lastIntentBuild = "one-drink · com.shawnsemmes.DrinkTracker.Widget"` and **no
`lastWidgetLog` at all**. `LogOneDrinkIntent.perform()` writes that key on its
first line, from any process, and nothing in the code removes it. By the
bisect table in `Diagnostics.recordIntentBuild`'s own comment — build present,
log absent — **the tap never reached `perform()`**. All 843 persistent-history
transactions in the phone's store name `com.shawnsemmes.DrinkTracker` as their
bundle; none names the widget. The widget drew its ＋, and the tap did not run
it. Why is not known (see How to reopen).

**The phone's persistent history, 2026-09-16, EDT:**

| Txn | Time | Author | Change |
|---|---|---|---|
| 836 | 17:53:58 | CloudKit import | insert `DrinkEntry` 456 |
| 838 | 17:55:59 | CloudKit import | insert `DrinkEntry` 457 |
| 839 | 17:56:03 | the app | update `DrinkEntry` 457 (its Health sample) |
| 840 | 17:56:31 | the app | insert `DrinkEntry` 458 |

**The watch's persistent history, same evening:**

| Txn | Time | Author | Change |
|---|---|---|---|
| 187 | 17:53:56 | the watch **complication** | insert `DrinkEntry` |
| 190 | 17:55:12 | the watch **app** | insert `DrinkEntry` |
| 192 | 17:56:34 | CloudKit import | insert `DrinkEntry` |

So the evening was: a drink logged on the wrist at 17:55:12 reached the phone's
store by import at 17:55:59, when the owner opened the phone app; the "1 drink"
the app then showed was that drink; and the widget, which had correctly read 0,
was never asked to read again until the app's own log at 17:56:31 reloaded it
through `DrinkStore.save`, when it read 2. The sync itself was fast wherever the
receiving app was awake — the complication's drink reached the phone in two
seconds, the phone's reached the watch in three.

**Why the widget never re-read.** Every reload the phone had was tied to a
write this device made: `DrinkStore`'s save, adopt and delete, a region change
in `AppSettings`, the intents' own — and `DrinkStore.syncFromHealth`, which
reloads only when another app's Health data has actually changed. A row that
arrives by CloudKit import triggers none of them. Reproduced on the simulator:
with the app already open, a change made to the store underneath it left the
widget stale after the app was left, on a build of `origin/main` (b7a2ebf), and
redrew on the fixed build. A first attempt at that test changed the store
*before* opening the app and was not a test at all: the widget rebuilt and read
the new count as the app opened, from a reload the timeline did not then record
the cause of, so the old build would have passed it too. That unattributed
build is why every reload the app asks for now records its reason.

**A second defect, found reading the code, that did not draw this 0.**
`QuickLogProvider.currentEntry()` drew `drinkCount: 0` when
`SharedModelContainer.make()` threw, `DrinkRepository.drinks(on:)` turned a
failed fetch into an empty day, and a missing App Group makes `make()` open a
private empty store without throwing. Three ways to draw a confident zero, none
recorded — the exact failure ADR-0004 names as the real defect ("losing the store
looks like an empty log"), on the one surface that never got the fix. The watch
complication got it in Phase 6 for a failed open only; a failed fetch still drew
an empty day there.

## Decision

**The app redraws the home-screen widget when the phone learns something the
widget has not been told**: when a CloudKit import *ends* successfully, and when
the app leaves the foreground (`WidgetReloads`, started in `DrinkTrackerApp.init`).

**The widget never draws a figure it did not read.** A missing App Group, a store
that does not open, or a read that fails each draw the unavailable state — the drop
glyph and "drinks today", no figure, no ＋ — and try again in fifteen minutes. The
complication's reads throw into its existing unavailable entry the same way.

**Only the two apps' launches write `Diagnostics.storeMode`**, and every breadcrumb
says which process wrote it and when, with a short ordered timeline of intent steps,
widget builds, reloads and their reasons, failed imports and app activations under
Settings → Diagnostics.

## Consequences

- **What the owner's sequence now does.** A drink that reaches the phone's store by
  import while the app is open is on the widget as soon as the app is left; one that
  arrives while the app is in the background redraws the widget when the import ends,
  if iOS lets the app run to receive it. The second half has not been observed: the
  simulators have no iCloud account and never import, so it is a tier-4 item.
- **Why the import-end event and not `.NSPersistentStoreRemoteChange`.** The watch
  observes the remote-change notification and needed a sixty-second floor, because it
  fires for any writer to the store file and the complication's own container writes
  bookkeeping that re-triggers it. On the phone only the app mirrors — the widget holds
  no iCloud container — so an import-end event can only come from the app's own
  mirroring, and a reload cannot cause the next one. No floor.
- **Why leaving the foreground and not arriving.** An iPhone's home-screen widget cannot
  be seen while the app is in front, so a reload on arrival spends a refresh on a screen
  nobody is looking at and reads the store before an import that is about to land.
  Leaving reads the store after everything the app did. **Once per leave, at its first
  step**: going home is `.active` → `.inactive` → `.background`, and a reload requested at
  `.inactive` is requested while the app is still in the foreground, which Apple's
  "Keeping a widget up to date" lists as not counting against the widget's budget; one
  requested at `.background` is charged, and nothing can change between the two. The
  first cut reloaded at both and said the second cost nothing — the review caught it.
  `.inactive` also covers the app switcher, which can end the process without reaching
  `.background`; a jump straight from `.active` to `.background` reloads there instead.
- **It redraws a widget; it does not touch sync.** Nothing here asks CloudKit for
  anything. ADR-0004's refusal of anything that retries, forces or schedules a transfer
  stands, and `CloudKitSyncMonitor` still only records.
- **The unavailable state has no ＋**, following the complication: a ＋ beside no figure
  logs blind, and a tap whose effect cannot be seen invites the second tap that logs a
  duplicate. The cost is that a widget whose read failed cannot log until the next read
  works. It cannot be produced on purpose on hardware; it was rendered from a scratch build
  that forced it, in both appearances. No new copy: "drinks today" is an existing widget
  key and the drop is the shared catalog's `tally.standard`.
- **Only the two apps' launches write the store mode.** It is the key Settings'
  release-visible "IN MEMORY" warning reads, and it is last-writer-wins across every
  process in the group, so it has to mean how *this launch* opened the store. When
  `SharedModelContainer.make()` wrote it on every open, a widget build a second after the
  app fell back to memory could overwrite the warning with "shared, CloudKit requested" —
  and the widget now builds every time the app is left — and so could a Siri or Shortcuts
  intent running in the app's own process. `open()` now records nothing and returns the
  mode; `DrinkTrackerApp.init` and `DrinkTrackerWatchApp.init` write it. (The first cut
  checked for an `.appex` bundle instead, which stopped the extensions but not an
  in-process intent — the review caught that too.) The widget puts the rung it opened on
  in its own timeline line, which will be the first reading of that rung from an extension
  on a real device the project has.
- **Retracted:** `SharedModelContainer.make()`'s comment that writes from a process opened
  without CloudKit "fail silently". It was written in 6f759f6 while the widget's log was
  failing for a different reason that 17853f3 found four days later — a non-optional
  `@Parameter` with no default, abandoning the tap before `perform()` — and it was never
  observed. On 2026-09-16 the simulator's widget extension, which has no iCloud container,
  wrote three `DrinkEntry` rows whose history names `com.shawnsemmes.DrinkTracker.Widget`,
  and the app displayed them. See ADR-0004's 2026-09-16 amendment.
- **Refused: giving the widget extension the iCloud container.** TN3164 says to let one
  process manage sync; the widget calls `make()` uncached on every timeline build, so it
  would start a mirroring container on each; nothing documented says an extension lives
  long enough after a tap to export; it is an entitlement change on a shipping target and
  an App Review surface; and the owner's report, read from the device, contained no widget
  write for it to speed up.
- **Not built, and the owner's decision: running the widget's intent in the app's process**
  (a `LiveActivityIntent` conformance or an iOS 26 `supportedModes` declaration), so a
  widget-logged drink would be exported by the app that mirrors. A simulator probe showed
  such a conformance does move `perform()` into the app, but nothing Apple documents says
  the export completes before a background-launched app is suspended, it would put a
  second mirroring container in the app unless the container were cached, and it moves a
  path that works onto one never run on hardware. Under the owner's standing ruling a
  latency change that cannot be shown to help is not built.
- **Diagnostics grow.** Every breadcrumb carries a process, a date and a time — the date
  because the owner tests in the evenings, and yesterday's "saved · 18:57:41" read tonight
  would look five minutes old. A timeline of twenty lines records every intent step, every
  widget build and what it read, every reload the app process asks for *with its reason*,
  every CloudKit import that fails, and every app activation. It is written from two
  processes with no lock, so two writes in the same instant can drop a line; it is
  diagnostics, not a record, and it is Debug and TestFlight only. It cannot show a widget
  whose App Group does not resolve — that process writes to its own private defaults — so
  that failure is the glyph on the widget with no widget lines in the timeline.
- **Found in passing and deliberately not fixed here, because each belongs to shared code
  the app's own screens depend on:** `DrinkRepository.nextQuickDrink` reads history through
  `try?`, so a failed read seeds the counter's default rather than the day's drink;
  `markAlcoholFreeOrThrow` refuses a day with drinks by checking `drinks(on:).isEmpty`, so
  a failed fetch reads as empty and ADR-0011's backstop could let such a day be marked; and
  the app's `@Query` screens do not read `fetchError`. Each wants its own change.
  *(All three addressed the same day: the marker's refusal in ADR-0011's amendment,
  the seed in ADR-0042's, and the screens in ADR-0004's second 2026-09-16 amendment.
  The Health zero's copy of the refusal, which this list missed, is in ADR-0025's.)*

## How to reopen

- **If a widget ＋ tap on hardware again does nothing**, read Settings → Diagnostics before
  anything else, and find the time of the tap in the widget timeline. A tap that ran shows
  `intent: entered (one-drink) · Widget` then. A tap that landed outside the ＋ circle and
  opened the app shows `app active · app` then and no `intent:` line — read the *time*,
  not whether a widget build sits nearby, because the app asks the widget to redraw for
  reasons of its own around an activation. A tap that shows neither never reached the app
  or the intent; the next step is Console.app filtered to `chronod` and the widget
  extension at that moment.
- **If a drink logged on the watch still reaches the phone's store without redrawing the
  widget**, the timeline narrows it: `import failed — …` means the import ended in failure;
  `reload widget — import landed` followed by a widget build reading the *old* count means
  the store did not yet hold the row; no import line at all means no import event reached
  the app while it could hear one, which is iOS not waking it; and a leave with no
  `reload widget — app left the foreground` means the scene-phase path did not run.
- **If the owner wants a widget-logged drink on the watch without opening the phone app**,
  the app-process intent above is the route to cost properly — on a TestFlight build, since
  an Xcode install mirrors to CloudKit Development over the push sandbox — and it is a
  decision, not a fix.
