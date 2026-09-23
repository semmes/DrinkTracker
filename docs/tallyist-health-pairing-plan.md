# Tallyist health pairing — feature plan

Companion to `docs/tallyist-1.2-spec.md` and `docs/tallyist-watch-plan.md`.
**Sequenced after the watch**, and deliberately not part of it: the watch
collects this data, but the feature is entirely on the phone.

Same working method as every other spec here: read "The risk" and "The four
rules" first, in every session, then take one phase at a time.

Written 2026-09-13.

---

## What this is, in one paragraph

The user's watch already records how they slept, what their resting heart rate
was, how variable it was, and how warm their wrist got overnight. Tallyist
already records what they drank. This feature lets the user put one beside the
other, on a surface they choose to open, for a metric they choose to enable,
after the log is long enough for the comparison to mean anything. It reads
Health and writes nothing. It concludes nothing.

---

## Decisions

You made the first four.

1. **Four metrics in scope:** sleep duration and stages, resting heart rate,
   heart rate variability, sleeping wrist temperature. Build order is by
   difficulty, not by that list order: resting heart rate first, because it is
   one clean daily number on every model, then sleep, then HRV, then wrist
   temperature, which needs a baseline decision nothing else does.
2. **The user picks what to look at.** Trends gains a control that puts a
   chosen Health metric beside the drink log. The app does not choose the
   question and does not open with an answer.
3. **The ask happens in context**, once the log is long enough to render
   something, showing what it would look like, once. Not in onboarding. Not
   as a form.
4. **Its own train, after the watch.** This has its own review surface and its
   own privacy-policy change, and mixing it into a platform launch would make
   both harder to explain.

And three this plan makes, each argued where it lands:

5. **Nothing read from Health is ever stored.** Not in SwiftData, not in
   UserDefaults, not in CloudKit. Read, compute, render, discard.
6. **No dual-axis chart.** Two series on one set of axes is the most
   causation-implying picture available, and this feature's whole discipline
   is refusing to imply causation.
7. **One toggle per metric**, defaulting off, matching the three separate
   comparison flags ADR-0038 already established rather than one umbrella
   switch.

---

## What the watch can and cannot supply

Two of the four things in the original brief turned out not to exist. Recorded
here so the question does not get reopened from memory.

**Blood pressure: the watch does not measure it.** Hypertension notifications
(Series 9 and later, Ultra 2 and later, not SE) analyse optical heart sensor
data over 30-day periods to flag a *pattern*, and report no systolic or
diastolic value at all. Apple states the feature "is not intended to diagnose,
treat, or aid in the management of hypertension," and on a notification the
user is directed to a third-party cuff. A blood pressure value reaches
HealthKit only if the user logs it by hand from such a cuff, which makes it
sparse, self-selected, and not a watch signal. There is no overlay to build.

**Blood oxygen: available in the US only through the redesigned workaround.**
The original feature remains under an exclusion order; the redesigned one takes
the reading on the watch and displays it only on the paired iPhone, and a
further USITC investigation opened in November 2025. Beyond the legal
situation, the readings are user-initiated spot samples rather than a
continuous nightly signal, which makes them a poor input for a night-by-night
comparison even where they work. Out of scope, and not a close call.

**What the watch actually contributes** to this feature is that it is on the
wrist overnight. That is a behavioural ask, and it should appear in the copy
once rather than as a recurring prompt: a user who does not sleep in their
watch will see nothing from three of these four metrics, and the app must not
nag them about it.

---

## The risk

Stated first because it governs every design decision below, and because
nothing else in this repo's roadmap carries it.

Every previous feature in Tallyist reports a quantity of alcohol. The
population reference (ADR-0018) compares drinks to drinks; the weekday card
(ADR-0032) compares drinks to drinks; the session card (ADR-0017) counts
drinks in a window. One axis, and a flat one: the app never had to decide
whether more was worse, because it never showed anything that carried a
direction.

This feature introduces a second axis that carries a direction the reader
already believes in. "6h 12m on nights with drinks, 7h 04m on nights without"
is a verdict, and no sentence in the app has to deliver it. **Copy discipline
does not save you here.** You could pass every 1.4.3 tone review and still have
built a coach, because the number does the judging.

