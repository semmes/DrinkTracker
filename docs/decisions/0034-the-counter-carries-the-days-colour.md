# 0034 — Today's counter carries the day's colour, and the typed path is one link

**Status:** accepted · **Date:** 2026-09-06 ·
**Amends:** ADR-0001 (the repeat control's home), ADR-0007 (a fourth ramp step;
the hero band as a named surface), ADR-0009 (the typed disclosure is retired),
ADR-0013 (Today's list order — shipped ascending, reverted to newest-first the
same day), ADR-0017 (the pace chip carries the ramp),
ADR-0023 revision (where the way back to a standard drink lives) ·
**Amended by:** ADR-0040 (Today's chrome: the four toolbar buttons Home v2
kept are gone; the tab bar replaces them, and Settings is a tab)

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
- **The list hint's two-way ternary** (`unspecified ? … : 'Tap a drink to
  change what it was.'`), added 2026-09-07: the shipped hint also requires a
  tappable row — one that is not a Health import, or is an adoptable one —
  because a day whose only rows are multi-count imports renders them
  read-only, and the prototype's second sentence over those answers no tap.
  No new copy; the third case shows nothing.

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

## Amendment (2026-09-07) — the type question is the presentation's, not the draft's

The owner used the shipped path and reported it: *"when I tap 'add specfic' the
behavior changes incorrectly and moves me to another page within that sheet
menu. It should leave the toggle options 'beer, wine, spirit, other' in place as
items I can scroll through rather than buttons."* They named the fix themselves —
the sheet reached by an untyped row's "Tap to say what it was" *"is rendering
correctly and you can use that as a reference."*

**Reproduced on a booted iPhone 17 Pro.** Tapping Beer in the Add-specific sheet
removed the whole DRINK section and put SIZE and STRENGTH in its place, inside
`withAnimation(.snappy)`, while the title changed from "One standard drink" to
"Beer" — every element in the scroll area replaced at once, with no way back to
Wine short of closing the sheet. The reference path, opened one tap away on the
same screen, kept its picker and appended size and strength below it.

**One term caused it.** `typeSection` was gated on
`showsTimeControl || adopting != nil || draft.needsType`, and `needsType` is
`type == .unspecified` — a value the picker itself writes. Every other
presentation satisfied that gate by a term fixed at init, so only "Add specific"
— the app's one `DrinkDetailSheet(draft:)` call site that passes no
`showsTimeControl` — was gated on the answer to its own question.

**The rule, stated once:** *what a sheet asks for is a property of the
presentation; the answer must never be able to withdraw the question.* This is
not new — ADR-0016's adoption picker persists because `adopting` cannot change
mid-presentation, and the edit path's because `showsTimeControl` cannot. It is
those two paths' rule, applied at the top instead of re-derived per frame:
`DrinkDetailSheet.asksType`, a stored `let` computed once in each initialiser.
The old doc comment's reasoning — "a picker there would be a second way to do
something already done" — was written for the retired four quick-add buttons and
is what drifted; the flag keeps its intent available to a future presentation
that really does open on a type the user already chose elsewhere.

**Size and strength stay a live read** of `draft.needsType`, deliberately.
ADR-0023 forbids rendering the stored 0.6 oz at 100% as a pill and a slider,
which is exactly what freezing both gates together would do. Only the type
question is a presentation property.

