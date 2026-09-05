# 0031 — Drinking days get a published reference, stated as a mean and never a percentile

**Status:** accepted · **Date:** 2026-09-05 · **Relates to:** ADR-0018 (the
population reference and its rules), ADR-0030 (the window it shares),
ADR-0006, spec Feature C's "Shape 2", constraints 3 and 5

## Context

The calendar's card counts days with drinks; nothing in the app said what
that count looks like for anyone else. The owner asked to use the reviewed
sources for insights. NESARC-III (2012 to 2013) publishes a mean:
past-year drinkers drank on 87.9 days a year, up from 83.5 a decade
earlier (NIAAA Spectrum; Dawson et al. 2015, PMC4330106). NSDUH 2023
corroborates it for adults 18 and over: 87.6 days among past-year users
(SAMHSA detailed tables 8.1B).

No published *distribution* of drinking frequency was found. NESARC's
data reference manual distributes only the frequency of five-, eight- and
twelve-drink days — threshold constructs, unusable under constraint 5 —
and NSDUH publishes the mean and one point ("daily or almost daily", 6.6%
of adult past-year users). A banded distribution exists only as unweighted
codebook counts, which are not a statistic.

So the feature takes the 1.2 spec's second shape: a single central
tendency, stated beside the user's own figure. "Lower than roughly N%" is
impossible here and is not attempted.

## Decision

**Two sentences on the Trends population card, under the volume lines:**
"You logged drinks on 9 of the last 28 days." and "US adults who drink
average about 7 in 28." The user's figure is the calendar's own definition
of a day with drinks — a calendar day with at least one entry, an entry at
0% included, a marker alone excluded — over the card's window (ADR-0030:
28 or 364 days), walked with the package's DST-safe day keys. The
reference is the mean scaled to the same number of days and rounded to
whole days: a mean over a population is not a figure a tenth of a day can
be checked against. The source line names both sources; the note adds one
sentence saying where the drinking-days figure comes from and that it is
a mean among adults who drank in the past year.

**Bundled as `us-frequency-reference.json`** in the core package with its
source, year, population and derivation, loaded by `FrequencyReference`
and pinned by tier-1 tests; hidden if the file is missing, never a
placeholder.

**What it must never become:** a percentile, a rank, a "most people", or a
comparison of any day's *amount* against a threshold. The sentence states
two counts of days and stops.

## Consequences

- The reference is 2012 to 2013 data, and says so on the source line. A
  newer published mean is a file change.
- The denominators differ from the volume comparison's, and the note says
  so: the mean is among past-year drinkers; the ARG percentages are
  renormalised to adults who drink.
- A user's window with no entries reads "You logged drinks on 0 of the
  last 28 days." — factual, under a first line that already says there were
  no drinks.
- The card grows by two lines. No schema change, no network, no new
  permission. Six app-catalog keys in.
- The contract's measure `drinking_days_per_28_days` becomes
  `drinking_days_in_window`, scaled to the same window as the volume
  average; a vector set pins the count and the scaling.

## How to reopen

A weighted, published frequency distribution — NHANES ALQ121 or NSDUH
ALCYDAYS as a table rather than a codebook — would let this line take the
first shape, "lower than roughly N% of adults who drink", by the same
bracket rule as the volume comparison; that is a data-file change and a
copy change under the same constraints. If the mean reads as a target in
real use, the sentence loses the reference and keeps the count.