Constraint 3 says the app measures and does not warn. The honest reading is
that this feature sits right on that line, and that the line is held by
structure rather than by wording.

The counter-argument, which is also honest and is why this is worth building:
Tallyist positions itself as a judgment-free *mindfulness* tool, and
mindfulness means noticing. The most useful thing a person can notice about
their drinking is what it does to them. Withholding data the user's own device
already collected, in the name of neutrality, is its own kind of paternalism,
and a tracker that will only ever tell you how much you drank is a less
truthful product than one that will also show you the night after.

So: build it, and let the structure hold the line.

---

## The four rules

These are to this feature what the three hard rules of ADR-0017 are to the
session card. They are not style preferences.

**1. Both sides, never a delta headline.** Two figures, side by side, in the
idiom the weekday and weekend cards already use. Nights with drinks, nights
without. The reader computes the difference; the app does not put it in bold,
does not colour it, does not prefix it with a sign, and does not say "worse".
A difference the reader works out is an observation. A difference the app
hands them is a verdict.

**2. Correlation shown, causation never claimed.** "On nights you logged
drinks", never "because you drank" and never "the effect of". No arrows, no
trend lines between the two, no dual-axis chart. The two numbers sit beside
each other and that is the whole claim.

**3. A sample-size gate, in both buckets.** The population reference hides
below four weeks. This needs more: enough nights with drinks *and* enough
nights without, or the comparison is noise dressed as a finding. Pick the
floor in Phase 1, defend it in the ADR, and hide the whole surface below it
rather than showing a caveat. A number with an asterisk still gets read as a
number.

**4. Never the reverse direction.** The app must never use physiology to
infer, predict, or question drinking. No "your resting heart rate suggests",
no prompting to log on a night the data looks unusual, no flagging a
discrepancy between the log and the body. That is diagnosis, it is the single
clearest stop condition in this document, and the fact that it would be
technically easy is exactly why it is written down.

---

## Stop conditions

Beyond the standing list in `docs/tallyist-1.2-spec.md`. If implementation
starts heading toward any of these, stop.

- **Walking steadiness, gait, or any impairment proxy.** Inferring
  intoxication is a medical claim and there is no version of it this product
  can make.
- **AFib history or irregular rhythm notifications.** Alcohol is a genuine
  trigger and that is precisely why surfacing it here would be medical advice.
- **Live heart rate during an active session.** That is impairment
  monitoring on a wrist, in a bar. Retrospective only, next day at the
  earliest.
- **State of Mind / mood logging.** Mental health data is a different risk
  class with different HealthKit rules and a different review posture. Not a
  smaller version of this feature.
- **Location, of any kind.** No new permission, no new category, no
  surveillance shape.
- **Any notification.** ADR-0017's third hard rule, unchanged and extended: no
  notification about drinking, and now no notification about the body either.
- **Storing health values anywhere.** See the architecture section; this one
  is easy to do by accident.

---

## The metrics

One section each. All four are read-only HealthKit reads on the phone.

### Resting heart rate — build this first

`HKQuantityType(.restingHeartRate)`. One value per day, computed by the watch,
available on every model. No aggregation to invent, no night-boundary problem,
no baseline to define. It is the cheapest of the four to build and the hardest
to misread, which makes it the right vehicle for building the entire surface
end to end in Phase 3.

### Sleep duration and stages

`HKCategoryType(.sleepAnalysis)`, with stage values (`asleepREM`, `asleepCore`,
`asleepDeep`, `awake`) on watchOS 9 and later. The most recognisable of the
four, and the most fiddly: a night is not a calendar day, and a sleep session
has to be assembled from multiple category samples rather than read as one
number. See "A drinking night is not a calendar day" below.

Show duration first. Stages are a second increment and carry more
interpretive weight per minute than duration does, so they deserve their own
look at the copy.

### Heart rate variability

`HKQuantityType(.heartRateVariabilitySDNN)`. Genuinely responsive to alcohol,
and noisy enough night to night that a reader can easily construct a story
from randomness. Two consequences: it needs a larger sample-size floor than
the others, and it needs the plainest possible presentation. Consider showing
it only at the wider ranges (`.quarter`, `.year`) where the averaging does the
work.

