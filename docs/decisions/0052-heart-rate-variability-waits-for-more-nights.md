# 0052 — Heart rate variability waits for more nights, and for the wide ranges

**Status:** accepted · **Date:** 2026-09-22 · **Relates to:** ADR-0048 (the
nights, the buckets and the base gate this record doubles); ADR-0049 (the
read layer this row's query joins, and the per-metric ask); ADR-0050 (the
card this is the third row of); ADR-0051 (the offer, and how a later metric
arrives); `docs/tallyist-health-pairing-plan.md` ("Heart rate variability",
"The four rules"); `docs/design/health-pairing/README.md` (the figure
table, the states table's "HRV at Week or Month", surface 2's caption);
`docs/health-pairing-phase-0-findings.md` (§2 of the addendum, the second
type)

The fifth of the health pairing's records, written in Phase 5 with the row.

## Context

The plan names heart rate variability as the third metric and says two
things about it that the first two rows did not need: it is "noisy enough
night to night that a reader can easily construct a story from randomness",
so it "needs a larger sample-size floor than the others" and "the plainest
possible presentation", and the plan suggests "showing it only at the wider
ranges (`.quarter`, `.year`) where the averaging does the work". ADR-0048
set the base gate at fourteen nights with a value in each bucket and left a
sentence beside it — "a noisier type (heart rate variability) passes a
larger floor" — without a number. This record supplies the number, the
ranges, and three things the plan predates.

**Which type.** The plan names `heartRateVariabilitySDNN`. Phase 0 found a
second identifier in the iOS 27 SDK, `heartRateVariabilityRMSSD`, and Apple
Support's "Recovery HRV" on the Series 12 and Ultra 4, and asked Phase 5 to
settle which the Health app charts before picking. Two facts settle it as
far as a simulator can. The SDK header on this Mac lists both as
`ms, Discrete (Arithmetic)`, SDNN available since iOS 11 and RMSSD since
iOS 27.0 only. And the Health app on an iOS 27.0 simulator lists **both**
under Heart — "Heart Rate Variability" and, separately, "Recovery HRV" —
so the long-standing type is not renamed or replaced; it keeps the name the
row uses, and Recovery HRV is a second metric beside it. Every Apple Watch
since Series 1 writes SDNN; which watches write RMSSD, and whether a Series
12 still writes SDNN, are field questions no simulator answers. CI compiles
with the iOS 26.5 SDK, in which RMSSD does not exist.

**How big a floor.** ADR-0048's arithmetic: with *n* nights the mean is
settled to about SD/√*n* of the night-to-night spread — a little over a
quarter at 14 (0.27), under a fifth at 28 (0.19), and the step from 14 to
28 buys less than the step from 7 to 14 did. Heart rate variability's
spread relative to its mean is several times resting heart rate's, so the
same fourteen nights leave its two means closer to two nights' worth of
noise than the other rows' are. What bounds the floor from above is the
log: a reader who logs three drink nights a week and marks four has 39 and
52 nights in a quarter, so 28 is reachable at Quarter for a regular log,
while 56 would put the row most of a year away for everyone.

**Which ranges.** Two floors of 28 are 56 nights, and a month holds 30. The
plan's suggestion and the arithmetic agree.

**Which day.** A watch samples heart rate variability through the day and
the night both, and the Health app charts one figure per calendar day. The
row could file the night's own samples (the sleep-day rule, 18:00 to 18:00)
or the calendar day after's daily average (the rule resting heart rate
uses). The first is closer to what alcohol acts on; the second is the
figure the reader can find in the Health app for that date, which the plan
makes the cross-check for every row.

## Decision

The third row reads **SDNN** — `HKQuantityType(.heartRateVariabilitySDNN)`,
the Health app's "Heart Rate Variability" — through the same daily
statistics query as resting heart rate, in milliseconds, one value per
calendar day, filed under the night before it (`.dayAfter`), so the row's
per-night figure is the one the Health app shows on that date.

Its floor is **twenty-eight nights with a value in each bucket**,
`PairedFigures.minimumNightsForHeartRateVariability`, twice the base and
passed to `HealthPairing.figures(_:values:minimumNights:)` — the parameter
ADR-0048 left for it. Below it the whole row is hidden, never shown with a
caveat, exactly as the base gate hides the others.

The row exists at **Quarter and Year only**. At Week and Month it is not
drawn, not read and not asked for: `PairedMetric.isShown(at:)` keeps it out
of the read the task makes, so no query runs and no breadcrumb is written
for a row that could not show. The switch's caption says where it is shown
— "Shown at Quarter and Year", the design's own words.

