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
