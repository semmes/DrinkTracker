# Trends on one window: plan

Written 2026-10-01 against `main` at 31cbd25 (PR #159), in a remote session with no
Swift toolchain. Everything here was read from the code and the records. Nothing was
compiled or rendered. The figures quoted from the owner's two screenshots (Trends at
Quarter, dark, taken on Wednesday 30 September 2026) were checked against the code that
drew them; the survey brackets and the week-pattern numbers were computed with a short
script that reimplements the bracket rule and the range rules, and they are labelled as
computed.

**Status:** not started. Four decisions below are the owner's. Phase 1 can start once
they are answered. **Revised the same day** after the owner asked for options that keep
the data on screen: decisions 1 and 2 now recommend figures over sentences, and the
first draft's recommendations are kept beside them as the alternatives.

**The ask (owner, 2026-10-01):** "I want to standardize the data with the timeframe
measurements. You'll see comparisons only show 28 days not aligned to the quarter. Then
days with a drink is 13 weeks and not aligned to quarterly. All data under trends should
align to weekly, monthly, quarterly, yearly and provide insights and data against those."

---

## What the screen does today

Every figure under the range picker, the days it covers, and whether it follows the
picker:

| Figure | Days it covers | Follows the picker |
|---|---|---|
| Chart, header total, "N days with drinks" | the range | yes |
| The dashed line | Week and Month: the range, per day. Quarter and Year: completed weeks or months only | yes, less the partial bar |
| Total, per day on average, days with no drinks logged, longest run | the range | yes |
| By weekday | the range | yes |
| **Weekly average** (Comparisons) | the last 28 days, or the last 364 once the first record is a year old, **whatever the picker says** | **no** |
| **Drinking days** (Comparisons) | the same 28 or 364 days | **no** |
| Days with a drink (Comparisons) | the range; hidden below 28 days, so never at Week | yes |
| From Apple Health | the range | yes |

### Findings

1. **Two of the three comparisons ignore the picker, by design.** ADR-0030 made the
   population window follow the age of the record, not the range: 28 days, then 364 once
   the record is a year old, because the survey's column is a twelve-month average and a
   four-week figure swings with one heavy week. `ComparisonsSection` runs its own two
   queries and its own `Date()` clock to cut that window, separate from the chart's.
   ADR-0038's 2026-09-23 amendment saw the result ("the two segments do cover different
   days; the headers say so") and accepted it. On the screenshot, at Quarter, the card
   reads 12.5 a week and 13 of 28 days, under a chart reading 158.9 over 88 days with 46
   days with drinks.

2. **Days with a drink already follows the picker.** "Last 13 weeks" is how the Quarter
   range is labelled everywhere: the chart card's own title on the first screenshot says
   the same. Its counts agree with the chart: 28 + 18 = 46 days with drinks, 37 + 51 = 88
   days, the header's "46 days with drinks" and the card's "42 of 88". So "13 weeks, not
   quarterly" is a question about what the Quarter range is called, not about this
   segment. Decision 4 covers it.

3. **Aligning the windows alone would still leave two weekly averages at Quarter.** The
   dashed line at Quarter is the mean of the 12 *completed* weeks (`bucketAverage`, 13.2
   on the screenshot). The range's own weekly figure is its total over its days:
   158.9 ÷ 88 × 7 = 12.6, which is also the "1.8 per day on average" card times seven.
   An aligned comparison would print 12.6 under a legend saying 13.2. Decision 3 covers
   it.

4. **The weekend comparison counts days before the first record as days without a
   drink.** Its only gate is the range's length (`WeekendSplit.isComparable`, 28 days,
   ADR-0038), never the record. At Year, a log started six weeks ago is spread over 335 to
   365 days, most of which nobody recorded, and set beside the published rates. At Month,
   a log with nothing in it yet already shows its own zeros beside "31 of every 100". The
   two population segments do not have this problem today, because their window waits
   for the record. The fix below closes it.

5. **The range's labels have four homes.** `TrendsView.chartTitle`,
   `TrendsView.sumLabel`, `PopulationReferenceCopy.rangeTitle` and `HealthPairingCopy`
   each switch over the range. They agree today; the build makes the comparisons read
   `rangeTitle` and nothing else.

---

## The approach: three rules

