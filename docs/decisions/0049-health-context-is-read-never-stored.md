# 0049 — Health context is read, never stored

**Status:** accepted · **Date:** 2026-09-21 · **Relates to:** ADR-0048 (a
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
   carry a value.** Every query records `Diagnostics.lastHealthPairingRead`:
   the metric's name, the window's day count and the wall time of the query
   (`resting heart rate · 364 days · 0.41 s · app · 09-21 20:15:03`). A call
   that never queries — no Health on the device, no day before today in the
   range — writes nothing, and neither condition is a fact about the
   person. The three arguments of `Breadcrumb.healthRead` are the only
   things the line can hold — no sample, no value, no count of days that
   had one, each of which is a fact derived from Health; a tier-1 test shows
   the line's digits are exactly the day count and the duration, and the
   guard on the name is that it has one call site, a literal. The day count
   is the request's, walked as calendar days so a window that starts on a
   midnight-transition day is not one short. Settings' row for it is
   Phase 3's, with the rest of that screen's changes; the first measurement
   is read from the owner's phone when Phase 3's surface makes the first
   read.

6. **The daily statistics query is the read for a per-day quantity.**
   HealthKit's own discrete average — temporally weighted for resting heart
   rate — anchored on the window's first day in one-day steps, one
   `HealthSample` per day that has one, carrying the statistic's own start
   and end, so the domain files it by its middle under the night before it.
   The middle is what makes that robust: which calendar HealthKit steps its
   intervals in is not documented, and a bucket that drifts an hour across
   a clock change still has its middle on the right day. A day with no
   sample is absent, never zero. One private query serves every *discrete*
   per-day quantity; a new metric is a public method naming its type, unit
   and label, and a cumulative type or an unconvertible unit there is an
   Objective-C exception, not an empty array — the four metrics the plan
   names are all discrete.

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
- **One write per query into the App Group** — a name, a day count and a
  duration, stamped with the process and the time as every breadcrumb is.
  A duration can hint at how much data a read walked, and so at whether
  data exists on a device whose table the gate is hiding; it is a fact
  about the store's work, not a value, it is visible only where Diagnostics
  are (debug and TestFlight builds), and it is the one thing the owner
  asked to know.
- **The pairing's calendar has to be the domain's.** `restingHeartRate`
  takes a calendar so that "today" — the day the window stops before — is
  the same day the domain's nights were built in. A caller that hands the
  two different calendars gets a window edge in the middle of a device day.
  Phase 3 passes one calendar to both.
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
  simulator with seeded Health data and tier 4 on the owner's phone. Two
  things that pass should look for: a sample seeded at 00:30 on the day
  after a clock change, which is where an interval stepped in the wrong
  calendar would show; and the App Group plist diffed before and after a
  read, where only `lastHealthPairingRead` may change.

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

## Amendment — 2026-09-22 (Phase 4: the sleep read, and two reopen paths taken)

Phase 4 adds the second read type and takes two of the reopen paths above,
as this record said they would be taken: by a surface that needed them.

**The second query shape exists.** Sleep is a category type with no
statistic to ask for, so `HealthKitService.sleep(in:endingBefore:calendar:)`
is a plain sample query over `readWindow` — every `HKCategorySample` of
`.sleepAnalysis` that *ends* inside the window (`.strictEndDate`), mapped
by name to `SleepStage` (a value this SDK does not name is dropped, never
guessed at) and handed to `HealthPairing.timeAsleep`, which merges the
asleep stages and files each stretch by its middle under the night whose
sleep day holds it (ADR-0048). The retrospective-only rule holds for a
category type the way decision 4 holds it for a quantity: a session still
running into today ends after the window and is not read, so no read can
return a stretch of the day it is made on; a session that began before the
window's first day is filed under a night the domain does not list and
drops on its own. `pairingReadTypes` is gone; `readTypes(for:)` maps the
metrics a caller names — resting heart rate, sleep analysis — to their
HealthKit types, so no request can name a type its caller did not. Everything
else in decisions 1 to 4 is unchanged: the samples are locals of one call,
empty is one state, the pairing asks for its own reads.

**The breadcrumb is per metric.** A render that shows two rows makes two
reads, and one line would have kept whichever finished last — the owner's
cost question wants both. `Diagnostics.recordHealthPairingRead` now keeps a
dictionary under `lastHealthPairingReads`, keyed by the metric's name, one
`Breadcrumb.healthRead` line each, and Settings' Diagnostics shows one row
per metric. What a line can hold is unchanged (decision 5: a name, a day
count, a duration — the keys are those same names), and the Phase 3 key is
removed on the next read so the plist carries one shape.

**The one authorization question is now asked.** The design's decision 1
says a metric that ships later arrives switched on for anyone with a pairing
switch on, and that its sheet appears on the next visit to Trends, beside the
table it feeds, not at launch. A read of a type never asked for returns
nothing, so something has to ask — and the reopen above named the honest
way: `statusForAuthorizationRequest`, which says whether a request is
*unnecessary* and never what was answered. `HealthKitService.pairingReadsNeedAsking(for:)`
wraps it, and `TrendsView` asks it once per visit, for the metrics whose
switches are on and only once the log clears the gate — so the sheet lands
the first time a row is possible, never over Week beside nothing, and never
names a figure the reader has switched off — calling
`requestPairingAuthorization(for:)` only on `.shouldRequest`. Every request
the pairing makes now names its metrics: a Settings switch asks for its own
type alone, the offer for every shipped one, Trends for the switched-on set.
A person who denied a type is `.unnecessary` and is not asked again; a
person who allowed it is the same `.unnecessary`; the app still cannot tell
them apart, and does not try. Once per visit rather than once per read, so
a sheet a reader sent away does not return on the next range change; an
answer HealthKit cannot give (`.unknown`, or a throw) asks nothing.

**Consequence for the cost measurement:** the Diagnostics line for sleep was
read later the same day, once the simulator was granted — `sleep · 86 days ·
0.01 s` at Quarter and `sleep · 356 days · 0.02 s` at Year, over 200 seeded
sessions on an M-series Mac, a floor as Phase 3's was;
`docs/health-pairing-phase-0-findings.md` §3 carries both, and the phone's
is still the owner's to read.

**What the render taught about the ask, kept here because this is where the
ask lives.** (a) HealthKit leaves an already-determined type off its sheet:
the request names every switched-on type, and a Phase 3 install's first
Quarter visit still showed a sheet listing Sleep alone — so the app does not
narrow the request, and need not. (b) iOS 27's sheet is two steps — the
types, then "How much data would you like to share" with *Past 30 Days and
Future Data* or *All Recorded Data and Future Data* — and Allow is on the
second only; the Settings app shows the same choice per type as None,
Limited Access ("30 days with data") and Full Access. A reader who takes the
30-day window hands every query 30 days whatever the range asks for, so a
card's source line can name a range its readings do not cover — Phase 0's
`earliestAuthorizedSampleDate` item, deferred above and now observed; the
gate keeps such a card off Quarter until the window grows to fourteen nights
a bucket. (c) A revoked read still writes its breadcrumb (`sleep · 86 days ·
0.00 s`): a cost and no value, decision 5 holding on the path that returns
nothing.

## Amendment — 2026-09-22 (Phase 5: the heart rate variability read, and the ask per metric)

**A third read type.** `readTypes(for:)` maps `.heartRateVariability` to
`HKQuantityType(.heartRateVariabilitySDNN)`, and
`heartRateVariability(in:endingBefore:calendar:)` reads it through the same
`dailyAverages` as resting heart rate — the header lists SDNN as `ms,
Discrete (Arithmetic)`, checked before it was added, as the Phase 4
amendment asked — in milliseconds, one value per calendar day, filed by
`.dayAfter`. ADR-0052 says why SDNN and not the RMSSD type iOS 27 added,
which CI's 26.5 SDK cannot name. Its breadcrumb is `heart rate variability ·
N days · T s`, a third line under `lastHealthPairingReads` and a third
Diagnostics row.

**The read and the ask are per metric now.** The model reads a metric only
where its row is possible — its switch on, the range one it is shown at
(heart rate variability: Quarter and Year, `PairedMetric.isShown(at:)`),
and the log alone clearing its own floor (`PairedMetric.minimumNights`,
twenty-eight for this one) — so no query runs, and no breadcrumb is written,
for a row that could not show. The sheet on Trends asks for exactly those
metrics, each once per visit (`askedPairingMetrics`, a set — one flag for
the visit would have been set by the first two rows at Quarter and kept the
third from being asked at Year, a review catch), so a Phase 4 install that
arrives with the new switch on meets its sheet the first time Quarter or
Year holds twenty-eight nights in each bucket, and never over Month, where
the row does not exist; a reader whose log clears fourteen but not
twenty-eight is asked for the two rows they can see and not the third —
except at the offer, whose acceptance asks for all three at once (ADR-0052,
ADR-0051's amendment).

**Cost.** The render's simulator number is in
`docs/health-pairing-phase-0-findings.md` §3 with the others, a floor as
they are; the phone's is the owner's to read.