The read, the ask and the gate are per metric now. The load skips any
metric whose own floor the log alone cannot clear, and the sheet on Trends
asks only for the switched-on metrics whose floor the log clears at this
range, each once per visit — so a Phase 4 install that arrives with this
switch on is asked for heart rate variability the first time it opens
Quarter or Year with twenty-eight nights in each bucket, and not before,
and never over Month; a reader asked for the first two rows at Quarter is
asked for the third at Year when Year clears its floor, not on the next
visit (the once-per-visit mark is per metric for that reason — a review
catch: one mark for the visit, set at Quarter, would have kept the third
sheet from ever showing). **The one exception is the offer:** accepting it
asks for every shipped type in one sheet, whatever the range and whether
or not this row's floor is met, because the offer the reader has just
accepted lists this row among the three it promises — one sheet at the
moment they asked, rather than a second one weeks later.

The figure is a whole number of milliseconds with "ms" beside it in the
unit face; the row's name is the Health app's; the sentences are the other
rows' with the unit swapped ("On nights you logged drinks, 42 milliseconds,
over 30 nights."). The switch is "Heart rate variability" over "Shown at
Quarter and Year", third in the Settings order, off by default, and it
arrives switched on for anyone with **either** earlier switch on — the two
before it, or-ed, decided once when its key is first missing and written
(ADR-0051's rule, extended as the Phase 4 amendment said it would be).

## Consequences

- **The row appears later than the others.** A reader whose log clears
  fourteen sees resting heart rate and sleep at Quarter while heart rate
  variability stays hidden until twenty-eight; the offer lists three rows
  and its acceptance turns on three switches, and the third row may lag
  the first two by weeks. The caption names the ranges, not the floor; the
  design's states table ("Switch on, gate not met: no row, no caveat") is
  what the reader meets, and nothing says why. Accepted: a sentence
  explaining the absence would be the caveat the rule refuses.
- **At Month the switch appears to do nothing.** The caption says so in
  advance, which is the whole of the mitigation. A reader who opens Trends
  on Month with only this switch on sees no section at all — nothing is
  read, nothing is drawn.
- **A day's average is not a night's reading.** Daytime samples are in the
  figure, so an active afternoon moves it as a late night does. The floor is
  twice the others' partly for this; the cost is a figure less specific to
  the night than the sleep-window alternative would be, in exchange for one
  the Health app can confirm.
- **The footnote is not extended.** The design's third sentence names
  sleep, heart rate variability and wrist temperature as coming "from nights
  you wear your watch to bed". For this row that is not true — the samples
  are the day's — so the sentence stays "Sleep comes from nights you wear
  your watch to bed", the one metric it is true of, as Phase 4 cut it.
- **Recovery HRV is not read.** A Series 12 reader may find a second HRV
  figure in the Health app that this row does not show. The row's name is
  the Health app's name for what it does show.
- **The design's suggested setting name, `showsHRVPairing`, is
  `showsHeartRateVariabilityPairing`** — the pattern of the two keys before
  it, spelled out.
- **Nothing new is written.** The switch and the inheritance are
  preferences beside the others; the read leaves its one breadcrumb per
  query (`heart rate variability · N days · T s`), a name, a day count and a
  duration; the figures are two means and two counts held for one render.
  Checked the way the earlier phases checked it, by grepping every added
  line for the write, store and log APIs.

## How to reopen

- **The floor.** One constant. A published night-to-night coefficient of
  variation for wrist SDNN in the general population, or an evening of the
  owner's own data showing the two means at 28 still moving from render to
  render, is the evidence that would move it; a reader who cannot reach 28
  at Quarter is not, since the row exists at Year too.
- **The ranges.** One switch statement. If a reader with a nightly log asks
  for the row at Month, the floor has to drop below fifteen for it to be
  possible, which reopens the floor first.
- **The type.** If the field shows that a Series 12 writes RMSSD instead of
  SDNN rather than beside it, the row loses its data on those watches and a
  second identifier has to be read — behind `#if compiler(>=6.4)` while CI's
  SDK cannot name it, or after the runner image moves. A second row for
  Recovery HRV is the other route, and the design's figure table already
  has the shape for it.
- **The day.** If the owner's cross-check against the Health app finds the
  day-after average too blunt — the drink nights and the marked nights
  reading the same at 28 while the night's own samples differ — the
  attribution is one argument (`.sleepDay`) and a sample query over the
  sleep window in place of the daily statistic.
