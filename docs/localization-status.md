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

**Step 1 is done.** An Xcode build extracted the 1.2-era strings: the app
catalog went 82 → 109 keys, the widget's 16 → 25. What did *not* extract is
the map for steps 2 and 3 — anything assembled by a String-returning helper,
because `Text(String)` is the verbatim initializer rather than the
localizable one.

**Step 4 is decided and done** — the package owns its display names and
localizes them against `Bundle.module`
([ADR-0020](decisions/0020-the-core-package-owns-its-display-names.md)),
which also settles how the CSV export behaves: headers stay English, row
values localize.

**Steps 2 and 3 remain**, and they are the same job seen twice: roughly
thirty String-returning helpers across the app assemble sentences by
interpolation, which freezes English word order and hides the strings from
the catalog. Converting each to a whole-phrase key is step 2; giving the
count-bearing ones real plural variations is step 3.

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
