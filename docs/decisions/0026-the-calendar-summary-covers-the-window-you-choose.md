# 0026 — The calendar summary covers the window you choose, clipped at today

**Status:** accepted · **Date:** 2026-09-03 · **Amends:** ADR-0006 (the
window is now chosen; the shape is not; the year view's footnote moves into
the card) · **Relates to:** ADR-0002 / invariant 3 (region lens), ADR-0007
(the year view), ADR-0015 and ADR-0020 (their reopen clauses), PRD invariants
8 and 9

## Context

ADR-0006 fixed the calendar's card to the 30 days ending today, and
`CalendarView` computed it from `Date()` regardless of which month the grid
showed — so a user paging back to July read July's grid over a card about
August and September. The year view had ADR-0006's reasoning but not its
figures: a footnote counting recorded days against 365, which for the year in
progress puts days that have not happened in the denominator. The owner asked
(2026-09-02) for a filter between the rolling window and a one-to-one match
with the month on screen, and for the same insights to carry into the year
view so a year reads at a glance.

Three things had to be decided that "the month" leaves open, and each had a
competing option worth stating honestly.

*What the current month means before it is over.* The competing option —
count the whole month and let ADR-0006's unlogged line absorb the future days
— is honest in the narrow sense that nothing is hidden, and wrong in the sense
that matters: "28 days have nothing logged either way" on September 2 names
days the user could not have logged. The calendar already dims future days
and makes them inert on the same reasoning.

*Whether the card follows the page.* The simpler option pins the month window
to the current month; it loses because the label would lie on a past page,
and the mismatch between grid and card was the reading error being fixed.

*What happens to the year footnote.* Keeping "N of 365 days have something
recorded" beside a card whose unlogged line counts elapsed days puts two
denominators (365 and 245) and two figures for "unrecorded" on one screen.
Re-basing the footnote to elapsed days and keeping it is redundant with the
card.

Two things were found on the way that the record should keep.
`SUSegmentedControl`, which Trends uses, is a row of `Text` with
`onTapGesture` — no button or selected trait for VoiceOver, verbatim `String`
titles the catalog never sees, a fixed height under Dynamic Type — so the
picker here is the native segmented control on interactive glass that
Settings already ships. And `recentSummary`'s day arithmetic chained offsets
from `startOfDay(endDate)`; reproduced with Foundation for America/Santiago
on 2026-09-06 (a day that starts at 01:00, because Chile moves its clocks at
midnight), the chained keys land on 01:00 of every earlier day and match one
of six drinking days' keys — on that one day, in Santiago, Havana, Cairo, and
Beirut, 29 of 30 days read unlogged. Havana's autumn change *repeats* the
midnight hour rather than skipping it, and there the damage ran the other
way: the fall transition day (2026-11-01) read as unlogged in every rolling
window that contained it, the whole month after. Generalising the API
without fixing it would have carried the bug into the new windows.

## Decision

**Two windows on the calendar, chosen by a segmented control directly above
the card — "Last 30 days" (default, the shipped behaviour) and "Month shown" —
persisted per device in `AppSettings.calendarSummaryWindow`.** "Month shown"
is the grid's own cells: whole for a past month, the 1st through today for the
month in progress, headed "…, through today" exactly when a day was clipped,
with the window's day count beside the title so the three day-counts stay
checkable against it. Future days are excluded, never counted as unlogged.
The rolling window keeps ignoring paging, as shipped; its title says what it
covers.

**The year view carries the same card for the year shown** on the same clip
rule — whole for a past year, January 1 through today for the current one —
and retires its recorded-days sentence, keeping "Blank days are days without
a record, not days without alcohol." as a caption under the legend. It has no
picker, because twelve named months match exactly one window.