### Sleeping wrist temperature

`HKQuantityType(.appleSleepingWristTemperature)`, Series 8 and later. One clean
nightly value and a real alcohol response, with two complications nothing else
here has:

1. **The model restriction is invisible to the user.** Someone on a Series 7
   sees nothing and cannot tell whether that is their watch, their permissions,
   or a bug. Handle it the same way as a denied read: show nothing, explain
   nothing, never prompt.
2. **The raw value is not the interesting quantity.** The Health app presents
   wrist temperature as a deviation from the user's own baseline, because an
   absolute figure means nothing to a reader. Tallyist would have to compute
   its own baseline, which is a new derived statistic and therefore something
   to define and defend rather than assume. Phase 6 decides it: the user's own
   median over the displayed range is the obvious candidate, stated as such in
   the UI, so the number is labelled as what it is.

---

## Architecture

### Read, compute, render, discard

**Nothing read from Health is persisted.** Not into SwiftData, not into
UserDefaults, not into the App Group. Each render queries HealthKit for the
displayed range, computes in memory, and throws the values away.

This is not fastidiousness, it is the decision that keeps the feature small:

- The SwiftData store mirrors to CloudKit. A health value written there is
  health data in the user's iCloud database, which is a schema version, a
  CloudKit console deployment, a migration fixture, a privacy-label question
  and a privacy-policy rewrite, all at once.
- It would also be redundant. HealthKit is already the durable store for this
  data, already syncs across the user's devices, and is already where the user
  goes to delete it.
- And it keeps one of the app's better claims intact: revoking Health access
  in Settings makes the feature disappear completely, with nothing left behind
  in Tallyist to explain or purge.

`HKStatisticsCollectionQuery` over the displayed range is the right shape for
the three quantity types. Sleep needs its own assembly, below.

**Two consequences to design around, both stated in the ADR:**

- The pairing renders only on a device where HealthKit has the data. The drink
  log syncs through CloudKit; Health data does not come with it. On an iPad, or
  on a second phone that has never been paired to the watch, the feature may
  show nothing. That is correct behaviour and should look like absence, not
  like an error.
- There is no cache, so a wide range means a real query. Measure it at
  `.year` before assuming it is free.

### HealthKit will not tell you a read was denied

`HealthKitService` already knows this and says so twice in its own comments:
`authorizationStatus(for:)` reports *share* permission only, and read access
"remains invisible by design". That is a deliberate HealthKit property, so
users cannot be probed for what data they have.

For this feature it means **the app genuinely cannot distinguish** between:

- the user denied the read,
- the user granted it and has no such data,
- the user's watch does not support the metric,
- the user does not wear the watch to bed.

All four are one state: no data. So there is exactly one correct behaviour, and
it is the same in all four cases: **show nothing, say nothing, prompt never.**
No "grant access to see this", no empty state explaining what they are missing,
no badge. The toggle exists in Settings for anyone who wants to go looking; the
in-context offer happens once. After that the app is silent about it forever.

Write this into the ADR as a rule rather than leaving it as a UI detail,
because every instinct in app design pushes the other way.

### A drinking night is not a calendar day

The core piece of new domain math, and the reason Phase 1 exists before any UI.

The app's day boundaries are calendar days (`calendar.startOfDay`), and
`SessionPace` deliberately works on absolute timestamps so midnight cannot
split a sitting. Neither convention answers the question this feature asks,
which is: *the drinks on the evening of the 14th, and the sleep that followed
them.* That sleep mostly happens on the 15th.

So Phase 1 defines a `DrinkingNight`: a window of drinks, and the sleep period
that follows it, keyed so the two can be paired and bucketed. Three things to
settle and pin with vectors:

1. **The window.** Drinks logged between some hour on day N and some hour on
   day N+1 belong to the night of N. A noon-to-noon or 18:00-to-06:00
   convention are both defensible; state one.
2. **Which sleep period.** The main sleep session whose start falls in that
   window, not every nap in it.
