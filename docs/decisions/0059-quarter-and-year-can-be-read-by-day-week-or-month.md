# 0059 — Quarter and Year can be read by day, week or month

**Status:** accepted · **Date:** 2026-10-01 · **Source:** the owner's request and
four answers of 2026-10-01 · **Amends:** ADR-0028 (the bars and the line follow a
grain the reader chooses; a bar is any bucket that holds a day of the range), ADR-0058
(the weekly figure is also Year's line under weekly bars, and its open question is
closed) · **Relates to:** ADR-0026 (the reader's choice, on a control VoiceOver can
name), ADR-0038 (the reader chooses, the app does not), ADR-0051 (what a visit is on
this screen), invariant 10

## Context

The owner, on the build of ADR-0058: *"can we add a feature for filtering on quarter
and year so that you can change if you want to see it by daily, weekly, or monthly
average drinks? So '-- Your average' stays daily on weekly and monthly then defaults
to weekly on quarterly and monthly on yearly with the option to change to daily or
weekly so that someone could see what their daily average was over a quarter or year
if they wanted to?"*

Four things were not settled by the request, and the owner answered each the same day:

1. **What the choice changes.** The dashed line has been on its bars' scale since
   Quarter and Year arrived in 2026-08 (per day under daily bars, per week under
   weekly, per month under monthly; the README and the copy review's entry for those
   ranges), because, in the chart's own comment, "a daily line under weekly bars would
   hug the floor and read as meaningless". ADR-0028 kept the rule, and its fourth
   amendment applied it at Quarter. A switch that moved the line alone would break it.
   The owner chose **"Bars follow the choice"**: daily shows daily bars and a daily
   line, weekly at Year shows weekly bars.
2. **Which choices.** Quarter offers **daily and weekly**; Year **daily, weekly and
   monthly**. A monthly Quarter was not offered: thirteen weeks usually hold two whole
   months and parts of two more (one to three whole months, by the day), so its line
   would be the mean of as little as one month.
3. **Memory.** **"Reset each visit"**: nothing is stored, and each visit to Trends
   opens on the range's own bars. A visit is what it already is on this screen: the
   Health pairing asks once per visit and forgets when the tab is left (ADR-0051).
4. **Placement.** **"Under the range picker"**: a second segmented control, shown only
   at Quarter and Year. It was built that way and rendered, and on that build the owner
   moved it: *"Instead of using a segment control below. Can you add a circular filter
   icon to the right of the monthly averages and then have dropdown they can pick from?
   This keeps the design cleaner and more minimal."* So the control is a circular
   filter button beside the legend, opening a menu.

