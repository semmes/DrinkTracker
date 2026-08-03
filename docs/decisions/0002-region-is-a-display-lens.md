# 0002 — Region is a display lens, not a property of the drink

**Status:** accepted · **Date:** 2026-08 (from the initial scaffold; recorded here)

## Context

The app supports three definitions of a standard drink — US (14 g of ethanol), UK
(8 g, called a "unit"), and Australia (10 g). The user picks one at onboarding and can
change it in Settings at any time.

The brief does not say what happens to existing history when someone changes region.
Two readings were available:

1. **Freeze the units at log time.** Each entry stores the number of standard drinks it
   was worth under the region in force when it was logged, and that number never
   changes.
2. **Treat region as a lens.** Entries store the physical facts — volume and ABV — and
   totals are computed in whatever region is current.

Option 1 is superficially appealing: it feels like it preserves what the user saw at
the time. But it makes any total a sum of UK units and US standard drinks added
together, which is not a number that means anything. A week spanning a region change
would produce a figure with no unit at all.

## Decision

Region is a display lens. Entries record volume, ABV, and — as provenance only — the
region they were logged under. Totals are always computed in the **current** region via
`LoggedDrink.standardDrinks(in:)`.

Changing the setting re-expresses history. It does not alter what was drunk.

The Settings copy says this plainly: "Changing it re-expresses everything, including
past days — what you drank doesn't change, only how it's counted."

## Consequences

- Any code path that totals drinks must take a region parameter. There is deliberately
  no zero-argument `total` on `LoggedDrink`.
- The stored `region` on an entry is provenance and must never be used for arithmetic.
  It exists so we can answer "what was this shown as at the time", not so we can sum
  with it.
- Trend ranges longer than the current 30 days will span region changes more often.
  The behaviour is already correct; it just becomes more visible.
- `DrinkDraftTests` pins this: "Totals use the caller's region, not the one stamped on
  the entry" and "A mixed-region history sums coherently in one unit".

## How to reopen

If the app ever needed to show a historical figure exactly as it appeared on a given
day — an export intended as a contemporaneous record, say — that would call for
rendering *alongside* the current-region total, not for changing how totals are
computed. The invariant would survive.
