# 0027 — The calendar shares a month or a year as an image of its own four figures, and nothing it does not show

**Status:** accepted · **Date:** 2026-09-03 · **Answers:** ADR-0015's "How
to reopen" (a summarising artifact, argued against ADR-0006) · **Supersedes
in part:** 1.2 spec Feature D's content line ("average per week") ·
**Relates to:** ADR-0006, ADR-0007 / invariant 10, ADR-0024 (the policy's
three copies), ADR-0026 (the fold it draws from)

## Context

The owner asked (2026-09-02) to share a month or a year from the calendar,
with the month card carrying the same insights as the in-app card: days
with drinks, days with none, the total, and the average on days you drank.
Feature D of the 1.2 spec shipped a month card carrying a total and an
average per week — figures the calendar screen does not show — and a
four-entry legend beside an in-app legend of five.

ADR-0015 chose a CSV over a summarising report because "choosing which
aggregates to headline is one step from a verdict", and its reopen clause
says a summarising artifact must be argued against ADR-0006, not slipped
in. A card with four figures is a summarising image, so this is that
argument. It is admissible because the card is ADR-0006's own shape and
nothing else: four independent, checkable counts, with unlogged days named
so the two day-counts never look like they should sum to the period; no
composite, no delta against another period, no arrow, no grade, no rate,
no comparison to anyone; the user's own record, exported at the user's own
initiative through the system share sheet; and every figure already on the
screen the user is looking at — the card headlines nothing the app does
not. The average covers drinking days only, so a stretch of unlogged days
cannot pull it down (ADR-0006's under-logging incentive does not arise),
and a period in progress is reported through today rather than with future
days counted as unlogged (ADR-0026's clip).

The competing option was to keep the card figure-free — the grid alone —
and let the CSV be the only export with numbers. It loses because the grid
alone is exactly what ADR-0006 warns against: two visible day-kinds and an
unnamed remainder that a reader takes as alcohol-free; and the shipped card
already carried numbers. The other competing option was to keep the
per-week figure the spec named. It loses on three counts: the calendar
screen never shows it, so a reader cannot check it; the shipped
implementation divided by the whole month's day count even on the 2nd,
which is the averaged-over-unlogged-days figure ADR-0006 rejects; and
drinks-per-week is the unit consumption guidelines are quoted in, so it
invites the threshold comparison spec constraint 5 refuses.

A smaller question was where the year share lives. A menu on the calendar
toolbar ("Share this month" / "Share this year") works technically but
costs the month share its one tap and is ambiguous while browsing March
2025 in September 2026. A person sharing an image others will read should
be looking at it first.

## Decision

**Two cards, month and year, each shared from the surface that shows it** —
the calendar's existing share button renders the visible month, the year
view gains its own share button for the visible year; no menu. Each card
carries exactly: the period's name; a "Through <date>" line while the
period is in progress, and the window's day count beside it; the calendar
card's four figures over the days through today, with the unlogged-days
sentence whenever it is non-zero; the grid (twelve mini grids in three
columns for a year, six rows reserved per month so the boxes align); the
five-entry legend, "Not logged" included; and the wordmark. Figures come
before the grid: count is the hero, and the unlogged sentence has to sit
under the counts it qualifies. The per-week average is removed, not moved.

**The rule that makes ADR-0015's clause answerable once:** a share image
may carry only a figure the in-app calendar surface for that period already
shows, produced by the same `DrinkTrackerCore` function —
`TrendSummary.summary(of:)` through `monthSummary` / `yearSummary`, the fold
ADR-0026 put behind the on-screen card. The card's captions are the in-app
card's keys through `RecentSummaryCaptions`, except the average, which
reads "on days with drinks" because the image's reader is not its subject
and that phrase is the first figure's own, so the reader sees which count
the average divides by. `today` is read once at render time and handed to
the summary, the "Through" line, and the future-day fade, so the three
cannot disagree.

**Rendering:** `Grid`/`GridRow` over the new `MonthGrid.rows` (tier-1
tested against `dayIndex`), `FlowLayout` for the legend, no `LazyVGrid`
and no `GeometryReader` under `ImageRenderer`; type size pinned to
`.large` inside the 360pt card, the in-app surfaces staying the Dynamic
Type and VoiceOver surface; a weekday header on the month card; per-item
filenames (`tallyist-2026-09.png`, `tallyist-2026.png`) through the
`(Item) -> String?` overload, from the calendar's own components rather than
an ISO format that would render in UTC. Colour stays one `ShareCardInk`
site holding the shipped ground/ink pair, with every fill and outline
decision from `IntensityPalette`; invariant 10 and the palette's own
comment now name it as the second literal-colour site, which closes the
1.2 review's open item.

**The privacy policy** names "a month or a year" in all three copies, date
bumped, same commit (ADR-0024).

## Consequences

- The spec's Feature D content changes: per-week is refused, not moved, and
  the What's New, reviewer notes, spec claims table, README, and copy
  review say "month or year" and list the four figures.
- The privacy policy's sharing bullet changes in all three copies with a
  date bump for one phrase — the claim is written to be checkable, and a
  year image is a new artifact.
- The year card is tall (~780pt, ~2340px at 3×): the four figures are what
  survive a Messages thumbnail; the grid is texture until opened. If the
  bubble rendering proves unreadable at tier 3, four columns with 8pt cells
  is the trade to re-run, not a new decision.
- The year render draws 365 cells on the main actor at share time —
  expected tens of milliseconds; to be measured at tier 3 and recorded here
  as an amendment.
- A shared image is a snapshot in the region and store state current at
  share time, like the CSV (ADR-0015): two shares made under different
  settings disagree in the totals and may disagree in a drinking day's
  shade, since the ramp buckets the lensed count (ADR-0002); they agree only
  in which days have drinks, which are marked as none, and which are blank.
- A current-year card leaves up to eleven months blank, and a blank future
  cell looks like an unlogged one; the "Through" line is what tells them
  apart. A future-dated row (an edit moved forward) draws faded in the grid
  and is excluded from the figures, so the number and the picture can differ
  by a faded cell.
- "on days with drinks" and "on days you drank" now coexist for one number,
  deliberately, on two surfaces with different readers; the catalog carries
  one more key for it. If the owner wants byte parity, the change is one
  key in `RecentSummaryCaptions` and touches nothing structural.
- The app catalog gains "Through %@", "on days with drinks", and "Share this
  year as an image", and loses the translatable "Tallyist" key (the wordmark
  is a name, rendered verbatim); the in-app legend's five words became keys
  in ADR-0026 and the cards follow them automatically.
- Old 1.2 TestFlight installs keep the per-week card until they update;
  nothing persists, so nothing migrates.
- The month share ignores the calendar's summary-window picker (ADR-0026):
  the button sits over the grid, and the image is that grid with its own
  figures. Making the card follow the picker is a small product decision
  for its own paragraph, not a silent change.
- ADR-0015's reopen clause is answered in one specific shape and should not
  be reopened per feature: the question is always "is it on the in-app
  calendar surface for that period, from the same function".

## How to reopen

Any figure not on the in-app calendar surface for that period must first be
argued onto the in-app card under ADR-0006 — independent, checkable, safe
under missing data — and only then reaches a card. A delta ("vs last
month"), an arrow, a grade, a streak, a longest gap, a rate in a
guideline's unit (per week, per day), or the population reference never
does: the first four reopen ADR-0006, the streak and the gap are spec stop
conditions, and ADR-0018's own stop condition already refuses sharing the
reference. A per-week figure returns only computed over recorded days and
argued against spec constraint 5, not by restoring the old line. If users
cannot find the year share from the year view, a menu on the calendar
toolbar with period-named items ("Share March 2025" / "Share 2025") is the
next design, and the month share must keep its one tap. If real recipients
(a clinician) ask for a range of months in one image, that is a new artifact
to argue here again, not a widening of the year card. If localization
arrives, the legend keys already live app-side and the cards follow the
in-app legend automatically.