**1. One set of days.** Every figure under the picker reads the range's own day walk,
the comparisons through the window rule 2 cuts from it, which is the whole range once
the log is old enough. `TrendsView` already folds the range once for the chart header
(`TrendSummary.rangeDays`, then `summary(of:)`), and the comparisons stop running their
own queries and clock and read that fold:

- **Weekly average** is the range total over the range's weeks, total ÷ (days ÷ 7). That
  is `PopulationReference.weeklyAverage(of:)`, the function the year view already uses
  for a complete year.
- **Drinking days** is the header's own "days with drinks" out of the range's days,
  beside the NESARC-III mean scaled to the same number of days.
- **Days with a drink** is unchanged: it already folds the range's weekday rows.

So the comparisons' figures are the header's figures, not recomputed copies, and they
cannot drift from it. ADR-0030's rule that the volume line and the day count cover one
set of days holds by construction.

**2. One floor for the published figures, and one clip.** The three comparisons appear
once the log holds 28 days of record, ADR-0018's floor kept and day-keyed (the reopen
ADR-0030's 2026-09-07 amendment named): the first entry or no-alcohol record is 27 or
more days before today. That one gate replaces ADR-0030's year of record and ADR-0038's
four weeks of range, at every range including Week (decision 1). While the log is
younger than the range, the comparisons cover the days from the first record to today
and say so (decision 2): the segment's span reads "Since Aug 12" instead of the range's
title, every denominator is that window's day count, and the published figures scale to
it. Once the log reaches back to the range's first day the clip is the range, and the
span is the range's own title. That closes finding 4 without hiding anything: a day
before the first record is never counted as a day without a drink.

**3. One weekly average.** At Quarter the dashed line becomes the range's weekly figure
(decision 3), so the legend, seven times the per-day card, and the comparison print one
number.

### What each range would show

Day counts are the ranges' own (`TrendRange.startDate`); the Quarter column uses the
screenshot's log, and the Week column a week holding 3 drinking days and 13.2 drinks,
since the screenshots do not show the week.

| | Week | Month | Quarter | Year |
|---|---|---|---|---|
| Days in the range | 7 | 30 | 85 to 91 (88 on 30 Sep) | 335 to 366 |
| Comparisons, after 28 days of record | shown | shown | shown | shown |
| Weekly average | the week's total: 13.2 | total ÷ 30 × 7 | **12.6** (was 12.5 over 28 days) | total ÷ days × 7 |
| Drinking days | 3 of 7 · about 2 in 7 | N of 30 · about 7 in 30 | **46 of 88 · about 21 in 88** (was 13 of 28 · about 7 in 28) | N of 335 · about 81 in 335, on 1 Oct |
| Days with a drink | 2 of 3 · 1 of 4, beside 31 and 24 of every 100 | as today | as today: 28 of 37 · 18 of 51 | as today |
| Every segment's span label | Last 7 days | Last 30 days | Last 13 weeks | Last 12 months |
| While the log is younger than the range | never: the floor is longer than the week | Since Aug 12, on days 28 and 29 of record only | Since Aug 12, until the log is 13 weeks old | Since Aug 12, until the log is 12 months old |
| The dashed line | per day, as today | per day, as today | **12.6 a week** (was 13.2) | per completed month, as today |

At Quarter the survey sentence stays "That's lower than roughly 15% of US men who
drink.": 12.5 and 12.6 a week fall in the same row of the table (computed).

### What the windows carry

- **The survey's own span is twelve months.** ARG's column is drinks "per week on average
  in the previous 12 months" (ADR-0030). Year matches it. Quarter is a closer fit than
  today's 28 days, and Month about the same as today. A single week set beside a
  distribution of twelve-month averages says where that week fell among other people's
  averages, and a reader's weeks spread wider than their own average does, so Week's
  sentence moves more than the others. The weekend rate is per 100 person-days; a week
  holds three weekend days.
- **A 7-day window holds exactly one of each weekday**, so for someone who drinks the same
  every Friday and Saturday, 13.2 a week, the Week figure reads 13.2 on every day of the
  year. It moves only when the drinking does. A week with 20 drinks reads "lower than
  roughly 10% of US men who drink" and one with 2 reads "lower than roughly 50%"
  (computed from the bundled table).
