# 0001 — Logging several of the same drink is called "repeat logging", not "party mode"

**Status:** accepted · **Date:** 2026-08 (commits `1940a82`, `1841c66`)

## Context

The feature was requested as "party mode": a way to log several drinks of the same type
without going through type → size → confirm each time.

The functionality is squarely on the right side of the line. Friction causes
under-logging, and under-logging defeats the product's whole claim of giving an
accurate picture. Someone catching up on an evening is doing the honest thing, and the
app should not tax it.

The *name* is a different question. App Store guideline 1.4.3 rejects apps that
encourage excessive alcohol consumption, and on an alcohol-tracking app the framing is
what a reviewer reads. "Party mode" is celebratory in a way "Repeat" is not — it reads
as the app being pleased about volume.

The README initially recorded this as a provisional call, with instructions for
renaming it back. That framing kept inviting the question, which is why it was
promoted to a settled decision in its own commit.

## Decision

The feature is called **repeat logging**. All user-visible copy stays factual and
countable: "Another beer", "How many", "3 of these", "Log 3 drinks".

This is not a placeholder awaiting a better name. **Do not reintroduce celebratory
framing here.**

The constraint generalises: no streaks, no encouragement to reach a number, nothing
that reads as a reward for volume, anywhere in the app.

## Consequences

- The copy is duller than it could be. That is the intended trade.
- The relevant strings live in `TodayView.repeatControl` and
  `DrinkDetailSheet.quantitySection`. Anyone editing them inherits this constraint.
- It applies to future features too — this is the reference for tone questions, not
  just a note about one label.

## How to reopen

Guideline 1.4.3 would have to change, or the feature would have to move somewhere the
guideline demonstrably doesn't reach. Neither is likely. A better *neutral* name is
always welcome; a celebratory one is not.