3. **Match the Health app's own attribution.** Apple attributes a sleep
   session to a particular day, and a user who compares Tallyist's figure to
   the Health app's and gets a different number will stop trusting both.
   Check what Health actually does and follow it, or document the divergence
   loudly. This is a research task before it is a coding task.

Everything here is a pure function over `[LoggedDrink]` and a list of health
samples, with `now` injected, living in `DrinkTrackerCore` and tested at tier
1 alongside the session vectors. Time zone changes, DST, a drink at 3am, a
night with no sleep recorded, two sleep sessions, and a nap all get cases.

### Where the surface lives

Trends, as a section below the existing comparison cards, with a picker for
which metric to pair. Not the chart. The existing chart has bars and an average
line and is about one quantity; overlaying a second series on a second axis
would be both visually heavy and, per rule 2, exactly the wrong picture.

The section shows, for the currently selected `TrendRange`, two figures side by
side with the night counts that produced them:

```
Resting heart rate

Nights you logged drinks     62 bpm     18 nights
Nights you didn't            58 bpm     31 nights
```

The night counts are not decoration. They are what lets the reader judge how
much the two figures are worth, which is the honest alternative to the app
judging it for them.

---

## The ask

Three properties, and the order matters.

**It waits.** The offer does not exist until the log clears the sample-size
gate for at least one enabled-able metric. Before that there is nothing to
show and therefore nothing to ask for.

**It shows before it asks.** The offer renders the card shape with the user's
*drink* figures already in it and the health column empty, so what they are
agreeing to is visible rather than described. A permission prompt for "heart
rate" in the abstract is a different decision from one where the shape of the
answer is on screen.

**It asks once.** Declined means gone. The Settings toggles remain for anyone
who changes their mind, and nothing in the app ever mentions it again. Given
that a denied read is invisible anyway, a second ask would be indistinguishable
from nagging someone who already said yes.

HealthKit only prompts for types whose authorization is undetermined, so adding
these four read types to `HealthKitService.requestAuthorization()` naturally
produces one sheet covering only what has not been asked before. Existing users
who already granted alcohol access see a sheet listing the four new types and
nothing else.

---

## Copy

House voice, plus two rules specific to this feature.

- **No comparative adjective, ever.** Not worse, not better, not lower, not
  higher, not improved. The figures are adjacent; the language is flat.
  "Nights you logged drinks" and "Nights you didn't" are the two labels, and
  they carry no direction.
- **Name the source and the span in the UI**, the way the population reference
  names its survey. "From Apple Health, last 90 days, 18 nights and 31
  nights." A number whose provenance is visible is a fact; one that appears
  unattributed is an assertion.

Everything new goes through the 1.4.3 tone review in
`docs/copy-review-1.4.3.md`, and this batch deserves a second pass rather than
one, because the failure mode is a sentence that reads neutral in isolation and
judgmental beside a number.

---

## Phases

One session each, `docs/tallyist-1.2-spec.md`'s constraints plus "The risk",
"The four rules" and "Stop conditions" pasted every time.

**Phase 0, research, no code.** What convention does the Health app use to
attribute a sleep session to a day? What does `appleSleepingWristTemperature`
actually return and against what baseline does Health present it? How long does
a year-range `HKStatisticsCollectionQuery` take on a real device? The answers
change Phase 1's signatures, so they come first.

**Phase 1, the domain.** `DrinkingNight`, the pairing, the bucketing, the
sample-size gate, the comparison value type. Pure, in `DrinkTrackerCore`, tier
1, with the edge cases above as vectors. No HealthKit import anywhere in this
phase, which is what keeps invariant 9 true and what makes the whole feature
testable without a device.

