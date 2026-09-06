# 0032 — Trends reports the log by weekday, and names the weekend the way its one source does

**Status:** accepted · **Date:** 2026-09-05 · **Relates to:** ADR-0028 (a
bar reports its own facts), ADR-0018 (the population reference's rules),
constraints 3 and 5

## Context

When drinks happen is a fact about the user's own log that needs no
external figure, and the app had no surface for it: the Trends chart
buckets by day, week or month, never by weekday. The owner asked to use
the reviewed sources for insights; one of them is the only paper found on
the weekly cycle of drinking in the US general population — Liang and
Chikritzhs, *Injury* 2015, on NHANES 2005 to 2010 day-level dietary
recalls. Its accepted manuscript, open in Curtin University's repository,
defines the weekend as Friday, Saturday and Sunday and reports 30.5 days
with a drink per 100 person-days on the weekend against 24.4 on Monday to
Thursday (a drink being 10 grams of alcohol or more, the authors' analytic
cutoff). Per-day-of-week rates are drawn in its figures but not tabulated.

**The competing option** was a bar chart of the seven weekdays. It loses
for the reason ADR-0028 gives: a chart of seven bars invites "which is
highest", and the tallest bar named is a rank. Seven rows of numbers say
the same facts without drawing the eye to one.

## Decision

**A "By weekday" card on Trends, under the summary cards**, for the
range the picker shows: seven rows in the calendar's order — the weekday's
name, the total logged on those days in the current unit (the package's
own amount phrase), and how many of that weekday's days had a drink ("4 of
4 days"). Then the user's own split on the paper's definition — "Friday to
Sunday: 6 of 13 days with a drink." / "Monday to Thursday: 4 of 17 days." —
then the published rate, "Among US adults, 31 of every 100 Friday-to-Sunday
days include a drink, and 24 of every 100 other days.", then a source line
that opens the note. The arithmetic is `TrendSummary.weekdayTotals` and
`weekendSplit` in the core package, over the range's own day walk, so the
seven totals sum to the range and the seven day counts to its length;
tier-1 tested, both week starts.

**Bundled as `us-weekend-reference.json`** with the paper's weekend
definition inside it, so the user's split and the published rate describe
the same days by construction. The paper's heavy-episode rate (40 grams or
more) is deliberately not carried: a cutoff of that size is a threshold in
all but name.

**No rank, no "most", no threshold, no verdict.** Nothing names a busiest
day; nothing relates a weekday to another or to the rate.

## Consequences

- Trends grows by one card of seven rows plus four lines; on a Week range
  each row is one day.
- The published rate is 2005 to 2010 data over drinkers and non-drinkers
  together, per person-day, which the note says; it is context for the
  user's own split, not a bracket. The user's split is days with any entry;
  the paper's is days with 10 grams or more — close, and stated.
- Weekday names come from the calendar, so they localize; "Friday to
  Sunday" and "Monday to Thursday" are the paper's definition and stay as
  words in the key.
- No schema change, no network, no new permission. Eight app-catalog keys
  in (one row key per plural of "day").
- The contract's sources file moves the paper from candidate to context
  with the full-text citation and the weekend definition; a vector set pins
  the fold.

## How to reopen

If the per-day-of-week rates behind the paper's figures are ever
published as numbers, the card can carry a rate beside each row — still a
rate, never a rank. A drinker-only rate would replace the all-adults one.
If the seven rows read as a league table in real use, the split alone
stays and the rows go.

---

## Amendment (2026-09-06) — the card becomes two tables

**Status:** accepted. The decision above is unchanged: same figures, same
sources, same refusals. This is a layout change only, from the owner's design
pass (`docs/design/Bar chart hover states design/`, screenshot
`05-weekday-insights.png`, DS card `ds/components/weekday-insights.card.html`).

Three problems in the shipped card, three fixes, **no new figures**:

1. **The unit noun printed seven times.** "3 standard drinks / 1 standard drink
   / 4 standard drinks…" down the card is a wall. The noun now becomes a
   two-line column head stated once, and each row carries only the numeral.
   `StandardDrink.amountPhrase` still supplies the digits and still drives
   VoiceOver — only the *visible* noun moved. The head reads the region's own
   plural (`Region.unitNamePlural`), so a UK reader gets "UNITS": the head is
   the one place the unit is named, so it has to follow the lens (ADR-0002).
2. **The two figures were stacked, not aligned.** The day count sat as a
   caption under the amount, so nothing lined up down the card. Two
   right-aligned numeric columns now do the comparing that the copy is
   forbidden to do — the reader sees the shape of their own week without a
   sentence naming a largest day.
3. **Three prose sentences carried three different denominators** — `20 of 39`,
   `10 of 52`, `31 of every 100` in running text, where the reader has to hold
   each one to notice they are not the same base. One small table instead:
   rows are the paper's own weekend definition, columns are **whose figure it
   is**. Nothing is recomputed, normalised, subtracted or ranked.

**Still refused, for the reason already given:** the seven weekdays are not
charted. A chart of seven bars invites "which is highest", and the tallest bar
named is a rank. If this card ever gains a per-row visual it must be a
published *rate* per row, never a bar whose height ranks the user's own days.

### The numeral rule is the only channel available

The user's own counts are rounded and tabular; the published rates stay in
default SF. Colour cannot carry that distinction — a second hue here would be a
new colour role, which PRD invariant 10 does not allow — so the numeral face
carries it alone, and softening it would merge two kinds of fact into one.
**Do not round the survey figures.**

### What accessibility sizes do

Three columns cannot hold their alignment at accessibility sizes, and a column
head that has scrolled away from its rows carries nothing. So the card folds
back to exactly the form this ADR first shipped: stacked rows with the noun
returned to each one, and the three reviewed sentences. The figures are
identical either way; only their arrangement changes. Verified on the simulator
at `accessibility-extra-large`.

### Consequences

- Seven new app-catalog keys, all visible-only: the two head pairs
  (`Days with a drink`, `Your log`, `US adults`), the two row labels
  (`Friday to Sunday`, `Monday to Thursday`), and the two ratio cells
  (`%@ of %lld`, `%lld of every 100`). 291 → 298.
- **No key is retired.** `weekendLine`, `weekdaysLine` and
  `weekendReferenceLine` are the *spoken* label of the comparison table and the
  *visible* text at accessibility sizes, so every 1.4.3-reviewed sentence
  survives verbatim on both paths. The table is a compact way to show them, not
  a rewording of them.
- The numeric columns are `@ScaledMetric` (88 / 74 / 100 at default type). They
  are what make a two-word head break onto two lines instead of running the
  width of the card and pushing its neighbour into it; a natural-width `Grid`
  leaves the head on one line, which was the first render's real defect.
- `GlassTokens.Typography` gains `sectionLabel`, `columnHead`, `rowFigure` and
  `rowCount`. `SectionLabel` was already named in `docs/design-system.md`'s type
  table without existing in code; it exists now.
- No schema change, no CloudKit step, no network, no new permission, no setting.

### How to reopen

Unchanged from above. Additionally: if the two-line column heads read as noise
at default type in real use, the heads can drop to one line by shortening
"Days with a drink" to "Days" — but the unit head cannot shorten, because a
bare "Drinks" would stop being the region's own word.
