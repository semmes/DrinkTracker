# 0037 — A cocktail is measured as the whole drink in the glass

**Status:** accepted · **Date:** 2026-09-08 · **Supersedes:** the measurement
model of [ADR-0035](0035-cocktail-is-a-fifth-type-measured-by-its-spirit.md) —
its pills, its strength, its Custom wording and its export clause; the type
itself, its position, its Siri case, its glyph (ADR-0036) and beer's 40 oz
stand · **Relates to:** ADR-0005 (the one-drink default, landed a second way),
ADR-0015 (the export footnote loses a clause), ADR-0019 (a spoken size is now
the glass), ADR-0022 and ADR-0023 (what an older build does with the row),
ADR-0014 (whose refusal of invented precision this record knowingly sets
aside for one type) · **Source:** the owner's review of the shipped type
control, 2026-09-08 — *"the oz options should be 3oz, 4oz, 6oz, custom to
better represent a mixed drink rather than a shot of a spirit."*

## Context

ADR-0035 put Cocktail on the drink sheet the day before and chose, between two
models of the same arithmetic, to measure a cocktail by the spirit in it:
pills of 1.5, 2 and 3 oz spirit, 40% strength, a Custom field asking for
ounces of spirit. That record weighed the whole-drink model — "4 oz at 15%",
in so many words — and set it aside on the argument that a drinker knows the
pour and not the mix's strength. Its reopen clause named the case for the
whole-drink model as a field report that the wording did not hold.

The owner used the shipped control and ruled the other way before any field
report: the pills should be the sizes of a mixed drink, not the shots in one.
That is not the reopen clause's trigger, and this record does not dress it up
as one. It is the owner's product ruling on a control they had in hand, which
is what a review of a shipped surface is for. What "engaging the clause"
means here is that ADR-0035's analysis of this model — its trap and its cost
— is taken as read and accepted with eyes open, not argued away.

Flipping the volume leaves one question the request does not answer: what
strength a whole drink has. A pill that says "6 oz" at the spirit's 40% is
four standard drinks, which is not a mixed drink either, so the strength has
to move with the volume. Three answers were weighed:

- **15%, with 4 oz the default.** 4 × 0.15 is 0.6 fl oz of ethanol — the US
  standard drink exactly (ADR-0005), and exactly the ethanol in the 1.5 oz at
  40% that record settled for spirit. The derivation is one sentence: a
  standard pour, mixed and diluted to a 4 oz drink.
- **20% with 3 oz the default, or 10% with 6 oz.** Each is also exactly 1.0 at
  its own pill, but the first anchors to a stirred drink at a strength that
  under-states one by half (a martini is about 1.8 standard drinks in 3 oz,
  near 30%), and the second is right only for a single pour in a tall glass.
- **A per-pill strength** — a 3 oz pill that also raises the slider to 30%.
  Rejected: a size pill that silently changes the strength hides the
  arithmetic the sheet exists to show, and no pill anywhere else does it.

## Decision

**A cocktail is the whole drink in the glass.** Its pills are "3 oz", "4 oz",
"6 oz" and Custom — the three sizes the owner named: a short stirred drink, a
shaken one, a tall one — with no vessel noun, because no one vessel fits a
mixed drink the way "can" fits a beer. **The default is 4 oz at 15%**: the
middle pill, exactly one US standard drink, and the same 0.6 fl oz of ethanol
as spirit's default pour because it *is* that pour, mixed to a glass. The
strength slider keeps its 0–60% range, since a spirit-forward drink is still a
cocktail. The Custom field asks for **"Ounces in the glass"** — the noun that
carries the model, at the one place its trap opens — over the plain "oz" unit
every other type uses. The Export footnote drops ADR-0035's clause and returns
to its 2026-09-02 wording, because a cocktail's two columns are now the same
shape as every other typed drink's.

Everything else ADR-0035 decided stands: the type, its position between spirit
and other in every ordered list, the Siri case, the glyph, and the 40 oz.

## Consequences

### What this buys

- The pills say what a person sees — the size of the drink in their hand — in
  the vocabulary every other type's pills already use. A row reads
  "Cocktail · 4oz · 15%", Siri says "Logged: Cocktail, 4oz, 15% ABV", the CSV
  holds 4 and 15: a drink, not a shot. ADR-0035's cost bullet about presenting
  the spirit's facts as the drink's is gone, and so is the footnote clause
  that covered it.
