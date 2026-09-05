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

## Amendment (2026-09-05): the readout moves above the plot, and a touch selection lasts the touch

The owner's design pass (`docs/design/Bar chart hover states design/`) found
that the placement fails the gesture it belongs to: the reading hand covers a
block that sits under the chart, and the card grows as the block appears, so
the figures move *toward* the hand at the moment they are wanted.

**Decision.** The readout moves into the chart card's own header, above the
plot, as two states sharing one box and crossfading between them: the range's
own figures when nothing is being scrubbed, the touched bar's while a finger is
down. The box has a floor rather than a fixed height, so the card's height does
not change with the selection at the sizes the design was drawn at, and grows
rather than clips above them — design-system §3 makes a fixed `height` a rule
violation, and it is the fault that disqualified `SUSegmentedControl` in
ADR-0026. Two of this record's Consequences are superseded: the card no longer
grows on a scrub and the summary cards no longer move, and the hint line now
lives inside the box and costs no extra height.

The floor is **84 points, not the design's 76**, and the difference was
measured rather than guessed. On a 402pt screen at the default text size the
idle state's own content is 76.2pt — the design's number, taken from the idle
state — but the scrub state's is 81.4pt, because its title is subheadline where
the idle title is footnote. At 76 the floor bound neither state and the card
moved 5pt on every selection: the exact fault this readout exists to remove. At
84 it binds both and the two states render at identical height, verified by
comparing the divider, the chart baseline and every card below it across the
two renders.

**The "sticky-until-dismissed" selection was an error of record.** On iOS 26
`chartXSelection` writes nil itself the moment the finger lifts, and an
instantaneous tap does not select at all — selection needs the short dwell that
begins a scrub. Measured, not inferred, in a compiled probe. So release-to-clear
is the shipped behaviour documented, not a behaviour changed, and the two
compositions that would make it explicit (`.simultaneousGesture` with a
zero-distance drag, and the WWDC23 `.chartGesture` idiom) were each measured to
capture the ScrollView's vertical pan and are not used. The gesture line is
untouched. Two clauses above are consequently dead: "tapping the selected bar
again" is neither reliable nor unreliable, it is moot, and the hint's "tap or
drag" was factually wrong on iOS 26 and is now "drag".

**The ✕ narrows to the stepped selection.** With no touch path to a selection
that persists, the ✕'s job belongs to the one that does: the selection the
accessibility stepper puts there, reachable by VoiceOver, Switch Control and
AssistiveTouch alike. A single `selectionIsHeld` flag, set only by `step()` and
cleared by every framework write, gates it. `.accessibilityAction(.escape)` and
the named "Clear selection" action are unchanged.

**The drink-type share rows leave the scrub and keep their home.** Four figures
read at a glance; four figures plus a type list does not, and the list is what
forced the block to grow. `PeriodDetailView` is unchanged and still renders
below the chart — title, "Today", day count, figure-or-phrase,
`RecentSummaryFigures` with its named unlogged count, the composition rows, the
✕ — for a stepped selection. **The honest cost, stated rather than hidden: a
touch user can no longer reach the composition rows**, because iOS 26 offers no
touch path to a persistent selection. The shipped 1.2 What's New describes a tap
that shows them; 1.3's reviewer notes correct it. The composition that would
restore a latching tap is in "How to reopen" and was measured to preserve
vertical scrolling.

**Inside the plot**, the change is: the `RuleMark` keeps its stroke and loses
its `.annotation` — the label moved to the header, where it now also carries the
line's own value as an independent fact beside the range's own. That is not a
relaxation of this record's refusal: no delta, no sign, no direction word, the
same three keys, and the two figures are the *range's*, never a bar's. All
`AxisGridLine`s are dropped in both axes; the zero baseline is itself a y-axis
grid line, so it is emitted explicitly at zero — dropping the axis wholesale
leaves the plot with no floor at all. Two marks that encode nothing about the
data are added: a translucent rail behind the selected bar, full plot height,
and a 1pt hairline from the plot's top edge to the bar's top. Both are accent at
low alpha, which design-system §2 already admits as a *selected state* — no new
colour role, invariant 10 intact. The rail is positioned at the midpoint of its
bucket's two edges: `position(forX:)` returns the instant, and a bar is centred
on its bin, so the bucket start alone lands half a bucket to the left of the bar
it names. Its width is the bucket's own pitch, not the design's literal 26
points: that number was drawn against 13 weekly bars, where it is slightly
*wider* than the 24.7pt pitch — the rail fills the slot, which is what makes it
read as a column behind the bar. Fixed at 26 it was narrower than a Week bar and
read as a stripe inside one, which the first simulator render showed.

