# Tallyist 1.4 — feature spec

Opened 2026-09-14 with the first 1.4 PR, the watch's Phase 0. Same shape as
the 1.2 and 1.3 specs: the project constraints and the App Review claims are
hard rules, each feature states what it adds and what it must not become, and
the claims table is the record of what was said to Apple and why it stays true.

## Project constraints

Unchanged from `docs/tallyist-1.2-spec.md` ("Project constraints" and "Stop
conditions"), and restated platform-neutrally in the product contract
(`contract/constraints.md`): no account, no servers, no goals, streaks, scores,
or advice, no user data shared between users, no consumption guidelines, report
never instruct, every new behavioural surface optional and off or neutral.
**The 1.3 train is frozen and awaiting App Review**; a fix that must ship in
1.3 is a new build and a re-submission, and says so.

## Feature A: the Apple Watch companion app — in progress

The whole of it is `docs/tallyist-watch-plan.md`: the decisions, the rules that
survive to the wrist, the architecture (a peer store mirrored through the same
CloudKit database; WatchConnectivity carries settings and never writes a row),
the four forced divergences, and eight phases. The owner's design for phases 3
to 6 is `docs/design/watch/`, with its five open questions answered at the end
of its README.

| Phase | State |
|---|---|
| 0 — the targets | **Done 2026-09-14.** Two targets, the shared scheme, entitlements, catalogs, icon, the verifier; the 1.4 bump. Recorded at the head of the plan's Phase 0. |
| 1 — the shared layer builds for watchOS | **Done 2026-09-14.** The package declares watchOS; `BundleIdentity` pins one App Group for the four identifiers; the shared catalog and the palette; `Shared/` and the package on both watch targets; the watch app opens the store and prints today's count; the `build-watch` CI job. Recorded at the head of the plan's Phase 1. Verified on hardware the same day: the watch's count follows the phone's about four to five seconds after a log. |
| 2 — the settings bridge | **Done 2026-09-14, ADR-0041.** `WatchContext` and its codec in the core package; the phone publishes region and counter seed over WatchConnectivity on activation, foreground and change; the watch stores them in its App Group under the keys `AppSettings` owns; the CloudKit probe runs on the wrist. Verified on the simulator pair, on activation and live. |
| 3 — the counter, and recording a day as no alcohol | **Done 2026-09-14, ADR-0042, ADR-0043, ADR-0045.** The counter over the shared store: ＋ through the one seed rule (`DrinkRepository.nextQuickDrink`, which Today, the day sheet and the widget now call too), − through `LoggedDrink.removableNewest` at tier 1, haptics, Double Tap, the region line, the storage strip, the tap to hide, and the no-alcohol button. Recorded at the head of the plan's Phase 3. Verified on the simulator pair by driving it, then on hardware by the owner the same day. |
| 4 — specify a drink | **Done 2026-09-14.** `TypePickerView` on a hold of ＋: five tiles that log the type at its defaults through `DrinkDraft(type:)`, one screen deep, back on the pick; the "Hold ＋" hint fills the counter's slot. Recorded at the head of the plan's Phase 4. Verified on the simulator pair and read back from its store. |
| 5 — the session, as dots | **Done 2026-09-14, ADR-0044.** One dot per drink in the sitting up to eight, in the rolling window's band from 3–5 up and outlined below it, over "N · 1h 12m"; behind the watch's own "Show session pace" switch at the bottom of the counter's scroll, off by default; eight rings and no line while hidden or redacted. Recorded at the head of the plan's Phase 5. Verified on the simulator pair. |
| 6 — complications | Next. |
| 7 — the live session bridge (optional) | The measured four-to-five-second CloudKit latency argues it may not be needed; decide after an evening's use, the plan's own criterion. |
| 8 — release | What's New (1.4), reviewer notes, the claims table re-verified against the watch, the privacy policy read against it, the watch screenshots. |

**What it must not become:** a standing number on a watch face that reads as
a score (constraint 3 — the complication shows a running session or today's
count and goes blank on a schedule), a second sync path (the bridge never
writes a row), or a Health writer (the watch requests no HealthKit
entitlement; the phone's backfill sweeps its rows).

## Also on this train

One phone-side fix that Phase 0 turned up: the iOS app's built `Info.plist`
had never carried `UIBackgroundModes` — the `INFOPLIST_KEY_` setting the
project relied on is not one Xcode injects — so CloudKit's silent pushes could
not wake the app and the store mirrored only in the foreground. Both apps now
carry an explicit `Info.plist` with `remote-notification`. It is a new
Background Modes entry for App Review to see; the reviewer notes for 1.4 should
say what it is for.

## App Review consistency

The four claims made for 1.0 hold unchanged on the watch and are re-verified
in Phase 8: no account, no server, no notifications sent by the app, no data
shared between users. The watch adds no data category, no collection and no
transmission the privacy policy does not already describe; Phase 8 confirms
that rather than assumes it, and if a line is needed all three copies change
together (ADR-0024).
