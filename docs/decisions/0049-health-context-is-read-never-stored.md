# 0049 — Health context is read, never stored

**Status:** accepted · **Date:** 2026-09-22 · **Relates to:** ADR-0048 (a
drinking night is not a calendar day; the domain this layer feeds);
ADR-0014 (the beverage import, the app's other read of Health); ADR-0004
and its 2026-09-16 amendments (Health follows the log); ADR-0047 (the
Diagnostics timeline and its breadcrumbs); ADR-0024 (the privacy policy's
three copies); PRD invariants 5, 6 and 9;
`docs/tallyist-health-pairing-plan.md` (decision 5, "Architecture", "HealthKit
will not tell you a read was denied", the stop conditions);
`docs/health-pairing-phase-0-findings.md` (questions 3, 4 and 5; the owner's
decision on question 3)

The second of the health pairing's records. The plan reserved a number for
it that the watch took; the next free one is this.

## Context

The pairing shows a person two averages of their own Health data beside
their log. Everything else the app shows comes from its own store, which
mirrors to CloudKit; this is the first figure the app derives from data it
does not own. Four things had to be settled about how it is read, and the
obvious build gets three of them wrong.

**Where the data lives while the app has it.** The obvious build caches: a
year-range query on every render looks expensive, so the natural move is to
keep the last result — in memory, in the App Group, in the store. The plan
refused that in advance (decision 5) and left the argument to this record.
The store mirrors to CloudKit, so a health value written there is health
data in the person's iCloud database: a schema version, a CloudKit console
deployment, a migration fixture, a privacy-label question and a
privacy-policy rewrite at once — and, Phase 0 found, a review rule as well:
App Review guideline 5.1.3 (ii), "may not store personal health information
in iCloud". The App Group is where the widget and the watch read, and a
value there is a value four processes can show. Even a private in-memory
cache is a copy whose lifetime nobody audits.

**What a read that returns nothing means.** HealthKit refuses, by design,
to say whether a read was denied: `authorizationStatus(for:)` reports share
permission only, so that a person cannot be probed for what data they
have. `HealthKitService` has said so in two comments since ADR-0014. The
pairing adds three more reasons for an empty read — a watch that cannot
measure the metric, a night it was not worn, a device the data never
synced to — and Phase 0 added a fourth, since iPadOS 17: an iPad with
Health syncing off. Every instinct in app design wants to tell the person
which one it was.

**Whose sheet asks for the read.** The app already asks for its own
beverage type on the Health context screen and from the Settings toggle.
Adding the pairing's read types to that request would be one line, and
HealthKit would show a sheet listing only the new types — the plan's own
suggestion. It would also ask a person who never turned a pairing switch
on about their heart rate, from a screen that has nothing to show for it.

**What the cost is.** Phase 0 could not measure a year-range query without
a probe, and the owner chose to have the shipping code measure it instead,
on a line in Settings' Diagnostics. That line is a write into the App
Group by the same layer whose rule is that nothing it reads is written
anywhere, so what the line may carry is part of this decision.

## Decision

1. **Read, compute, render, discard.** `HealthKitService.restingHeartRate`
   returns an array of `HealthSample` values that exist for one call; the
   caller hands them to the domain and drops them. The service holds no
   property for them, `@Observable` or otherwise. Nothing in the store can
   hold one: the schema is unchanged at V2 and has no field for a health
   value, so persisting one would be a schema version, which is the kind of
   change that cannot happen by accident. The App Group receives one line
   per read (decision 5) and no value.

2. **No data is one state.** A denied read, a granted read of an empty
   store, a watch that cannot measure the type, a night it was not worn, a
   device the data never reached, and a store that threw all return the same
   empty array, with no error and no flag beside it. There is no API in the
   app that tells them apart, and none will be added that pretends to. What
   follows for every surface: show nothing, say nothing, prompt never — the
   Settings switch is where a person who wants to know goes looking, and the
   one-time offer asks once. `requestPairingAuthorization` returns nothing,
   because there is nothing true to return.

3. **The pairing asks for its own reads.** `requestPairingAuthorization`
   asks for `pairingReadTypes` and nothing else, and only the pairing's
   switch and offer call it (Phase 3). The app's beverage request is
   untouched. `pairingReadTypes` holds only what the shipped build shows —
   resting heart rate — and each later phase appends its own, so a person
   who accepted the offer sees each new metric's sheet listing that type
   alone (the design's decision 1). The beverage type's share status is not
   consulted by a pairing read: sharing alcohol samples and reading heart
   rate are separate answers.

4. **Retrospective only, as a shape.** `HealthPairing.readWindow` runs from
   the start of the range's first day to the start of the day holding
   `now`, never including it, and the query reads that window. No read the
   pairing makes can return a figure from the day it is made on, so nothing
   built on the read layer can become a live readout — the plan's stop
   condition on a current-moment signal, enforced before any UI exists.
   Nothing is lost: a night counts only once the day after it has ended
   (ADR-0048), so the newest day any night needs is yesterday's.

5. **The cost is measured by the code that ships, on one line that cannot
   carry a value.** Every read records `Diagnostics.lastHealthPairingRead`:
   the metric's name, the window's day count and the wall time of the query
   (`resting heart rate · 364 days · 0.41 s · app · 09-22 08:15:03`). Those
   are the three arguments of `Breadcrumb.healthRead` and the only things
   the line can hold — no sample, no value, no count of days that had one,
   each of which is a fact derived from Health. A tier-1 test pins that the
   line's digits are exactly the day count and the duration. The day count
   is the request's, walked as calendar days so a window that starts on a
   midnight-transition day is not one short. Settings' row for it is
   Phase 3's, with the rest of that screen's changes; the first measurement
   is read from the owner's phone when Phase 3's surface makes the first
   read.

6. **The daily statistics query is the read for a per-day quantity.**
   HealthKit's own discrete average — temporally weighted for resting heart
   rate — anchored on the window's first day in one-day steps, one
   `HealthSample` per day that has one, spanning the day, so the domain
   files it by its middle under the night before it. A day with no sample
   is absent, never zero. One private query serves every per-day quantity;
   a new metric is a public method naming its type, unit and label.

7. **The span a figure covers comes from the data, not from an
   authorization API.** iOS 27 lets a person grant a window of recent
   history, and `earliestAuthorizedSampleDate(for:)` would report it —
   Phase 0's finding. It is not read here: CI compiles with the iOS 26.5
   SDK, and it is not needed for honesty, because `PairedFigures` already
   carries the first and last nights that contributed, which is the span
   the surface names. A shorter grant simply produces fewer nights.

## Consequences

- **The pairing renders only where Health has the data.** The drink log
  syncs through CloudKit; Health data comes with it only where Health's own
  sync is on. An iPad on the same Apple Account with Health syncing shows
  the table (iPadOS 17 and later has its own store); a second phone never
  paired to the watch, or an iPad with syncing off, shows nothing, and that
  looks like absence, not an error. The design's strings that say "on this
  iPhone" are wrong on an iPad, and Phase 3 rewords them.
- **Every render at Year is a real query.** There is no cache to make the
  second render cheaper than the first. The breadcrumb is where the cost
  is read, and if it argues for one, the reopen below says what kind.
- **A person who denied the read is never told.** They turned a switch on
  and nothing appeared. That is the rule, and the Settings footnote is the
  one place the app says what the switches need; nothing else may.
- **One write per read into the App Group** — a name, a day count and a
  duration, stamped with the process and the time as every breadcrumb is.
  A duration can hint at how much data a read walked; it is a fact about
  the store's work, not about the person, and it is the one thing the
  owner asked to know.
- **The permission sheet shows the app's existing purpose string**, which
  is about alcohol samples, above a request for heart rate. Phase 7 rewrites
  `NSHealthShareUsageDescription`; Phase 3's device pass will see the
  mismatch first and should say so rather than fix it early.
- **Revoking the read in Health makes the row vanish with nothing left
  behind** but the switch's own boolean and the last breadcrumb — which is
  what makes "nothing stored" a claim the privacy policy can make checkable
  in Phase 7.
- **No test tier reaches the query.** `HealthKitService` is app-target code
  with no `TEST_HOST`; CI proves it compiles. The window and the breadcrumb
  are pinned at tier 1; the query's behaviour is Phase 3's tier 3 on a
  simulator with seeded Health data and tier 4 on the owner's phone.

## How to reopen

- **If the breadcrumb shows a year-range read costing enough to feel** on
  a real phone, the reopen is a memo that lives and dies with the view that
  asked — keyed by the range and the day, discarded on every leave — and
  never a value in the App Group or the store. Anything that outlives a
  render is a cache in the sense this record refuses.
- **If the pairing ever needs to know that a sheet has been shown** (the
  design's decision 1 asks for a later metric's sheet on the next visit to
  Trends), `HKHealthStore.statusForAuthorizationRequest` answers whether a
  request is *unnecessary* without saying what was answered. That is the
  one authorization question HealthKit permits, and it stays honest; it is
  not built until a surface needs it.
- **If CI's toolchain reaches the iOS 27 SDK**, `earliestAuthorizedSampleDate`
  can clamp the window to what the person granted and name the span from
  the grant rather than the data. Until then, decision 7 stands.
- **If a metric needs something other than a daily average** — heart rate
  variability may want the samples from the sleep period only — that is a
  second query shape beside `dailyAverages`, not a change to it.
