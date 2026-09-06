# 0034 — Today's counter carries the day's colour, and the typed path is one link

**Status:** accepted · **Date:** 2026-09-06 ·
**Amends:** ADR-0001 (the repeat control's home), ADR-0007 (a fourth ramp step;
the hero band as a named surface), ADR-0009 (the typed disclosure is retired),
ADR-0013 (Today's list order — shipped ascending, reverted to newest-first the
same day), ADR-0017 (the pace chip carries the ramp),
ADR-0023 revision (where the way back to a standard drink lives)

## Context

The owner produced a Home v2 design (`docs/design/today2/`, the *Tallyist iOS
Prototype* canvas — the design project cannot be read automatically from this
environment, so the bundle is dropped in by hand, as it was for ADR-0029 and
ADR-0032). It keeps the counter and rebuilds everything around it: the number
sits inside a coloured tile keyed to the day's amount, a legend states the
bands, a two-segment pill says which drink ＋ is following, the four quick-add
buttons and the repeat row are gone in favour of one "Add specific" link, and
today's rows run forward with a time and a chevron instead of a standard-drink
column.

Most of it is straightforwardly buildable. Four things were not, and each is
the reason this record exists rather than a commit message.

**The band's quantity.** The drawing bands by *drink count* (1–2 / 3–5 / 6–9 /
10+) while every other ramp surface — including the drawing's own calendar —
bands by *standard drinks*. Shipping both would mean one swatch labelled "3–5"
meaning entries on Today and standard drinks on the calendar, on the same day,
one tap apart. Three large drinks are six standard drinks: Home would say 3–5
and the calendar 6+.

**A fourth ramp step.** The drawing introduces `#05172e` for 10+, which is not
in the documented blue family and has no dark-mode counterpart anywhere in the
bundle. Adding it moves the calendar, the year view and both share cards too.

**A stored mode.** The prototype holds `plusMode` in state, set by any typed
save and never cleared. ADR-0023's revision says in bold that the mechanism is
the log itself, with no stored mode and a midnight reset; PRD invariant 1
requires the widget's ＋ to mirror the app's, which app-local state breaks by
construction.

**A tinted pace chip.** ADR-0017 and the 1.2 spec refuse urgency styling on the
rolling count by name.

## Decision

Asked, the owner ruled: **the hero and the calendar must never disagree**, the
fourth step ships and the calendar moves onto it too, the pill is two log
buttons rather than a mode, and the pace chip gets its tint.

So:

**One fold, one palette, four bands, everywhere.** `DayIntensity` gains
`.veryHigh`; the buckets become 1–2 / 3–5 / 6–9 / 10+ over the region-lensed
standard-drink total. Today's tile calls `DayIntensity.bucket` and paints with
`IntensityPalette.fill`/`ink`/`isOutlined` — the calendar cell's own functions,
reached by name. The two surfaces cannot drift because there is nothing to keep
in step: they are the same two calls. The ramp's new step is validated in both
modes; the arithmetic is in ADR-0007's amendment and in
`IntensityPalette`'s doc comment.

**The pill logs; it does not arm.** Two segments — a plain standard drink, and
the drink the day is following. The highlighted one is what ＋ would log, and
tapping the other logs *that*, immediately. Selection is derived from
`DrinkDraft.dayTemplate`, so midnight resets it, deleting the drink undoes it,
and the widget stays in lockstep because there is no state for it to be out of
step with. The pill is not a new control: it is ADR-0023's "Record a standard
drink instead" and ADR-0001's repeat, put side by side with the current one
marked.

**The typed path is one link.** "Add specific" — in the Logged-today heading,
and under the counter on an empty day, which has no heading to carry it —
opens the sheet on an untyped standard drink, so it asks
"what was it?" first and only then offers size and strength, with no time
control (invariant 2). The persisted disclosure, the four quick-add buttons, the
repeat row and `AppSettings.prefersDetailedLogging` are all deleted.

**The chip carries the ramp**, from `.high` upward — ADR-0017's amendment holds
the argument and the measurements.

## Consequences

### What this buys

- A day reads the same on Today and on the calendar, by construction rather
  than by discipline. That was the owner's stated requirement and it is the
  strongest property of the change.
- The top of the ramp describes something again. "6+" covered a six-drink
  evening and a fourteen-drink one identically.
- The counter area finally says what ＋ will do, in words, under both seeds —
  the caption is `DayLogSheet`'s own sentence, moved into a shared
  `CounterSeedCaption` so Today and the day sheet cannot word it differently.
- One fewer preference. The typed path no longer has a mode to be in.

### What it costs, honestly

- **Every existing calendar re-shades at the top end.** A 10-drink day was
  `#0d366b` and is now `#05172e`. Nothing about the record changed; the display
  lens got finer. Share cards exported before and after this build will differ.
- **The neutral contract moves too, and is not bumped here.**
  `semmes/tallyist-product` (v1.7.0) pins the three-bucket ramp — in
  `vectors/measurement.json`'s `intensity_thresholds` and `intensity_cases`, and
  in `domain/aggregation.md`'s calendar-intensity section, whose pseudocode
  stops at `high`. None of it is wrong about anything the contract *tests*
  today, but all of it is now behind iOS. Bumping it is a separate PR in that
  repo, and the standing merge authorization is this repo's — so it is left
  open deliberately, alongside ADR-0033's longest-run rule, which is the other
  iOS decision the contract has not caught up with.
- **The typed path gains a step.** Four one-tap buttons became one link into a
  sheet where the type is still chosen. That is the failure mode PRD invariant
  1's own note warns about, and it is the design's deliberate trade: the
  disclosure occupied the screen permanently for a path most days do not use.