**The primary action follows** (owner's call, same report). `logButtonTitle`
returned "Save details" for any untyped draft, so Add specific said it before a
type was named — over a row that does not exist yet, whose button writes what ＋
writes. That branch now also requires `editingEntryID`, so adding facts to a row
already on the record keeps ADR-0016's word and a new drink says "Log drink" for
the whole presentation, rather than flipping under the first tap. No string is
new or retired; the three sheet button titles are `ButtonVM.title` literals and
remain outside the catalogs, which `docs/localization-status.md` already tracks.

*Ruling B, 2026-09-07 (1.3 release review).* The fix above still read
`draft.needsType` live, so the untyped row's own path — "Tap to say what it
was" — said "Save details" until the first type tap and "Save changes" after
it: the same mid-presentation change, one row lower. The owner ruled that
**"Save details" holds for the whole presentation.** `logButtonTitle` now reads
a stored `let`, `savesDetails`, decided in `init(draft:)` as
`editingEntryID != nil && needsType` (adoption's initialiser sets it true);
everything else is unchanged. No test tier reaches this view, so the
structural guard is the stored constant, as with `asksType`.

**PRD invariant 2's wording is corrected in the same commit.** It claimed the
type picker appears "only when editing an existing entry", which stopped being
true when this ADR shipped "Add specific"; the time-control half is unchanged and
still hard.

### Not built, and why

- **A "no type" segment.** ADR-0023 keeps `.unspecified` out of
  `selectableCases` on purpose; the way back to an untyped drink is closing the
  sheet, not picking "none" from a list of beverages.
- **Remembering the last type chosen.** A stored mode, which this ADR refuses by
  name — the widget's `LogOneDrinkIntent` mirrors the app through the log, and a
  mode fails days later as "the widget logged a beer".
- **A tier-1 guard.** The honest shape would be a pure `DrinkSheetForm` value in
  the core package, and it was declined: the fault was *where the read happened*,
  not what the boolean computes, so a test would pin the rule while leaving the
  reading discipline — the thing that actually broke — uncovered, and would put a
  presentation type in a package invariant 9 keeps free of UI. The structural
  guard is that `asksType` is a stored constant, which cannot be re-derived, and
  a doc comment naming the failure mode. Verification is tier 3, stated in the
  commit.

### Verified here

All four CI gates locally (policy dates, 226 domain tests, simulator build, 80
integration tests) plus tier 3 on a booted iPhone 17 Pro, both paths, before and
after: the picker staying with the chosen segment marked, size and strength
appearing beneath it, Beer → Spirit switching in place with the pills and the
slider re-seeding, the estimate holding at "≈ 1 standard drink", "Log drink" on
the new-entry path and "Save details" still on the untyped-row path. The taller
content is reachable by the gesture the report names — an upward drag grows the
sheet to its large detent — which is what the reference path has always done.

## Amendment (2026-09-07) — band edges follow the printed digits

**Status:** accepted · **Date:** 2026-09-07 · **Amends:** the Decision's
bucketing rule ("1–2 / 3–5 / 6–9 / 10+ over the region-lensed standard-drink
total") in its rounding step only · **Relates to:** ADR-0007 (the ramp),
`StandardDrink.formatted` (every printed total), the contract's
`vectors/measurement.json`

### Context

The 1.3 release review probed `DayIntensity.bucket` against the figure a day
prints. The band rounded the raw total to a whole drink (`.rounded()`, the
rule since 1.0) and compared it against 10, 6 and 3; every surface that prints
a total — Today's hero and its spoken label, the day sheet, the calendar cell's
description, the summary cards, the share cards — rounds to one decimal through
`StandardDrink.formatted`. The two roundings disagree in a band 0.05 wide under
each edge: 9.4583 rounds to 9 and 9.5000 to 10, while both print
"≈ 9.5 standard drinks". Probe-verified: 9.4583 → `.high`, 9.5 → `.veryHigh`;
the same pair at 5.5 (`.medium` / `.high`) and at 2.5 (`.low` / `.medium`). Two
days a reader cannot tell apart by their figure drew two colours — on the one
surface, Today's tile beside its own number, that this ADR built so the colour
and the amount could never be out of step.

**The owner ruled (2026-09-07): bucket on the one-decimal displayed value.**

### Decision

`DayIntensity.bucket` decides on `StandardDrink.displayed(total)` — the
`(total × 10).rounded() / 10` that `formatted` prints, now one named function
that the formatter, `readsAsOne` and the band all call — and the edges are the
half-steps between the labels: **9.5 and up is 10+, 5.5 and up 6–9, 2.5 and up
3–5, anything else logged 1–2.** `hasEntries` still forces at least 1–2.
Non-finite input is unchanged and does not trap: NaN and −∞ fail every
comparison and take the floor, +∞ the top, exactly as the whole-drink rule
behaved (`.rounded()` passes all three through).

The band is therefore a pure function of the printed digits, and the tests say
so: over a sweep of 15,001 totals from 0 to 15, `formatted(x) == formatted(y)`
implies `bucket(x) == bucket(y)`, and the band never falls as the total rises.
The probe pairs are pinned by value, and so is the non-finite behaviour.

### Consequences

- **Which days move, and which way.** A total in [x.45, x.5) at each edge —
  2.45–2.4999, 5.45–5.4999, 9.45–9.4999 — moves *up* one band, because it
  prints as "2.5", "5.5" or "9.5". No day moves down. Every surface that reads
  `DayIntensity.bucket` moves together — Today's hero, the calendar, the year
  view, both share cards, the pace chip — because they are the same call; that
  is the property this ADR bought, now holding against the printed figure too.
- The legend words are unchanged; "6–9" still contains every whole total it
  sits under (`labelsDescribeTheirRange` is untouched).
- **The neutral contract still pins the three-band, whole-drink rule.**
  `semmes/tallyist-product`'s `vectors/measurement.json` (`intensity_thresholds`
  with no `very_high_at_or_above`) and `domain/aggregation.md`'s
  calendar-intensity pseudocode describe neither the fourth band (this ADR) nor
  the one-decimal edge (this amendment). Both are one contract bump, raised
  rather than assumed — the standing merge authorization is this repo's — and
  not touched here.
- No schema change, no CloudKit step, no setting, no copy change, no catalog
  change.

### How to reopen

If the edges ever go back to the whole drink, the change is one line back to
`.rounded()` — but then `formatted` has to round the same way, or the probe
pairs return. The rule underneath is the one worth keeping: *a band and the
figure it sits beside must round through one function.*

## Amendment (2026-09-08) — the empty day says less

**Source:** the owner's review of Today, 2026-09-08: *"under the 'Record no
alcohol today' button, we don't need the microcopy that says 'Plus logs one
standard drink, with no type, editable afterwards' — you can delete that. Then
when someone taps 'Record no alcohol today' we don't need the 'Remove that
record' link text. If a user taps the plus they can remove that record. We
should keep the text 'Recorded as no alcohol today. Tap the plus sign to change
that.' You can keep other microcopy when logging drinks and specifying
categories."*

### Context

Home v2 left two explanatory pieces on the empty day. The first was the
`CounterSeedCaption` under "Record no alcohol today" — the reviewed, seed-aware
replacement for the drawing's "Or tap + — one tap is one standard drink." (this
record's not-built list) — with a `UsualDrinkSeedCaption` wrapper owning the
whole-log fetch the usual-drink seed needs, so `TodayView` never ran an
unbounded query for a sentence. The second predates Home v2: the marked state's
"Remove that record" link, the user-set marker's way back, which ADR-0025
withheld only for a Health-mirrored marker.

The owner used the screen and ruled both unnecessary on Today. Their reasoning
for the link is one this repository already relies on: a logged drink clears
the day's marker (`DrinkRepository.saveOrThrow` deletes every marker on a
drink's day, and names the two-device case), so ＋ is a way back that already
exists, and − then removes the drink if the tap was only a correction — two
taps to a blank day, and no second control. The caption's case is the owner's:
the empty day is the state with the least to explain, the pill says what ＋
repeats once a described drink exists, and the drink sheet says the rest.

### Decision

- **No caption under "Record no alcohol today".** The empty day shows the
  button and "Add specific" and nothing between them. `UsualDrinkSeedCaption`
  is deleted — it fed only that site. `CounterSeedCaption` itself stands,
  still shared by the pill on Today and by the day sheet, so wherever the
  sentence *is* shown it is still the same sentence.
- **No "Remove that record" on Today.** The user-set marked state reads
  "Recorded as no alcohol today" over a footnote, **"Tap the plus sign to
  change that."** — the owner's own wording, one new app key. The
  Health-marked state is untouched ("From Apple Health", ADR-0025).
  `DrinkStore.unmarkAlcoholFree` stays; the day sheet still calls it.
- **The day sheet keeps both** — its counter caption (with the − sentence) and
  its "Remove that record". The owner scoped the ruling to the home screen,
  and the day sheet is the surface for editing the record after the fact,
  where a removal control earns its place. Today and the day sheet now differ
  in *what* they show, not in how they word it, so this record's "cannot word
  ＋ differently" holds as stated.

### Consequences

- Two fewer things on the empty day; one sentence where a control was. **No
  schema change, no CloudKit step, no setting.** App catalog: one key in
  ("Tap the plus sign to change that."), none out — both removed strings are
  still used by the day sheet.
- **Removing an accidental marker on Today now takes two taps and passes
  through a logged drink**: ＋ writes a standard drink, which clears the marker
  and is for a moment a real row (Health receives it if writing is on); −
  deletes it and retires the sample. The end state is the same blank day; the
  transient is new. A user who wants the marker gone *without* logging anything
  has the day sheet.
- A user on the usual-drink seed no longer sees on Today what ＋ will write on
  an empty day — the pill does not exist until a described drink does. The
  setting's own description in Settings still says it, and the first tap shows
  it in the row.
- 1.4.3: "Tap the plus sign to change that." is an instruction about a
  control, not about drinking; it sets no target and grades nothing (copy
  review, 2026-09-08).

### Verified here

No test tier reaches `TodayView` (app target, no `TEST_HOST`), so CI proves
compilation only. Tier 3 on a booted iPhone 17 Pro, before and
after: the empty day shows the button and "Add specific" with nothing between
them; "Record no alcohol today" turns the tile to the outline and prints
"Recorded as no alcohol today" over "Tap the plus sign to change that.", with
no link; ＋ then clears the marker and logs one standard drink — the tile moves
to the 1–2 band and the row appears — which is the way back the sentence
promises. All four CI gates green locally (245 domain tests, the generic
build, 81 integration tests, the glyph generator clean); the app catalog went
302 → 303 with exactly the new sentence in.

### How to reopen

A field report of markers users cannot find their way out of on Today — someone
who does not read ＋ as the way back — is the case for the sentence to become a
control again, and the copy would be "Remove that record" as before; the day
sheet's link is the model. The caption's return has a lower bar: it is one
line, and the sentence is still reviewed and still in the catalog.

## Amendment (2026-09-08, ADR-0040)

Home v2 kept the four glass buttons in Today's top-right corner — History,
Calendar, Trends, and the gear that presented Settings as a sheet. The
owner's next drawing (Home v3, `docs/design/bottom-nav/`) deletes them and
adds nothing in their place: the five surfaces sit side by side in the
system tab bar, Settings a page among them. Nothing else on this record's
Today changes — the band, the legend, the pill, the rows and "Add specific"
are as decided here. ADR-0040 holds the reasoning.