*Landed 2026-09-21, ADR-0048.* Three things it settled against this plan's
own text, each argued there: the sleep that pairs with a night is Health's
sleep day — 18:00 to 18:00, a session filed whole by its middle, naps summed
in — rather than "the main sleep session … not every nap", because Phase 0
found that is what the Health app shows and the rule above says match it or
document it; the second bucket holds nights *recorded* as no alcohol and a
night with nothing logged is in neither column (ADR-0033's (b), for
ADR-0006's reason); and the gate is fourteen nights with a value in each
bucket. The drink window is 06:00 to 06:00. A per-day figure pairs with the
day after. `HealthPairing` and `DrinkingNight` in the core package;
`PairedFigures` is the value type the surface renders.

**Phase 2, the read layer.** `HealthKitService` gains the four read types and
a statistics query per metric, returning plain value types the domain layer
consumes. Nothing persisted. Handles the no-data state as the single state it
is.

*Landed 2026-09-21, ADR-0049.* One read type, not four — resting heart
rate, the only one the shipped build shows; each later phase appends its own
so its first request lists that type alone. The pairing asks for its reads
through `requestPairingAuthorization`, never through the app's beverage
request. `restingHeartRate(in:endingBefore:calendar:)` is HealthKit's daily
discrete average over `HealthPairing.readWindow`, which never includes the
current day; it returns `[HealthSample]` for one render and an empty array
for every kind of nothing. Every read leaves one breadcrumb,
`Diagnostics.lastHealthPairingRead` — the metric, the window's day count,
the wall time, and no value — which is where the query cost this plan could
not measure is read once Phase 3 makes the first read.

**Phase 3, resting heart rate, end to end.** The Trends section, the metric
picker, the two-figure card, the Settings toggle, the in-context offer. One
metric, the whole surface. This is the phase where the copy gets written and
argued, and where the pairing ADR ("the app pairs, it does not conclude") is
written.

*Landed 2026-09-21, ADR-0050 and ADR-0051.* No metric picker — the design's
first change to this plan: the Settings switches are how the reader picks,
and every switched-on metric that clears its gate is a row in one table
under "From Apple Health", last on Trends. `HealthPairingSection` resolves
the row's condition and the offer's once, and the heading is their literal
disjunction. The card is the weekday table's parts: "Your averages" beside
DRINKS and NO DRINKS, the metric's name over "36 and 48 nights", the two
averages in the reader's numeral face with "bpm", the source line and a
note that defines the columns to ADR-0048's buckets. `PairedFigures` has no
member for a difference and no view computes one; a range change crossfades
the figures rather than rolling them. One switch, "Resting heart rate", off
by default, in a section directly after Comparisons. The offer is the card's
shape with "– –" for figures and the log's own counts, gated on **both**
buckets from the log alone (this plan's third rule applied to the ask; the
design's text said the drink side) — accepted sets the answer, shows the
system sheet, then turns the switch on; declined is gone for good, once per
device, and turning the switch on in Settings answers it too. The read is
`TrendsView`'s `.task`, keyed on the range, the day, the buckets and the
switch, and skipped when the log alone cannot clear the gate; the request
is derived once per change of its inputs, not once per frame, and only when
the section could show something. The card draws figures only under the
range they were read for. Five of the design's strings changed, listed once
in ADR-0050: the source note and the spoken row say "nights recorded as no
alcohol" rather than "every other night", every "on this iPhone" is "on
this device", and the offer's copy is singular. Verified on a scratch
simulator with a seeded log and 200 seeded resting heart rate samples:
every range (the row at Quarter and Year, nothing at Week and Month), the
fold at `.xLarge` and AX5, both appearances, the offer's one-time
behaviour across a relaunch, accepting with the read denied leaving nothing,
the read revoked in Settings leaving nothing on screen, and the App Group
plist diffed before and after — the breadcrumb, the switch's boolean and
the offer's only. The first cost measurement: `resting heart rate
· 355 days · 0.01 s` at Year on the simulator, over 200 daily samples; the
owner's phone gives the real number. Not privacy-policy work: the policy
still says Tallyist reads no other Health data, which this build makes
false, and the Phase 7 rewrite has to land before any release build carries
it.

**Phase 4, sleep duration.** Stages as a separate increment once duration is
shipped and read correctly.

*Landed 2026-09-22, ADR-0049, ADR-0050 and ADR-0051 amended.* Duration only;
stages are the next increment, as this says. A second row under the same
heading from the same parts: "Sleep" over its night counts, "6h 12m" beside
"7h 04m" — `HealthPairing.timeAsleep` averaged per bucket behind the same
fourteen-night gate, printed from `HealthPairing.hoursAndMinutes` (one
rounding to the minute, half up, carrying into the hour; tier 1) with the
minutes zero-padded as the design draws them, and spoken as "6 hours, 12
minutes asleep". The read is a sample query over the window's sleep
analysis samples ending inside it (`.strictEndDate`, so a session still
running into today is not read), mapped by name to `SleepStage`; the
breadcrumb is now one line per metric (`lastHealthPairingReads`), since a
render that shows two rows makes two reads. A second switch, "Sleep" over
"Time asleep on nights you wear your watch", and the footnote in the
design's three-sentence shape — "Each switch…", and the wear-to-bed sentence
cut to sleep, the one place the app says it. The offer shows both rows and
returns to the design's plurals
("Show these on Trends"); accepting turns on both switches. **The design's
decision 1 is built:** sleep arrives switched on for anyone with the resting
heart rate switch on and off for everyone else, decided once when its key is
first missing and written so the two are independent after; its sheet is
asked for on the next visit to Trends that could show a row — once the log
clears the gate, never over Week — beside the table, through HealthKit's
one honest question (`statusForAuthorizationRequest`), once per visit and
only for the metrics whose switches are on. No difference is computed
between the rows any more than within one;
the note now reads "Each row is two averages…" and says nothing about sleep,
because the switch's caption already does. Ten app keys in, four out (351 →
357). Verified: 361 domain tests under both SwiftPM build systems (seven new),
114 integration tests (four new, pinning the inheritance and its one-time
nature), the CI-form and signed builds with no warning in the changed files,
and the inheritance on the real build by files on a scratch simulator. The
render pass ran later the same day, once the owner granted the simulator:
every item on the list, the sleep sheet listing sleep alone on a Phase 3
install, and iOS 27's two-step Health sheet found on the way — CLAUDE.md's
Phase 4 render bullet.

**Phase 5, HRV.** Larger gate, plainest presentation, possibly wide ranges
only.

*Landed 2026-09-22 (ADR-0052; ADR-0049, ADR-0050 and ADR-0051 amended). The
third row reads SDNN — the type every Apple Watch writes and the one the
Health app lists as "Heart Rate Variability"; iOS 27's RMSSD type is listed
beside it as "Recovery HRV", a second metric rather than a rename, and is
the ADR's reopen — through the same daily statistic as resting heart rate,
in whole milliseconds with "ms" beside the figure, filed under the night
before by the same day-after rule so the per-night figure is the one the
Health app shows on that date. The floor is twenty-eight nights with a value
in each bucket (`PairedFigures.minimumNightsForHeartRateVariability`, the
parameter Phase 1 left for it; SD/√n under a fifth, and the most a quarter's
shorter bucket holds for a three-nights-a-week log), and the row exists at
Quarter and Year only — two floors of 28 are more nights than a month holds
— so at Week and Month it is not drawn, not read and not asked for. The
read, the ask and the gate are per metric: the model reads only a metric
whose own floor the log clears at a range it is shown at, and the sheet on
Trends asks only for those, each once per visit, so a Phase 4 install that
arrives with the new switch on is asked for heart rate variability the
first time Quarter or Year holds twenty-eight nights a bucket, and never
over Month; the offer's acceptance is the named exception, one sheet for
all three types at the moment the reader asked for all three rows. The switch,
"Heart rate variability" over "Shown at Quarter and Year", inherits from
the two before it, or-ed, once. The footnote is not extended: the design's
sentence would have said this figure comes from nights the watch is worn to
bed, and its samples are the day's. Six app keys in, none out (357 → 363).
Verified: 362 domain tests under both SwiftPM build systems (one new), 116
integration tests (two new), the CI-form and signed builds with no new
warning in the changed files, the catalog synced from a fresh full build
and diffed, and tier 3 on the scratch simulator — CLAUDE.md's Phase 5
bullet has the list.*

**Phase 6, wrist temperature.** Including the baseline decision, which is the
one piece of new statistics in this feature and needs its own paragraph in the
ADR.

*Landed 2026-09-22 (ADR-0053; ADR-0049, ADR-0050 and ADR-0051 amended). The
baseline decision is to have none: the fourth row shows the reading the
watch records, averaged over each bucket's nights, to the hundredth of a
degree in the unit the reader's Health app shows, with no sign and no
deviation. The argument, in the ADR with Phase 0's arithmetic: a median over
the range's own nights makes the two columns' mean deviations sum, weighted
by their nights, to the gap between the range's mean and its median, which
is small, so unless the columns barely differ or the readings are skewed
the columns land on opposite sides of zero and their two signs state the
direction of the difference between the columns — the thing rule 1 says
the app never signs, and two signed deviations are read against each other
even when they happen to share a sign; a baseline from other
nights loosens the tie and keeps two signed figures read against each other;
a baseline over the no-drinks nights makes the drink column the difference
itself. The reading is the idiom of every other row, and the pair is the
observation. Each night's sample — Apple's one aggregated value, stamped
during the sleep — is read by a sample query and filed under the night whose
sleep day holds its middle (`.sleepDay`, the rule Phase 1 built for it),
behind the base gate at every range. The unit comes from HealthKit's
`preferredUnits` (the reader's choice in Health for an authorized type, or
the locale's default), asked only beside a read that returned samples, and
the mean converts with
Foundation's affine conversion at the moment it is drawn. The design's note
under the row keeps its place and says what the figure is — "Wrist
temperature is the overnight reading your watch records. Apple Health shows
it as a change from a baseline of its own." — because the plan's cross-check
is the Health app, which shows a change from a baseline that is not in
HealthKit. The switch, "Wrist temperature" over "One figure a night, from
your watch", inherits from the three before it, or-ed, once; the footnote's
third sentence names sleep and wrist temperature as the nights-in-bed
metrics. The hardware restriction is the empty state, and no model is named.
Seven app keys in, one out (363 → 369). Verified: 363 domain tests under both
SwiftPM build systems (one new: the row's two figures are the plain means,
each night filed by its sleep day, with unlogged nights' readings in neither),
117 integration tests (one new: the inheritance from any of the three), the
CI-form and signed builds with no new warning in the changed files, the
catalog synced from a fresh full build and diffed, and tier 3 on the scratch
simulator — CLAUDE.md's Phase 6 bullet has the list.*

*The owner's first device pass of the four rows, 2026-09-22 (ADR-0048,
ADR-0050 and ADR-0051 amended; CLAUDE.md's bullet "The owner's device pass
of the four rows…" has the list). Four findings on an iPhone running iOS
27. **The floor follows the range:** the prompt and the rows appeared only
at Quarter and Year, because one floor of fourteen was more than Week's
five countable nights or Month's twenty-eight could hold twice; the
owner's ruling — show it on all options, provided we have the data — made
the floor per range, two a bucket at Week, seven at Month, fourteen at
Quarter and Year (`PairedFigures.minimumNights(at:)`), read by the offer,
the read, the table and the ask alike; rule 3 holds at every range, and
the noise a two-night mean carries is accepted and stated in the ADR, not
on the card. Heart rate variability keeps ADR-0052. The line above, "the
row at Quarter and Year, nothing at Week and Month", and the Phase 4 note's
"never over Week" describe the code before this. **The card's secondary
ink** was 2.48:1 in dark mode on iOS 27 — the hierarchical `.secondary`
style is vibrant on glass, and this app's dark ground is black — so every
text in the app target takes the flat semantic colour now (design-system
§2). **The range picker is native** (it had missed single taps on
hardware; design-system §6). **The watch app** was not installed with the
phone build — a development install's behaviour, not the project's;
CLAUDE.md's bullet says what to do.*

**Phase 7, release.** Below.

---

## ADRs

Four. This plan reserved 0046 to 0049 for them; the watch took those numbers
before the first was written, so each takes the next free number in
`docs/decisions/` when its phase writes it (the design README's rule), and
the list below is in the order they are expected to land.

- **0048, a drinking night is not a calendar day** — written in Phase 1,
  2026-09-21. The window, the sleep attribution, matching the Health app, the
  second bucket, the gate, and the vectors.
- **0050, the app pairs, it does not conclude** — written in Phase 3,
  2026-09-21. The user picks the axis; both figures side by side with their
  night counts; no delta headline, no comparative language, no dual-axis
  chart. The argument for why structure rather than copy is what holds
  constraint 3 here.
- **0049, health context is read, never stored** — written in Phase 2,
  2026-09-21. No SwiftData, no CloudKit, no cache. What that buys, and the
  two consequences (device-dependence, query cost). Also a review rule:
  guideline 5.1.3 (ii). It carries the invisible-denial rule as well, since
  the read layer is where that rule is enforced; the ask's own record
  (below) inherits it.
- **0051, the ask happens at the moment of value** — written in Phase 3,
  2026-09-21. In context, once, showing before asking; and the
  invisible-denial rule that makes silence the only correct empty state. It
  added two things this plan left open: the offer waits for the log on both
  sides, not the drink side alone, and it asks once per device.

---

## Release

The heaviest release checklist of any feature in this repo, because it is the
first one that changes what the app reads about a person.

**The privacy policy sentence that becomes false.** `docs/privacy-policy.md`
currently ends its Apple Health bullet with: *"Tallyist reads no other Health
data."* That is a specific, checkable claim, and this feature breaks it. All
three copies change in the same commit with the date bumped (ADR-0024), and
`ci.yml`'s `policy-copies` job enforces the date agreement. Write the
replacement as precisely as the original: which four types, read only, never
stored, never transmitted, revocable in Health.

**The usage description string.** `INFOPLIST_KEY_NSHealthShareUsageDescription`
in `project.pbxproj`, in both the Debug and Release configurations. The current
text is entirely about alcohol samples and will read as a mismatch to a
reviewer looking at a sleep permission request.

**App Privacy labels.** The app currently declares Data Not Collected, and that
stays true: nothing is transmitted, nothing is stored, nothing leaves the
device. Confirm rather than assume, and make sure the reasoning is written down
somewhere a future session can find it.

**Reviewer notes.** Expect scrutiny. An alcohol app reading sleep and cardiac
data is a shape reviewers have seen go wrong. The notes should say what it
does (shows the user their own two averages side by side, on a screen they
open, for metrics they enabled), and what it does not do (no diagnosis, no
advice, no threshold, no notification, no inference about drinking from
physiology, nothing stored, nothing transmitted). The 1.0 Resolution Center
response is the model for the register.

**Also:** `docs/app-store-listing.md` What's New; `docs/copy-review-1.4.3.md`
for every new string; `docs/design-system.md` for the paired-figure card;
CLAUDE.md's Current state.

---

## Testing

| Tier | What lands there |
|---|---|
| 1, domain | Night alignment, pairing, bucketing, the sample-size gate, the baseline math. The great majority of this feature. |
| 2, repository | Nothing new. Health values are never written. |
| 3, simulator | The card at every range and Dynamic Type size, the picker, the offer's one-time behaviour, the empty state rendering as absence. HealthKit data can be seeded in the simulator's Health app, which makes more of this reachable than it looks. |
| 4, device | Real watch data, the Health app cross-check (does Tallyist's sleep figure match Health's for the same night?), query cost at `.year`, and the permission sheet's real content. |

The Health app cross-check in tier 4 is the one that matters most and is
easiest to skip. A figure that disagrees with the Health app is worse than no
figure, because it makes the user distrust both.

---

## What I could not verify

- **The Health app's sleep-day attribution convention.** Phase 0's first
  question. Everything in Phase 1 keys off it.
- **What `appleSleepingWristTemperature` returns** and how Health derives the
  deviation it displays. Phase 0's second question, and the reason wrist
  temperature is last.
- **Query cost** for a year-range statistics collection on a real device. No
  desk answer.
- **Whether Health data is present on an iPad** signed into the same account,
  which decides whether the feature renders there at all. The app ships
  `TARGETED_DEVICE_FAMILY = "1,2"`, so this is a real surface, not a
  hypothetical.
- **Whether adding four read types changes anything about App Store Connect's
  health-related questionnaires.** Worth checking before the build rather than
  at submission.
