# Trends on one window: plan

Written 2026-10-01 against `main` at 31cbd25 (PR #159), in a remote session with no
Swift toolchain. Everything here was read from the code and the records. Nothing was
compiled or rendered. The figures quoted from the owner's two screenshots (Trends at
Quarter, dark, taken on Wednesday 30 September 2026) were checked against the code that
drew them; the survey brackets and the week-pattern numbers were computed with a short
script that reimplements the bracket rule and the range rules, and they are labelled as
computed.

**Status:** not started. Four decisions below are the owner's. Phase 1 can start once
they are answered.

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

**1. One set of days.** Every figure under the picker reads the range's own day walk.
`TrendsView` already folds the range once for the chart header
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

**2. One floor for the published figures.** The three comparisons appear when the range
holds at least 28 days (Month, Quarter and Year) **and** the log covers the whole range:
the first entry or no-alcohol record is on or before the range's first day. Otherwise the
card holds one sentence saying why (decisions 1 and 2). This one gate replaces three:
ADR-0018's four weeks of record, ADR-0030's year of record and ADR-0038's four weeks of
range. It also closes finding 4. It is day-keyed, the reopen ADR-0030's 2026-09-07
amendment named.

**3. One weekly average.** At Quarter the dashed line becomes the range's weekly figure
(decision 3), so the legend, seven times the per-day card, and the comparison print one
number.

### What each range would show

Day counts are the ranges' own (`TrendRange.startDate`); the Quarter column uses the
screenshot's log.

| | Week | Month | Quarter | Year |
|---|---|---|---|---|
| Days in the range | 7 | 30 | 85 to 91 (88 on 30 Sep) | 335 to 366 |
| Comparisons | one sentence | shown | shown | shown |
| Weekly average | | total ÷ 30 × 7 | **12.6** (was 12.5 over 28 days) | total ÷ days × 7 |
| Drinking days | | N of 30 · about 7 in 30 | **46 of 88 · about 21 in 88** (was 13 of 28 · about 7 in 28) | N of 335 · about 81 in 335, on 1 Oct |
| Days with a drink | | as today | as today: 28 of 37 · 18 of 51 | as today |
| Every segment's span label | | Last 30 days | Last 13 weeks | Last 12 months |
| The dashed line | per day, as today | per day, as today | **12.6 a week** (was 13.2) | per completed month, as today |

At Quarter the survey sentence stays "That's lower than roughly 15% of US men who
drink.": 12.5 and 12.6 a week fall in the same row of the table (computed).

### The limits the floor exists for

- **The survey's own span is twelve months.** ARG's column is drinks "per week on average
  in the previous 12 months" (ADR-0030). Year matches it. Quarter is a closer fit than
  today's 28 days, and Month about the same as today. A single week set beside a
  distribution of twelve-month averages mostly says where that week fell, and it pushes a
  reader toward either end of the table. That is why Week gets a sentence rather than a
  percentile. The weekend rate is per 100 person-days; a week holds three weekend days.
- **Windows that are not whole weeks move with the week's pattern.** A 30-day window
  holds four or five of each weekday. For someone who drinks the same every Friday and
  Saturday, 13.2 a week, the Month weekly figure moves between 12.3 and 15.4 as the
  window gains or loses a fifth Friday or Saturday. Today's 28-day window always holds
  exactly four, so it never does this. Quarter moves between 12.5 and 13.2, and Year
  between 13.0 and 13.4 (all computed over every day of 2026). The Month chart's own line
  and per-day card already move this way, so this is not new to the screen, only to the
  comparison. The survey's rows are wide enough that the sentence rarely changes (12.3 to
  15.4 all read "15% of US men"), but a reader at a row's edge can see it flip between
  two neighbouring percentages within a week. The alternative, whole-week windows inside
  each range, puts "Last 28 days" back under "Last 30 days", which is the mismatch this
  plan removes.

---

## Decisions this plan needs

**1. Week.** *Recommended:* no comparisons at Week. The card holds one sentence:
"Comparisons appear at Month, Quarter and Year. A week is too short to compare with these
surveys." (draft; 1.4.3 review). *Alternative:* compute all three over the 7 days.
- Cost of the recommendation: Trends starts on Week each time the app launches, so the
  comparisons are one tap away on every visit, where today the weekly average and drinking
  days show at Week. You asked for the Health offer not to wait for Quarter for this
  reason (2026-09-22). If it bothers you here, the fix is Trends' starting range, a
  separate one-line decision, not a shorter comparison.
- Cost of the alternative: it reverses ADR-0018's floor and ADR-0038's. The weekly-average
  percentile would set one week against twelve-month averages, and three weekend days
  would sit beside a rate per hundred.

