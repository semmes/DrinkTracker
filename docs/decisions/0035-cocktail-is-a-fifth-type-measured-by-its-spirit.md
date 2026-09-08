# 0035 — Cocktail is a fifth drink type, measured by the spirit in it; beer offers the 40 oz bottle

**Status:** accepted · **Superseded in part by:**
[ADR-0037](0037-a-cocktail-is-measured-as-the-whole-drink.md) (2026-09-08),
which moved the measurement to the whole drink on the owner's review of the
shipped control — the pills, the strength, the Custom wording and the export
clause decided below are history; the type, its order, its glyph and the 40 oz
stand · **Date:** 2026-09-07 · **Relates to:** ADR-0005 (its
"adding a type later" clause, exercised here for the first time), ADR-0009 and
ADR-0023 (the seeds; `.unspecified` stays outside the picker), ADR-0022 and
ADR-0023 (what an older build does with a row it cannot name), ADR-0015 (the
export's footnote), ADR-0019 (the Siri enum), ADR-0036 (the glyph the type
wears) · **Source:** the owner's request, 2026-09-07; the *Drink Icons* canvas
(`docs/design/icons/`) had drawn the cocktail as a candidate and said in so
many words that adding it "is a product decision — it needs a default
size/ABV, a Siri entity, and a localized name."

## Context

The owner asked for a Cocktail category on the drink sheet's type control, and
for a 40 oz pill under beer. The second is a size list growing by one entry.
The first is a new kind of drink, and the question a new kind has to answer is
what its two physical facts *mean* — because the log stores a volume and a
strength for every typed drink and computes everything else from them
(`StandardDrink.count`), a cocktail is whatever pair of numbers the app decides
to ask for.

Two models were on the table, and they are the same arithmetic with a
different anchor:

- **The spirit in it.** A cocktail is 1.5 oz of spirit at 40% by default, the
  bar-standard pour, and its sizes are pours: 1.5, 2, 3 oz of spirit. Volume
  means what was poured; strength means the bottle's.
- **The whole drink.** A cocktail is, say, 4 oz at 15%: the glass's contents
  at a mixed strength. Volume means the glass; strength means an estimate of
  the mix.

Both satisfy ADR-0005's rule that a new type "either lands on 1.0 at its
default or documents why it doesn't" — 1.5 × 0.40 and 4 × 0.15 are each 0.6 fl
oz of ethanol, the US definition. So the rule does not decide it. What decides
it is which pair of numbers a person can actually state about the drink in
their hand. A drinker knows the pour ("a double", "a 2 oz Old Fashioned") and
the bottle's strength is printed on it; almost nobody knows a cocktail's mixed
ABV, and a glass's volume is nearly uncorrelated with the alcohol in it — a
highball is 1.5 oz of spirit in 8 oz, a martini is 3 oz in 3 oz. The whole-drink
model's 15% is a number no one measured, which is the "invented precision"
ADR-0014 refuses for imports.

Each model has a trap where the user types into Custom what the other model
asks for. Under the whole-drink model, a user who knows their pour was 1.5 oz
types it and gets 0.4 drinks — a 62% under-count that *looks plausible*, and
ADR-0005 says under-counting is the failure this product exists to prevent.
Under the spirit model, a user who types the glass (8 oz at 40%) gets 5.3
drinks — an over-count, and one the live estimate makes obviously wrong.
Wrong-and-visible beats wrong-and-plausible, and the visible trap can be
closed almost entirely by wording at the one place it opens.

The competing option for the 40 oz was to leave beer at "the two common cases"
— the rule under which the 22 oz bottle was dropped — and let the forty stay a
Custom entry. The owner asked for the pill by name; the forty is a size people
buy and call by its number, and spirit already carries three pours, so the
two-case rule was a habit of that row rather than a principle.

## Decision

**A fifth selectable type, `DrinkType.cocktail`, measured by the spirit in
it.** Its default is 1.5 oz at 40% — exactly 1.0 US standard drink, the same
fact spirit rests on (ADR-0005), and it re-expresses under the region lens like
any spirit (1.75 UK units). Its pills are "1.5 oz spirit", "2 oz spirit",
"3 oz spirit" and Custom; every label carries the noun, and for a cocktail the
Custom field asks for "Ounces of spirit" with "oz spirit" as its unit, so the
word that carries the model is present exactly where the glass-size trap
opens. The strength slider runs 0–60% as spirit's does. The type sits between
spirit and other in `selectableCases`, in `allCases`, and in Siri's
`QuickLogDrinkType`, so the picker, the Trends composition rows, the seed
tie-break and the disambiguation list agree on one order. Its name is
"Cocktail", localized through the package's catalog like the other four.

**The export says what a cocktail's columns are.** The CSV is the one surface
read across a desk from someone else (ADR-0015), so the Export footnote gains
the clause: "for a cocktail they are the spirit poured and its strength". The
columns themselves are unchanged — `volume_oz` and `abv_percent` hold the two
facts the user stated.

**Beer offers the 40 oz bottle**, after the can and the pint, with the default
unchanged. The 22 oz stays out.

## Consequences

### What this buys

- A person who orders cocktails can say so, and the sheet asks them the one
  thing they know — how much was poured — rather than a strength they would
  have to invent. The default is one drink, so the two-tap path stays honest.
