# 0058 — Trends compares the range the reader chose

**Status:** accepted · **Date:** 2026-10-01 · **Source:**
`docs/tallyist-trends-alignment-plan.md` (draft PR semmes/DrinkTracker#160) ·
**Amends:** ADR-0018 (its floor kept, counted in days of record and applied at every
range), ADR-0030 (its window retired for Trends; the year view unchanged), ADR-0031
(the reader's count is the chart header's, over the range), ADR-0032 and ADR-0038
(the weekend comparison waits for the record, not for four weeks of range),
ADR-0028 (the dashed line at Quarter) · **Relates to:** ADR-0006 (a summary, not a
score), ADR-0026 (one fold, the DST-safe day walk), ADR-0033 (counted from the
record), ADR-0039 (the column), the contract's `domain/aggregation.md` · **Amended
by:** ADR-0059 (the line follows a grain the reader chooses at Quarter and Year; the
open question below is closed — the amendment at the end)

## Context

The owner, on two screenshots of Trends at Quarter (2026-10-01): *"I want to
standardize the data with the timeframe measurements. You'll see comparisons only show
28 days not aligned to the quarter. Then days with a drink is 13 weeks and not aligned
to quarterly. All data under trends should align to weekly, monthly, quarterly, yearly
and provide insights and data against those."*

Of everything under the range picker, two figures ignored it. The Weekly average and
Drinking days comparisons read ADR-0030's window — the trailing 28 days, then 364 once
the first record was a year old — through `ComparisonsSection`'s own two queries and
its own `Date()`, whatever the picker said. ADR-0038's 2026-09-23 amendment saw the
result ("the two segments do cover different days; the headers say so") and accepted
it. On the screenshot the card read 12.5 a week and 13 of 28 days under a chart
reading 158.9 over 88 days with 46 days with drinks. Days with a drink already
followed the picker: "Last 13 weeks" is the Quarter range's own name, and its 28 + 18
and 37 + 51 were the chart's 46 days with drinks over its 88.

The plan found three more things the alignment had to settle:

- **Aligning the windows alone left two weekly averages at Quarter.** The dashed line
  at Quarter was the mean of the twelve *completed* weeks (`bucketAverage`, 13.2 on
  the screenshot), and the range's own weekly figure is its total over its weeks,
  158.9 ÷ 88 × 7 = 12.6, seven times the per-day average (the card printed 1.8). An aligned
  comparison would have printed 12.6 under a legend saying 13.2.
- **The weekend comparison counted days before the first record as days without a
  drink.** Its only gate was the range's length (ADR-0038's four weeks of range),
  never the record, so a log six weeks old was spread over Year's 335 to 366 days
  and set beside the published rates, and at Month an empty log's zeros sat beside
  "31 of every 100".
- **The range's labels had four homes** (`TrendsView.chartTitle` and `sumLabel`,
  `PopulationReferenceCopy.rangeTitle`, `HealthPairingCopy`); they agreed, and the
  comparisons now read one of them.

**The options, each costed in the plan and drawn as a mockup over one sample log
before the owner chose.** For Week: all three comparisons over its 7 days (chosen);
the week's total with a fixed published figure in place of the moving percentile
("at least half of US men who drink average 3 or fewer a week"), steadier but a new
derived figure and a different shape from the other ranges; or no comparisons at Week
and a sentence saying they start at Month, the first draft, the least data on the
screen every reader meets first. For a log younger than the range: clip to the days
since the first record and say so (chosen); or one sentence until the log covers the
range, which at Year is a year of waiting. For the Quarter line: the range's weekly
figure (chosen); the completed-weeks line kept and both numbers labelled, which keeps
the line still and leaves "which is my average?" on the screen; or the comparisons
over the completed weeks too, which puts 84 days under a header saying 88, the
mismatch itself. For Quarter's name: "Last 13 weeks" (chosen), because "Last 3 months"
is untrue of thirteen weekly bars and a calendar quarter is one day long on 1 October.
And a fifth the mockups raised: with the clip on the comparisons alone, a log 51 days
old at Quarter read "Your weekly average · 6.4" on the chart (88 days, 37 of them
before the first record) over a comparison reading 11 a week — two weekly averages
again, for as long as the log is younger than the range.

## Decision