**2. A log younger than the range.** *Recommended:* until the log covers the range, the
card holds one sentence, for example "Comparisons appear here once your log covers the
last 13 weeks." (draft). *Alternative:* compute over the part of the range the log
covers, and label the span "Since 12 August".
- Cost of the recommendation: a new reader sees comparisons at Month after 30 days of
  record, at Quarter after about three months and at Year after about a year. Today they
  see a 28-day figure under every range from day 28.
- Cost of the alternative: a span label that is not the range's, the mismatch you asked
  to remove. Quarter and Year would also read identically until the log is three months
  old.

**3. The line at Quarter.** *Recommended:* the range's weekly figure (12.6 on the
screenshot), the same number as the comparison and seven times the per-day card.
*Alternative:* keep the mean of the completed weeks (13.2), and Quarter shows two
different weekly averages.
- Cost of the recommendation: during a week the line dips a little for a weekend-heavy
  log (12.5 to 13.2 for the steady 13.2 above), where the completed-week mean holds still.
  The README's "never sags just because a new week started" becomes true of Year only.
  The contract's line rule changes, so Android follows.
- Year's line (per completed month) is left alone. No figure on the screen restates it,
  and ADR-0029's year-in-review card is defined by it.

**4. What Quarter is called.** *Recommended:* keep "Last 13 weeks". It is exactly what
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
  (28 days, the value `WeekendReference.minimumDays` and `minimumHistory` hold today) and
  `comparisonAvailability(range:endingOn:firstRecord:calendar:)`, answering shown, range
  too short, or log too short. The weekly figure over a fold moves to `TrendSummary`, so
  the line and the comparisons call one function. `PopulationReference.weeklyAverage(of:)`
  stays as the year view's name for it.
- Retired with their tests rewritten: `PopulationReference.Window`,
  `window(firstRecord:now:)`, `weeklyAverage(_:window:endingAt:region:calendar:)`,
  `minimumHistory`, `FrequencyReference.drinkingDays(in:last:endingOn:calendar:)`,
  `WeekendSplit.isComparable` and `WeekendReference.minimumDays`.
- New tests:
  - the gate at each range on both sides of the log boundary, with no record, and in
    Santiago on a midnight-DST range start;
  - agreement over a seeded log at every range: the weekly figure × days ÷ 7 is the
    header total, drinking days are the header's days with drinks, which are the weekday
    rows' sum and the weekend split's sum, and every denominator is the range's day count;
  - at Quarter, the line equals the comparison's weekly figure;
  - a drink at the range's far edge counts in every figure or in none.

### Phase 2: Trends

- `TrendsView`'s snapshot gains the first record. Its entry query is `.reverse`, so the
  first entry is `allEntries.last`; the first marker is `alcoholFreeDays.first`. It passes
  the range's fold, the weekday rows, the range and the availability to
  `ComparisonsSection`.
- `ComparisonsSection` drops its two `@Query`s and its `Date()`. That also removes a
  second projection of the whole log on every body pass. The section draws the segments,
  or the one sentence when any switch is on and the gate is shut. With every switch off it
  still draws nothing; the heading still cannot outlive its content.
- `WeeklyAverageComparison` and `DrinkingDaysComparison` take the fold and the range.
  Every segment's span is `rangeTitle(range)`.
- `averageLineValue` at Quarter reads the shared weekly figure (decision 3).

### Phase 3: copy

New keys, drafts for the 1.4.3 review (no em dashes, no imperative):

| Where | Draft |
|---|---|
| Week (decision 1) | "Comparisons appear at Month, Quarter and Year. A week is too short to compare with these surveys." |
| Log too short (decision 2), one key per range | "Comparisons appear here once your log covers the last 30 days." / "…the last 13 weeks." / "…the last 12 months." |
| No drinks in the range | "No drinks in the last 30 days." / "No drinks in the last 13 weeks." ("…12 months." exists) |
| Weekly average note | "Your average covers your last 30 days. The survey asked about the last 12 months." / the same for 13 weeks ("…your last 12 months, the span the survey asked about." exists) |

Out: "No drinks in the last 4 weeks." and "Your average covers your last 4 weeks." The span
labels and the drinking-days sentences are existing keys. A remote session cannot run
`xcstringstool`, so keys changed here are changed by hand in the catalog's own byte shape
and re-synced by the next local build (PR #88 removed one key that way).

### Phase 4: records

- A new ADR, the next free number (0058 if nothing lands first): Trends compares the
  range the reader chose. It amends ADR-0018 (the floor), ADR-0030 (whose own reopen
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
  - a log younger than Quarter (the sentence at Quarter and Year, the segments at Month);
  - Week's sentence;
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
