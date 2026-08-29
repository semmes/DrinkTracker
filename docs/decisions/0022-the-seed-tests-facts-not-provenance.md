# 0022 — The quick-log seed tests physical facts, not provenance

**Status:** accepted · **Date:** 2026-08-29 · **Relates to:** ADR-0009,
ADR-0014, ADR-0016, PRD invariant 7

## Context

Count-first logging (ADR-0009) means the "+" has to answer "one more of what?"
on the user's behalf. `DrinkDraft.quickCount` answers it from the log: the
type logged most often, at the size and strength it was last logged at.

Health import (ADR-0014) put a shape into the store that is not a drink anyone
described — `type .other`, 0 oz, 0% — and the same commit taught the two seed
helpers to skip it, filtering on `isImportedFromHealth`. That guard is correct
and it has held. It is also **provenance-based**, and provenance is the part
that does not survive contact with a real installation:

`countedDrinks` is an additive optional, mirrored to CloudKit with no
migration plan (`Shared/SchemaVersions.swift`, `stages: []`), which is exactly
what makes it a safe schema change. The cost of that safety is that a build
which predates the attribute cannot see it. When one account has both — a 1.1
TestFlight build on one device and App Store 1.0 on another, which is the
ordinary state of affairs while a version is in review — the 1.0 side
materialises every imported row as an ordinary `.other` drink at 0 oz and 0%.
1.0's seed helpers have no filter at all, so `.other` takes the plurality (the
first anchored Health query walks *all* history, so a single sweep can mint
hundreds of rows), the newest one becomes the template, and every automatic
surface — Today's +, the widget, the day sheet, bulk fill — writes 0 oz / 0%
drinks under it. Each write adds another `.other`, so the fault is absorbing:
it never self-corrects, and the counter and the standard-drink figure beneath
it disagree permanently.

This was reported from the field, not found in review.

The competing option is to leave the rule as it is and treat this as a
cross-version artefact that resolves itself once every device is on 1.1+. That
is a real argument: the marker guard is precise, it names the actual concept
("this row is a mirror"), and a fact-based test is a proxy. But a proxy that
cannot be defeated by a schema gap is worth more here than a name that can,
and this will not be the last additive attribute.

## Decision

**A drink with no volume is never the template for another drink.**
`LoggedDrink.isRepeatable` is `volumeOunces > 0`, and `quickCount` requires it
before repeating: when the most recent drink of the winning type fails the
test, the seed falls through to *that type's* defaults rather than to beer, so
a habitual Other drinker still gets Other. The marker-based filters in
`mostLoggedType` / `mostRecentDrink(ofType:)` stay exactly as they are — this
is a second, independent test, not a replacement.

**Volume is the test; strength is not.** A real size at 0% is a drink someone
chose to record that way, and rewriting it to the type's default strength
would log alcohol they did not have — the log may under-record, never
over-record. Volume separates the two cases exactly: the detail sheet refuses
to save a drink without one (`canLog`), so a zero volume is never something a
user typed, and `LoggedDrink.importedFromHealth` is the only constructor in
the codebase that produces one.

Two ADR-0014 leaks on the Today screen close with it: the repeat control took
its template from the newest row of the day with no filter at all — rendering
"Another other · 0oz · 0%" and writing exactly that on a tap — and Today's
"Logged today" rows offered tap-to-edit, swipe-Edit and swipe-Remove on
imported entries, which History and the day sheet have always refused. Remove
was the sharp one: it reaches `health.deleteSample(id:)` on another app's
sample UUID. Today now mirrors History's branch, adoption included
(ADR-0016).

## Consequences

The reported symptom becomes structurally impossible from every count-first
surface at once, because all of them route through `quickCount` — one guard
rather than five call sites, and a tier-1 test that runs macOS-native in CI
covers it.

What it does not do is repair a store that already contains those rows. On a
1.0 device they are ordinary entries: the marker filter cannot see them, this
guard stops them being *copied* but they still hold their votes in
`mostLoggedType`, and the app does not delete entries the user did not ask it
to. They have to go by hand, from History. Settings → Export log finds them —
they are the rows with an empty size and strength whose source reads Tallyist
rather than Apple Health.

The seed can now differ from the drink it names: "most-logged type" and "at
its last size" come apart when the last one is unusable. That is the intended
trade, and it is the same fallback the calendar's caption already described.

## How to reopen

If a future feature has a legitimate reason to log a zero-volume drink — a
"drink" that is genuinely a count, entered by hand rather than imported — then
volume stops separating the two cases and the test has to change with it.
Reopen on the marker becoming reliable, too: if the schema ever gains a
non-additive migration that guarantees every client sees `countedDrinks`, the
fact-based test is redundant belt-and-braces and could be dropped — though it
costs one comparison, so the bar for removing it should be higher than
tidiness.