- The two-tap path is still exactly one drink (ADR-0005, landed a second way),
  and the invariant's test gains a second pin: the cocktail's default and
  spirit's hold the same ethanol by construction, not merely to the same
  rounding.
- Nothing downstream changed. Same two facts in the row, same arithmetic, same
  repeat, template, adopt and export behaviour; an older build still decodes
  the row to `.other` with the arithmetic intact (ADR-0035's own analysis).
  **No schema change, no CloudKit step, no setting.**

### What it costs, honestly

- **The 15% is an estimate, and it is right for exactly one shape of drink**: a
  single 1.5 oz pour mixed to 4 oz. A stirred drink at 3 oz runs near 30%, and
  the pill reads 0.75 drinks at 15% — under by about half for a martini. A
  single pour in a 6 oz tall glass runs about 10%, and the pill reads 1.5 —
  over by half. The slider corrects both and the live estimate shows the
  number move, but the two-tap path is honest only for the middle case.
  ADR-0035 called this "invented precision" and refused it; this record
  accepts it on the owner's ruling, because the alternative — asking for the
  pour — is the model it replaces.
- **The plausible under-count is now live.** A user who knows their pour was
  1.5 oz and types it into Custom records 0.375 drinks, and "≈ 0.4 standard
  drinks" does not look wrong the way 5.3 did. This is the trap ADR-0035
  identified for this model, and under-counting is the failure ADR-0005 names
  as the one this product exists to prevent. The defence is the field's own
  wording; the escape for someone who genuinely knows their pour is Custom
  plus the slider — 1.5 oz at 40% reads 1.0 exactly, as spirit does — or the
  Spirit type itself.
- **Rows recorded under ADR-0035's model keep their facts and change their
  reading.** A "Cocktail · 1.5oz · 40%" row written by a 1.3 pre-release build
  is still a true fact about the spirit and totals the same, but now reads as
  a very small, very strong drink. No App Store build has carried the type,
  so no user holds one; the owner's test devices may.
- **Siri's size parameter is the glass, not the pour.** "Log a 2 oz cocktail"
  lands on Custom at 15% (0.5 drinks) where it found the "2 oz spirit" pill
  (1.33) the day before. The intent records what was said, as the sheet does.
- **The neutral contract is a step further behind.** `semmes/tallyist-product`
  still enumerates four types (ADR-0035's own note), and the fifth's model has
  now changed once before the contract ever saw it.
- Three app-catalog keys retire — "Ounces of spirit", "oz spirit", and the
  footnote ADR-0035 reworded — and two enter — "Ounces in the glass" and the
  footnote's restored 2026-09-02 self: 303 → 302. The pill labels stay outside
  every catalog (the standing size-axis deferral).

### What pins it

Tier 1: `DrinkTypeDefaultsTests.defaultsTable` (4 and 15),
`defaultsHitTheOneDrinkInvariant` (1.0, and equal to spirit's ethanol),
`defaultPillMatchesDefaultVolume` ("4 oz" — the first type whose default pill
is not its first), `sizeOptions` (volumes 3, 4, 6, Custom; labels exactly
"3 oz", "4 oz", "6 oz"; no label says "spirit"), `IntentDraftTests.cocktailIntent`
(a spoken 6 finds its pill; a spoken 1.5 is Custom at 0.375),
`LogExportTests.cocktailRow` (`Cocktail,4,15,1`). Tier 2:
`DrinkRepositoryTests.cocktailRoundTripsAndUnknownTypeDegradesToOther` over
the new facts. Tier 3, on the simulator: the four pills with "4 oz" selected,
"15% ABV", "≈ 1 standard drink", the Custom placeholder, the row on Today.
Tier 4, for the owner: the pills on a real display beside the other types',
and a spoken cocktail size.

## How to reopen

- A field report that people's cocktail totals run low — the plausible
  under-count arriving — is the case for a per-type row wording or for asking
  the strength rather than assuming it. ADR-0035's spirit-pour model is the
  costed alternative, and its record is intact.
- Vessel nouns on the pills ("3 oz short", "6 oz tall"), if the owner wants
  them to read like beer's, are one label each; `DrinkSizeOption.id` is the
  label, so they need only stay unique within the type.
- A region whose standard drink no 4 oz default can land on is ADR-0005's own
  reopening condition.
