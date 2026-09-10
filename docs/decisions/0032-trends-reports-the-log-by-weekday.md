# 0032 — Trends reports the log by weekday, and names the weekend the way its one source does

**Status:** accepted · **Date:** 2026-09-05 · **Relates to:** ADR-0028 (a
bar reports its own facts), ADR-0018 (the population reference's rules),
constraints 3 and 5 · **Amended by:**
ADR-0038 (the comparison is the reader's to show, and waits for four
weeks of range — see the amendment below), ADR-0038's own 2026-09-10
amendment (the comparison leaves this card for the Comparisons section — see
the last amendment below)

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

---

## Amendment (2026-09-07) — the fold moves to xLarge, the comparison columns size to their content, and a row is one VoiceOver stop

**Status:** accepted. From the 1.3 release review. The tables, the figures and
the refusals above are unchanged; this corrects *when* the tables give way and
*how wide* their columns are, and fixes a VoiceOver fault in the weekday rows.

### What was wrong

The 2026-09-06 amendment folded the tables only at accessibility sizes and
verified that fold at accessibility-extra-large alone; the 1.3 release review
then computed from the HIG's caption2 table that the label column would starve
from xLarge on a 375pt screen and from xxLarge on a 402pt one. Rendering found
it worse still, and this decision was rendered rather than reasoned. Measured
from frames of the shipped card on the iPhone 17 Pro simulator (402pt; content
width 328pt), by the numeric columns' trailing edges:

| Content size | Each numeric column | Label column | Widest name (subheadline) | Rendered |
|---|---|---|---|---|
| medium / large | 88 | 136 | Wednesday 81 | one line |
| xLarge | 122 | 68 | Wednesday 90 | "Wednes-/day", "Thurs-/day" |
| xxLarge | 136 | 40 | Wednesday 100 | every name hyphenated, "Sat-/ur-/day" |

The columns are `@ScaledMetric(relativeTo: .caption2)`, and the metric grows
faster than the text style it is named for — 1.39× at xLarge and 1.54× at
xxLarge against the names' 1.13× and 1.27× — so the label column starves two
sizes before the accessibility threshold. The comparison table fails sooner
still: its fixed 74/100pt columns left "Monday to Thursday" (125pt at the
default size) 140pt on a 402pt screen but only 113pt on a 375pt one, so on the
smaller phones the label wrapped at the **default** size, and at xLarge on the
402pt screen it wrapped too ("Friday to / Sunday").

Design-system §3 says wrap, never clip — and a weekday name broken mid-word
with a hyphen is neither; it is the fold arriving too late.

### Decision

1. **The fold happens at xLarge**, the first size above the default:
   `isStacked` is `dynamicTypeSize >= .xLarge`. Extra-small through large keep
   the owner's table on every screen width; xLarge and up get the stacked rows
   and the three reviewed sentences, which read correctly at any width.
2. **The comparison table's numeric columns size to their content** — the
   head or the widest cell, whichever is wider — with no fixed width. Both
   heads are one line, so a fixed width bought nothing there and cost the label
   column the room it needed. Rendered at the default size the columns come to
   60pt ("YOUR LOG", measured from the frame) and about 87pt ("31 of every
   100", the caption's own width), and "Monday to Thursday" sits on one line
   with a 375pt screen's label column at about 138pt against the phrase's 121.
3. **The weekday table keeps its 88pt scaled columns.** They are still what
   breaks the two-line heads, and at the sizes the table now appears at they
   are 88pt on every screen: the label column is 136pt on 402 and 109pt on
   375, against 81 for "Wednesday".
4. **Each weekday row is one VoiceOver stop.** The row's `accessibilityElement`
   and label were on the `GridRow`, and a modifier on a `GridRow` is applied to
   each of its cells, so every weekday was three identical stops (a compiled
   probe in the review counted six elements for two rows). The label now sits
   on the name cell and the two figure cells are hidden. The stacked form and
   the comparison table (modifiers on a `VStack` and on the `Grid`) were
   already one element each.

### Why not a narrower weekday column and a later fold

Holding "Wednesday" at xLarge on a 375pt screen needs the two numeric columns
under 70pt at that size, and the head's widest line, "DAYS WITH", is 67pt at
the default size with the same metric behind it: a column narrow enough for
the name is a column that squeezes the two-line head into three. On the 402pt
screen alone a ~76pt column would hold the weekday names at xLarge, but the
comparison labels are a coin toss there (141pt of phrase in 141pt of column)
and a 390pt screen is one too. One threshold serves every width, so it is the
one at which nothing fragments anywhere.

### Consequences

- "What accessibility sizes do" above now reads as "what the sizes above the
  default do": the fold is at xLarge, not at the accessibility threshold. The
  figures are identical either way; only their arrangement changes.
- The `@ScaledMetric` consequence above is corrected: only the weekday
  table's column is scaled (88); the comparison table's 74/100 are gone. At the
  sizes the tables appear at, the scaled value is its base value.
- The frames, listed in the pull request that landed this amendment:
  `fixed-large-weekday.png` (table, both labels one line),
  `fixed-xLarge-weekday.png`, `fixed-xxLarge-weekday.png`,
  `fixed-xxxLarge-weekday.png`, `fixed-axXL-weekday.png` (stacked, nothing
  hyphenated), against `baseline-xLarge-weekday.png` and
  `baseline-xxLarge-weekday.png` (the shipped fragments), all on the
  iPhone 17 Pro. The 375pt case is arithmetic, stated above; there is no
  375pt simulator on the build Mac.
- The one-stop-per-row fix follows from the documented `GridRow` semantics
  and the review's measurement of the fault; the stop count after the fix is
  not measured here — an in-process macOS probe cannot see SwiftUI's
  accessibility tree — and is stated as tier 3 for VoiceOver on a device.
- One measurement note for the next pass: the simulator's resting content
  size on that Mac is `medium`, which is one step *below* the iOS default
  (`large`). The default-size frames here were taken at `large`; earlier
  amendments' "default type" measurements may have been at medium, where
  caption2 and the columns are the same but the names are a point smaller.
- No key in or out, no schema change, no CloudKit step, no setting.

### How to reopen

If the stacked form at xLarge reads as a step down in real use, the route back
is a table whose column widths come from the text rather than from a scaled
constant — measured heads, not `@ScaledMetric` — so the label column can be
guaranteed rather than computed; that is a layout engine change, not a
threshold change, and a threshold change alone re-creates the hyphenation
above.

---

## Amendment (2026-09-08) — the comparison is the reader's to show, and waits for four weeks of range

**Status:** accepted, by ADR-0038. The figures, the sources and the refusals
above are unchanged. Two things move:

1. **A switch.** Settings → Comparisons → "Weekend and weekdays" shows or
   hides the comparison section — the split beside the published rate and
   its source line. On by default. The seven weekday rows are the reader's
   own log and never depend on it.
2. **A floor.** The comparison section appears only when the range holds
   `WeekendReference.minimumDays` (28) calendar days or more —
   `WeekendSplit.isComparable`. The decision above put it on every range,
   which on Week placed three Friday-to-Sunday days beside a rate per
   hundred person-days: the noise the population card's own four-week gate
   exists to keep off the screen. Below the floor the section is silent, as
   that card is below its gate; Month, Quarter and Year are unchanged.

Nothing is added, ranked or recomputed; the Week range shows one fewer
block. Tier 1 pins the floor (`weekendComparisonGate`).

---

## Amendment (2026-09-10) — the comparison leaves this card

**Status:** accepted, by ADR-0038's 2026-09-10 amendment. The figures, the
sources, the tables and the refusals above are unchanged. What changes is
which card the second table sits in.

Trends now groups its three published comparisons under a `COMPARISONS`
heading that names each one with the title its Settings switch carries. The
weekend split is one of the three, so it moved into its own
`WeekendComparisonCard` under that heading, and this card kept only the seven
weekday rows.

**The rows had to stay outside the heading**, and that is the whole reason
for the move. They are the reader's own log, gated by nothing — ADR-0038 says
so explicitly — so a heading reading *Comparisons* over them would misdescribe
them. Worse, it would undo this record's own refusal: the Decision above
declines to name a busiest day or relate one weekday to another, and the
amendment below it explains that the aligned numeric columns exist because
*alignment does the comparing the copy refuses to do*. The word "Comparisons"
printed over seven weekday figures is that comparison made in the app's voice,
which is the rank this card has never drawn.

**What the move costs, named rather than hidden:** the split no longer sits
directly beneath the seven rows it is folded from, and with both population
comparisons shown it can be two cards below them. It never referenced those
rows' figures and states its own denominators in every form, so no meaning is
lost — but the adjacency was real and is gone.

**Two things carried across deliberately.**

1. **"Days with a drink" stays visible above the comparison table.** It headed
   the block before the move and it is still load-bearing: without it the
   table reads "6 of 13" and "31 of every 100" under heads saying only YOUR
   LOG and US ADULTS, and nothing says what is counted — the weekday table's
   own column head of that name is in another card now. It is demoted from a
   section label to a `.caption` line under the card's title, shown only in
   the table form (the stacked sentences and the table's spoken label say
   "days with a drink" themselves), and hidden from VoiceOver for the same
   reason. Same key; it is still the weekday table's third column head.
2. **Every measured constant moved byte-identical**, into a shared
   `ComparisonTable` so there is one copy rather than two to re-measure:
   `columnHead`, `emptyHeadCell`, `ratioCell` and the `>= .xLarge` fold
   threshold, which both cards now read so they still fold together.
   `@ScaledMetric figureColumn` (88) stays with the weekday table alone —
   the comparison table's columns are content-sized on purpose, because a
   fixed 74/100 left the label column 113pt on a 375pt screen where "Monday
   to Thursday" needs 125.

**The card's title changed case**, from `BY WEEKDAY` to "By weekday", as a
consequence of the split rather than a decision of its own:
`GlassTokens.Typography.sectionLabel`'s uppercase-tracked form is documented
for "a card that holds more than one table", and this card no longer holds
two. The shared `CardTitle` gives all four titled cards on Trends the same
sentence-case treatment, one step below the uppercase section heading above
them.

### Consequences

- `WeekdayCard` holds no switch of any kind — `showsComparison` is gone — so
  nothing in it can be gated by accident. ADR-0038's "the rows never depend on
  it" is now structure rather than a comment.
- The four-week floor is unchanged and still lives in
  `WeekendSplit.isComparable`; it is now checked in `ComparisonsSection`
  alongside the other two gates, so the heading and the card appear and
  disappear together. Tier 1 still pins it (`weekendComparisonGate`).
- No figure, source, threshold or string changes. No schema change, no
  CloudKit step.

### How to reopen

If the adjacency turns out to matter — a reader looking for their weekend
split under the seven rows and not finding it — the reopen is to put a second
copy of the split back under the rows, which this record refuses on the same
grounds it refuses a chart: two printings of one figure invite the reader to
compare them. The likelier fix is order: the weekend card is the last of the
three and could be the first, directly under the heading and so closest to the
rows above it.
