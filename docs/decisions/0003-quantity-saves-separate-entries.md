# 0003 — Quantity saves N separate entries, not one entry with a count

**Status:** accepted · **Date:** 2026-08 (commit `1940a82`)

## Context

The drink sheet has a "How many" stepper (1–12). Logging 3 wines could be stored either
as one entry carrying `count: 3`, or as three independent entries.

One entry with a count is the smaller data model and the more obvious first
implementation.

## Decision

`DrinkDraft.makeLoggedDrinks(region:)` returns N distinct `LoggedDrink` values, each
with its own `UUID`, and `DrinkStore.save(_ drinks:)` writes them individually.

Timestamps stagger by one second so list ordering is deterministic. That is a
tie-breaker, not a claim about when each drink was actually consumed.

## Consequences

Each entry keeps:

- **Its own identity**, so it is individually editable and removable. Removing one of
  three logged wines leaves the other two — verified: 8.9 → 7.9.
- **Its own HealthKit sample.** A count-bearing entry would write one beverage sample
  for three drinks, or need bespoke logic to write three from one record.
- **Its own row in history.** The log reads as what happened rather than as a summary
  of it.

The cost is N rows where one would do, and N HealthKit round-trips on save. Both are
trivially small at a cap of 12, and the cap exists partly for this reason.

This decision is what keeps the quantity feature coherent with editing and removal
rather than being a special case they both have to know about.

## How to reopen

A bulk-logging feature at a much larger scale — importing a year of history, say —
would make N-writes-per-action worth revisiting. Nothing at the current scale does.
