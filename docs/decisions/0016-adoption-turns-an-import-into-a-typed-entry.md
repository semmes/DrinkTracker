# 0016 — Adoption turns an import into a typed entry, and never touches Health

**Status:** accepted · **Date:** 2026-08-26 · **Relates to:** ADR-0014 (its
reopen path), ADR-0003 / PRD invariant 7, invariant 6

## Context

ADR-0014 made imported Health drinks count-based and read-only, and named the
one legitimate door out: an *adoption* flow, where the user types in the real
size and strength — "creating precision that must be typed in", never relaxing
read-only to get there. The user asked for that flow (2026-08-26).

The design questions were where the typed facts go, what happens to the
mirror, and what Health sees.

## Decision

**Adoption rewrites the imported entry in place: same identity, same
timestamp, same external sample id — with the user's typed type, size, and
strength, and `countedDrinks` cleared.** Clearing the count is the single
switch that flips every downstream behaviour: the entry joins the real
standard-drink math under the region lens, renders like any logged drink, and
stops being treated as a mirror.

**Health is never touched.** Adoption goes through `DrinkStore.adopt`, not
`save`: `save` retires the old sample and writes a fresh one, and both halves
are wrong here — the old sample is *another app's* (HealthKit wouldn't let us
delete it, and it is the legitimate Health record), and writing our own would
double-count the drink in Health. The log learns; Health already knows.

**Keeping the external sample id is load-bearing twice.** It is the dedup key,
so a re-delivered sample (reset anchor, second device) finds the adopted entry
and inserts nothing — the count cannot resurrect. And its presence keeps the
entry out of the HealthKit backfill, so no second sample is ever written.

**Deletion sync no longer removes it.** `removeImportedEntries` only deletes
count-based rows; an adopted entry has typed-in facts and is Tallyist's own
record now. If the source app deletes its sample, the user's typed entry
stays — the mirror direction never inverts (ADR-0014's rule, inherited).

**Only single-count imports are adoptable** (`LoggedDrink.isAdoptable`). A
"3 drinks" sample cannot become one typed entry without breaking invariant 7
(quantity is N separate entries, never a count on one), and splitting it into
N entries has no honest Health story: only one entry can carry the sample id,
and the others would backfill fresh Tallyist samples on top of the external
one. Multi-count mirrors stay read-only.

**Surface:** the same conventions as editing — tap or leading-swipe
("Add details") on the imported row in History opens the detail sheet in an
adoption mode: type picker, size, strength, no time control (the sample's
timestamp is the one fact the import already has; adoption adds facts rather
than revising them), primary action "Save details".

## Consequences

- A switcher can upgrade their imported history one drink at a time, and each
  adopted drink starts responding to the region lens like everything else.
  Totals can change at the moment of adoption — from the flat count of 1 to
  what the typed facts compute — which is the feature being honest.
- Adoption is one-way. There is no "un-adopt": the count was the absence of
  facts, and facts, once stated, are edited like any entry's (the normal edit
  path opens up because the entry is no longer imported). The Health sample
  still exists unchanged, so nothing is lost at the source.
- After adoption, editing the entry goes through `DrinkStore.save`, which
  retires "its" sample and writes a Tallyist one. That converts the Health
  record from the external sample to ours — acceptable, because the user is
  now actively curating this entry in Tallyist — but it means the external
  app's sample is deleted only if HealthKit permits (it doesn't, for another
  app's data), leaving the external sample in place alongside ours. **This is
  the one known wrinkle:** an adopted-then-edited drink can appear twice in
  Health (once per app), never in Tallyist. Recorded here honestly; fixing it
  would need `save` to know an entry's sample is foreign, which is a
  follow-up if real use hits it.
- No schema change. Adoption is a value-level rewrite of fields that already
  exist, which is why it could ship before the next `VersionedSchema` bump.

## How to reopen

- Multi-count adoption (splitting "3 drinks" into three typed entries) needs
  an answer for the Health-echo problem first — some way for N−1 entries to
  be excluded from backfill without carrying the sample id. That is a schema
  conversation (a "foreign sample" marker), and it goes through the
  `SchemaVersions.swift` recipe.
- The adopted-then-edited wrinkle above becomes worth fixing the moment a
  real user reports double counting in Health: give `DrinkStore.save` a way
  to know a sample id is foreign and skip the retire half.
