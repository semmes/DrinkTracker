# 0030 — The population comparison covers the survey's window once it can, and a complete year gets the same comparison

**Status:** accepted · **Date:** 2026-09-05 · **Amends:** ADR-0018 (the
window) · **Relates to:** ADR-0006, ADR-0026 (the year's fold), ADR-0027 and
ADR-0029 (never on a share card), spec constraints 3 and 5, the contract's
`domain/aggregation.md` ("Measures a source may be compared against")

## Context

The population card compares the user's average over the trailing four
weeks against the Alcohol Research Group's 2020 norms table. The table's
own page says what its column is: the number of drinks adults "consumed
per week on average in the previous 12 months", the National Alcohol
Survey's graduated-frequency volume over a twelve-month frame (ARG,
"Updated US Drinking Norms (2020 Data)"; the N14 methods paper, PMC9350305,
"all major drinking measures follow the NAS tradition using the last
12-month time frame"). So the card placed a four-week figure on a
twelve-month distribution. That is not wrong — the sentence says "your
average" and the note said "your last 4 weeks" — but it is noisy in a way
the survey is not: one heavy week moves a four-week average by a quarter
and a yearly average by two percent, and the comparison swung with it.

Separately, the year view now shows a whole year's four figures
(ADR-0026) and a year-in-review card (ADR-0029), and nothing on that page
placed the year against the same table, though the arithmetic is one line.

The owner asked (2026-09-05) to use the reviewed sources for insights
within constraints 3 and 5. Two of the five items are this record.

**The competing option** for the window was to keep four weeks and add the
twelve-month figure as a second sentence. It loses: two averages one above
the other invite the reader to compare them, which is a delta between
windows, the thing ADR-0026 made law against. One window at a time, named.

## Decision

**The window follows the record.** Once the first recorded fact — an entry
or a no-alcohol marker — is 52 weeks old, the card's average covers the
trailing twelve months (364 days, a fixed divisor of 52); before that it
covers the trailing four weeks as shipped (28 days, divisor 4); below four
weeks the card does not render. Both are instant-based windows with a
fixed divisor, the 1.2 rule kept (`PopulationReference.Window`,
`window(firstRecord:now:)`, `weeklyAverage(_:window:endingAt:region:)` —
arithmetic that lived in the view and is now in the package, tested). The
note names the window: "Your average covers your last 4 weeks." or "Your
average covers your last 12 months, the span the survey asked about."

**A complete year is compared on the year view**, under its summary card,
for a year that has ended and has a record (ADR-0029's gate), from the
same summary: the year's weekly average is its total over its weeks
(`weeklyAverage(of:)`, `dayCount / 7`), converted to grams and bracketed by
the same function. "In 2025, your average was about 4 standard drinks a
week. That's lower than roughly 35% of US adults who drink." The
sentences, the source line and the note are one shared set
(`PopulationReferenceCopy`), so the two surfaces cannot drift.

**Never on a share card.** ADR-0018's stop condition and ADR-0027's rule
stand: the comparison is read by the user, in the app.

**Region-matched references were sought and not found.** The Health Survey
for England, the Scottish Health Survey, the National Survey for Wales, ONS
and the Australian NDSHS and National Health Survey all band weekly
consumption only at their guideline (14 units; 35/50; 10 standard drinks).
A "lower than roughly N%" built on those bands would be a guideline
comparison in disguise. UK and Australian users stay compared against US
adults, as the card says outright; the two are recorded in the contract's
sources file as candidates with the reason.

## Consequences

- For a user whose record is older than a year, the number changes on the
  day this ships and the note says why. The four-week figure is no longer
  visible anywhere for them; Trends' Month range and the calendar's rolling
  card still show recent totals.
- The twelve-month window includes the same Health-import imprecision the
  four-week one did (imports at the current region's grams), and the same
  "entries after now are not excluded" rule, both recorded in the contract.
- The year comparison prints "No drinks logged in 2025." for a year of
  markers only, and no comparison line — a zero average has no bracket, as
  on the card.
- The bundled table is unchanged; no schema change, no CloudKit step, no
  network, no new permission. Nine app-catalog keys in.
- The contract's measure `weekly_average_standard_drinks` now names both
  windows and the year form; a vector set pins the window gate and both
  divisors.

## How to reopen

A published, fine-banded weekly distribution for the UK or Australia whose
band edges are not a guideline would replace the US comparison for those
regions — swap the file, keep the function. A newer National Alcohol
Survey norms table replaces the 2020 one outright. If users read the
twelve-month figure as stale after a change in their drinking, the
four-week window can return as a *choice*, one window shown at a time, on
ADR-0026's model — never two averages on one card.
