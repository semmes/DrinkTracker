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

## Amendment, 2026-09-18 — what `swift test` puts in the bundle depends on the build system

The first consequence above says SwiftPM copies `.xcstrings` into the bundle
verbatim. That was a fact about SwiftPM's *native build system*, not about
SwiftPM. From Swift 6.4 (Xcode 27.0) `swift test` builds with Swift Build —
Xcode's engine — by default, and it treats the catalog as Xcode always has.
Read from both builds' products, same sources, on one Mac:

| | native (Swift 6.3.3, Xcode 26.6) | Swift Build (Swift 6.4, Xcode 27.0) |
|---|---|---|
| products | `.build/arm64-apple-macosx/debug` | `.build/out/Products/Debug` |
| the bundle | flat | `Contents/Resources/`, code-signed |
| the catalog in it | `Localizable.xcstrings`, verbatim | `en.lproj/Localizable.strings`, compiled, all 28 keys |
| `xcstringstool generate-symbols` | not run | run over the source catalog |

On Swift 6.4, `--build-system native` still produces the left column, which is
how the build system was told apart from the compiler: one compiler, one set of
sources, 292 passing under native and 290 under the default. The flag prints
that it is deprecated and will be removed, so it is a way to check both shapes
locally and not a fix.

**What broke, and the fix.** Two tests in "Package localization" parsed the
catalog out of `Bundle.module`, and failed where there is no `.xcstrings` to
parse — locally under Xcode 27, while CI's domain job, on the runner image's
default Xcode 26.6, stayed green. They now read the catalog from the source
tree, relative to `#filePath`. That is the file they were always about: the keys
a person typed, and the file `generate-symbols` reads. The bundle was a route to
it that one build system happened to offer. No scheme or test plan includes the
package's tests, so `swift test` from a checkout is the only way they run, and a
compile-time path holds there. `bundleCarriesTheCatalog` still checks the
bundle, in whichever form it takes.

**Two alternatives, probed rather than argued.** Declaring the catalog a second
time as a `.copy` resource of the test target builds on Swift 6.4, and gives that
target a `Bundle.module` of its own, which shadows the package's inside the
tests under both build systems — with no diagnostic. `bundleCarriesTheCatalog`
then passes while inspecting `DrinkTrackerCore_DrinkTrackerCoreTests.bundle`: the
name contains "DrinkTrackerCore" and the copied catalog is in it, so the one test
that guards the package's real bundle would guard nothing. Trying the bundle
first and falling back to the source tree leaves which path ran to the
toolchain, which is the disagreement this removes.

**The tests still fail when they should.** In a scratch copy, under each build
system, the untouched catalog passes all 292, and each of these turns the run
red: adding ADR-0023's "Standard drink", deleting "Cocktail", adding a
positional key, emptying the strings table, renaming the file. Under Swift Build
the collision never reaches its test — `generate-symbols` fails the build first,
with the error that once failed CI — so there the test is a second guard; under
native nothing generates symbols and it is the only one at tier 1. Under native
the renamed catalog's predecessor also stayed in the bundle from the build
before, so a bundle read can pass on a file the source no longer has.

**The consequence this changes.** "`swift test` resolves every lookup to its
key" is now true only under native; under Swift Build a lookup goes through the
compiled table. For English that is the same text — 27 of the 28 values are
their keys, and the summary line's positional value renders identically, which
is why the same 292 tests pass on both — so CI is still unaffected today. It
stops being free when a second language lands: with a French value added in a
scratch copy, Swift Build put `fr.lproj/Localizable.strings` in the test bundle
and native compiled nothing. Under native the exact-English assertions could
never meet a translation; under Swift Build they can, on a Mac whose language
has one. That last step is ordinary bundle behaviour and was not measured here.
CI's runners are English, so it would first show on a translator's own machine
— worth knowing before step 5 of `docs/localization-status.md` begins.

## How to reopen

- If the domain ever needs a string that is genuinely *presentational* —
  phrasing that belongs to one screen rather than to the concept — that
  string belongs in the app catalog, not here. The test that pins the key set
  is the tripwire.
- If a scripted consumer of the CSV appears and needs stable *values* as well
  as headers, add a machine-readable column (a raw enum value) rather than
  un-localizing the human one.