- **Windows that are not whole weeks move with the week's pattern.** A 30-day window
  holds four or five of each weekday, so for the same log the Month weekly figure moves
  between 12.3 and 15.4 as the window gains or loses a fifth Friday or Saturday. Today's
  28-day window always holds exactly four, so it never does this. Quarter moves between
  12.5 and 13.2, and Year between 13.0 and 13.4 (all computed over every day of 2026).
  The Month chart's own line and per-day card already move this way, so this is not new
  to the screen, only to the comparison. The survey's rows are wide enough that the
  sentence rarely changes (12.3 to 15.4 all read "15% of US men"), but a reader at a
  row's edge can see it flip between two neighbouring percentages within a week. The
  alternative, whole-week windows inside each range, puts "Last 28 days" back under
  "Last 30 days", which is the mismatch this plan removes.

---

## Decisions this plan needs

**1. Week.** *Recommended (revised):* all three comparisons over the 7 days, worded as
the week's own facts, behind the same 28-day record floor as every other range. The
weekly-average segment prints the week's total ("13.2 standard drinks, last 7 days"; the
total of a week is the weekly figure, nothing is scaled) and the survey sentence as it
stands; drinking days "3 of 7 · about 2 in 7"; the weekend split's three and four days
beside the published rates. Trends opens on Week, so this is the comparison a reader
meets first on every visit.
- Cost: it reverses ADR-0038's four-week floor on the weekend comparison; ADR-0018's
  floor, four weeks of record, stands. The sentence at Week moves with the
  week: a quiet week reads "lower than roughly 50% of US men who drink" and a heavy one
  "lower than roughly 10%", where Month's moves between neighbouring rows at most. The
  span label says which week it is, and the sentence's words do not change.
- *Alternative 1b, steadier:* at Week the weekly-average segment keeps the week's total
  and swaps the moving percentile for a fixed published figure read off the same table:
  "At least half of US men who drink average 3 or fewer a week" (2 for all adults and
  for women; the first row of each column at or past 50%, computed from the bundled
  file). A derived figure the app does not show today, so it costs an ADR-0018 amendment,
  a copy review row and a contract vector of its own, and it gives Week a different shape
  from the other three ranges.
- *Alternative 1c, the first draft:* no comparisons at Week and one sentence saying they
  start at Month. The least data, and the one a reader meets on every launch.

**2. A log younger than the range.** *Recommended (revised):* compute over the days from
the first record to today, and say so. The span label reads "Since Aug 12" (a new key,
"Since %@", the date as text) in place of the range's title, every denominator is that
window's day count, and the published figures scale to it: "You logged drinks on 46 of
the last 51 days." and "US adults who drink average about 12 in 51." are the existing
reviewed sentences, true as written, because the days from the first record to today
are the last 51 days. The weekly average is the window's total over its weeks (51 ÷ 7).
Once the log reaches back to the range's first day, nothing is clipped and the label is
the range's. Appears from day 28 of record at every range, as today.
- Cost: while the log is younger than 13 weeks, Quarter and Year show the same figures
  under different chart titles, and the comparisons' day count differs from the chart
  header's (51 against 88). The span label is what makes that a statement rather than a
  mismatch, so it has to be read; at the accessibility sizes it sits under the title.
- *Alternative 2b, the first draft:* one sentence until the log covers the range
  ("Comparisons appear here once your log covers the last 13 weeks."). Nothing to
  misread, and nothing to read: at Year, a year of waiting.

**3. The line at Quarter.** *Recommended (confirmed):* the range's weekly figure (12.6
on the screenshot), the same number as the comparison and seven times the per-day card.
- Cost: during a week the line dips a little for a weekend-heavy log (12.5 to 13.2 for
  the steady 13.2 above), where the completed-week mean holds still. The README's "never
  sags just because a new week started" becomes true of Year only. The contract's line
  rule changes, so Android follows.
- *Alternative 3b:* keep the completed-weeks line (13.2) and name both numbers, the
  legend as "Your average, full weeks · 13.2" and the comparison as the range's 12.6.
  Two weekly averages on one screen, each labelled. It keeps the line still and changes
  nothing on the chart or in the contract, and it leaves the question "which is my
  average?" on the screen.