**The owner decided all five on 2026-10-01, each as recommended** ("Go with your
recommendations on the second").

**One set of days.** Every figure under the picker whose denominator is a count of
days reads the range's own days, cut at the first record's day while the log is
younger than the range — the *window*. Under it: the dashed line, the per-day card,
"Days with no drinks logged" (both counts), the By weekday rows, and all three
comparisons. The comparisons stop running their own queries and clock and read the
fold `TrendsView` already makes for the chart card, so their figures are the header's
figures: the weekly average is the window's total over its weeks, the drinking days
are the header's own days with drinks out of the window's days, and days with a drink
fold the window's weekday rows. ADR-0030's rule that the volume line and the day count
cover one set of days now holds for every figure on the screen, by construction.

**The bars keep the range.** The picker's promise is the span of the x axis, so a
week before the first record draws as it always has, with nothing in it, and a bar's
readout still reports that bar's own days. The header's total, its days with drinks
and the longest run are counts no day before the first record can change, and the
Health rows count nights with a record; none of them moves.

**A young log says so.** While the window is clipped the total card's label reads
"since Aug 12" in place of the range's words, every comparison's span reads "Since Aug
12", and every printed "of N" is the window's N, so the clip is visible wherever a
denominator is. The date is the window's first day, month and day, from one function
(`TrendWindow.sinceText`). Once the log reaches back to the range's first day nothing
is clipped and no label changes — every reader whose log is older than a year.

**One floor for the published figures.** The three comparisons appear once the log
holds 28 days of record: the first entry or no-alcohol record falls 27 or more days
before today, counted in day keys. That is ADR-0018's four weeks, kept, and day-keyed
for the first time (the reopen ADR-0030's 2026-09-07 amendment named). It replaces
ADR-0030's year of record and ADR-0038's four weeks of range, at every range, Week
included. A gate on how much has been recorded says nothing about what was recorded,
which is ADR-0038's line.

**Week shows all three, as the week's own facts.** Seven days hold one of each
weekday, so their total is the weekly figure and nothing is scaled. The weekly-average
segment prints that total ("13.2 standard drinks a week", the existing figure key,
because the plan's copy table names no new one and the rate it states is true of the
week) over the survey sentence as it stands; its folded and spoken sentence is "You
logged 13.2 standard drinks in the last 7 days.", because "Your average is about…" is
untrue of one week; its note says "This figure is compared on this device…" where the
other ranges say "Your average is compared…", and "This figure covers your last 7
days. The survey asked about a year." The drinking days read "3 of 7" beside "average
about 2 in 7", and the weekend split its three and four days beside the published
rates.

**One weekly average.** At Quarter the dashed line is the window's weekly figure: the
legend and the weekly-average comparison print one number, which is seven times the
per-day average before either is rounded. (The per-day card prints that average to one
decimal, so seven times the printed card can differ from the legend by the rounding:
101.8 over 88 days prints 1.2 a day and 8.1 a week.) Year's line stays the mean of its complete months, over the complete months
inside the window while it is clipped; no figure on the screen restates it, and
ADR-0029's year-in-review card is defined by it.

**Quarter stays "Last 13 weeks".**

**Nothing else moves.** The year view's comparison still covers a complete calendar
year (`PopulationReference.weeklyAverage(of:)`, now the year view's name for the same
function the line and the comparison call). The share cards, the Settings switches and
"Compare with", the From Apple Health section, the schema, CloudKit, the privacy policy
and the network are untouched. The rules are unchanged: no rank, no delta, nothing
chosen by what the figures say. That is also the line on "insights": what each range
gets is its own figures and the published figures beside them.

**Mechanics.** `TrendWindow.swift` in the core package replaces
`PopulationWindow.swift`: `TrendWindow` (the range, its day keys, whether it is
clipped, whether the record clears the floor), `TrendSummary.trendWindow` and
`comparisonWindow` (nil under the floor), `TrendWindowFold` (the window's classified
days, its `summary(of:)`, its weekday rows, `dailyAverage`, `daysWithoutDrinks`,
`weeklyFigure` and `averageLine`), and `TrendSummary.weeklyFigure(of:)`.
`weekdayTotals(of:)` folds any classified days; the range form delegates to it. Retired,
their tests rewritten rather than deleted: `PopulationReference.Window`,
`window(firstRecord:now:)`, `weeklyAverage(_:window:endingAt:region:calendar:)`,
`minimumHistory`, `FrequencyReference.drinkingDays(in:last:endingOn:calendar:)`,
`WeekendSplit.isComparable` and `WeekendReference.minimumDays`.

**Readings taken where the plan was silent**, each the only one consistent with its
rules:

- An empty log, or one whose only rows are dated after today, clips nothing. There is
  no first day inside the range to cut it at and no date for a "Since" label; the
  figures read the range as they always have ("7 of 7" days with no drinks logged on a
  new install), and the comparisons stay under the floor.
- A first record on the range's own first day clips nothing: the log reaches it.
- The drinking days need only their own bundled file. They used to require the
  survey's file too, a quirk of the population window they shared; the window they
  share now is the range.
- The first record is the older of the newest-first entry query's last row and the
  marker query's first row. Health imports are entries and Health's zero-day markers
  are markers, so both count as records, as they did for ADR-0018's gate.
- A no-alcohol marker's day is the start-of-day instant of the zone it was written in
  (`AlcoholFreeDay.day`), and the window reads it in the current zone, as every other
  surface does. A marker written in a zone east of the reader, read there, falls on
  the day before: the window then starts a day early, the "Since" label names that day,
  and the floor clears a day early. This is the "alcohol-free markers stored as
  instants" limit the 1.2 review recorded, not repaired here; the old gate compared
  the same instant.
- The opened note at Week says "This figure is compared…" (one key per survey column,
  the derivation sentence ADR-0018 quotes unchanged). The plan's copy table did not
  list it; decision 1's "worded as the week's own facts" covers it, and the review
  below found the omission.

## Consequences

- **Both population comparisons change on the day this ships, for every reader past
  the floor.** The window ADR-0030 put on every range, 28 days or 364 once the log was
  a year old, becomes the range's own. On the screenshot's log, younger than a year,
  Quarter's 12.5 over 28 days becomes 12.6 over 88, "13 of 28 · about 7 in 28" becomes
  "46 of 88 · about 21 in 88", and the survey sentence stays "lower than roughly 15% of
  US men who drink" because 12.5 and 12.6 fall in one row (computed in the plan). For a
  log under a year old, Year now matches the survey's twelve-month span, Quarter is a
  closer fit than the old 28 days, and Month is about the same. For a log older than a
  year, whose comparisons covered 364 days at every range, Year still matches and the
  shorter ranges now cover less of the survey's span. Days with a drink already followed
  the range, so at Month, Quarter and Year it is unchanged; it now appears at Week as
  well (below).
- **Week's sentence moves with the week.** A single week set beside a distribution of
  twelve-month averages says where that week fell among other people's averages, and
  a reader's weeks spread wider than their average does: a quiet week reads "lower
  than roughly 50% of US men who drink" and a heavy one "lower than roughly 10%"
  (computed in the plan from the bundled table). The words do not change and the span
  says which week. Trends opens on Week, so this is the comparison a reader meets
  first.
- **Windows that are not whole weeks move with the week's pattern.** A 30-day window
  holds four or five of each weekday, so for a steady weekend drinker the Month figure
  moves between 12.3 and 15.4 as the window gains or loses a fifth Friday or Saturday;
  Quarter moves between 12.5 and 13.2 and Year between 13.0 and 13.4 (the plan's
  computation over every day of 2026). The Month line and per-day card already moved
  this way; the comparison now does too, and a reader at a row's edge can see the
  percentage flip between neighbours within a week. Whole-week windows inside each
  range would put "Last 28 days" back under "Last 30 days", the mismatch this record
  removes.
- **The Quarter line dips a little during a week** for a weekend-heavy log (12.5 to
  13.2 for that steady log) where the completed-weeks mean held still. The README's
  "never sags just because a new week started" is now true of Year only. The
  contract's line rule changes, so Android follows.
- **On a log under a week old, Quarter's line projects the log's days to a week.**
  Decisions 3 and 5 make the Quarter line the window's weekly figure however short the
  window, and Quarter has no completeness rule of its own any more, so a window of d
  days draws total × 7 ÷ d: one day with 4 drinks reads "Your weekly average · 28"
  above a single weekly bar of 4, and for any window under seven days the line stands
  above every bar. Main drew no line while every drink in the log lay in the current
  calendar week, as on that first day (its mean over the range's twelve completed weeks
  was zero); a log under a week old that had crossed into a new week drew one at a
  twelfth of the earlier week's total.
  It is what the plan determines, so it is built as decided and pinned at tier 1
  (`quarterLineUnderAWeek`); it shows only at Quarter and only in a log's first six
  days, since Trends opens on Week. **Put to the owner:** if a line above every bar on
  a first day reads wrong, the smallest change is no line while the window is under
  seven days, the rule Year keeps for a month — one condition
  in `TrendWindowFold.averageLine` and the test's two expectations. *(Kept by the
  owner on 2026-10-01: "That's acceptable and we can keep as is." The amendment below.)*
- **While the log is younger than 13 weeks, Quarter and Year show the same figures
  under different chart titles**, and every printed "of N" reads the days since the
  first record (51, say) while the chart's title and its bars cover the range (88 days
  on 30 September). The "Since" labels are what make that a statement rather than a
  mismatch, so they have to be read; at the accessibility sizes the span sits under the
  segment's title.
