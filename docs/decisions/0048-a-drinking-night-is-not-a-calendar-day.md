# 0048 — A drinking night is not a calendar day

**Status:** accepted · **Date:** 2026-09-21 · **Relates to:** ADR-0006 (a
summary, not a score; unlogged days are named, never assumed alcohol-free);
ADR-0033 (a run of days with no alcohol is counted from the record, never
from silence); ADR-0025 (a Health zero becomes a marker); ADR-0017 (sessions
are runs of absolute instants); ADR-0026 (`dayKeys`, the DST-safe day walk);
ADR-0018 (the population reference's four-week gate); PRD invariants 8 and
9; `docs/tallyist-health-pairing-plan.md` ("A drinking night is not a
calendar day", the four rules); `docs/health-pairing-phase-0-findings.md`
(question 1, and the resting heart rate question it left to this record);
`docs/design/health-pairing/README.md` (decision 2: the heads stay DRINKS
and NO DRINKS, and the source note carries the second column's definition)

The first of the health pairing's records. The plan reserved 0046 to 0049 for
four; those numbers were taken by the watch, and the others take the next
free number when their phase writes them.

## Context

Every figure Tallyist has shown so far is keyed to a calendar day
(`Calendar.startOfDay`) or to nothing at all (`SessionPace`, which works on
absolute instants so midnight cannot split a sitting). The health pairing
asks a question neither convention answers: *the drinks on the evening of
the 14th, and the sleep that followed them* — sleep that mostly happens on
the 15th. So the feature needs a unit of its own, and four things had to be
settled before a line of it could be typed. Each was an argument, not an
obvious call.

**The window.** The plan offered noon to noon and 18:00 to 06:00 as "both
defensible". They are not equally so. A window must give every drink to
exactly one night, and it must pair each drink with the sleep that *follows*
it: 18:00 to 06:00 leaves a drink at 14:00 belonging to no night, and noon to
noon gives a drink at 10:00 to the night whose sleep is already over.

**Which sleep, and which day.** Phase 0 read the Health app's rule off the
app itself, since Apple publishes none: a sleep day runs 18:00 to 18:00, it
is named for the morning inside it, a session that crosses 18:00 is filed
whole under the day that holds its middle, and **naps are summed in** —
the day's Time Asleep is everything asleep filed under it. The plan had
wanted "the main sleep session whose start falls in that window, not every
nap", and its own third rule says to match the Health app or document the
divergence loudly, because a figure that disagrees with the Health app for
the same night makes the reader distrust both. Resting heart rate has the
mirror question: it is a figure per *calendar* day, revised through the day
and the next, and the design left "which day's figure pairs with which
night" to this phase.

**The second bucket.** "Nights with drinks" is plain. "Nights without" can
mean two things, and ADR-0033 has already named them: (a) every night whose
total is zero, which includes nights with nothing logged, or (b) nights the
person *recorded* as no alcohol — `AlcoholFreeDay` markers, the ADR-0025
population included. The design's draft source note said "every other
night", which is (a); the plan's labels ("nights you logged drinks", "nights
you didn't") describe the log rather than the body and could carry either;
and the design's decision 2 asks this record to say plainly whether a night
with nothing logged is counted.

**The gate.** The population reference hides below four weeks of record; the
plan wants more here, in both buckets, and hidden rather than caveated.

## Decision

**A night is named for its evening — the calendar day its evening falls on —
and owns three windows, all computed in the calendar handed in and
re-normalised through `startOfDay` at every step.** `DrinkingNight` in the
core package.

1. **The drink window is 06:00 to 06:00.** A drink logged from 06:00 on the
   evening's day to 05:59:59 the next belongs to the night. A drink at 3 a.m.
   is the night before it; a drink at 9 a.m. is the night that follows it.
   Six is the hour the Health app's own sleep chart ticks at, and it is the
   hour at which "the sleep that follows this drink" changes from last
   night's to tonight's. Consecutive windows tile time exactly, including
   the 23- and 25-hour nights around a clock change.

2. **The sleep is Health's sleep day, matched rather than reinvented.** The
   night's sleep day is 18:00 on the evening's day to 18:00 the next — the
   day Health names for the morning of the night. A stretch of sleep is
   filed, whole, under the sleep day that holds its middle; a night's time
   asleep is the sum of every stretch filed under it, **an afternoon nap
   alongside the night before it**; the asleep stages are merged where they
   overlap or touch, so two sources recording the same hour count it once;
   in bed and awake are not sleep. This is the divergence the plan's rule
   demanded be documented if taken, and it is taken the other way: the
   domain follows the Health app, so the two figures for one night can
   agree. The five sessions typed into Health in Phase 0 are a tier-1
   vector, and the package sums them to the hour the app showed.

3. **A per-day figure pairs with the day after.** Resting heart rate for the
   night of the 14th is the 15th's figure: the day the night wakes into,
   whose estimate the night's sleeping heart rate is inside. This is the
   same key as the sleep day (Health's "15th" is this type's night of the
   14th), so one rule covers every metric: **a night's health value is the
   day after, in that type's own sense of a day.** `NightAttribution` names
   the two senses, `.sleepDay` and `.dayAfter`.

4. **A night is counted once the day after it has ended.** A per-day figure
   is provisional in two degrees: while its day runs, the estimate is a
   rough one the watch improves through the day; and through the day after
   that, the watch may still replace it ("the current or previous day",
   Apple's words). The rule waits out the first and accepts the second: on
   any render the newest night is the evening two days ago, decided by the
   injected `now`, and its figure can still move once during the day it
   first appears. Nothing is cached, so a render simply follows the replaced
   sample; waiting a further day would hold back three nights to avoid a
   refinement rather than a draft. One rule for every metric, so the buckets
   an offer counts from the log alone are the buckets the table will use.

5. **The second bucket holds nights recorded as no alcohol, and nothing
   else.** A night is in "no drinks" when the calendar day it is named for
   carries a marker and nothing was logged in its window. A night with
   nothing recorded is in *neither* column. The app has never read silence
   as abstinence: ADR-0006 names unlogged days precisely so a reader will
   not assume the remainder was alcohol-free; the owner's own ruling on the
   Trends readout was that a marked day prints a 0 and an unlogged day does
   not, because "0 is the same as alcohol free where the user made the
   decision not to have alcohol… vs. the user not interacting with the app
   and it's unknown to us"; and ADR-0033 chose (b) for the longest run for a
   reason that applies here with more force. Under (a), omitting a drinking
   night would move that night's value into the "no drinks" column — the
   two figures converge, and the reader who would rather not see a
   difference is paid for not logging, which is ADR-0006's failure mode
   exactly. Under (b) an omission removes the night from the comparison and
   touches the other column not at all; the only way into "no drinks" is a
   record. So the head the owner chose, NO DRINKS, is true of every night
   under it, and the source note can say what the column holds in one
   sentence: *nights you recorded as no alcohol; a night with nothing logged
   is in neither column.*

6. **The gate is fourteen nights with a value in each bucket.** Not fourteen
   nights in the bucket: fourteen that Health has a value for, so a night
   the watch was not worn does not count toward showing the row. The floor
   is a statement about noise that holds whatever the metric's spread is:
   the mean of n nights is settled to about SD/√n of the night-to-night
   spread, which at 14 is a little over a quarter of it, where 7 is over a
   third; the step from 14 to 28 buys less than the step from 7 to 14 did.
   Two weeks is also a unit a reader understands. Below the floor on either
   side the domain returns nothing, and the surface shows nothing — no
   asterisk, no caveat. A noisier type asks for a larger floor through the
   same parameter (heart rate variability, Phase 5).

7. **The value type is two figures, two counts, and the span they cover.**
   `PairedFigures`: the mean and the night count for each column, and the
   evenings of the first and last nights that contributed. Each mean is over
   the bucket's distinct nights that have a value; a night with none is
   absent, not zero, and two values for one night collapse to their mean
   before the night joins the average. There is no difference, no ratio, no
   sign, and no property that relates one column to the other. A tier-1 test
   pins the *stored* properties to exactly those four, which catches a field
   added to the type; a computed property, or an extension in the app
   target, it cannot see, so for those the guard is review — the same guard
   every other rule in this record has.

Nothing in the package reads a health value to decide which bucket a night
is in; the buckets come from the log and its markers alone. Nothing imports
HealthKit; the read layer hands in plain `HealthSample` and `SleepSample`
values that live for one render.

## Consequences

- **The row will appear for fewer people, and later, than the design's
  invented numbers suggest.** "31 nights without" over thirteen weeks was
  drawn as every other night; here it is the nights the person marked. A
  reader who never records a no-alcohol day never sees the row, and the app
  does not tell them why — the same absence the longest run shows them as
  "None recorded". The Settings switch and the offer stand; a marker a day is
  what fills the second column. At Week the row can never appear (seven
  nights, gate of fourteen), and at Month only in theory: thirty nights less
  the two held back leave twenty-eight against a gate of twenty-eight, so
  every night would need a record, a value, and an exact fourteen-and-
  fourteen split. Quarter and Year are where it lives.
- **The offer's condition changes.** The design gates the one-time offer on
  the drink side alone, expecting the other side to be plentiful. It is not,
  so the offer has to clear the gate on both sides from the log
  (`NightBuckets.clearsGate`), or a person could accept, grant access, and
  be shown nothing. Its caption counts marked nights, not "without". Phase
  3's copy review carries the wording.
- **Time asleep includes naps, and a phone-only sleep schedule contributes
  nothing.** Both are what the Health app does; the second because in-bed
  samples are not sleep, and a night of them alone has no time asleep.
  Overlapping sources are merged rather than ranked — Health ranks its
  sources, and a night where two disagree can differ from the app's figure.
  A tier 4 item, not a code path.
- **The stretch is the unit filed, and that is a third rule, matching
  neither of the two Phase 0 could not tell apart.** Health was seen filing
  single typed samples by their middle; a watch night is many stage samples,
  and whether Health files each, or the period it assembles from them, was
  not observable. This record files each *merged stretch*: touching stages
  join, an awakening splits. Two consequences, both only for sleep that
  crosses 18:00, which a night does not and a long nap can: a stage that
  touches another across the boundary follows the merged stretch's middle
  rather than its own, and a session that wakes across the boundary lands on
  two nights, where the assembled period would land on one. Pinned by a
  vector so the behaviour is on record; the plan's tier 4 cross-check on a
  real device is what settles which rule Health uses, and the reopen below
  names the change.
- **Two nights are held back on every render**, and the sleep figure lags
  its own completion by six hours (its day ends at 18:00, the rule waits for
  midnight). Nobody will see it; one rule was worth more than six hours. The
  newest night's per-day figure can still be replaced once by the watch
  during the day it first appears (decision 4); the render follows it.
- **A 1 a.m. drink costs two nights.** It makes the night before it a drinks
  night (right) and leaves the night of its own day unrecorded, because the
  app will not mark a day that holds a drink (also right: that calendar day
  did). The person can still mark the next day.
- **Values are the mean of the samples filed under a night.** Resting heart
  rate is temporally weighted in HealthKit; a plain mean differs only when a
  day holds more than one sample, which the watch's replacement rule makes
  rare and a time-zone crossing makes possible. Recorded, not corrected.
- **The zone is the device's, at render time.** A night logged in London
  and read in New York is keyed in New York, as every calendar day in the
  app is. Health may map a session by the zone stored on the sample; the
  domain's rule is pinned by vectors and Health's is a tier 4 check after
  travel.
- **The plan's ADR numbers move.** This is 0048; the other three take the
  next free number when written, and the plan's list says so now.

## How to reopen

- **If the second column stays empty in the field** — the row never
  appearing because people do not mark nights — the alternative is (a),
  "every other night in the record", one predicate in
  `HealthPairing.buckets` and a rewording of the head, the note and the
  offer's caption. The reason it was not chosen is the incentive above, and
  a reopen has to answer it, not restate the sparsity.
- **If a real watch night that crosses 18:00 is filed differently from a
  typed session** — Health filing the assembled period rather than each
  merged stretch, or each sample on its own — the change is in
  `asleepStretches` and the middle it files by; the Phase 0 vectors stay,
  the boundary vector changes to the observed shape, and a vector for the
  watch's own sample pattern joins them.
- **If the newest night's figure is seen to move on the day it appears** and
  a reader notices, the rule in `HealthPairing.nights` waits one more day
  (`dayAfter.end` plus a day); three nights held back instead of two.
- **If the Health app's own figure for a night disagrees with the package's
  on a real device** (the plan's tier 4 cross-check), the sleep day rule or
  the merge is wrong, and the fix is to match Health again, not to explain
  the difference in copy.
- **If fourteen proves too high or too low** for a particular metric, the
  floor is a parameter; the default is one constant with the arithmetic
  above beside it.
- **If the day-after pairing for a daily figure looks wrong against real
  data** — a resting heart rate sample turning out to be stamped in a way
  that puts a day's figure on the wrong side of midnight — `NightAttribution`
  gains a case and the read layer picks it; the night and its windows do not
  change.

## Amendment — 2026-09-22 (the owner's device pass: the floor follows the range)

The owner, testing the four rows on their phone: *"Under Trends, Apple
watch data prompt to grant access only shows up when you select quarter or
year. They don't appear on month or week trends. We ask them to share past
30 days and future data so we should show it on all options, provided we
have the data."* The sixth decision above set one floor — fourteen nights
with a value in each bucket — and its consequence was that the row could
never appear at Week (five countable nights against fourteen) and at Month
only in theory (twenty-eight against twenty-eight). The offer, gated on the
same floor from the log, is where a reader meets the feature, so it too
lived at Quarter and Year, and Trends opens on Week. The reopen entry for
the floor says it is a parameter; this engages it.

**Decision.** The floor is per range. `PairedFigures.minimumNights(at:)`
is fourteen at Quarter and Year, seven at Month and two at Week; the base
constant stands, and the two wide ranges still read it. Every gate reads
the range's floor: the offer's (`HealthPairingSection.resolve`), the
read's (`HealthPairingModel.load`, which still skips a metric the log
alone cannot clear), the table's (`figures(_:values:minimumNights:)`) and
the ask's (the sheet on Trends), through `PairedMetric.minimumNights(at:)`.
Heart rate variability is untouched: ADR-0052's twenty-eight, at Quarter
and Year only, its caption still true. Rule 3 holds at every range as it
did — a gate in both buckets, the whole surface hidden below it, no
caveat — at two nights on both sides at Week and seven on both at Month.

**Why two and seven.** A Week range holds five countable nights: seven,
less the two `nights(from:through:completeBy:)` holds back while Health may
still revise them. Any floor above two makes the row impossible there and
the ruling unmet, and two is the least a mean is a mean of. Month holds
twenty-eight, and seven is the number the sixth decision weighed fourteen
against: SD/√7 is a little over a third of the night-to-night spread,
where SD/√14 is a quarter. The noise argument that set fourteen does not
go away at the shorter ranges; it is accepted there, on the owner's ruling,
and stated here rather than on the card: a figure at Week is a mean of two
to five nights and moves by a night's reading, and the two columns can
differ by noise alone, in either direction. The night counts printed under
each row's name — "2 and 3 nights" — are the reader's measure of that,
which is what the design prints them for.

**What a reader sees.** The offer can appear at Week or Month once the
current range's log holds the floor on both sides, so the opening range can
now show it; the rows follow, resting heart rate, sleep and wrist
temperature over two or more nights a column at Week and seven at Month.
"Provided we have the data" is the gate: a week with one marked night
shows nothing, as before. The authorization window the owner named — iOS
27's "Past 30 Days and Future Data" — does not enter the gate, and does not
need to: a reader who took it has readings for the last thirty nights,
which is Week's and Month's whole span, and Quarter and Year still count
only the nights that have a value.

**Cost.** Two-night means at Week, and figures there that can change from
one visit to the next as a night rolls into or out of the window. The
tier-1 vector pins the four floors and a Week fixture — two drink nights
and two marked nights among the five countable nights clear it, one marked
night does not, and the base floor never would — and the means it returns
are over exactly those nights.

**How to reopen.** The floors are one function with the arithmetic beside
it, and the design README's own line is "the gate is per row and per
range". If Week's two-night means prove to read as findings in use, the
honest alternative is not three — six of five nights, the row gone again —
but the sixth decision's own hiding: Week back to the base floor, one line
in the function, and the offer with it.

**Verified on the owner's iPhone (iOS 27) the same night** — "Verified on my phone
it's fixed": the rows and the offer at Week and Month on the owner's own log, with
the pickers and the ink of the same pass (ADR-0050's amendment of this date).
