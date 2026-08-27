# 0018 — The population reference is a bundled statistic, renormalized in the open

**Status:** accepted · **Date:** 2026-08-27 · **Source:** `docs/tallyist-1.2-spec.md`
Feature C · **Relates to:** ADR-0006, spec constraints 2, 4, 5

## Context

The 1.2 spec replaced a friends leaderboard with an anonymous population
reference, on the evidence that normative feedback works by correcting the
*overestimate* people carry about how much peers drink — while a live
leaderboard normalizes whatever the group actually does. The spec gated the
feature on sourcing: a citable statistic with a stated year, convertible to
grams of ethanol per week, describing adults **who drink** — and said to cut
the feature rather than estimate.

The research (2026-08-27) found one source that fits: the Alcohol Research
Group's **2020 National Alcohol Survey** consumption norms table (N=9,668,
NIAAA grant P50AA005595) — a cumulative distribution of drinks per week.
It describes *all* US adults, but states the abstainer share explicitly
(28% at zero), which makes drinkers-only percentiles exact arithmetic:
`(p_all − 28) / 72`. No drinkers-only table is published anywhere we found.

## Decision

**Ship the renormalized table, with the derivation disclosed everywhere the
data lives** (user decision, from three options: renormalize-and-disclose /
use all-adults / cut). The bundled JSON carries the published all-adults
values *and* the derived drinkers values side by side, plus a `derivation`
field stating the arithmetic; the tier-1 suite recomputes every row, so a
transcription error fails CI, not a user. The in-app note says the
percentages are "recalculated to cover only the 72% who reported drinking."
This is renormalization of published numbers — the same class of mechanical
transform as the unit conversion the spec mandates — never estimation.

**Comparison happens in grams.** The user's 4-week average converts
region-units → grams (`× gramsPureAlcoholPerStandardDrink`); survey levels
are US drinks × 14 g. A UK user's "7 units" and a US user's "4 drinks" are
the same 56 g and read the same comparison, pinned by tests across all
three regions.

**The bracket is conservative and the phrasing is fixed.** An average
rounds *up* to the next survey level, so "lower than roughly N%" (rounded
to 5) is true at the bracket's edge rather than optimistic inside it. Above
the table's top, the line flips to "more than roughly N%" (floored) —
"lower than roughly 0%" states nothing. "Lower than", never "better than";
no congratulation, no warning, either direction.

**What it will never contain:** thresholds. No NIAAA limits, no Dietary
Guidelines lines — a descriptive statistic is a fact; a threshold is a
recommendation, and spec constraint 5 (and the App Review record) says this
app gives none. Also: no other Tallyist users, no sharing, no identifiers,
no network call — the file ships in the core package and loads from the
bundle.

**Gates:** hidden until four weeks of recorded history (below that the
average is noise); hidden entirely if the bundle is broken — never a
placeholder number; the comparison line is omitted for a zero average
(nothing honest to say).

## Consequences

- A UK or AU user is compared against a US population, in their own units.
  The card says "US adults who drink" outright, so the mismatch is named,
  not hidden. A UK/AU source with the same rigor can join the bundle later.
- The statistic ages. It is stamped 2020 in the UI, which is the honest
  state; refreshing it is a data-file change with the same tests.
- The renormalization inherits the source's rounding (±0.5pp, ±0.7pp after
  division) — absorbed by "roughly" and rounding to the nearest 5.

## How to reopen

- A published drinkers-only distribution (or a newer NAS norms table)
  replaces the derivation outright — swap the file, keep the tests.
- Any pull toward per-user comparison, sharing, or thresholds is not a
  reopen of this record; the spec's stop conditions end that conversation.