- **A log under a week old shows weekday rows with nothing in them**, "0 of 0 days",
  for the weekdays it has not reached: the fold's existing zero-of-zero row, now
  reachable at every range.
- **The weekend comparison returns to Week**, which ADR-0038 took it off, and the two
  population comparisons, on Week all along over their own window, now cover the week
  itself. On Month a log 28 or 29 days old shows all three as "Since <date>". Below 28
  days of record the section is silent at every range, as the population comparisons
  were below ADR-0018's floor; the weekend comparison, which used to set an empty log's
  zeros beside the published rates at Month, now waits too. The clipped cards above the
  section still show.
- **`ComparisonsSection` no longer reads the store or the clock**, which removes a
  second projection of the whole log on every body pass and the separate clock
  ADR-0038's segments read; `TrendsView`'s own `today`, refreshed at midnight and on
  every foreground, now governs the floor too.
- **Copy:** seventeen app-catalog keys in, two out (386 → 401), reviewed under 1.4.3
  (`docs/copy-review-1.4.3.md`, 2026-10-01). Out: "No drinks in the last 4 weeks." and
  "Your average covers your last 4 weeks.". The catalog was synced with
  `xcstringstool` from a fresh full generic build into a scratch copy of `main`'s and
  diffed before it was copied in: exactly those nineteen keys, nothing else changed.
