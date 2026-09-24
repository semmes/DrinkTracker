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
**1.3 is approved and live** (2026-09-20 by the store's version history; the
owner reported the approval on 2026-09-23), so 1.4 is the next version people
install. **1.4 carries two features, the watch (Feature A) and Apple Health on
Trends (Feature B)**: the owner decided it on 2026-09-23, reversing the health
pairing plan's decision 4 (ADR-0054). Their release work landed together, in
one policy change and one set of App Store material (the pairing's Phase 7 and
the watch's Phase 8, below).

## Feature A: the Apple Watch companion app — done

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
| 6 — complications | **Done 2026-09-14, ADR-0046.** Four families on `StaticConfiguration`: today's count in the day's band everywhere (the tile shrunk to a disc), the sitting only as dots on the rectangular card, whose ＋ runs `LogOneDrinkIntent`; a timeline with an entry at each change the face makes on its own, ending with the sitting; redaction to the glyph and the words. Recorded at the head of the plan's Phase 6. Verified on the simulator's Smart Stack, including a log from the card's ＋. **The owner's device pass passed on 2026-09-15**, and produced three edits (the circular numeral alone, the session-pace switch gated on a drink, the type named back on a pick) plus one field report, all merged in PR #102. |
| 7 — the live session bridge (optional) | **Not built. Closed 2026-09-15** on the owner's ruling and an investigation recorded in ADR-0041's amendment: the leg that carries the drink cannot be expedited (no API on `NSPersistentCloudKitContainer`; the only lever is `CKSyncEngine`, which means owning `CKRecord` identity), and WatchConnectivity cannot reach the face at all — the complication holds no `WCSession`. The phase's own text carries two errors, corrected where it is closed in the plan. Three app-owned latencies the investigation found are the owner's open question, recorded in `CLAUDE.md`. |
| 8 — release | **Done 2026-09-24, with the pairing's Phase 7 (ADR-0054).** What's New (1.4) and reviewer notes, the Background Modes entry explained, in `docs/app-store-listing.md`; the claims table below re-verified against the built watch; the privacy policy read against it and **changed** (the plan's read, that it needed no line, did not survive the audit: it named only the phone's widget, said nothing of the watch's own copy of the log, and its "only network traffic" sentence left out the settings the phone sends the watch); the four privacy manifests corrected to Apple's App Group reason. Candidate watch screenshots from a scratch simulator are in `Claude outputs/1.4-screenshots/`; choosing and uploading them is the owner's. |

**What it must not become:** a standing number on a watch face that reads as
a score (constraint 3 — as built, every family shows today's count in the
day's band and resets at the next midnight, and the sitting appears only as
dots on the rectangular card behind an off-by-default switch, ADR-0046; the
spec's first wording here, "a running session or today's count, blank on a
schedule", predates that ADR), a second sync path (the bridge never writes a
row), or a Health writer (the watch requests no HealthKit entitlement; the phone's
backfill sweeps its rows).

## Feature B: Apple Health on Trends — done

The whole of it is `docs/tallyist-health-pairing-plan.md` (the risk, the four
rules, the stop conditions) and ADR-0048 to ADR-0053. If the reader turns it
on, Trends shows four figures from Apple Health beside the log (resting heart
rate, sleep, heart rate variability, sleeping wrist temperature), each as the
reader's own average over nights with drinks logged and over nights recorded
as no alcohol, with the night counts. Read-only, one switch per metric off by
default, a one-time offer on Trends, read for one render and never stored.

| Phase | State |
|---|---|
| 0 — research | **Done 2026-09-21** (PR #112), `docs/health-pairing-phase-0-findings.md`. |
| 1 — the domain | **Done 2026-09-21** (PR #113), ADR-0048. |
| 2 — the read layer | **Done 2026-09-21** (PR #114), ADR-0049. |
| 3 — resting heart rate end to end | **Done 2026-09-21** (PR #115), ADR-0050 and ADR-0051. |
| 4 — sleep | **Done 2026-09-22** (PRs #116, #117). |
| 5 — heart rate variability | **Done 2026-09-22** (PR #118), ADR-0052. |
| 6 — wrist temperature | **Done 2026-09-22** (PR #119), ADR-0053; the columns' floor (PR #120) and the owner's iOS 27 device pass (PRs #121, #122). |
| 7 — release | **Done 2026-09-24 (ADR-0054).** The privacy policy's three copies name the four types, read-only and never stored (the third is pushed by the mirror on merge); `NSHealthShareUsageDescription` names them in both configurations; App Privacy confirmed as Data Not Collected with the reasoning below; reviewer notes and What's New in `docs/app-store-listing.md`. |

**What it must not become:** a verdict. The plan's four rules hold by
structure, and the reviewer notes say which: both sides and never a delta,
correlation shown and causation never claimed, a gate in both buckets, and
never the reverse direction (no physiology reading drinking).

## Also on this train

One phone-side fix that Phase 0 turned up: the iOS app's built `Info.plist`
had never carried `UIBackgroundModes` — the `INFOPLIST_KEY_` setting the
project relied on is not one Xcode injects — so CloudKit's silent pushes could
not wake the app and the store mirrored only in the foreground. Both apps now
carry an explicit `Info.plist` with `remote-notification`. It is a new
Background Modes entry for App Review to see; the 1.4 reviewer notes say what
it is for.

The rest of the train: the phone widget redraws when
an import lands and draws no figure it did not read (ADR-0047); a failed read
or save is shown as one, never as an empty day (ADR-0004's amendments); the
Settings iCloud row says "Syncing" only once something has moved; the owner's
iOS 27 device pass (flat ink on glass, a native range picker, segmented pickers
on plain glass); Trends' three comparisons as one card (ADR-0038 amended); the
Settings copy pass; and, with the release, the four privacy manifests' defaults
reason corrected to Apple's App Group reason (1C8F.1).

## App Review consistency

Re-verified on 2026-09-23 against main, with the watch and the pairing built,
and the four manifests, four entitlements files and every Info.plist read and
diffed against the last 1.3 commit (3b57382). This section first said "the four
claims made for 1.0 … no account, no server, no notifications sent by the app,
no data shared between users". That was not the 1.0 response's list (the 1.2
spec's is, below), and "no notifications" was never literally true: the tip
jar's opt-in local renewal reminder has shipped since 1.0.

| Claim made in the 1.0 response, kept through 1.3 | 1.4 |
|---|---|
| "no goals, streaks, scores, or advice" | Preserved on both new surfaces. The watch shows today's count on the calendar's scale and nothing it could be measured against; its optional session dots are counts in a window, off by default. The Health card is two averages side by side with night counts: no difference computed, nothing coloured, signed or ranked, no threshold, no advice, and no physiology used to read drinking (ADR-0050). |
| "No user-generated content is shared between users" | Preserved. The watch's log is the user's own, in the user's own private CloudKit database; WatchConnectivity links only the same user's paired phone and watch and carries two settings. Nothing the pairing reads from Health leaves the device. Alcohol samples imported from Health become log rows and sync like every other row, only through the user's own private CloudKit database. |
| "There are no accounts of any kind" | Preserved. The only CloudKit call outside mirroring is `accountStatus()`, which reads the device's iCloud sign-in. |
| "External services, tools, and platforms ... None" | Preserved. New frameworks are Apple's only (WatchConnectivity, WatchKit, CloudKit in the watch processes, four HealthKit read types). `Package.resolved` is byte-identical to 1.3's; the watch targets link the local core package alone. |

| Other claims the notes, listing and policy make | 1.4 |
|---|---|
| "No networking code of its own" (policy, notes) | Holds. No `URLSession`, `Network`, web view or image loader in the app's code; the only URLs are system-opened links. Unchanged nuance: ComponentsKit carries `URLSession` in an Avatar component the app never uses, linked into the iOS app only. |
| The only network traffic is Apple's iCloud sync and App Store purchases (policy) | **Changed in the policy.** The phone now sends its paired watch two settings over WatchConnectivity (`WatchContext`: region, counter seed, a version, a timestamp), never a row. The policy now names the settings and the time they were sent, and says "nothing else about you". The App Store half also names the tip jar's product fetch: opening Buy me a drink loads products and entitlements from the App Store whether or not a tip is left. |
| "Tallyist reads no other Health data" (policy) | **False on main from the pairing's Phase 3; true again.** The sentence now follows a list of what is read: the alcohol category, and the four pairing types plus the temperature unit, only if switched on. |
| The purpose string explains the reads | **Rewritten.** It described alcohol only, while the pairing's sheet listed heart, sleep and wrist types (seen on a scratch simulator before the change). It now names all four, in Debug and Release. |
| "No new permissions" (the 1.2 and 1.3 notes' closing line) | **Not repeated.** 1.4 adds a HealthKit read request for four types, a watch app, and the remote-notification background mode on both apps. The 1.4 notes' closing line says so. |
| Health writes: only the drinks you log, as alcoholic beverages | Holds. The one share set is the beverage type; the pairing asks `toShare: []`; nothing on the watch imports HealthKit. |
| The watch writes no Health data | Holds. No HealthKit entitlement or import in either watch target. |
| Counts on the watch are privacy-sensitive (notes) | Holds as worded: "marked privacy-sensitive, so watchOS redacts them on a locked watch". Every complication family's figure is `.privacySensitive()` (`CounterComplication.swift`), and the owner's device pass saw the card redact with the watch off the wrist. Always-On is not claimed for complications: there it depends on the wearer's Hide Sensitive Complications setting. The watch app's own count is concealed under `.privacy` redaction (`CounterTile.swift`, ADR-0045); design-system §9 records two things Always-On still shows beside it. |
| No notifications from the app | Holds with the nuance the contract records: the tip jar's local renewal reminder, opt-in, unchanged since 1.0. The watch, the complication and the pairing post nothing; `aps-environment` serves CloudKit's silent pushes only. |
| Data Not Collected; no new privacy label categories | Holds. See "App Privacy" below. |
| No new third-party code | Holds (above). |
| Privacy manifests declare every required-reason API | **Corrected.** All four declared UserDefaults reason CA92.1, the app-only reason, while every target uses the App Group suite, whose reason is 1C8F.1 (Apple's `NSPrivacyAccessedAPITypeReasons`, read 2026-09-23). The app now declares both (its appearance setting is in the standard suite); the widget, watch app and complication declare 1C8F.1. The pairing's `ContinuousClock` timing is not on Apple's required-reason list. |
| `ITSAppUsesNonExemptEncryption = NO` covers the upload | Set on the iOS app only; the embedded watch app is not a separate submission. Unverified until the first 1.4 upload. |

### App Privacy

**Data Not Collected stays true, and no answer in App Store Connect changes.**
The reasoning, checked rather than assumed, as the pairing plan's "Release"
asks:

- Apple's definition (quoted in `docs/health-pairing-phase-0-findings.md`):
  "collect" means transmitting data off the device so the developer or a
  partner can access it, and data processed only on the device is not
  collected.
- The drink log leaves the device only through the user's own private
  CloudKit database and their own HealthKit store, neither of which the
  developer can read (unchanged since 1.0; the iOS manifest's comment says so).
- The pairing's four types are read into memory for one render and discarded:
  no SwiftData field, no `UserDefaults` value, no CloudKit record, no cache, no
  file (ADR-0049, and each phase's grep of its added lines). The one thing
  written about a read is a Diagnostics line holding the metric's name, the
  window's day count and the read's duration, stamped with the process and the
  time, on the device.
- The watch adds no collection: its store mirrors through the same private
  database, WatchConnectivity links the user's own two devices, and it has no
  Health access at all.
- All four manifests carry an empty `NSPrivacyCollectedDataTypes` and
  `NSPrivacyTracking` false.

The answer would change the moment a Health value, or anything else, left the
device to a server; the policy promises to change before any such version
ships.

Reviewer notes and What's New for 1.4 are in `docs/app-store-listing.md`.