- Everything downstream needed no new rule: a cocktail row is a typed drink
  with a real volume, so it repeats (ADR-0022's `isRepeatable`), templates the
  day (ADR-0023), adopts an import (ADR-0016), exports, and joins every total by
  the same arithmetic as spirit. The Trends composition gains a row in
  `allCases` order and the Siri phrase "Log a cocktail in Tallyist" exists by
  virtue of the enum.
- The forty is one tap where it was a typed number.

### What it costs, honestly

- **Rows, Siri's reply and the CSV present the spirit's facts as the drink's.**
  A Today row reads "Cocktail · 1.5oz · 40%", Siri says "Logged: Cocktail,
  1.5oz, 40% ABV", and the file's columns hold 1.5 and 40. The arithmetic is
  exactly right and the two numbers are the ones actually stated, but a reader
  may take the volume for the whole pour. The footnote clause covers the file;
  the rows are left as they are, with a per-type wording ("1.5oz spirit · 40%")
  as the costed alternative if a field report says the row misleads.
- **Multi-spirit and liqueur drinks are not a pill.** A Negroni, a Long Island,
  a spritz are Custom plus the slider (a spritz is, say, 5 oz at 11%); a user
  who picks a pill for one records a spirit-strength pour that may be off in
  either direction. This is the same class of approximation the beer and wine
  pills already make, recorded rather than built around.
- **An older build mislabels the row, and can make it permanent.** The store
  keeps the type as its raw string, and every shipped build (1.0–1.2) decodes an
  unknown one to `.other` (`DrinkEntry.logged`). On such a device a cocktail
  reads "Other, 1.5oz, 40% ABV" — an odd row whose arithmetic is exactly right,
  ADR-0023's chosen degradation, not ADR-0022's zero-volume one — and it casts
  an *Other* vote in `mostLoggedType`, so a two-device household on the
  usual-drink seed can seed differently until both update. If that build edits
  or repeats the row, it rewrites it as a genuine Other entry, which the updated
  build then shows as Other; that goes by hand from History. Not repairable by
  shipping. **No schema change, no CloudKit step, no new setting.**
- **The tie-break moves only where a cocktail is involved.** `allCases` order
  breaks ties in the seed, so cocktail loses one to spirit and wins one against
  other; a log with no cocktail resolves exactly as before. Pinned in
  `CalendarTests.tiesAreStable`.
- **The pill labels are outside every string catalog.** `DrinkSizeOption.label`
  is a plain `String` rendered verbatim, the standing deferral
  `docs/localization-status.md` records; "40 oz bottle" and the three cocktail
  labels join it. The sheet's "Ounces of spirit" and "oz spirit" are not in
  that gap — they are `LocalizedStringKey`s and land in the app catalog; only
  the pills are verbatim.
- **Beer's size row wraps to two lines at the default size** on a 393pt
  screen — four pills where there were three. Spirit already did; beer now
  does. The 40 oz at beer's default 5% is 3.33 standard drinks in one tap: a
  correct figure for one physical bottle, and the first pill in the app whose
  default lands a single entry in the calendar's 3–5 band. No 1.4.3 exposure
  was found in that (a size is a size), and the reasoning is in the copy
  review so it is on record.
- **The neutral contract is behind again.** `semmes/tallyist-product` v1.7.0
  enumerates `beer / wine / spirit / other / unspecified` in
  `domain/entities.md`. It joins ADR-0033's longest run and ADR-0034's four-band
  ramp as iOS decisions the contract has not caught up with; bumping it is a PR
  in that repo, and the standing merge authorization is this one's.

### What pins it

Tier 1: `DrinkTypeDefaultsTests.defaultsTable`, `defaultsHitTheOneDrinkInvariant`
(cocktail is in the 1.0 loop), `defaultPillMatchesDefaultVolume` ("1.5 oz
spirit"), `sizeOptions` (the four cocktail pills with the " oz spirit" suffix;
beer's four with the forty and without the 22), `everyPillHasVolume` (no pill
can record zero volume — ADR-0022 by construction), `neverSelectable` (the
order, literally), `IntentDraftTests.cocktailIntent`,
`LogExportTests.cocktailRow`, `PeriodDetailTests` (the composition row order),
`CalendarTests.tiesAreStable`. Tier 2: `DrinkRepositoryTests.cocktailRoundTripsAndUnknownTypeDegradesToOther`
(the raw value round-trips; an unknown one reads back as Other with its facts
intact — the mechanism the whole cross-version argument rests on). The Siri
mirror has no test at any tier: the test bundle does not compile
`Shared/LogDrinkIntent.swift`, so `QuickLogDrinkType` is out of reach there,
and a test written for it was dropped for that reason; the two exhaustive
switches in that enum (`init(_:)` and `drinkType`) are the guard, and the
compiler is what enforces it. Tier 3, on the simulator: the five-segment
picker, the cocktail pills, the forty. Tier 4, for the owner: "Log a cocktail
in Tallyist" spoken to Siri, and the Shortcuts app's parameter list showing
the fifth type.

## How to reopen

- A field report that people type glass sizes into a cocktail's Custom field
  despite the wording is the case for the per-type row wording first, and for
  the whole-drink model only if the wording does not hold — that model's own
  trap is the plausible under-count, which is the worse failure.
- A region whose standard-drink definition no cocktail default can land on is
  ADR-0005's own reopening condition, not a new one.
- Localizing the size axis (the `String` labels) is the standing localization
  deferral; the four new labels do not change its terms.