- *Alternative 3c, rejected:* make the comparisons cover the completed weeks too. Then
  the card's day counts are 84 where the header above says 88, which is the mismatch
  this plan exists to remove.
- Year's line (per completed month) is left alone under all three. No figure on the
  screen restates it, and ADR-0029's year-in-review card is defined by it.

**4. What Quarter is called.** *Recommended (confirmed):* keep "Last 13 weeks". It is exactly what
Quarter covers, 12 full calendar weeks and this one so far, and the chart has always said
it. *Alternatives:* "Last 3 months" is not true of 13 weekly bars. Calendar quarters
("This quarter", July to September) start nearly empty: on 1 October a quarter is one
day, under the floor for its first month, and the 2026-09-26 change moved the labels
toward naming the exact days, not away from it.

**And the train.** 1.4 (1) is in App Review (the lookup API reads 1.3 live today), and
this is a product change, so it belongs on 1.5: its first PR bumps `MARKETING_VERSION`,
as 1.3 and 1.4 were opened, unless you would rather hold the bump until 1.4 is approved so
that a rejection can still be answered from `main` as 1.4.

---

## Build

A product decision and an enhancement (PRD §3): an ADR, tier-1 tests for the arithmetic,
tier-3 renders with numbers, the README, and the old behaviour's tests updated in the
same commit, never deleted quietly.

### Phase 1: the core package (tier 1)

- A new file in `DrinkTrackerCore` in place of `PopulationWindow.swift`: the shared floor
  (28 days, the value `WeekendReference.minimumDays` and `minimumHistory` hold today,
  now a count of day keys) and `comparisonWindow(range:endingOn:firstRecord:calendar:)`,
  answering nil while the record is under the floor, else the day keys from the later of
  the range's first day and the first record's day through today, with whether it was
  clipped. The weekly figure over a fold moves to `TrendSummary`, so the line and the
  comparisons call one function. `PopulationReference.weeklyAverage(of:)` stays as the
  year view's name for it.
- Retired with their tests rewritten: `PopulationReference.Window`,
  `window(firstRecord:now:)`, `weeklyAverage(_:window:endingAt:region:calendar:)`,
  `minimumHistory`, `FrequencyReference.drinkingDays(in:last:endingOn:calendar:)`,
  `WeekendSplit.isComparable` and `WeekendReference.minimumDays`.
- New tests:
  - the floor on both sides of day 28 of record, with no record, and in Santiago on a
    midnight-DST range start;
  - the clip: a log younger than the range covers the first record's day through today
    at every range, Quarter and Year agreeing while the log is under 13 weeks, and a log
    old enough covers the range exactly;
  - agreement over a seeded log at every range: the weekly figure × days ÷ 7 is the
    header total, drinking days are the header's days with drinks, which are the weekday
    rows' sum and the weekend split's sum, and every denominator is the window's day count;
  - at Quarter, the line equals the comparison's weekly figure;
  - a drink at the window's far edge counts in every figure or in none, and a day before
    the first record is in no denominator.

### Phase 2: Trends