- **`counterSeed == .usualDrink` loses its typed one-tap.** `DrinkDraft.dayTemplate`
  is seed-blind, so what withholds the pill is an explicit
  `guard settings.counterSeed == .standardDrink` in `TodayView.typedDayTemplate`
  — and it has to be: under the usual-drink seed ＋ follows the day-blind
  plurality rule, so a highlighted right segment would name a drink ＋ is not
  actually following. The deleted repeat row was seed-blind. A `.usualDrink` user goes from a one-tap repeat to the
  link. Named here rather than discovered later; the cheap mitigation, if it
  bites, is to show the pill under that seed too with
  `TrendSummary.mostRecentDrink(ofType:)` as the template — but that resurrects
  the seed asymmetry ADR-0023 removed, so it is recorded rather than built.
- ~~**Today's list runs forward while History and the day sheet run
  backward.**~~ Shipped that way from the drawing and reverted the same day on
  the owner's review: the just-logged row belongs where the eye lands, not at
  the end of a list that grows all evening. Today matches the other two
  surfaces. See ADR-0013's amendment for why the original argument was wrong.
- **The two deepest fills are 1.50:1 apart** (1.35:1 dark). That is the ramp's
  floor behaving like a ramp's floor; the perceptual gate still passes with room
  (ΔL\* 0.153 / 0.108).

### Things the drawing shows that were deliberately not built

- **The unlogged tile's `rgba(0,0,0,0.22)` ring.** An outline is ADR-0007's
  channel for *recorded as no alcohol*; a second ring differing only in alpha
  would collapse it, and 0.22 over the grouped ground measures 1.69:1 anyway.
  The two zero states stay distinguishable by the words directly beneath the
  tile — and by the alcohol-free tile's own fill, which is neutral rather than
  clear.
- **The ＋ button's `0 2px 10px` drop shadow.** Depth comes from the system
  material; `grep -rn "\.shadow(" --include=*.swift` returns nothing and should
  keep returning nothing.
- **The legend's 0.45 opacity on inactive labels.** Over secondary that
  composites to roughly a quarter alpha at 11pt. Emphasis rides weight and ink
  tier instead.
- **`rgba(60,60,67,0.4)` on the untyped row's glyph** (2.14:1, under the 3:1
  floor for a meaningful glyph) and `rgba(60,60,67,0.5)` on the footer hint
  (2.67:1). Both are `.secondary`.
- **"Standard drink" as the untyped row's title.** The package's key is "One
  standard drink", worded that way to avoid an `xcstringstool generate-symbols`
  case collision with the region unit name, and it is simultaneously the CSV
  entry, the summary line and Siri's reply. Renaming it on Today alone would
  make one entry read two ways across four surfaces.
- **"Or tap + — one tap is one standard drink."** True only under the
  standard-drink seed. Replaced by the reviewed, seed-aware
  `CounterSeedCaption`.
- **"Removed a drink" in the undo bar.** The shipped bar already reads "Removed
  one standard drink", because `DrinkType.unspecified.displayName` is a whole
  sentence. A new key to say strictly less.
- **The prototype's 3-hour session gap and 4-drink chip threshold.** Both
  contradict ADR-0017's shipped constants and neither was raised; read as
  prototype convenience.

### Measured, not eyeballed

Numeral on band, light: black on `#86b6ef` 9.95:1; white on `#2a78d6` 4.42:1
(large text — the numeral is 68pt); white on `#0d366b` 11.95:1; white on
`#05172e` 17.97:1. Dark: white on `#184f95` 8.10:1; black on `#3987e5` 5.77:1;
black on `#9ec5f4` 11.75:1; black on `#cde2fb` 15.87:1. Alcohol-free is
`Color.primary` at 10% / 16% with the 0.35 stroke — `IntensityCell`'s exact
values. Unlogged is `.clear` with a `.secondary` numeral. White on the ＋'s
`AccentFill` is 5.39:1. **No literal colour is introduced by this change
outside `IntensityPalette`'s two new constants.**

### Verified here

All four CI gates locally (policy dates, 226 domain tests, simulator build, 80
integration tests) plus tier 3 on a booted iPhone 17 Pro: every band including
both zero states, light and dark, the band and legend tracking ± , the pace
chip escalating and going neutral again, "Add specific" opening on the type
question with no time control, the pill appearing when a beer is described and
vanishing when a standard drink is logged over it, and the whole screen at
`accessibility-extra-large`. Two real defects were found by rendering rather
than reasoning: the pace chip clipped mid-word at AX5 (a capsule sized to its
own text overflows its card), and the pinned plain-list header drew on nothing,
so rows scrolled underneath "Add specific" — the heading is now a row, not a
`header:`.

## How to reopen

- **The band's quantity.** If a reader reports the tile's colour disagreeing
  with the numeral inside it — 3 drinks in the 6–9 shade because they were
  large — that is the count-band reading asking to be built. It would need its
  own fold in the core package and an answer for the calendar, which would then
  disagree instead.
- **The fourth step.** If 10+ turns out to be rare enough that the extra band
  never renders for most users, the ramp collapses back by deleting one case;
  the reverse direction (a fifth step) needs the whole ramp re-spaced, because
  `#05172e` is its floor.
- **The typed path.** If logging a beer measurably drops, the disclosure's
  reopen path is ADR-0009's own: the split is the thing to revisit, not the
  counter.
- **The pill under `.usualDrink`** — see the cost above.