**What was refused, and why it is worth recording.** The design's third scrub
figure was a longest run without a drink. `docs/tallyist-1.2-spec.md` stops on
"A streak counter or a longest-gap record" and ADR-0027 names a longest gap as a
stop condition: a run is a number that can be protected, which is the
under-logging incentive ADR-0006 exists to refuse. The slot takes ADR-0006's own
second figure, days with none. The design also asked for the live figure in the
intensity ramp's top step; that step is the *6+ drinks* fill, where colour is
the datum, so tinting whatever a bar happens to hold would print a 0.4-drink
week in heaviest-day ink and make lightness carry interaction state instead of
magnitude. The figure is `.primary`. Contrast was not the objection and was
measured anyway: #0d366b 11.76:1 on white and 10.54:1 on a light card ground,
#9ec5f4 9.51:1 on the dark ground. And the design's zero-bar outline is not
built: the outline is ADR-0007's dedicated channel for *recorded as no alcohol*,
a zero bucket can be seven unlogged days, Trends has no legend to name it, and
at 3pt with a 1.5pt inset it renders solid — reading as "a very small amount",
the one thing it was meant not to say.

**Named consequences.** The average line is unlabelled for the duration of a
touch, since the legend is idle-only; the state is transient, ends on release,
and nothing on screen at any moment is phrased against the line. The range total
appears twice on the screen — the header and the first StatCard — from the same
fold; a figure repeated is not a figure contradicted. The header's day count
needs ADR-0006's classifier, not `daysWithoutDrinks`'s complement, which differs
by exactly the 0%-ABV days and would have made the header contradict the bar
under it by one: `TrendSummary.rangeSummary` is the new fold and a tier-1 test
pins its total equal to the bars' sum. The compact row prints three of the four
figures and cannot print the named unlogged count; it is spoken instead, and the
stepped selection's block still prints it. The three captions are the calendar
card's own, unabbreviated, so one figure never carries two vocabularies on one
screen — measured at ~330pt against a 330pt content width, which wrapped, so the
row offers the design's 14pt gaps, then 8pt, and only then stacks: a wrapped row
is the card growing on a selection. `.sensoryFeedback` now also ticks on the
release write. Row 2 of the scrub is a numeral *or* a phrase by design, so the
block's optical weight changes between bars — deliberate, and not to be "fixed"
by printing 0 for a marker day.

**No schema change, no CloudKit step, no setting, no App Group key, no widget
change, no networking.** One app-catalog key in, one out. Pinned at tier 1
(`rangeSummaryClassifier`, `rangeSummaryTotalAgreesWithBars`,
`rangeSummaryRegionLens`). Verified at tier 3 on the simulator over a seeded
quarter: the idle and scrub states at identical card height, the rail and
hairline tracking the selected bar, the zero baseline present with the grid
gone, both zero-day readouts ("Not logged" and "Recorded as no alcohol"), and
dark mode. The gesture's coexistence with the ScrollView on hardware, the box at
AX5, Reduce Motion, and the release tick remain tier 3/4 and are stated as such
in the commit.

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

If a latching tap is wanted back — so a touch user can reach the composition
rows again — the composition below was measured to preserve the ScrollView's
vertical pan (scrollY 548 on a vertical drag) *and* to scrub after the hold,
clearing on release. Note that a `chartGesture` replaces the default gesture
wholesale, including its own nil-on-release:

    .chartXSelection(value: selectionBinding)
    .chartGesture { proxy in
      SpatialTapGesture()
        .onEnded { proxy.selectXValue(at: $0.location.x) }
        .exclusively(before:
          LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
              if case .second(true, let drag?) = value { proxy.selectXValue(at: drag.location.x) }
            }
            .onEnded { _ in clearSelection() }
        )
    }

If the owner wants the design's live-figure tint after all, the route is a named
colour set in the asset catalog (light `#0d366b`, dark `#9ec5f4`) — the
`AccentFill` precedent from ADR-0029 — plus a design-system §2 roles row with
the three measured contrast figures. Not a widening of `IntensityPalette`'s
doc comment: that comment forbids styling uses specifically, and this is one.
