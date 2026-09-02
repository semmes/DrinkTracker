# 0025 — A Health zero is a recorded no-alcohol day

**Status:** accepted · **Date:** 2026-09-02 · **Amends:** ADR-0014 (zero-count
samples) · **Relates to:** ADR-0011, ADR-0016, ADR-0022, PRD invariants 6 and 7

## Context

ADR-0014 imports other apps' `numberOfAlcoholicBeverages` samples as
count-based, read-only entries. It said nothing about a sample whose value is
zero, and the code dropped them: `fetchExternalChanges` kept only positive
counts — an implementation choice that never reached the ADR, had no test, and
made a day another app had recorded as "0 drinks" look exactly like a day with
no data at all. The owner asked (2026-09-02) whether a day marked zero
elsewhere shows up as a no-alcohol day here. It did not.

Tallyist already holds that "no entries" and "no alcohol" are different facts,
and records the second only as an explicit claim (`AlcoholFreeDay`; README,
"recorded, not inferred"). A zero-count sample *is* that claim, made by the
same person in a different app: "I was here, and there was nothing to log."
Dropping it loses a recorded fact; showing it as a gap misreports one.

The competing option was to leave zeros alone — no schema change, no CloudKit
step, the user marks the day by hand. It loses for the reason ADR-0014's
import exists at all: a switcher's history should appear without retyping, and
the days they recorded as alcohol-free are part of that history.

## Decision

**A zero-count external sample on a day with no entries marks that day
alcohol-free, carrying the sample's id. Days with no Health record stay
blank.** Concretely:

- The repository classifies every external sample: a positive count is a
  count-based entry (ADR-0014), zero is a marker
  (`markAlcoholFreeFromHealth`), anything else is dropped. The rule lives in
  `DrinkRepository.importExternalSample`, where tier-2 tests hold it; the
  service drops only what Health cannot store (negative, non-finite) and
  otherwise passes every sample through — what a value *means* is decided in
  the repository.
- **One sweep's deletions are applied before its additions**
  (`DrinkRepository.applyExternalChanges`). A HealthKit sample cannot be
  edited, so a correction in the other app — a zero re-saved, a day changed
  from one drink to none — is a delete plus a save in the same delta, and a
  marker is one per day: the stale record has to be gone before the
  replacement is offered, or the zero is refused and the day ends blank for
  good. Deletions first is right for every transition and costs nothing.
- The standing rules apply unchanged, whoever is asserting. A day with
  entries — typed or imported — refuses the marker (evidence beats
  assertion). A day the user already marked keeps the user's marker, with no
  sample id. A positive import, or any logged drink, clears the marker through
  `saveOrThrow` as before.
- The marker is a Health mirror, so it inherits ADR-0014's terms. **Read-only
  in Tallyist**: the day sheet and Today say "From Apple Health" and offer no
  "Remove that record", and `unmarkAlcoholFree` refuses it — HealthKit will
  not let this app delete another app's sample, so a removal here could never
  propagate and the two stores would disagree for good. **Deletion sync
  removes it** when the sample is deleted at the source
  (`removeImportedMarkers`). The CSV export prints Apple Health in its source
  column.
- `AlcoholFreeDay.healthKitSampleID` is **schema version 2** — an optional,
  additive attribute, migrated lightweight from V1 through the plan
  `SchemaVersions.swift` documents, with the V1 shape frozen beside it and
  upgrade-path tests that reopen real V1 store files.
- The import anchor carries a **generation**. Generation 1 (1.1's reading)
  walked past every zero; bumping it makes the first sweep after this ships
  walk history once more, so zeros already passed become markers on existing
  installs. Drinks the walk re-offers dedup by sample id, adopted ones
  included. Two details keep the walk honest: the outgoing anchor is
  **drained first** for the deletions only it can report (a walk from no
  anchor reports none), and the anchor is **committed after** the delta is
  applied, so a sweep cut short replays instead of skipping what it never
  applied.

## Consequences

- **CloudKit's Production schema needs the new attribute before the next
  TestFlight build, not just the App Store one** — TestFlight installs mirror
  to Production too. Development learns a field when a debug build exports a
  record carrying it, and a marker whose sample id is nil may not create the
  field, so check first: CloudKit Console → the app's container → Development
  → Schema → Record Types → `CD_AlcoholFreeDay` should list
  `CD_healthKitSampleID`; if it does not, add it by hand with the type
  `CD_DrinkEntry.CD_healthKitSampleID` already has. Then *Deploy Schema
  Changes* to Production. Without that step, records carrying the field fail
  to export and sync stalls — silently, as every CloudKit failure is. This is
  the owner's step, recorded in CLAUDE.md as part of the release.
- Older builds (1.0, 1.1) sharing the account see a plain marker — they show
  the day as no alcohol, which is right — and can remove it, because they do
  not know it is a mirror. If they do, this build does not re-import it (the
  anchor has passed), the same one-way cross-version loss ADR-0022 describes.
- A zero refused because the day had entries is gone for that sample. If the
  entries are removed in a *later* sweep the day goes blank, not back to no
  alcohol — the deletion-over-dormancy trade `saveOrThrow` already makes for
  the user's own markers. (In the same sweep the deletion is applied first
  and the zero lands.)
- The re-walk re-mirrors any imported row a 1.1 user removed through the
  Today leak ADR-0022 closed: the sample is still in Health, so the mirror
  returns. That is the store agreeing with Health again, but it will look
  like a drink coming back.
- A user-set marker and a Health marker can both land on one day when two
  devices act before CloudKit merges. The day then reads as Apple Health's
  everywhere — day sheet, Today, export — "Remove that record" is not offered
  while the Health marker stands, and a logged drink clears both.
- A second zero sample on the same day (two apps, or one app twice) attaches
  to nothing; deleting the first sample removes the marker although the
  second still stands. Rare, and the day can be re-marked by hand.
- A user-set marker that a positive import cleared is not restored when that
  import is later deleted at the source. Already true before this ADR; now
  stated.
- Two devices import with their own anchors, so both walk the same zero; the
  second finds the day marked and does nothing.
- The one-time re-walk costs one full-history query and one fetch per
  existing sample on the first foreground after updating; the service's own
  comment already calls a re-walk "harmless, just slow".
- The support page's sentence that Tallyist records "no alcohol" only when
  you say so is amended: it is recorded when you say so — here, or in
  another app that writes it to Health. The privacy policy's Health bullet
  says the same, in all three copies.
- Whether third-party apps write explicit zero samples at all is an
  ecosystem fact not checked here. If none do, nothing changes for anyone.

## How to reopen

If users want to *dismiss* a Health-derived marker in Tallyist without
touching the other app — "that day is wrong, but I can't edit that app any
more" — that is an override, not a removal: a record that says "the user set
this sample aside", kept so the sample cannot re-mark the day on a later walk.
Design it as its own change, the way ADR-0016 designed adoption; don't relax
read-only to get there. And if HealthKit ever distinguishes "recorded zero"
from "no data" by anything other than the value, the classification here
should read that instead.