- **The contract** (`semmes/tallyist-product`) changes its population-card row, the
  Quarter line, both measures and the gating, its copy deck and its vectors, in a draft
  PR; its old description of the windows as instant-based was already stale since
  ADR-0030's amendment. By its `VERSIONING.md` a behaviour change both platforms must
  make is MAJOR, though 1.7.0, the change this one reverses, went out as a minor; the
  number is the owner's.
- **No schema change, no CloudKit step, no setting, no network, no share card, no
  privacy-policy change.** `MARKETING_VERSION` is 1.5: 1.4 (1) is in App Review, so
  this rides the next train. The PR was to stay a draft until 1.4 was approved, because
  Xcode Cloud archives every commit on `main`; the owner tested the branch on their phone
  and asked for it on `main` the same day, with 1.4 still in review. So `main` is the 1.5
  train from this merge, and a fix 1.4 still needs is made on a branch from 98e494b, the
  commit its archive was made from.

## The review before the PR

An adversarial review ran over the first three commits before anything was pushed:
six lenses (plan conformance; the invariants and the ADR rules; the core's edge cases,
probed in a scratch copy of the package; the SwiftUI layer; mutation testing of the new
tests; stale callers and comments), each finding put to two skeptics, one checking it
against the code and concrete inputs and one against the plan and the records. 27
findings, 21 surviving at least one skeptic. **No figure on the screen was wrong**, and
every rule held: no delta, no rank, nothing chosen by what the figures say, one set of
days, a floor on the record alone. What it found, and what was done:

- **A tier-1 gap, fixed.** No test had a first record dated today, so changing the
  clip's upper bound from "on or before today" to "before today" passed all 412 tests
  and would have left a reader's first day unclipped. `dayOne` pins it at every range;
  the mutation now fails 22 checks. Every other mutation the reviewer ran was already
  caught: never clipping, a floor of 27 or 29, the floor counted from the window or in
  instants, the old Quarter line, partial months at Year, the range's days under the
  per-day average, the zero-day count, the weekday rows or the summary, the weekday
  fold counting totals instead of entries, the weekly figure over a fixed 4 or rounded
  weeks, a future record clipping, an empty log clearing the floor.
- **Quarter's line on a log under a week old** (three findings, one refuted on the
  plan's grounds): recorded above and put to the owner, not changed.
