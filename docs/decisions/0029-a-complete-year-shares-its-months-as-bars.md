# 0029 — A complete year shares its twelve months as bars, under the year card's own figures

**Status:** accepted · **Date:** 2026-09-05 · **Amends:** ADR-0027 (a third
card, and one word in its rule) · **Relates to:** ADR-0006 (a summary, not a
score), ADR-0026 (the fold), ADR-0028 (the average line's rule and register),
ADR-0007 / ADR-0010 / invariant 10 (the fill token), ADR-0015 (a summarising
artifact), ADR-0024 (the policy's copies — untouched, and why), spec
constraints 3 and 5

## Context

The owner delivered a design (2026-09-05, the claude.ai/design project
*Share Card*, bundled at `docs/design/Share_cards/`) with three cards: the
month and year cards as shipped in 1.2 — reference only, the bundle's README
says so, and its geometry diffed against `ShareCardParts.swift` finds no
change — and a **year-in-review card**: one complete past year, the four
figures, and under them a bar chart of the year's twelve monthly totals with
a dashed line at the year's monthly average. It opens the 1.3 train.

ADR-0027 made one rule law: a share image carries only a figure the in-app
calendar surface for that period already shows, from the same function.
Twelve monthly totals in one image are not on the year view, so this record
argues them in rather than slipping them past. Two things need the argument:
the bars and the line.

**The bars.** Each is a month's `totalStandardDrinks` — the third of
ADR-0006's four figures, over that month's grid, from `monthSummary`, the
fold behind the month view's own card ("Month shown", ADR-0026). A reader
who doubts a bar taps the month's name on the year view and reads the same
number on the card under the grid. What the review adds is not a new figure
but twelve instances of an existing one side by side — and side by side is
what ADR-0027 was careful about. Twelve months are not a delta: no bar is
expressed against another, none is ranked or named the tallest, the axis is
the year's own scale, and `YearInReview` has no field for a difference. It
is the year view's shape — twelve months at once — with a figure the month
view already shows in place of the grid the year view shows.

**The line.** Total ÷ 12. The Trends Year chart already draws this figure as
"Your monthly average" (`TrendSummary.bucketAverage`: the mean per
*complete* month, the trailing partial month excluded — ADR-0028 kept it as
it was, and the contract's `domain/aggregation.md` tabulates it). Over a
complete calendar year every month is complete, so the review's line is that
function fed twelve complete months. It is not per week or per day, the
units consumption guidelines are quoted in (spec constraint 5, ADR-0027's
reopen clause).

It does divide by twelve whether or not a month has anything logged, and
that is the one respect in which this card departs from ADR-0027's care: the
fourth figure divides by days with drinks precisely so a stretch of unlogged
days cannot pull it down (ADR-0006's under-logging test), while a month with
nothing logged pulls this line down. Three things make it admissible. It is
a figure the app already shows, on Trends, under the same rule, and the
caption names it in Trends' own words ("your average") rather than inventing
a second average. The card is only ever of a *complete* year, so the sag
ADR-0028 kept off Trends — the trailing partial month — cannot occur. And the
unlogged sentence sits directly above the chart, naming how many of the
line's days have no record at all. The alternative — a mean over months with
something recorded — is a fifth average with a denominator no screen shows
and the contract does not list; it is the reopen path below, not the
default.

**The competing option** was to keep the year card as the only year image
and let the CSV carry monthly totals for anyone who wants them. It loses
because the owner designed this card for a reader the CSV does not serve —
a year, read at a glance by someone who was not there — and because the
figures are the app's own, argued above.

**Entry point.** The design says the card is "suggested from the year view
once a first full calendar year is on record", with past years selectable.
ADR-0027 refused a menu on the *calendar* toolbar because it cost the month
share its one tap and was ambiguous while browsing March 2025 in September
2026, and its reopen clause named a period-named menu as the next design.
The year view's own navigation already is a chronological year picker, so
the review needs no second one. "Suggested" is read as *offered*, never
*prompted*: Feature D's rules (no prompts, no nudges, no badges) hold, and
the control is the only entrance.

## Decision

**A third card, the year in review, for a calendar year that has ended and
has something recorded in it.** It carries exactly: the year as its title
with the day count under it (365 or 366; no "Through" line — the year is
whole); the year card's four figures with the unlogged sentence, in the
shared components; a chart captioned "Standard drinks by month · the dashed
line is your average, N" ("Units by month" under the UK lens) — a three-tick
axis at 0, half, and the tallest month rounded up to a whole drink; one
hairline at the middle; twelve bars in the accent fill token (`AccentFill`,
500 in both modes, design-system review R2), equal width, 4pt apart, 3pt
top corners; a 1pt baseline; the average as the Trends chart's own dashed
stroke, without a label of its own, omitted at zero exactly as Trends omits
it; the calendar's one-letter month symbols under the bars; then the
wordmark. Same ground and inks (`ShareCardInk`), same 360pt document, same
renderer, same terms — built at share time, nothing persisted, nothing
logged about the share. Filename `tallyist-2025-review.png`, distinct from
the year card's so "Save to Files" never overwrites one with the other.

**The arithmetic is `YearInReview` in `DrinkTrackerCore`**
(`TrendSummary.yearInReview`): the summary from `yearSummary`, one total per
month from `monthSummary`, the average from `bucketAverage` over the twelve
as `PeriodTotal`s, the axis maximum shaved of floating noise before it is
rounded up. Tier-1 tests pin that every bar equals the month card's total,
that the bars sum to the year's total, that the average is total ÷ 12 with
an unlogged month counting as zero, that a year with nothing recorded is
not on record, the completeness gate, the region lens, and that a year in
progress — which the gate never hands in — would clip like every other
window. Nothing in the type is relative to another year.

**The entry point is the year view's share button.** For the year in
progress it stays a one-tap `ShareLink`: there is no review of a year that
is not over. For a complete year with a record, the same button opens a
two-item menu naming both pictures — "Share as a calendar", "Share as a year
in review" — each a `ShareLink` with its own preview ("2025", "2025 in
review"). The gate reads the summary the page already computed
(`isComplete` and `daysUnlogged < dayCount`), so it costs no second walk
over the log. No banner, no badge, no prompt.

**ADR-0027's rule is amended in one clause**: a share image may carry only
a figure the in-app calendar surface for that period *or for a period
nested in it* already shows, produced by the same `DrinkTrackerCore`
function — and a line the in-app Trends chart already draws, under the same
rule. The review is the one artifact this admits; a delta, an arrow, a
grade, a streak, a rank, or a rate per week or per day still never reaches
a card.

**The privacy policy is unchanged.** Its sharing bullet says "the calendar
can render a month or a year as an image" and enumerates no content; a year
in review is a year rendered as an image, from the same surface, on the same
terms, so the claim stays true and checkable without a three-copy date bump
(ADR-0024). The 1.3 reviewer notes describe the chart.

## Consequences

- Twelve monthly totals now exist in one image where before they existed
  one month at a time. The comparison is available to any reader; the app
  makes none. That is a real change in what the artifact affords, and the
  mitigations are structural — no field for a delta, no rank, no callout,
  the year's own scale — not editorial.
- The average line counts unlogged months as zero, the departure argued
  above. A user whose January and February predate the app sees a line
  pulled down by two empty months, with the unlogged sentence above naming
  the 59 days. If real use shows this reading as a verdict, the reopen path
  below is one function and one caption, not a new card.
- The dashed line is secondary ink on both grounds; where it crosses a bar
  it reads at about 1.1:1 in light and 1.9:1 in dark, so the line is read in
  the gaps and against the ground, as on Trends. Measured, not eyeballed:
  bars on the white ground 5.39:1 and on the dark ground 3.15:1 (WCAG
  1.4.11's 3:1 for graphics); secondary ink 4.74:1 / 5.97:1 as before. No
  new literal-colour site: the bars are the `AccentFill` asset, and
  `ShareCardInk` remains the only site beside `IntensityPalette`
  (invariant 10).
- "your average" and "on days with drinks" coexist on one card,
  deliberately: the caption is Trends' register for Trends' line (ADR-0028's
  "your average, never a target"), and the figure is ADR-0027's wording for
  ADR-0006's figure. The owner's design chose both; ADR-0027's reasoning
  ("the reader is not the subject") would argue for "the dashed line is the
  monthly average, N". One key changes it.
- A half-drink axis tick ("34.5") is wider than the 20pt axis column and
  overflows leftward into the card's padding, as it does in the design; it
  is `fixedSize`, so it never wraps. "120.5" still fits inside the 24pt
  padding.
- The year share loses its one tap for past years — a menu with two named
  items, ADR-0027's own next design. The month share and the current year
  keep theirs.
- Six app-catalog keys in — "Share as a calendar", "Share as a year in
  review", "%@ in review", "Standard drinks by month", "Units by month",
  "the dashed line is your average, %@" — none in the core package
  (`YearInReview` carries no strings) and none in the widget. The month
  initials are the calendar's own symbols, so they localize for free.
- No schema change, no CloudKit step, no App Group key, no new permission,
  no networking; the CSV, the month card and the year card are untouched —
  their renders were diffed by eye against the design bundle and found
  identical, and every part they share with the new card is unchanged.
- The card is offered for any complete year with one recorded day, a first
  partial year included; its unlogged sentence and its line both say so. A
  year with no record at all gets no review — twelve empty bars would be a
  picture of the install date.
- Old 1.2 installs have no review card until they update; nothing persists,
  nothing migrates.
- Verified at tier 3 on the simulator (2026-09-05): the menu's two items,
  the share sheet with "2025 in review", and the PNG the sheet's Preview
  opened, rendered from a seeded 2025 in the real store; both appearances,
  the UK caption, a year of markers only, and a tall December rendered
  headlessly; PNG chunks are IHDR/sRGB/pHYs/eXIf/iDOT/IDAT only, the EXIF
  carrying orientation, resolution and pixel size. **Still tier 3/4 for the
  owner's device pass:** the chart's legibility in a Messages bubble, the
  dashed line over dark bars on a real display, "Save to Files" naming both
  year images, the tmp directory after a share, VoiceOver's reading of the
  menu, and a real year that began mid-year.

## How to reopen

If the line reads as a verdict in real use — someone stops logging a month
to keep it low, which is ADR-0006's exact test — replace its denominator
with months that have a record (an entry or a marker on any day) and change
the caption to say so; that is a new row in the contract's average table and
a one-line change here, not a new card. If the owner wants byte parity with
ADR-0027's register, "the dashed line is the monthly average, N" is one key.
If users cannot find the review, the year view can carry the same
`ShareLink` as a row under its summary card; it must stay a control, never a
prompt. A range of years in one image, a year-over-year anything, the
tallest month named, or a per-week or per-day rate never returns without an
answer to ADR-0006's under-logging test and to spec constraint 5. If
localization arrives, the month symbols already follow the calendar and the
caption's two phrases are separate keys that wrap as one paragraph.
