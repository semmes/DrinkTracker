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
  save that then fails — ADR-0004's second 2026-09-16 amendment. *Closed by
  ADR-0004's third amendment of that date: a failed save now writes nothing to
  the log or to Health, and the count does not move for it either.*)

Pinned at tier 2 (`FailedReadTests`), on a real store file overwritten under
its open container: an in-memory store could not be made to fail a fetch (a
model missing from the schema fetches as empty, and the unsupported predicates
tried crashed the process rather than throwing), and a damaged file throws
Cocoa error 259 deterministically. The test restores the bytes and saves, and
checks that nothing the failed ＋ did was left pending to be written then.

Not changed: the history fetch is still the whole log under both seeds, though
the standard-drink seed reads only today's entries from it.

## Amendment, 2026-09-19 — the row fits the case it is on

This record gave the wrist "the counter — the one number, ＋, −" and left its
measurements to the design, which drew the row once: 44 · 86 · 44 at 4pt gaps
inside 8pt margins, 198pt, "the one arrangement that fits the usable width".
That is a 45mm's screen. A 40mm's is 162pt and a 41mm's 176, and there the
row ran off the glass — by 10pt a side on the 40mm, each disc cut to 34pt of
its 44pt target, and by 3 on the 41mm — and took the column with it, since a
column is as wide as its widest child: "Record no alcohol today" ran edge to
edge, and the marked day's second line with it. On the 44 and 42mm the row
fitted the glass with 1 and 2.5pt to spare. Found on 2026-09-18, on a
throwaway simulator, while rendering the complication; Phase 3 had listed the
small cases as unrendered, and the owner's hardware pass was on a larger one.

**The discs never give.** Both are touch targets, and ＋ is the control this
record exists for: 44pt on every case. What gives, in the order that costs
the reader least, is **the margins first** — from the drawn 8 until the row
stands its own 4pt gap from the glass, no tighter to the edge than it is to
itself — **and then the tile.** Inside the tile the design's own two ratios
re-derive the corner and the numeral (side × 36 / 126 and × 68 / 126, the
phone's hero; its instruction is to "re-derive from these rather than picking
new numbers"), and the pieces it gives no ratio for — the bare numeral, the
hidden bar, the glyph — scale from their drawn size on the drawn 86. The
arithmetic is `CounterRow` in the core package, twelve tier-1 tests over
every case's width; the watch reads its width from the view's own geometry
(`CounterMetrics`), never from a device table.

**What the view is given is not the screen.** watchOS keeps 2pt of the glass
clear on each side before the app lays anything out — measured from renders
of every case below but the Ultra 2: the full-width button stands 10pt from
the glass on a 46mm, inside an 8pt margin — so a 40mm's view is 158pt wide. The rule takes both numbers, the
view's width and its safe-area inset, so that "a gap from the glass" means
the glass. The first build took the width alone, stood the row 6pt off and
cost the tile 4pt; the render, measured, is what found it.

| Case | Screen | Column's margin | Tile | Numeral | Row, from the glass |
|---|---|---|---|---|---|
| 40mm | 162 | 2 | 58 | 31 | 4 |
| 41mm | 176 | 2 | 72 | 39 | 4 |
| 44mm | 184 | 2 | 80 | 43 | 4 |
| 42mm | 187 | 2 | 83 | 45 | 4 |
| 45mm | 198 | 6 | 86 | 46 | 8 |
| 49mm, Ultra and Ultra 2 | 205 | 8 | 86 | 46 | 11.5 |
| 46mm | 208 | 8 | 86 | 46 | 13 |
| 49mm, Ultra 3 | 211 | 8 | 86 | 46 | 14.5 |

Every width was read from that case's own simulator. Memory had the Ultra 3
at the earlier Ultras' 205.

**The large cases do not change — measured.** On throwaway 45mm, 46mm and
49mm (Ultra 3) simulators, `main` at d4f5bb5 against this change, every pixel
of the screen but the status bar's clock, in eleven states each — 0, 1, 3, 6,
16 and 100 drinks; a day recorded as no alcohol, by the user and from Health;
and 1, 3 and 16 with the session row: **none differs** (176,418, 189,904 and
199,606 pixels a frame). The binaries differ, and the same comparison flags
29,557 pixels between two different states. The 45mm is identical for a
reason worth keeping: the old row overflowed its 8pt padding there by 2pt a
side, which put it — and the column it stretched — the drawn 8pt from the
glass, and the rule's 6 with the system's 2 land in the same place on
purpose. The Ultra 2's width was read and not rendered; it takes the same
values as the Ultra 3.

**Rendered on throwaway simulators**, signed builds, the store seeded with
`sqlite3`: the 40, 41, 42 and 44mm in those eleven states, before and after,
the row measured 4pt from the glass on all four and both discs 44pt wide. And
on the 40mm, by taps: the − dimmed beside a Health-owned newest drink and its
refusal ("Remove that drink on the phone", two lines in its pill) — which
Phase 3 could not reach; the hide, its bar 27 × 5.5 in the 58pt tile and the
legend's labels gone with the swatches unmoved, and its toast; the type
picker, unchanged, since its columns were always flexible; a pick's toast;
the real ≈ line; the session switch under the fold; and the storage strip, by
making the scratch store unopenable — also unreached since Phase 3.

**What it costs.** The tile is the hero, and on a 40mm it is 58pt beside 44pt
discs — 1.3 to 1 where the design drew nearly 2 to 1 — with the count at 31pt
rather than 46. "Record no alcohol today" takes two lines in its capsule on
the 40 and 41mm. The 42 and 44mm give 3 and 6pt of tile to stand 4pt from the
glass rather than 2.5 and 1.

**Not verified:** the unreadable state, which needs a fetch to fail under an
open store — its lines are centred and wrap in the same column; Always-On and
redaction; Double Tap; VoiceOver, where no label changed and the tile's tap
target is 58pt at its least; anything on hardware, where the owner's watch is
a larger case.

## How to reopen

- If 58pt is too little hero on a 40mm, that is a drawing to make and not a
  constant to change: the discs cannot shrink, so a larger tile means a row
  that is not three across — the tile over its two discs, say.
  `CounterRow.tileSide` is where the three-across answer lives, and its tests
  hold every case's width.

- If field reports show ＋ taps lost to failed reads — the timeline lines
  above, or `failed (one-drink)` breadcrumbs naming a fetch rather than a save
  — the fallback to reconsider is not "seed from nothing" but a narrower read:
  under the standard-drink seed only today's entries matter, and a bounded
  fetch fails less than an unbounded one. Logging a guessed drink from ＋
  stays refused. (Bulk fill seeded from the calendar's own query and could
  still guess on a failed read — recorded in ADR-0004's amendment, not fixed
  here. *Closed by ADR-0011's second 2026-09-16 amendment: bulk fill reads its
  seed from the store, and a read that fails stops it.*)
- If field reports say people want to state a size from the wrist, the
  Digital Crown over `DrinkType.sizeOptions` is the obvious shape, and it is
  additive.
- If phantom Double Tap entries appear in the field, the first move is to
  require the gesture twice within a second (a confirmation the platform
  supports), not to remove the gesture.
- If a fourth surface ever logs a drink, it calls `logOneDrink`. A new copy of
  the rule is the thing this record exists to refuse.