- `TrendsView`'s snapshot gains the first record. Its entry query is `.reverse`, so the
  first entry is `allEntries.last`; the first marker is `alcoholFreeDays.first`. It
  derives the comparison window once, folds it with the same `summary(of:)` and
  `weekdayTotals` the header uses (over the clipped keys when the log is young, which is
  the range's own fold otherwise), and passes that fold, the weekday rows, the range and
  the window to `ComparisonsSection`.
- `ComparisonsSection` drops its two `@Query`s and its `Date()`. That also removes a
  second projection of the whole log on every body pass. It draws nothing while the
  window is nil, as it does with every switch off; the heading still cannot outlive its
  content.
- `WeeklyAverageComparison` and `DrinkingDaysComparison` take the fold and the window.
  Every segment's span is `rangeTitle(range)`, or "Since Aug 12" while the window is
  clipped, from one function all three segments read.
- `averageLineValue` at Quarter reads the shared weekly figure (decision 3).

### Phase 3: copy

New keys, drafts for the 1.4.3 review (no em dashes, no imperative):

| Where | Draft |
|---|---|
| The weekly-average segment's spoken and folded sentence at Week, where "Your average is about…" is untrue of one week; one key per region and number | "You logged 13.2 standard drinks in the last 7 days." |
| The clipped span (decision 2) | "Since Aug 12" ("Since %@", the date as text) |
| No drinks in the window | "No drinks in the last 7 days." / "…30 days." / "…13 weeks." ("…12 months." exists); while clipped, "No drinks since Aug 12." |
| Weekly average note | "This figure covers your last 7 days. The survey asked about a year." / "Your average covers your last 30 days. The survey asked about a year." / the same for 13 weeks ("…your last 12 months, the span the survey asked about." exists); while clipped, "Your average covers the days since Aug 12." |

Out: "No drinks in the last 4 weeks." and "Your average covers your last 4 weeks." The span
labels, the drinking-days sentences (true of a clipped window, which is the last N days)
and the weekend sentences are existing keys. A remote session cannot run
`xcstringstool`, so keys changed here are changed by hand in the catalog's own byte shape
and re-synced by the next local build (PR #88 removed one key that way).

### Phase 4: records

- A new ADR, the next free number (0058 if nothing lands first): Trends compares the
  range the reader chose. It amends ADR-0018 (its floor kept, now the record's at every
  range), ADR-0030 (whose own reopen
  clause names this route: a window "as a *choice*, one window shown at a time, on
  ADR-0026's model"), ADR-0031, ADR-0032 and ADR-0038 (the shared gate), and ADR-0028
  (the Quarter line).
- `docs/design-system.md` (the Comparisons section row and its sentence state),
  `docs/copy-review-1.4.3.md`, the README's "The population reference" and its sentence
  about the line, and `CLAUDE.md`.
- The 1.5 What's New and reviewer notes. 1.3's notes told App Review the window "follows
  the length of the user's record", so 1.5's should say it follows the range the reader
  picks.

### Phase 5: the contract

A draft PR in `semmes/tallyist-product`:
- `domain/aggregation.md`: the population card row and the Quarter line row of "Your
  average", the two measures and "Population reference gating";
- the copy deck's `reference.*` keys;
- `vectors/insights.json` with `tools/verify_vectors.py`, and the CHANGELOG.

It also corrects drift that predates this plan: the contract still describes the
population windows as instant-based, which iOS stopped on 2026-09-07 (ADR-0030's
amendment raised it and left it). Android follows. By `VERSIONING.md`'s own words a
behaviour change both platforms must make is MAJOR, although 1.7.0, the change this one
reverses, went out as a minor, so the number is yours.

### Verification

- **CI** is the compile and test gate in a remote session: the domain tests (tier 1), the
  two simulator builds and the integration tests. No test tier reaches the Trends views
  (app target, no `TEST_HOST`), so for the views CI proves compilation only.
- **Tier 3**, in a local session with a simulator:
  - Trends at all four ranges over a seeded log of more than a year, light and dark, at
    the default size and at `accessibility-extra-large`;
  - a log of 40 days: the segments at Week and Month over the range, and at Quarter and
    Year over "Since <date>" with the same figures on both;
  - a log of 20 days: no section at any range;
  - Week's three segments over a quiet week and a heavy one;
  - the Quarter legend and the comparison printing one number.
- **Tier 4**, the owner: your own log at each range against the screenshots above.

### What does not change

- The year view's comparison, which covers a complete calendar year.
- The share cards.
- The Settings switches and "Compare with".
- The From Apple Health section, which already follows the range with its own floors.
- The By weekday rows.
- The schema, CloudKit, the privacy policy and the network: none of them are touched.
- The rules: still no rank, no delta, and nothing chosen by what the figures say
  (ADR-0038). That is also the line on "insights": the copy review keeps the word off
  Trends because each would characterise a bar. What this plan gives each range is its
  own figures and the published figures beside them.

## What I could not verify

Nothing was compiled or rendered. The screenshot's figures were checked by arithmetic
against the code paths that drew them. The survey brackets come from the bundled JSON
with the bracket rule reimplemented in Python. The week-pattern figures come from a
simulation of `TrendRange.startDate` with a Sunday-first week, which is what the
screenshot's 88 days and 37 weekend days imply for the owner's phone.
The copy is a draft until the 1.4.3 review. The work is one PR here (core, Trends, copy
and records) and one draft PR in the contract; the renders want a local session.