- **The Week note's first sentence**, fixed: "This figure is compared…" (readings).
- **A marker read west of the zone it was written in** dates the window a day early:
  recorded in the readings; both skeptics advised against a code change, since every
  surface reads markers the same way.
- **Comments and records that overstated**, fixed: "seven times the per-day card"
  printing the legend's number, which the card's one-decimal rounding breaks (101.8
  over 88 days prints 1.2 a day and 8.1 a week); when a 23:59 record clears the floor
  (from midnight 27 days later, not "the next morning"); the floor's reason, which is
  the record's length and not the window's; the Quarter line still called the
  completed-weeks mean in three comments; "the range" in the weekday and weekend docs;
  the figure line's doc at Week; the clipped note's comment, which claimed a survey
  caveat the plan's clipped note does not carry (the copy stays as the plan drafted it).
- **Refuted, and left:** that Year's "the span the survey asked about" now overstates
  (a range of twelve calendar months is that span); that `windowFold(of:in:)` should
  guard against range days from another range (its one caller passes its own, and the
  view's route is tested equal to the log's); that the year view's "Trends already
  covers the trailing window" is stale; two doc examples.

**A second pass over the records** (three lenses: every behavioural claim against the
code, the records against the plan and each other, every quoted string and the listing;
one skeptic per finding; 26 findings, 23 surviving, many the same fault seen by more than
one lens) found no claim about behaviour wrong in the code's direction but several
records that said more or less than the code does, all corrected before the commit: the
README, design-system and ADR-0030's amendment gave the clipped note the survey caveat,
which the plan's clipped note does not carry; this record's consequence about long logs
used the screenshot's 28-day log as its example and said every comparison changes, where
days with a drink already followed the range; its "51 against 88" predated decision 5,
under which nothing prints 88 while clipped; "main drew no line" was true only while the
whole log lay in the current calendar week; the tier-1 count folded rewritten tests into
the new ones; ADR-0030's amendment and `CLAUDE.md` called the retired average
instant-based, where only its gate was; ADR-0031's amendment named the wrong fold for the
header's count; ADR-0018's amendment quoted a phrase it never contained; the plan still
listed the weekday rows as unchanged; the copy review miscounted What's New's sentences;
and the 1.5 reviewer notes said "No figure is expressed against another", untrue of a
comparison, and misquoted the legend's capital Y (now "The line and the comparison are
not set against each other", 1,478 bytes).

## Verification

