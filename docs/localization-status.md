# Localization status

**Honest summary: the app is not localized, and this document is about what was done
to make localizing it possible rather than about having done it.**

## What's in place

**String Catalogs exist.** `Localizable.xcstrings` ships in both targets, currently
empty. `SWIFT_EMIT_LOC_STRINGS` was already `YES` on every configuration, so
`Text("…")` literals are already emitted as localizable strings — **the next Xcode
build populates both catalogs automatically.** That step needs Xcode; it cannot be
done from a machine without it, which is why the files are committed empty.

**Plural forms are declared, not derived.** Six call sites used to build a plural by
appending `"s"` to `Region.unitName`. `Region` now declares `unitNamePlural` and
`unitName(for:)`, and everything routes through those.

That claim was false until 2026-08-28: a seventh site, the VoiceOver label on the
drink sheet's live estimate, still appended a literal `"s"` outside the
interpolation — welding English morphology onto a noun the package had already
translated. It is fixed, and the lesson is that "everything routes through those"
is a claim worth re-checking mechanically rather than asserting.

That is not localization. Appending `"s"` is an English rule applied by string
surgery, and it fails on an irregular noun and fails completely in languages with
more than the two plural categories English has. Centralising it means a catalog has
**one** place to replace rather than six, and a test pins that both forms exist and
differ for every region.

**Formatting is already locale-aware.** Dates go through `.formatted(.dateTime…)`,
and the calendar derives its first weekday and weekday symbols from `Calendar` rather
than assuming a Sunday-first week — tested both ways.

## What is not done

**No translations.** Source language is English and there is exactly one language.

**Interpolated strings still assume English word order.** `"\(count) drinks today"`,
`"Another \(type)"`, and similar build sentences by concatenation. Word order is not
universal, and neither is putting the number first. These need to become catalog keys
with positional format specifiers before any translation is meaningful.

**Ternary pluralization remains at the view layer.** `RecentSummaryCard` still
chooses between two hardcoded phrases on `== 1`. Correct for English, wrong for
most target languages, and the right fix is catalog plural variations — which
requires the catalog to be populated first. (`DayLogSheet` lost its ternaries in
the ADR-0013 rewrite, but its new interpolated captions — "Plus logs a
\(type), \(oz)oz at \(pct)% …" — are fresh instances of the word-order problem
above.)

**`DrinkType.displayName` and `Region.displayName` are English literals** in the
domain package. `DrinkTrackerCore` has no bundle to localize against, so these either
move to the app layer or the package gains its own resources.

## Progress (2026-08-28)

**Steps 1–4 are done, and the catalogs are populated.** Four catalogs now carry
**284 keys**: 221 in the app, 33 in the widget, 26 in the core package, and 4 in a
new `AppShortcuts.xcstrings`. Extraction and the committed catalogs agree exactly
— zero missing, zero stale, verified key-set against key-set.

**How the catalogs get populated, since this cost a lot of confusion.** A build
from the command line does *not* write extracted strings back into `.xcstrings`.
It emits `.stringsdata` and stops; the write-back is an Xcode GUI behaviour. That
is why several "I built and nothing happened" sessions were not doing anything
wrong. The step is reproducible without the GUI:

```
xcrun xcstringstool sync <Catalog>.xcstrings --stringsdata <every .stringsdata for that target>
```

Two traps in that command. The **filename picks the string table** — syncing a
file named `app.xcstrings` looks for a table called `app`, finds none, and empties
the catalog. And an incremental build re-extracts only what it recompiled, so
force a full rebuild first or the sync will prune every key whose file did not
compile.

**Step 4 is decided and done** — the package owns its display names and localizes
them against `Bundle.module`
([ADR-0020](decisions/0020-the-core-package-owns-its-display-names.md)), which
also settles the CSV export: headers stay English, row values localize.

**Steps 2 and 3 are done.** Roughly thirty display helpers moved from `String` to
`LocalizedStringKey` (and the Siri dialogs to `LocalizedStringResource`).

**A silent lookup failure was found and fixed.** The core catalog filed the drink
summary line under `%1$@, %2$@oz, %3$@%% ABV`. `String.LocalizationValue` builds
its key with plain `%@` in source order, so the lookup was for a different string,
missed, and fell back to the key itself — which *is* the interpolated English, so
nothing looked wrong and a translation would simply never have appeared.
**Positional specifiers belong in a localization's value, never in a key.** A test
now rejects any key containing one.

