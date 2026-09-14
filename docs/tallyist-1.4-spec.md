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
| 1 — the shared layer builds for watchOS | **Done 2026-09-14.** The package declares watchOS; `BundleIdentity` pins one App Group for the four identifiers; the shared catalog and the palette; `Shared/` and the package on both watch targets; the watch app opens the store and prints today's count; the `build-watch` CI job. Recorded at the head of the plan's Phase 1. |
| 2 — the settings bridge | Next. |
| 3 — the counter, and recording a day as no alcohol | |
| 4 — specify a drink | |
| 5 — the session, as dots | |
| 6 — complications | |
| 7 — the live session bridge (optional) | |
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
