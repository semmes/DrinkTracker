# 0028 — A Trends bar reports its own facts, never its distance from the line

**Status:** accepted · **Date:** 2026-09-03 · **Relates to:** ADR-0006 (a
summary, not a score), ADR-0001, ADR-0002, ADR-0007 / ADR-0010 (no second
colour), ADR-0014 / ADR-0023 / ADR-0025 (the row shapes the breakdown
names), ADR-0015 and ADR-0027 (not a share surface), ADR-0026 (the fold and
the heading), PRD invariants 3, 8, 9, 10, spec constraints 3–4

## Context

The owner asked (2026-09-02) for a tap-and-drag over the Trends bars "to
see additional data within that chart. That way if a user sees a spike or a
dip they can have context into that charting." The want is legitimate and
unserved: a bar was a height and nothing else, and a zero bar could not say
whether it was a day recorded as no alcohol or a day with nothing logged —
the very distinction ADR-0006 and the calendar's five-case `DayIntensity`
exist to keep, and one `TrendsView` could not draw because it never read
`AlcoholFreeDay`. The trailing bucket on Quarter and Year is always short
and nothing on screen said why.

The word "context" is the whole design problem. The obvious way to give a
bar context is to explain it *relative to something*, and the only
something on the chart is the dashed "Your average" line. The competing
option, stated so someone could still argue for it: an in-chart annotation
with a relative line — "1.5 above your average" — the shape most chart
libraries and competitors ship. It is factually true, the line is already
drawn, and a reader's eye computes the distance anyway; putting it into
words looks like restating what is visible.

It loses on four counts. It is a delta against another figure, which
ADR-0006 rules out by name. "Above" and "below" are direction words the
tone rules forbid outright, and a signed number is a direction whatever
word is used. The PRD's refusal table upholds "no goals, no targets" by the
rule mark being "labelled 'Your average', never a limit" — printing distance
from it is what makes it function as one, and the average moves with every
log, so the printed delta is a moving target that re-creates the
under-logging incentive that decided ADR-0006. And the average is the
*range's* mean: the same Tuesday would carry "1.5 above" on Week and "0.4
below" on Month. A sentence about a day that changes with the picker is not
a fact about the day, and the app has no business making it.

The second real choice was whether an honest zero bar needed the markers.
It does — a gap is not a day without alcohol — so Trends now reads
`AlcoholFreeDay`, which is also what exposed that the existing "Days with
nothing logged" card counts every zero-total day, markers included.

## Decision

