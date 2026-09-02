# 0014 — Health import: count-based, read-only, deduped by sample

**Status:** accepted · **Date:** 2026-08 · **Relates to:** ADR-0002, ADR-0003,
ADR-0011, PRD invariants 3 and 7 · **Amended by:** ADR-0025 — a zero-count
sample, which this record never mentioned and the code silently dropped, is now
a read-only no-alcohol marker, and deletion sync removes that marker as it
removes a count-based mirror (the sync-mechanics bullet below predates it)

## Context

Tallyist wrote to Apple Health from day one but never read from it, so drinks
recorded by other apps — a user's history from whatever they used before —
were invisible. The request: anything alcohol-related in Health should appear
in Tallyist automatically.

The obstacle is that `numberOfAlcoholicBeverages` samples carry only a count
and a timestamp. No type, no volume, no ABV — and Tallyist's entire math runs
on grams derived from volume × ABV, re-expressed through the region lens
(ADR-0002).

## Decision

**Imported drinks are count-based: one beverage counts as exactly one drink,
in every region.** No conversion to a default-size drink — that would be
invented precision wearing real numbers. `LoggedDrink.countedDrinks` carries
the external count; when set, `standardDrinks(in:)` returns it unchanged under
any lens, because "a drink" from an unknown source is one drink under any
lens. The UI says what it knows: "From Apple Health · counted as 2 drinks",
never a fabricated "12oz · 5%". (User decision, from two options presented.)

**Imported entries are read-only.** No edit (there is nothing truthful to put
in the size and strength fields) and no delete in Tallyist — HealthKit only
lets an app delete its *own* samples, so a Tallyist-side delete could never
propagate and the two stores would disagree forever. Change or delete the
drink in the app that logged it (or in Health), and the mirror follows via
deletion sync. The Today counter's minus skips imported entries for the same
reason.

**Sync mechanics:**

- An anchored HealthKit query runs on the same foreground sweep as the
  HealthKit backfill; the anchor persists in the App Group, so the first run
  imports all history and later runs handle only changes, including deletions.
- The app's own samples are filtered out by source bundle — importing them
  back would double every drink. The two directions can't collide: backfill
  only touches entries with **no** sample id, imports always arrive **with**
  one (the external sample's UUID, which is also the dedup key).
- Deletion sync removes only count-based mirrors. A Tallyist-written sample
  deleted in the Health app does *not* delete the log entry: the log is the
  source of truth for the app's own records (the mirror direction never
  inverts).
- Imports route through `saveOrThrow`, so an imported drink clears a same-day
  alcohol-free marker exactly like a logged one — evidence beats assertion,
  whichever app recorded the evidence. Calendar bulk fill skips days with
  imported entries automatically (they have entries; ADR-0011 already refuses).
- Imported shells never seed the quick-log template (`mostLoggedType` /
  `mostRecentDrink` exclude them) — the counter's plus must template on data a
  person actually entered.

## Consequences

- A switcher's history appears on first launch after granting Health access,
  and totals may change materially the moment it lands. That is the feature
  working, and the Settings Health footnote says it in advance.
- Totals now mix gram-derived and count-based figures. Honest but coarser:
  a UK user's imported "3 drinks" is 3 units, though the source app may have
  meant US standard drinks. The alternative — guessing — was worse.
- Read authorization is invisible by design in HealthKit (denied reads look
  like an empty store), so import is best-effort and silent, matching the
  app's existing Health posture.
- Two devices importing the same external samples dedup by sample UUID; if a
  future Health change breaks UUID stability across devices, the dedup key
  needs a second look.

## How to reopen

If users ask to "claim" an imported drink — turn it into a full Tallyist entry
with a real size and strength — that is an *adoption* flow, not an edit: it
creates precision that must be typed in, and it has to retire the mirror
without deleting the external sample. Design it as its own change; don't relax
read-only to get there.
