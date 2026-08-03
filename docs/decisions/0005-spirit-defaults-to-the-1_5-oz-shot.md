# 0005 — Spirit defaults to the 1.5 oz shot, and the one-drink invariant is real

**Status:** accepted · **Date:** 2026-08 · **Resolves:** README "Known spec
discrepancies" #1 · **Relates to:** PRD Iteration 1(d)

## Context

The design brief stated that every default size/ABV pair should resolve to "almost
exactly 1.0" standard drinks, and called that load-bearing. Its own configuration
table then contradicted it twice:

| Type | Brief's default | US standard drinks |
|---|---|---|
| Beer | 12 oz @ 5% | 1.00 |
| Wine | 5 oz @ 12% | 1.00 |
| **Spirit** | **1 oz @ 40%** | **0.67** |
| **Other** | **8 oz @ 10%** | **1.33** |

Both were implemented as literally written and pinned by a test, so the deviation
was visible rather than silently corrected — but that left the invariant itself
undecided. Either it is real and the table is wrong, or it is not real and the app
should stop describing it as load-bearing.

The invariant matters because the app's whole claim is an accurate answer to how
much someone is drinking. If tapping Spirit and logging without adjusting anything
records two-thirds of a drink, the fast path systematically *under*-counts — and
under-counting is the specific failure this product exists to prevent. The two-tap
path is the one most people will use most of the time, so whatever it defaults to
is, in practice, what the app measures.

## Decision

**The one-drink invariant is real.** Every type with a real serving size opens at
almost exactly 1.0 US standard drink.

**Spirit's default becomes the 1.5 oz shot**, which was already among its size
options. At 40% that is 0.6 fl oz of ethanol — the US definition exactly, not
approximately.

**Other is a deliberate exception.** It has no presets and no typical serving to
anchor to; its default seeds the Custom field rather than describing a real drink.
It stays at 8 oz @ 10%.

## Consequences

- Tapping Spirit and logging without adjusting now records 1.0 drinks instead of
  0.67. Totals for spirit drinkers who use the fast path go **up**, which is the
  point: the previous number was an undercount, not a smaller truth.
- Historical entries are untouched. They record volume and ABV, not a default, so
  nothing is retroactively rewritten.
- `defaultSizeOption` no longer returns `sizeOptions[0]`. It is now derived from
  `defaultVolumeOunces`, because the two must agree — the selected pill's volume is
  what `DrinkDraft.volumeOunces` actually reads, so changing the number alone would
  have silently done nothing. Presentation order in `sizeOptions` is now free to be
  only about presentation order.
- The test that pinned the deviation is replaced, not deleted: `defaultsHitTheOneDrinkInvariant`
  asserts the rule, `otherIsExempt` pins the exception, and
  `defaultPillMatchesDefaultVolume` guards the coupling that made this a two-line
  change rather than a one-line one.
- Adding a type later means picking a default that lands on 1.0, or documenting why
  it is an exception. That is a real constraint, and an intended one.

## How to reopen

If a future region's definition makes a single default impossible to satisfy across
all of them simultaneously — the invariant is currently expressed in US standard
drinks — this becomes a question of which region the defaults are anchored to,
rather than whether the invariant holds. Nothing about the current three regions
forces that.