The request kept Week's and Month's legend as it was ("'-- Your average' stays daily on
weekly and monthly"). On the menu's build the owner changed that too: *"I think we
should change the text on week and month to 'Your daily average' for better clarity and
matching with more descriptive text that we use on Quarter and Yearly."*

The competing option worth stating is to leave the chart alone: the per-day card under
the chart already prints the daily average over a quarter or a year. It prints the
figure without the bars it averages, and the request was to see the range that way.

## Decision

`TrendGrain` (day, week, month) in the core package, with `TrendRange.grains` and
`defaultGrain`: Week and Month `[day]`, Quarter `[day, week]` opening on week, Year
`[day, week, month]` opening on month — the buckets each range has always drawn.
`TrendRange.bucket` is now the default grain's unit.

On Trends, at Quarter and Year, **a circular filter button sits at the trailing end of
the chart card's title row, beside the legend it changes**: the system's
`line.3.horizontal.decrease.circle` glyph, 20pt at the default text size and scaled with
the title, in accent ink because it is a control. It opens a menu of the range's
grains, **Daily · Weekly** at Quarter and **Daily · Weekly · Monthly** at Year, with a
check on the current one. Its state is the legend beside it ("Your weekly average ·
5.1"), never a fill or a colour (invariant 10). Week and Month have one grain and show
no button. The button is its own VoiceOver element after the header, labelled
"Average" with the grain as its value, and its target, 44pt or the glyph's own size
once the largest text sizes draw it bigger (51pt at AX4, 58 at AX5), is centred on the
glyph.
It sits over the header rather than in it, because the header takes no touches and
reads as one VoiceOver element, and the title row leaves it room (the glyph and a gap
of 6), so the header's measured height and its 80pt floor are unchanged. It is there
whenever the range has a choice, line or no line: on a log with no complete month,
Year draws no monthly line and no legend, and the button stands alone. It fades with
the idle header while a bar is read, where the period's day count takes that corner.

The choice is `@State` in `TrendsView`, nil meaning the range's own, and it is cleared
by a range change and by leaving Trends, so every range opens on its own default and
every visit on the range's own bars; nothing is stored. Changing it clears the
selection, as a range change does.

**The bars and the line follow the grain** (`TrendWindowFold.averageLine(grain:)`):
- daily bars: the per-day average, the per-day card's own figure;
- weekly bars: the window's weekly figure, total ÷ (days ÷ 7), which the
  weekly-average comparison prints for the same range when it is shown (28 days of
  record and its switch on);
- monthly bars: the mean of the complete months inside the window, the line's rule
  unchanged, printed nowhere else.

The legend names the line by its scale at every range: "Your daily average" over daily
bars, Week's and Month's included, where it said "Your average"; "Your weekly average"
and "Your monthly average" as before.

**Selection, stepping and the spoken chart follow the grain** (`bucketStart`,
`bucketStarts`, `adjacentBucketStart` and `periodDetail` take an optional grain that
falls back to the range's). **A bar is any bucket that holds a day of the range** — it
starts on or before the last day and ends after the first. At the range's own grain
that is the old rule, since the first bucket starts on the range's first day. Under
weekly bars at Year it is not: Year starts on the 1st of a month, so its first weekly
bar is the week holding that 1st, drawn from the week's start and counting only the
days from the 1st. `PeriodDetail.firstDay` is that first counted day, and the readout
names the week from it, never from a day it does not count: on 1 October 2026 in a
Sunday-first calendar (the US), "Nov 1, 2025" and "1 day", since 1 November 2025 was a
Saturday; in a Monday-first one, Nov 1 to 2 and 2 days.

**Year's x axis names its months outright**, every other month from the range's first
(Nov, Jan, Mar, May, Jul, Sep on 1 October 2026), because under weekly bars the chart's
domain begins a few days before the 1st and a two-month stride then labelled Dec, Feb….
The monthly chart's labels are the same dates as before, pixel for pixel. **Bar
corners** shrink as bars multiply: 6 as drawn, 2 for Quarter's 85 to 91 daily bars and
Year's 48 to 54 weekly ones, 1 for Year's 335 to 366 daily bars.

**Nothing under the chart changes with the grain.** The per-day card, the days with no
drinks logged, the longest run, the weekday rows and the comparisons read the window
(ADR-0058), whatever the bars are cut into.

**Three things a fine grain needed, from the code review.** A scrub across Year's daily
bars crosses 365 of them, and the chart redrew everything on each: the selection's tick
now fires where the range's own bars change (a week at Quarter, a month at Year), as
it does on the default chart, rather than at the frame rate; the parts of a render that
do not depend on the selection (the bars, the fold, the range's figures and the line)
are derived once per change of their inputs (`TrendsChartCache`, after the Health
pairing's request memo); and the selected bar's end comes from its calendar unit
instead of a walk of the range. The selection rail keeps its 12pt floor, wider than a
daily bar at Year, and is clamped to the plot so the first and last bars' rails stay
inside it.

## Consequences

- **At their defaults the four ranges draw what they drew, but for the title row.**
  Rendered against ADR-0058's frames of the same log: at Week and Month every changed
  pixel is in the legend's box, which reads "Your daily average" where it said "Your
  average"; at Quarter and Year every changed pixel is in the chart card's title row,
  where the legend moves left by the glyph and its gap and the glyph appears. Nothing
  moves vertically, and the range picker is unchanged.
- **The legend has 26pt less room at Quarter and Year.** On a 375pt iPhone SE the
  longest, "Your monthly average · 22.6", still fits one line beside the title; at the
  accessibility sizes the title row already stacks, and the legend wraps under the
  title as it did.
- **A choice lasts only while the reader stays on Trends.** Someone who reads Year by
  day, logs a drink on Today and comes back finds Year by month again. That is the
  owner's "Reset each visit"; the range itself is kept across tabs, as it always was.
- **Weekly bars at Year begin and end with partial weeks.** The first holds one to
  seven days (one on 1 October 2026 in a Sunday-first calendar) and so can stand far
  below its neighbours; the readout names its days and counts them, as it does
  Quarter's trailing week.
- **Daily bars at Year are about a point wide.** They read as a texture of days rather
  than as bars to compare one by one; the selection rail keeps its 12pt floor, about
  twelve days wide there, while the 1pt hairline marks the day itself.
- **A log under a week old draws its weekly figure above every weekly bar at Year
  too.** One day with 4 drinks reads "Your weekly average · 28" over a bar of 4 under
  weekly bars at Year, as at Quarter. The owner kept that at Quarter on 2026-10-01
  (ADR-0058's amendment); it follows here from the same rule.
- **"Average" as the control's label** names the line, not the bars, which the control
  also changes; the chart's own spoken label ("standard drinks per week") says what the
  bars are once the choice is made.
- **A menu takes two taps where the segmented control took one**, and its choices are
  out of sight until it opens; the legend beside it says which average is drawn. That
  is the owner's trade, for one row of controls instead of two.
- **The selection's tick is coarser than the bars at a fine grain**: one per week at
  Quarter by day, one per month at Year by day or week.
- **Week and Month's legend reads "Your daily average"**, one word longer than "Your
  average": Week and Month have no menu, so the title row keeps all its width, and the
  legend still has more room there than at Quarter and Year.
- Four app-catalog keys in, "Daily", "Weekly", "Monthly" and "Your daily average", and
  one out, "Your average", which nothing reads now (401 → 404); "Average" is an existing
  key. No schema, CloudKit, setting, privacy or network change.

## Verification

- **Tier 1:** seven new tests and two widened ones (`PeriodDetailTests`,
  `TrendWindowTests`): each range's choices and default; a bar that starts on the
  range's last day, a Sunday at weekly grains and the 1st at Year by month (the one
  mutation the code review found the suite letting through, the overlap rule's
  `<=` made `<`, now fails six checks); every grain's bars holding
  every day of the range once and summing to its total; `bucketStart` matching
  `bucketed`'s placement for every bar at every grain, in UTC and in Santiago at
  Quarter and Year; every bar's detail agreeing with the bar over 10,000 drinks at
  every grain; Year's first weekly bar beginning before the range, selectable, partial,
  and counting only its days in the range; daily bars at Quarter and Year; stepping at
  a chosen grain; and the line per grain at every range, clipped or not. 421 tests under
  both SwiftPM build systems, nothing slow at 25ms in the changed files. The code
  review also probed the lookup over 4.8 million touches, in seven zones (Santiago and
  Lord Howe among them) and three first weekdays, at every range and grain: every
  resolved bar is a key `bucketed` makes, with a detail of the same days.
- **Tier 2:** 124 integration tests on the iPhone 17 Pro Max simulator, after one run
  that crashed in the known parallel CoreData setup and passed on the re-run.
- **Tier 3:** a throwaway iPhone 17 Pro on iOS 27, deleted afterwards, with ADR-0058's
  seeded logs, rendered through an instrumented copy of the tree that opens on a given
  range, grain and selection. All five grain views in light and dark; Week and Month
  without the control, and again after the rename, reading "Your daily average" in
  light, dark and at `accessibility-extra-large`; Quarter and Year at
  `accessibility-extra-large`; a 40-day log
  and a one-day log at every grain; bars selected at launch, both as a touch leaves the
  header and as VoiceOver holds the block below (Year's first weekly bar, its last, a
  Quarter day, a Year day). Every printed figure was recomputed from the store:
  65 ÷ 89 = 0.7 and 65 ÷ (89 ÷ 7) = 5.1 at Quarter; 249 ÷ 335 = 0.7 and
  249 ÷ (335 ÷ 7) = 5.2 at Year; the 1 November week's 6 drinks on one day; the
  trailing week's 5 days. Then by real taps: on the first build, the Weekly segment
  switched on one tap and a round trip to Today and back found Year still selected with
  its monthly bars and "Your monthly average · 22.6"; on the menu, one tap opened it
  over the chart with Daily, Weekly and a checked Monthly, and Daily drew "Your daily
  average · 0.7". The menu build rendered at Quarter and Year in light and dark, at
  each grain, at `accessibility-extra-large` (the glyph scales and sits on the title's
  first line), with a bar selected (the button gone, "1 day" in its corner), on a
  one-day log (the button alone, no legend), with the rail at Year's first and last
  daily bars inside the plot, and on a throwaway 375pt iPhone SE, deleted afterwards.
  The code review's last pass found the target smaller than the glyph above AX3; with
  it sized to the glyph, at `accessibility-extra-extra-extra-large` (a 57pt glyph) a tap
  on the circle's left edge, 26pt from its centre and outside the old 44pt square,
  opened the menu. On the same build by taps: Daily chosen; the menu opened again with
  the check on Daily and dismissed with no choice, Daily kept; then a round trip to
  Today and back, Year still selected and back on "Your monthly average · 22.6".
- **Not rendered:** VoiceOver over the button and the stepped bars, a UK region, a
  midnight-DST zone on screen, a Monday-first calendar on screen, the haptic and a
  scrub's frame rate on hardware.
- **Tier 4, the owner, the same day:** an Xcode build of the PR's head (c0de45e) on
  their phone, *"Tested it on my phone and it's working"*, and the PR merged at their
  word as 525f208 with all ten checks green. The report names no single item, so
  VoiceOver over the button, the haptic during a scrub and a scrub across Year by day
  on their log stay as listed above, unconfirmed on hardware.

## How to reopen

If readers want the choice kept, a stored grain per range is one setting, at the cost
of the default no longer being what a range opens on; keeping it for a session rather
than a visit is one line in `TrendsView`'s `onDisappear`. If a monthly Quarter is
asked for, it is one more case in `grains`, with a line that is the mean of one to
three months. If daily bars at Year read as noise on a small phone, Year's `grains` can
drop `.day` and keep the per-day card as the year's daily average. If the button is
missed, the owner's first answer, a segmented control under the range picker, was built
and rendered on 2026-10-01 but never committed; restoring it is a segmented `Picker`
bound to `grainBinding` under `rangePicker`, shown when `range.grains.count > 1`.