**Eight further defects were found by audit and fixed**, all of the same family —
a sentence assembled at the call site instead of being one key:

| Site | Was | Now |
|---|---|---|
| `SectionLabel` | `let text: String` → `Text(text)`, the verbatim initializer | takes `LocalizedStringKey`; recovers ten headings and a singular/plural pair |
| `QuickLogWidget` | `countLabel: String`, so the widget's own caption reached no catalog | `LocalizedStringKey`; accessibility label is a whole key per branch |
| `TodayView`, `DayLogSheet` | hand-rolled `"≈ %@ %@"`, a placeholder-only key | `StandardDrink.liveEstimate` |
| `IntensityCell` | `"%@, %@"`; no singular branch; hardcoded English unit | region-aware `amountPhrase`; non-today branch composes verbatim |
| `DrinkDetailSheet` | `unitName` + literal `"s"` | `StandardDrink.accessibleEstimate` |
| `PopulationReferenceCard` | noun injected as a bare placeholder | one whole key per region and number |
| `SessionPaceCard` | singular chosen on `count == 1` exactly | chosen on the digits actually displayed |

**The rounding rule that kept recurring.** Several of those picked the noun's form
from the raw value while showing a rounded one, so 1.02 drinks read "1 standard
drinks" — and one standard drink at the default size is the most common logged day
there is. `StandardDrink.readsAsOne` is now the single definition of that rule.

## What is still not done

**No translations.** Source language is English and there is exactly one language.

**Plural variations are not filled in.** Count-bearing sentences are whole keys per
branch, which is what lets a catalog carry real variations — but the variations
themselves are a per-language job in Xcode's catalog editor, done at translation
time.

**Some counts cannot take plural variations at all.** Where the count is
fractional it reaches the catalog as `%@`, and a plural rule cannot select a
category from a string — a `stringsdict` rule fed a string renders `(null)`.
`SessionPaceCard` documents this at the call site. It is a real limit, not an
oversight: `StandardDrink.formatted` renders a variable number of decimals and no
numeric specifier reproduces that.

**`RecentSummaryCard` splits counts from their nouns.** "3" and "days with drinks"
are separate views, so the four labels carry no count and can take no variation.
Fixing it means restructuring the card, which changes visible copy — a decision,
not an edit.

**A few strings are still unreachable**, held behind ComponentsKit model
properties that demand `String`; `ButtonVM.title` is the main one.

**The privacy policy is now extractable, which is a decision to make before
translating.** Typing `SectionLabel` as a key required `policySection` to follow,
so the policy's headings and body paragraphs are now catalog keys. Nothing forces
them to be translated — a catalog can mark a string as not for translation — but
the claims in that text are written to be checkable against the entitlements and
the App Store privacy labels, and a mistranslation would misstate them. Decide
deliberately, and keep `docs/privacy-policy.md` in step.

**Auto-generated comments are missing on the new keys, and a build will not add
them.** Xcode writes translator comments when *it* is the thing adding a key to a
catalog. `xcstringstool sync` added them first, so a subsequent GUI build found
nothing new and generated nothing — confirmed by building the pulled tree in
Xcode on 2026-08-28, which produced no catalog change at all. The 81 pre-existing
comments were preserved by the sync; the ~140 new keys have none and will not
acquire any from building.

That is the one real cost of the sync route, and it is a mild one: comments are
translator hints, not content, and Xcode's catalog editor can add them by hand.
The same build produced no catalog change of any other kind, which is the
confirmation that sync writes what the GUI would.

## The order to do it in

1. Build in Xcode once. Both catalogs populate from the existing literals.
2. Convert the interpolated sentences to catalog keys with positional specifiers.
3. Replace the `== 1` ternaries with plural variations in the catalog.
4. Decide where `displayName` lives — app layer, or resources in the package.
5. Only then add a second language.

Steps 1–4 are prerequisites. Translating before them produces strings that are
grammatical in English and broken everywhere else.

## Why this is worth doing at all

The app ships three regional definitions of a standard drink — US, UK, Australian —
so it already assumes users outside one country. Shipping an English-only interface
to a feature set built around international differences is an odd place to stop.
