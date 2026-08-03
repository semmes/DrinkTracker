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

**Ternary pluralization remains at the view layer.** `RecentSummaryCard` and
`DayLogSheet` still choose between two hardcoded phrases on `== 1`. Correct for
English, wrong for most target languages, and the right fix is catalog plural
variations — which requires the catalog to be populated first.

**`DrinkType.displayName` and `Region.displayName` are English literals** in the
domain package. `DrinkTrackerCore` has no bundle to localize against, so these either
move to the app layer or the package gains its own resources.

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