**The figures keep ADR-0006's shape exactly** — four independent numbers plus
the named unlogged count — over one window at a time, and this record adds
one clause to it as law: **no delta between windows.** The card never shows
two windows or a change between them; switching crossfades the digits rather
than rolling them. An average over no drinking days prints "—" (spoken "No
days with drinks to average"), not 0, because a figure that does not exist
should not be printed as one; the total keeps printing 0, which is a
checkable fact.

**The math is one fold in `DrinkTrackerCore`**, `TrendSummary.summary(of:
[CalendarDay])`, fed by `MonthGrid.days(through:)` for the month and year
windows (`monthSummary`, `yearSummary`) and by `recentSummary` — now a
wrapper over `trailingDays`, whose keys come from the package's one DST-safe
day walk, `dayKeys`, extracted from `dailyTotals` — for the rolling one. Every
window shares one definition of a day (a key present in the totals table has
entries, even at a total of 0.0; else a marker means no alcohol; else nothing
is known — the rule `DayIntensity.bucket` already applies), so the card
cannot disagree with the grid above it.

**The heading strings are presentational and live in the app catalog**
(ADR-0020's clause); no core key is added. The card's captions move into
`RecentSummaryCaptions` and the four figures into `RecentSummaryFigures`, so
every later surface that reports a window of days reuses the reviewed copy
rather than restating it. The in-app legend's five labels become catalog keys
(`DayIntensity.legendKey`, app-side) — `Text(String)` is the verbatim
initializer, so they had never reached the catalog; they stay out of the
package because its symbol generation derives an identifier from every key
and "1–2" and "6+" are the ones it has no answer for.

**"Today" is view state** in both calendar views, refreshed on the
day-change notification and on foregrounding — the 1.2 review's "Today pinned
to its launch day" class of bug, pre-empted for a card headed "through today".

## Consequences

- A user can now flip between two windows and see different numbers one tap
  apart. The app never puts them side by side, but the comparison is
  available to anyone who wants it, and that is a real change in what the
  surface affords. The mitigations are structural — one window on screen,
  no field for a delta, no numeric roll — not editorial.
- `dayCount` no longer always equals a round number, so the unlogged line's
  implicit denominator changes with the window. The title now carries the
  window and its day count so the line stays checkable; that is one more
  line of chrome on a card ADR-0006 wanted spare.
- The month in progress shows thin figures early — "1 day" on the 1st —
  which is honest, not a bug, and will be reported as one.
- The year view loses its "N of 365" sentence; anyone who liked that exact
  phrasing now reads days with drinks plus days with none from the card.
  ADR-0006's sentence citing that footnote is amended by this record rather
  than edited; the reasoning survives as the card's unlogged line.
- The rolling card no longer has the midnight-DST blind spot. That is a
  behaviour change for one day a year in three zones and about thirty in
  Havana, and the tests that pin it (`rollingWindowOnTransitionDay`,
  `rollingWindowOnRepeatedMidnight`) fail against the old arithmetic.
- The average on a fresh install's rolling card reads "—" instead of "0"
  until a day with drinks exists. A two-line, separable change; the owner can
  say the word if the old "0" should stay.
- One more App Group key that the widget never reads, not CloudKit-synced, so
  two devices may hold different windows — like region. The figures recompute
  from `@Query` on every merge, so sync simply re-renders.
- Twelve app-catalog keys added ("Month shown", "Days the summary covers",
  "%@, through today", "1 day", "%lld days", "No days with drinks to
  average", "Blank days are days without a record, not days without
  alcohol.", and the five legend words "No alcohol", "1–2", "3–5", "6+",
  "Not logged", none of which the catalog held before — count the file,
  don't trust this list) and the two year-footnote keys retired; the
  "%@, through today" key serves both a month and a year and may need
  splitting at translation time.
- "Month" on Trends still means the rolling 30 days, and Trends' ComponentsKit
  picker keeps its VoiceOver hole. Both recorded as follow-ups, not fixed
  here.
- The share card, when it prints the four figures (ADR-0027), must use
  `monthSummary` / `yearSummary` so the image and the card on screen agree —
  and argues that rendered summary against ADR-0006 there, per ADR-0015's
  reopen clause. The shipped 1.2 card's per-week
  figure divided by the whole month's day count, future days included;
  ADR-0027 removed it rather than correcting it.
- No schema change, so no CloudKit step — stated because ADR-0025 made the
  step easy to assume. No new permissions, no new privacy label categories,
  nothing leaves the device.
- `RecentSummary` and `RecentSummaryCard` keep their names; "recent" now
  means "the chosen window", and a doc line says so.

## How to reopen

- A third window — a week, a rolling "Last 12 months" or "Last 365 days" on
  the year view, "since install" — is additive: one more case, one more
  heading, the same fold. Add it if real use asks, and only with a grid that
  matches it or a stated reason the mismatch is acceptable; never as a
  comparison.
- Showing two windows at once, a change against the previous period, an
  arrow, or a "vs" line is not a reopen of this record but of ADR-0006, and
  needs its answer to the under-logging incentive — one that does not rely on
  the user's discipline. A delta is a score with a sign.
- If padding a partial month ever seems right, the test is whether the
  sentence "N days have nothing logged either way" would be true of days that
  have not happened. It will not be.
- Making the share card follow the picker, persisting the window per surface,
  or syncing it through iCloud are small product decisions that get their own
  paragraph here, not silent changes.
- Truncation of the picker at accessibility sizes is a fix (the `RegionRow`
  pattern: two Buttons with a checkmark on interactive glass), not a reopen.
- If Trends' "Month" is ever renamed, revisit "Month shown" for consistency
  across the two tabs.