**Tier 1** (Xcode 27.0): 414 domain tests under both SwiftPM build systems: 13 new
(`TrendWindowTests`), and the 11 tests of the retired API in `InsightReferenceTests` and
`PopulationReferenceTests` rewritten to pin its successor (one more, the year view's
weekly average, gains an assertion that it is Trends' function), built with
`-warn-long-expression-type-checking=25` and flagging nothing.
**Tier 2:** 124 integration tests on the iPhone 17 Pro Max simulator, the same 124 as
`main`. Both schemes built in CI's form with only the warnings `main` already has, the
watch verifier with `--ci`, the policy-date check and the glyph generator clean. No
test tier reaches the Trends views (app target, no `TEST_HOST`), so for them CI proves
compilation.

**Tier 3**, on a throwaway iPhone 17 Pro on iOS 27.0 created for this and deleted
after, never the working pair; 114 frames on 1 October 2026, every figure read back by
OCR and checked against an independent computation of the seeded log (a Python
seeder that wrote the store with `sqlite3` and computed each range's figures from the
same drink list). A scratch copy of the tree, never the worktree, opened the app on
Trends at a given range and scroll position from launch variables; the renders are of
that build, which differs from the branch only in those two hooks.

- **A log older than a year** (a weekend drinker since 1 August 2025): all four ranges,
  light and dark, at the default size and `accessibility-extra-large`. Every figure
  matched: Week 5 standard drinks, 3 days with drinks, 0.7 a day, 5 of 7 with none,
  "5 standard drinks a week", 3 of 7 beside "about 2 in 7", the weekend 3 of 3 and 0 of
  4 beside the published rates; Month 24, 11 of 30, 5.6 a week, about 7 in 30, 10 of
  12 and 1 of 18; Quarter 89 days, 65, 32 of 89, about 21 in 89, 28 of 37 and 4 of 52,
  63 of 89 with none, and **the legend "Your weekly average · 5.1" over the comparison's
  "5.1 standard drinks a week"**, one number; Year 335 days, 249, 118 of 335, about 81
  in 335, 104 of 143 and 14 of 192, the monthly line 22.6. At accessibility-extra-large
  every segment folds to its sentences with its span under its title; at Week the
  sentence reads "You logged 5 standard drinks in the last 7 days.", at Quarter "Your
  average is about 5.1 standard drinks a week."
- **A log of 40 days** (from 23 August): Week and Month over their own ranges; Quarter
  and Year "Since Aug 23" on every segment and "since Aug 23" on the total card, both
  with 40 days: 30 standard drinks, 15 of 40, about 10 in 40, 13 of 16 and 2 of 24, 0.8
  a day, 28 of 40 with none, weekday rows summing to 40 days, and the legend and the
  comparison both 5.3; the Year line 25, September alone being complete. The bars span
  13 weeks and 12 months.
- **A log of 20 days** (from 12 September): no Comparisons section at any range; Month,
  Quarter and Year clipped, "since Sep 12", 14 of 20 with none, 0.7 a day, the Quarter
  line 4.9, no Year line.
- **Week over a quiet week and a heavy one:** 1 a week reads "That's lower than roughly
  60% of US adults who drink." and 20 a week "lower than roughly 10%", over 1 of 7 and 4
  of 7, the weekend 1 of 3 and 3 of 3.
- **A log of one day** (4 drinks): Quarter's line at 28 above a single bar of 4, the y
  axis drawn to 30 — the case recorded above and put to the owner; Week's line 4.
- **A 40-day log with no drinks:** "No drinks in the last 7 days." at Week and "No drinks
  since Aug 23." at Quarter, the reader's tracks empty beside the published bars.
- **The notes, opened by a tap** (the simulator tool): at Week "This figure is compared
  on this device…" and "This figure covers your last 7 days. The survey asked about a
  year."; at Month "…your last 30 days. The survey asked about a year."; clipped "Your
  average covers the days since Aug 23."
- **Before, from `main` on the same logs at Quarter:** the year log's legend 5.4 over a
  comparison of 5.1 for "Last 12 months" and 127 of 364 days; the 40-day log at 0.3 a day,
  77 of 89 with none, the legend 2.5, the comparisons "Last 28 days", 6 a week and 11 of
  28, and the weekend split 13 of 37 counting the days before the first record.

**Not rendered, stated:** VoiceOver (the spoken forms are the folded sentences, which
were rendered); a UK or Australian region; the Men and Women columns at Week; a
midnight-DST zone on screen (tier 1 pins it); Increase Contrast; a 375pt phone; a live
range change's crossfade; hardware. **Tier 4, the owner, the same day:** a build of the
branch on their phone, "working as expected". Their first read of the one-day Quarter
line is that it looks correct; the question stays open until they decide it.

## How to reopen

If Week's moving sentence reads as a verdict on one week, the costed alternative is
the plan's 1b: the week's total beside a fixed published figure read off the same
table, which needs an ADR-0018 amendment, a copy review row and a contract vector of
its own. If the "Since" label is missed and a young log's comparison reads as a
contradiction of the chart above, the plan's 2b is the sentence in its place until the
log covers the range. If a still Quarter line matters more than one weekly average, 3b
labels the two; 3c is not open, since it re-creates the mismatch. If the Month figure's
week-pattern swing is reported, whole-week windows are the route, and they re-open the
labels. Moving Quarter to calendar quarters is a separate decision about what the range
is, not about what it compares.

## Amendment (2026-10-01): the sub-week Quarter line is kept, and the line follows a grain

**The owner's answer to the question this record put to them**, after the case was
explained (one day with 4 drinks reading "Your weekly average · 28" above a bar of 4,
on a log's first days only): *"That's acceptable and we can keep as is."* The line
stays the window's weekly figure however short the window, and
`quarterLineUnderAWeek` stays as it is. The alternative recorded above, no line while
the window is under seven days, is the reopen if the case is reported from the field.

**The same day the owner asked for Quarter and Year to be read by day, week or month**
(ADR-0059). The rule this record gave the line at Quarter is now the rule for weekly
bars at either range: under Year's weekly bars the line is the window's weekly figure,
the number the weekly-average comparison prints, and the sub-week case above reaches
Year's weekly view on the same terms. Daily bars at Quarter and Year take the per-day
average, the per-day card's own figure; monthly bars at Year keep the complete-months
mean. Everything under the chart still reads the window, whatever the bars are cut
into.
