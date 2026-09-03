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

**Steps 1–4 are done, and the catalogs are populated.** As of 2026-08-28 four
catalogs carried **284 keys**: 221 in the app, 33 in the widget, 26 in the core
package, and 4 in a new `AppShortcuts.xcstrings`. Extraction and the committed
catalogs agreed exactly — zero missing, zero stale, verified key-set against
key-set.

**That count has drifted since, and the drift is hand-made.** Sessions without
a Swift toolchain cannot run the sync, so keys have been spliced into the files
directly, in the exact shape each one already uses. The app catalog went 221 →
228 with the RecentSummary plural work (PR #47), and ADR-0023 (the untyped
standard drink) took it to **235** while adding 2 to the widget's and 2 to the
core package's, and rewording one intent description in both app and widget.

Current: **321 keys** — 256 app, 34 widget, 27 core, 4 shortcuts (counted
2026-09-03 after ADR-0028's sync on top of ADR-0027's and ADR-0026's: the bar
detail's five keys in — the tip line, "No type", "1 drink" / "%lld drinks",
"No bar selected" — and "Days with nothing logged" relabelled "Days with no
drinks logged"; ADR-0027's sync had put "Through %@", "on days with drinks",
and "Share this year as an image" in and the translatable "Tallyist" out, and
replaced the policy's "Where your data can go" paragraph and its date line
with their reworded keys, both re-marked `shouldTranslate: false`, so the
count of marked keys is still 14; ADR-0026's sync had put twelve app keys in
— the summary window's picker and headings, the "—" average's spoken form,
the year caption, and the five legend words, which `Text(String)` had kept
out of the catalog until `DayIntensity.legendKey` — and the two year-footnote
keys out; the shared "%@, through today" key serves a month and a year and
may need splitting at translation time).

**"Extraction and the committed catalogs agree exactly" was re-established on
2026-09-02** by running the sync below against a clean build on a machine with
Xcode: every catalog came back byte-identical except for one reworded footnote
key. The hand-spliced keys were right. It remains a dated claim — an absent key
falls back to the key itself, so nothing breaks when it drifts — and the sync
should be repeated before a second language.
The core package's additions are the one part already pinned:
`PackageLocalizationTests` walks `DrinkType.allCases` and fails in CI if a
display name has no key.

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

**Fractional counts do not take plural variations yet — but they can.** Where the
count is fractional it currently reaches the catalog as `%@`, and a plural rule
cannot select a category from a string: a `stringsdict` rule fed one renders
`(null)`. That much is real.

The last clause of this paragraph used to say no numeric specifier could
reproduce `StandardDrink.formatted`'s variable decimals. That was wrong, and the
recipe is written down here so translation-time work starts from the answer
rather than re-deriving it. Asking the compiler what each shape emits:

| Interpolation | Specifier | Drives a plural rule? |
|---|---|---|
| `\(StandardDrink.formatted(c))` — a `String`, today's shape | `%@` | no |
| `\(c)` — the raw `Double` | `%lf` | yes, but renders `2.500000` |
| `\(c, format: .number.precision(.fractionLength(0...1)))` | `%@` | **no** — the intuitive fix does not work |
| `\(c, specifier: "%g")` | `%g` | **yes** |

`%g` drops trailing zeros, so on a value pre-rounded the way `formatted` rounds it
— `(c * 10).rounded() / 10` — it renders exactly what `formatted` renders: 1, 2.5,
2.4 from 2.44, 1.3 from 1.3333. Verified against the current output across that
range. `specifier:` compiles on `String.LocalizationValue` as well as
`LocalizedStringKey`, so the package helpers are not shut out of it.

Two things to check when doing it, neither of which blocks: `%g` resolved through
`String(format:locale:)` follows the locale's decimal separator, so a German build
would read "2,5" where today it always reads "2.5" — a fix, but a visible one; and
the pre-rounding must stay, since raw `%g` on 1.3333 renders "1.3333".

**Do this at translation time, not before.** The change only pays off once a
language with more than two plural categories exists, it cannot be verified
without one, and it moves display formatting — which is where this project's last
run of bugs lived.

**`RecentSummaryCard`'s captions carry no count, and that is now a decision
rather than an oversight** (2026-08-28). "3" and "days with drinks" are separate
views, so a caption cannot hold plural variations — a key can only take them if
the count is inside it. Putting it there would print the number twice, directly
under the 40-point one; taking it out of the caption would dismantle the
four-figure layout ADR-0006 exists to protect. A caption under a number is doing
different work from a sentence: the number carries the meaning and the caption
names it, so a translator into a language with more than two forms picks the one
that reads best. Documented at the call site, the way `Region.unitName(for:)`
documents its own limit.

Where that trade is *not* accepted is spoken. VoiceOver fuses each number into its
caption, leaving no adjacency to carry the meaning, so the two whole-number
figures now pass a single key holding the count — fully pluralisable. The two
fractional figures deliberately do not: their value reaches the catalog as `%@`,
so a separate key would be no more pluralisable than the caption and would add a
string to translate for nothing.

The same pass fixed a live English bug the card had carried: the totals caption
was `"\(region.unitNamePlural) total"`, always plural, so a total of exactly one
read "1 standard drinks total". It is four whole phrases per region and number
now. The two day figures had always agreed with their numbers; this one had
simply never been made to follow.

**A few strings are still unreachable**, held behind ComponentsKit model
properties that demand `String`; `ButtonVM.title` is the main one.

**The privacy policy stays in English — settled, not pending**
([ADR-0021](decisions/0021-the-privacy-policy-stays-in-english.md)). Its fourteen
strings carry `"shouldTranslate": false`, so they never reach a translator and
cannot drift from the hosted copy. `Privacy Policy` and `Read this policy online`
stay translatable — navigation and an affordance rather than claims, and the
former is shared with the Settings row and the Support link.

The reasoning in one line: the claims are written to be checkable against the
privacy manifest and entitlements, and that check only works in the language it
was written for. The hosted copy now says so itself instead of implying it.

`shouldTranslate` survives `xcstringstool sync` — verified, because a marking a
routine re-sync silently dropped would be worse than none. Only for a key that
did not change, though: editing a policy sentence makes a new key, which sync
creates unmarked. Re-mark it by hand in the same commit, and check the count
(`grep -c '"shouldTranslate" : false' DrinkTracker/Localizable.xcstrings` → 14).

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
