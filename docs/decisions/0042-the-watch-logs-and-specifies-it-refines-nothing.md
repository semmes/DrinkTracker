# 0042 — The watch logs and specifies; it refines nothing

**Status:** accepted · **Date:** 2026-09-14 · **Relates to:** PRD invariants
1, 2, 3 and 8; ADR-0023 (the counter's seed rule and its day memory);
ADR-0034 (the counter carries the day's colour); ADR-0041 (the watch is a
peer store); ADR-0017 (no notifications); `docs/tallyist-watch-plan.md`
(decisions 5 and 9, Phase 3, Phase 4, divergence 1); `docs/design/watch/`

## Context

The wrist gets the counter — the one number, ＋, − — and the question is what
＋ means there and how much of the phone's logging surface comes with it.

**＋ has one meaning everywhere or the invariant fails.** Invariant 1's own
wording is that one tap "cannot mean different things in the widget and the
app". The watch is now a third surface making the claim. Today's ＋ and the
widget's `LogOneDrinkIntent` each carried their own copy of the same five
lines — fetch the history, `DrinkDraft.quickCount(1, …)`, make the drink,
save it — and a third copy is how the rule would drift: ADR-0023's whole
argument, and the day-sheet caption bug `countSeedPreview` exists to prevent.

**Double Tap.** watchOS fires the frontmost app's primary action on a pinch,
and logging with one hand occupied is the single best thing this platform
offers a drink tracker (the plan, decision 5). The risk is real: an accidental
entry in a log whose whole value is accuracy is a worse bug than a missed tap.
Two things had to be true before it shipped. It must fire only while the
counter is frontmost, which is how the modifier behaves. And a Double Tap log
must be **distinguishable by feel** from an on-screen tap, so a pinch the user
did not mean announces itself immediately rather than being found in History
three days later. SwiftUI does not say which input activated a button, so the
distinction needed a mechanism.

**Specifying.** The phone's `DrinkDetailSheet` asks type, then size pills,
then an ABV slider, at a three-quarter sheet that took three attempts to get
right. None of it fits a 45mm screen, and cramming it there breaks invariant 2
twice: it turns the fast path into a form, and it asks at log time what the
whole model says to ask after.

**A dry day.** The design proposed a "Record no alcohol" button on the empty
day and marked it as undecided. The owner decided yes (2026-09-14): the wrist
is the surface you are wearing at the end of a dry day.

## Decision

**＋ runs the one implementation of the seed rule.** `DrinkRepository`
gains `nextQuickDrink(seed:region:)` and `logOneDrink(seed:region:)`; Today's
＋, the widget's intent and the watch's ＋ all call them, and no view builds
the drink itself. The watch reads the seed and the region from the App Group,
where the settings bridge put them (ADR-0041).

**Double Tap is ＋** — `.handGestureShortcut(.primaryAction)` on the ＋
button and nothing else in the app — **with its own haptic.** The button's
style records when a press begins; an activation with no press within the
last moment came from the gesture and plays `.directionUp`, a touch plays
`.click`. Never `.success`, which reads as praise for the act (invariant 8).
The − beside it is the correction path, and an entry the watch just logged
always satisfies ADR-0043's rule, so an accidental drink is removable where
it happened. That is the mitigation, and it is load-bearing.

**Specifying means the type, at the type's defaults.** Phase 4's picker
offers `DrinkType.selectableCases` — five glyphs, never `.unspecified` — and
writes `DrinkDraft(type:)` at the defaults. Beer, wine, spirit and cocktail
defaults each resolve to almost exactly one US standard drink by construction
(ADR-0005, ADR-0037), so a drink logged from the wrist is as accurate as a
two-tap phone log of the same type. Size and strength are refinements, and
refinements happen on the phone, after.

**The empty day records no alcohol**, through `markAlcoholFreeOrThrow` —
exactly what Siri's intent does — with the phone's own words ("Record no
alcohol today"; "Recorded as no alcohol today"; "Tap the plus sign to change
that."). The phone's `DrinkStore.markAlcoholFree` writes nothing to Health, so
the watch's marker has no side effect the wrist cannot mirror; a marker
mirrored from Apple Health reads "From Apple Health" and offers no way to
clear it (ADR-0025).

**The haptic is the receipt.** No confirmation step, no sheet, no "logged"
screen. The user is not looking.

**Amended 2026-09-15, on the owner's device pass: a pick names its type
back.** That rule holds for ＋, where the count on screen already shows
everything the tap did. A pick is the one write on the wrist that records a
*fact about the drink*, and the counter has no room to carry it afterwards —
so the reader had no way to know the type had been saved, which matters
precisely because they will open the phone later to add a size or a
strength. The hint slot now carries the type's own name — "Beer", "Wine" —
for about two seconds after a pick, through the same toast the other
messages use. It names the type and nothing else: the size and strength that
went with it are the type's defaults, not the reader's statement, and
printing them back would present a default as a choice (ADR-0023's rule).
The owner's wording was "1 standard beer"; the count is dropped because one
pick is one drink and the numeral above says so, and "standard" is dropped
because it would be a US-only claim — a 12oz beer at 5% is one standard
drink in the US and about 1.7 units in the UK, and invariant 3 makes every
figure follow the region.

## Consequences

- Three surfaces, one rule, one function. A future change to the seed rule is
  one edit and every ＋ follows.
- The press-tracking heuristic is a heuristic: a gesture that lands within
  three-quarters of a second of a real press on the ＋ is read as a touch. The
  cost is one wrong haptic in a case that requires both inputs at once.
- The counter screen carries a second control on the empty day. The design's
  proposal drew it; it takes the ≈ line's slot, since an empty day has no
  figure to estimate.
- Nothing on the wrist edits a drink's size or strength. A reader who wants
  that reaches for the phone, where the row is one tap away.
- Phase 4's hint ("Hold ＋ to say what it was") is not shown until the picker
  it names exists.

## Amendment, 2026-09-16 — ＋ does not guess a seed it could not read

ADR-0047 found in passing that `nextQuickDrink` read the history through
`try?`, so a failed fetch seeded ＋ from an *empty* history rather than
failing, and left open whether a failed read should throw or fall back —
a product call, made here. **＋ now throws when the history cannot be read,
and nothing is logged.**

What the fallback wrote, and why that is the wrong half of the trade:

- **Under the standard-drink seed**, an empty history has no day template, so
  a reader who had described a wine got an untyped standard drink. That row is
  the day's newest entry, and the day template *is* the newest repeatable
  entry (ADR-0023's revision) — so one failed read silently turned every later
  ＋ that day, on every surface, into standard drinks. That is a change to
  what ＋ does that the reader never asked for — the outcome ADR-0023's
  2026-09-06 amendment guards against, reached through a write the reader did
  not describe rather than through a stored mode. A described 16 oz IPA at 7%
  logs as 1.0 where it is 1.9.
- **Under the usual-drink seed**, an empty history has no plurality, so the
  fallback logged beer at beer's defaults for anyone — a typed claim about a
  drink, made on no evidence at all. ADR-0023's rule is that degrading to ugly
  beats degrading to false; this degraded to false.
- **It only wrote a row in the half-failed case.** Where a fetch fails because
  the store is failing, the save after it fails too — it did in every failure
  produced for this change — so the fallback bought nothing then, and wrote a
  wrong row only where the read failed and the write did not: silently, to be
  found in History later. (A failed save still leaves its insert pending, and
  the next save that works writes it — ADR-0004's second 2026-09-16
  amendment — so even the "bought nothing" case could deliver the guess late.) This record's own argument for Double Tap applies
  unchanged: in a log whose whole value is accuracy, a wrong entry is a worse
  bug than a missed tap, and a missed tap that says so can simply be repeated.

What each ＋ now does when the history cannot be read:

- **The watch** plays the refusal haptic and shows "Not saved", which it
  already did for a failed save — `logOneDrink` threw before; it now throws
  one step earlier.
- **The widget's `LogOneDrinkIntent`** fails, and its breadcrumb records
  `failed (one-drink): …`, as it did for a failed save.
- **Today's ＋ and the calendar day sheet's ＋** log nothing — not to the
  store and not to Health — and the count does not move, and the Diagnostics
  timeline records `Today ＋ not saved — history unreadable` or its day-sheet
  equivalent. No new copy. (That is less than a failed *save* does there:
  `DrinkStore.save` writes the Health sample first and never reports the store
  save that then fails — ADR-0004's second 2026-09-16 amendment.)

Pinned at tier 2 (`FailedReadTests`), on a real store file overwritten under
its open container: an in-memory store could not be made to fail a fetch (a
model missing from the schema fetches as empty, and the unsupported predicates
tried crashed the process rather than throwing), and a damaged file throws
Cocoa error 259 deterministically. The test restores the bytes and saves, and
checks that nothing the failed ＋ did was left pending to be written then.

Not changed: the history fetch is still the whole log under both seeds, though
the standard-drink seed reads only today's entries from it.

## How to reopen

- If field reports show ＋ taps lost to failed reads — the timeline lines
  above, or `failed (one-drink)` breadcrumbs naming a fetch rather than a save
  — the fallback to reconsider is not "seed from nothing" but a narrower read:
  under the standard-drink seed only today's entries matter, and a bounded
  fetch fails less than an unbounded one. Logging a guessed drink from ＋
  stays refused. (Bulk fill seeds from the calendar's own query and can still
  guess on a failed read — recorded in ADR-0004's amendment, not fixed here.)
- If field reports say people want to state a size from the wrist, the
  Digital Crown over `DrinkType.sizeOptions` is the obvious shape, and it is
  additive.
- If phantom Double Tap entries appear in the field, the first move is to
  require the gesture twice within a second (a confirmation the platform
  supports), not to remove the gesture.
- If a fourth surface ever logs a drink, it calls `logOneDrink`. A new copy of
  the rule is the thing this record exists to refuse.