**Tap or drag selects one bar** (`chartXSelection`); the selected bar keeps
its accent and the rest dim to 35%; the "Your average" rule mark is drawn
exactly as before, never dimmed and never annotated against the selection.
**A block under the chart, in the same card, reports the bar's own facts:**
the period as a date (a day's full date, a week's interval, a month's name
through `SummaryHeading` so "…, through today" is assembled in one place),
the day count for a week or month bar (the calendar card's own count line),
the total in the current unit for a day, what was logged by kind with entry
count and contribution — Beer, Wine, Spirit, Other, No type, From Apple
Health — with the rows summing to the bar, which zero a zero day is
("Recorded as no alcohol", with "From Apple Health" when the marker is
Health's, or "Not logged"), and for a week or month the calendar card's four
ADR-0006 figures with unlogged days named, in the same component
(`RecentSummaryFigures`) the calendar uses. Nothing is phrased against the
average line, ranked, or scaled to the range; `PeriodDetail` in
`DrinkTrackerCore` has no field for any of those, and a test pins that a
day's detail is identical whichever range contains it.

**The selection is view state only**, identified by the raw selected Date
and derived each render, so a drink logged while a bar is selected updates
it in place; cleared by a 44pt ✕, by the range picker (a day on Week would
silently become a week on Quarter), by tapping the selected bar again where
the system allows it, and by VoiceOver escape. Nothing about it is
persisted, synced, or logged. **The chart becomes one adjustable VoiceOver
element**: its value speaks the selected bar; swipe up and down step through
the bars by the same selection sighted users see; from nothing selected,
down lands on the newest bar and up on the oldest. **The Trends card is
relabelled "Days with no drinks logged"**, which is what it counts. No
setting: this is a read affordance over data already on screen, like
tapping a calendar day, not a behavioural surface.

**The block is on-screen only and is not a share surface.** ADR-0027's rule
governs images and is untouched; a Trends week is not a calendar surface,
and its four figures are not shareable. Both records cite `summary(of:)` as
the single classifier, which is what makes a Trends week's figures and a
shared month's figures the same arithmetic.

## Consequences

- The chart card grows when a bar is selected and the summary cards move
  down; the hint line ("Tip: tap or drag across the bars to see what each
  one holds") is one more sentence on the screen, kept on the calendar's
  precedent for a gesture with no visible affordance.
- Trends runs a second `@Query` (`AlcoholFreeDay` — already on the screen
  through `PopulationReferenceCard`, now in `TrendsView` too), and a render with a bar selected makes one `periodDetail` pass over the
  log on top of the one pass the view makes for its bars — both derived once
  per render in a snapshot, never once per bar, and never cached; acceptable
  to ~10k entries (a tier-1 test agrees every bar with its detail at that
  scale), measured at tier 3.
- "Today" is view state refreshed on the day-change notification and on
  foregrounding, as the calendar's is (ADR-0026): the range's end, the
  selected bar, and the "Today" caption move together at midnight.
- Selection changes animate explicitly (the dimming, the block's transition)
  rather than through an animation keyed to the selection on the card, which
  would have put the chart's data change inside the animation on a range
  switch and morphed the bars from one range into the next; the range picker
  clears the selection in the same update it changes the range.
- The chart's per-mark VoiceOver stops are replaced by stepping — a user who
  learned the thirty stops loses them and gains a sentence per step.
- The selection gesture is Apple's: whether the scrub coexists with the
  ScrollView and whether tap-again clears are tier-3 facts. If the scrub
  captures vertical pans, the documented fallback is a `.chartGesture` with a
  spatial tap plus the calendar's quarter-second hold before a drag; the ✕ is
  the contract either way.
- An import row a 1.0/1.1 device materialised with `countedDrinks` stripped
  (ADR-0022's cross-version shape) reads as "Other" in the breakdown — the
  log as it stands. A day with a 0% drink counts under "Days with no drinks
  logged" as it did under the old label; the relabel fixes the contradiction
  with the block, not that edge.
- The per-entry list and a jump to the day sheet are not built.
- Six app-catalog keys in and one out — five new strings and the relabelled
  card — none in the core package (the typed names are
  `DrinkType.displayName`, "From Apple Health" is an existing key, and "No
  type" is the one new name: ADR-0023's vocabulary, used because
  `.unspecified.displayName` is the summary line "One standard drink"); "so far" appears nowhere — the on-device clip wording is ADR-0026's
  "through today", and a bucket's day count says the rest.
- No schema, no CloudKit step, no App Group key, no widget change, no new
  permission or privacy category, no networking; the CSV and the share cards
  are untouched.

What it buys: a zero bar finally names its zero; the trailing bar says it is
four days rather than reading as a fall; a bucket bar carries ADR-0006's
partitioned figures instead of a bare height; and the "Your average" line
stays a line rather than becoming a sentence.

## How to reopen

If users ask what a bar is *relative to*, the honest answer is more
independent facts — a bounded per-entry list for day bars, or a jump to the
calendar's day sheet — never a delta; both are open without touching this
record (the day-sheet jump drags `DayLogSheet`'s store/health/undo
dependencies across tabs, which is why it waited). Reopen the delta question
only with an answer to ADR-0006's under-logging test — the feature has to be
safe for someone having a bad month — and to the picker-dependence problem
above; "the line is already visible" is not an answer, it is the reason the
line suffices. If tier 3 shows the tap-again clear is unreliable or the hint
is noise, drop the hint and keep the ✕. If the app ever sets `\.calendar`
in the environment, pass that calendar to `periodDetail` or the dimmed bar
and the described week can disagree by a day. If Swift Charts gains a
first-class per-mark accessibility action, the single adjustable element
can give way to per-mark elements. If the "Days with no drinks logged" card
should instead split into the calendar's three counts now that Trends has
the markers, that is a layout change to argue on its own, not a reopening
of this one.
