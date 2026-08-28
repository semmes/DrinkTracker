# 0020 — The core package owns its display names, and the export splits headers from values

**Status:** accepted · **Date:** 2026-08-28 · **Amends:** ADR-0015 ·
**Relates to:** PRD invariant 9, `docs/localization-status.md` step 4

## Context

`docs/localization-status.md` left one question open before any translation
could begin: **where do `DrinkType.displayName`, `Region.unitName`, and
`LoggedDrink.summaryLine` live?** They sit in `DrinkTrackerCore`, and the note
recorded the obstacle plainly — the package "has no bundle to localize
against, so these either move to the app layer or the package gains its own
resources."

Two things have changed since that was written.

**The package now has a bundle.** Feature C (ADR-0018) added
`resources: [.process("Resources")]` for the population-reference JSON, so
`Bundle.module` already exists. The option that used to cost a new resource
target now costs a `defaultLocalization` line.

**More things read those names.** They are no longer app-only: `LogExport`
(also in the package) writes drink types into the CSV, and the App Intents
(ADR-0019) speak `summaryLine` aloud through Siri.

## Decision

**The package keeps its display names and localizes them itself**, through
`String(localized:bundle: .module)` behind a small `localized(_:comment:)`
helper, with the keys in `Sources/DrinkTrackerCore/Resources/Localizable.xcstrings`.
(User decision, from two options presented.)

Moving them to the app layer was the stricter reading of invariant 9, and it
was rejected on a concrete consequence rather than on taste: `LogExport` lives
in the package, so an app-owned name table would leave the exporter unable to
name a drink type at all — it would need names injected through every call,
which is a wider change that buys nothing the user can see.

**Invariant 9 still holds.** It bars UI and persistence, and its stated reason
is testability: the domain must compile and be testable without Xcode. A
string table is neither UI nor persistence, and it imports only Foundation.

**Sentences are whole keys, never assembled fragments.** `summaryLine` and
`liveEstimate` each resolve one key with their arguments in place, so a
translation can reorder them. The nouns (`unitName`, `unitNamePlural`) stay
available for composition, but `unitName(for:)` documents its own limit: it
picks between two forms by English's rule, and a language with more plural
categories needs the count and the noun in a single key. That is why
count-bearing sentences are keys at their call sites.

### The CSV export: headers no, values yes

ADR-0015 pinned the CSV's column layout as a public contract *and* said the
file's audience is people. Localization forces those two apart, so this
record amends it with an explicit split (user decision, from three options):

- **Column headers never localize.** `date,time,entry,…` is the
  machine-readable half; a script keyed on `standard_drinks` must keep working
  in any language. Pinned by a test.
- **Row values do localize** — drink types, "No alcohol recorded", "Imported
  drink", unit names — because a French user hands a French doctor a French
  document.
- **Product names are neither.** "Tallyist" and "Apple Health" stay
  as-written; translating a source column would make provenance harder to
  read, not easier.

## Consequences

- **CI is unaffected, for a reason worth knowing.** SwiftPM copies
  `.xcstrings` into the bundle verbatim, while Xcode compiles it to
  `en.lproj/Localizable.strings` (verified in a built app). So `swift test` on
  CI resolves every lookup to its key — which *is* the English source string —
  and the 118 domain tests keep asserting exact English with no locale setup.
  The shipping app gets the compiled table.
- A missing catalog entry is invisible at runtime: the lookup falls back to
  the key and the app looks fine, while a translator receives a file with half
  the app absent. A test therefore asserts that every name the code produces
  is a key in the catalog.
- Two catalogs now exist (package and app). The split is by ownership, not by
  convenience: if the type knows the name, the package holds the string.
- Adding a language means adding translations to both, and the CSV changes
  language with the app — which is the intent, and is now stated in the
  export's own documentation.

## How to reopen

- If the domain ever needs a string that is genuinely *presentational* —
  phrasing that belongs to one screen rather than to the concept — that
  string belongs in the app catalog, not here. The test that pins the key set
  is the tripwire.
- If a scripted consumer of the CSV appears and needs stable *values* as well
  as headers, add a machine-readable column (a raw enum value) rather than
  un-localizing the human one.
