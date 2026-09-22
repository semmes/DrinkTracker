# 0050 — The app pairs, it does not conclude

**Status:** accepted · **Date:** 2026-09-21 · **Relates to:** ADR-0048 (a
drinking night is not a calendar day; the buckets and the gate this surface
draws); ADR-0049 (health context is read, never stored; the read that feeds
it and the invisible-denial rule); ADR-0051 (the ask happens at the moment
of value; the offer that sits in this card's place); ADR-0017 (the session
card's three hard rules, the model for rules held by structure); ADR-0032
and its amendments (the weekday table, whose parts this card is built from,
and the rule that alignment does the comparing the copy will not);
ADR-0038 (the comparisons are the reader's to show, and are named on
Trends); ADR-0001 and PRD §1 (the app measures and does not warn); PRD
invariants 9 and 10; `docs/tallyist-health-pairing-plan.md` ("The risk",
"The four rules", "Copy"); `docs/design/health-pairing/README.md` (the
table, the switches, the three changes to the plan);
`docs/copy-review-1.4.3.md` (the batch of the same date)

The third of the health pairing's records, written in Phase 3 with the
surface, as the plan asked. The plan reserved a number for it that the watch
took; the next free one is this.

## Context

Every figure Tallyist has shown is a quantity of alcohol, and the app has
never had to decide whether more was worse, because nothing it drew carried
a direction. The health pairing puts a second axis beside the first, and
that axis carries a direction the reader already believes in: "62 beats per
minute on nights with drinks, 58 without" is a verdict that no sentence has
to deliver. The plan says this in its first section and says why copy
discipline cannot hold the line alone — a card can pass every tone review
and still be a coach, because the number does the judging. Constraint 3
(the app measures and does not warn) is therefore held here by structure,
and this record is the argument for which structure.

Four questions had to be settled to draw one row. Each is a place where the
obvious build makes the app conclude.

**What is shown.** The obvious build shows the difference: "4 bpm higher on
nights you drink", a delta with a sign, perhaps a colour. That is the
finding the reader came for, and it is the one thing the plan's first rule
forbids, because a difference the app hands over is its judgment and a
difference the reader works out is their observation. The next most obvious
build shows the two figures and *also* the difference, smaller. Same
verdict, smaller type.

**Who chooses the axis.** The plan's decision 2 put a metric picker on
Trends. The owner's design removed it: the Settings switches are how the
reader picks, one metric each, and every metric switched on that clears its
gate is a row in one table. The question is whether the app should ever
choose a metric to show — the one with the biggest gap, the one with the
most data — and the answer ADR-0038 already gave for the comparisons holds
here with more force: a selection keyed to what a figure says is a verdict
by another route.

**What holds the row back.** ADR-0048 set the gate at fourteen nights with a
value in *each* bucket. This record has to say what the surface does below
it — a caveat, an asterisk, a greyed row, or nothing — and the plan's third
rule answers: hide the whole row, because a number with an asterisk still
gets read as a number.

**Which direction the data flows.** The pairing reads the body to show it
beside the log. The reverse — reading the body to say something about the
drinking: "your resting heart rate suggests", a prompt to log on a night the
data looks unusual, a flag on a night the log and the body disagree — is
the plan's fourth rule and its clearest stop condition, and it is
technically the easiest thing in the feature to build, which is exactly why
the structure has to make it impossible rather than merely unwritten.

## Decision

1. **Both figures, side by side, with their night counts, and never a
   delta.** One card, one grid, three columns, in the weekday table's own
   idiom and from its own parts (`ComparisonTable`, `CardTitle`,
   `SourceDisclosure`): the title "Your averages" beside the heads DRINKS and
   NO DRINKS, then the metric's name over "36 and 48 nights", then the two
   averages in the reader's numeral face with their unit. The domain returns
   `PairedFigures` — two `Figure`s, each an average and a count — and has no
   member for a difference; no view computes one; no test asserts one, even
   to check a sign. The columns are aligned so that the alignment does the
   comparing (ADR-0032's rule), and nothing else does: no colour on either
   figure (the only brand colour on these surfaces is the switch's tint and
   the offer's two buttons, and a colour on a figure would be a delta
   drawn), no bold on one of the pair, no arrow, no sign, no chart, and no
   numeric roll between ranges — a range change crossfades the figures,
   because a roll from 62 to 58 draws a direction that the subject change
   does not have. The card is drawn from what was read, under the range
   that read covered (`HealthPairingModel.Loaded` pairs the figures with
   their request), so on a range change the previous card stands until the
   new read lands and then the figures and their source line change
   together; a figure is never shown under another range's name. The night
   counts are on the card because they are what lets a reader weigh the two
   averages, which is the honest alternative to the app weighing them.

2. **The reader picks the axis; the app never does.** One switch per
   metric in Settings, under "Apple Health on Trends", **off by default** —
   unlike the three comparisons above it, which put a published figure
   beside the reader's own and default on. This is the first figure the app
   derives from data it does not own, and the reader turns it on. Only the
   metrics the shipped build shows get a switch (one, as of this phase);
   nothing is drawn disabled for the ones that are not. There is no metric
   picker on Trends, no rotation, no "most relevant" — every row a reader
   has switched on and that clears its gate is shown, in the Settings order,
   and the section's heading appears exactly when at least one row or the
   offer does. `HealthPairingSection` resolves the row's condition and the
   offer's once, and the heading's condition is the literal disjunction of
   the two, so a heading over nothing cannot be written without deleting the
   `if` the card lives in (ADR-0038's rule). The card never re-reads the
   switch: `resolve` alone decides what is drawn. `TrendsView` reads the
   switch and the offer's flag once more, for a different question — whether
   to derive the request at all, and whether to read — and never to draw.

3. **Below the gate there is nothing, at every range.** A row whose either
   bucket holds fewer than fourteen nights with a value is not drawn — no
   caveat, no asterisk, no greyed figure, no "not enough data yet" — and
   the section's heading goes with it when it was the only row. That is the
   same state as the switch being off, the read being denied, the watch not
   measuring the type, and a device the data never reached: one state, and
   absence is what it looks like (ADR-0049's rule, on the surface). At Week
   the gate cannot clear in principle (seven nights against fourteen); at
   Month it can only in theory (thirty nights split two ways); the row lives
   at Quarter and Year. The gate is checked from the log alone before any
   read is made, so a switch left on over a short log reads nothing.

4. **The data flows one way, and the types make the other way impossible
   to reach by accident.** `HealthPairing.buckets` takes drinks and markers
   and returns which nights are which; `HealthPairing.figures` takes those
   buckets and the nightly values and returns two averages. Nothing in the
   core package takes a health value and returns anything about a night's
   drinking, and nothing in the app reads a health value except to hand it
   to `figures`. The read never includes the current day (ADR-0049), so no
   value the pairing holds can describe the night in progress. No
   notification exists, and none may (ADR-0017's third hard rule, extended
   to the body by the plan's stop conditions).

5. **The copy names the source and the span, and carries no direction.**
   "From Apple Health, last 13 weeks" under the row; "Two averages of your
   own Health data…" behind the disclosure, with the two columns defined to
   the domain exactly — "No drinks means nights you recorded as no alcohol;
   a night with nothing logged is in neither column" — and "Tallyist keeps
   none of it". VoiceOver speaks the long phrases the short heads stand for,
   in two sentences of the same shape: "On nights you logged drinks, 62
   beats per minute, over 36 nights. On nights recorded as no alcohol, 58
   beats per minute, over 48 nights." No comparative adjective anywhere,
   spoken or shown (the plan's copy rule); every sentence is in
   `HealthPairingCopy`, one file, so the rule is checkable in one place and
   the card, its large-type fold and its spoken label cannot drift. Reviewed
   twice in `docs/copy-review-1.4.3.md`, the second pass reading each line
   beside its number. One string reached the card from outside that file:
   the shared source line's VoiceOver hint said "Explains this comparison",
   the word this card exists not to be, so `SourceDisclosure` takes a hint
   and the card passes "Explains these figures" — a review catch, and the
   reason a reused part's spoken strings are part of the batch too.

6. **At the sizes where the table cannot hold, it folds to the sentences.**
   From `.xLarge` up (`ComparisonTable.folds`, the weekday table's own
   threshold), the card shows the title, the metric's name and the two
   VoiceOver sentences as body text — so nothing a reader meets at a large
   size is newly worded, and the sentences were reviewed once for both
   paths.

## Consequences

- **A reader can, and will, subtract.** Sixty-two beside fifty-eight is
  four, and a reader who wants that number has it in a glance. That is the
  design: the observation is theirs, and the app has said nothing it would
  have to defend as advice. The cost is that a reader who wants the app to
  tell them what the four means does not get told, here or anywhere.
- **The card is one row for now.** Sleep, heart rate variability and wrist
  temperature arrive one phase each, each as a row under the same heading
  from the same parts, with its own switch. The order is the Settings
  order. The offer (ADR-0051) covers whatever rows the build ships.
- **The header row fits on one line down to a 375pt phone at the default
  size**, measured with CoreText (calibrated against ADR-0032's recorded
  width: "Monday to Thursday" measures 140.3 against its 141) rather than
  assumed: the title is 85.7pt, the heads 45.2 and 67.0, the row's natural
  width 213.9pt; a "62 bpm" cell in tabular figures is 49.2; the leading
  column has 170.9pt on a 375pt phone against "Resting heart rate" at
  122.1, and 160.4 against three-digit figures. The numeric columns are
  content-sized on purpose, not fixed: at the design drawing's two 84pt
  columns the leading column on a 375pt phone would have 119pt (111 at the
  weekday table's 88pt scaled metric), and the metric's name would wrap.
- **The offer's card is this card's shape with the figures blank**
  (ADR-0051), so what a reader agrees to is on screen rather than described.
- **The feature adds no colour and no literal.** Ink is `.primary`,
  `.secondary` and `.tertiary`; the grounds are the card's glass; the only
  brand colour is the switch's tint and the offer's two buttons — the
  accent-filled primary and the accent-ink text button — all the design
  system's existing controls. Invariant 10 is untouched.
- **The second column can hold a night another app marked.** The markers
  the buckets read include the read-only ones ADR-0025 makes from another
  app's zero-count Health sample, so "nights you recorded as no alcohol"
  covers a night recorded in the other app too. The app already calls those
  "Recorded as no alcohol — From Apple Health" on the day sheet, so the
  phrase is the app's own name for both; no distinction is drawn here.
- **A revoke made while Trends is open takes effect on the next read.** The
  request is keyed on the range, the day, the log and the switch, not on the
  foreground, so a read revoked in Settings while the card is up leaves it
  standing until the tab is returned to, the range or the day changes, or
  the log does — then the read returns nothing and the card goes. Nothing
  was stored meanwhile; what stood was one render's figures.
- **No test tier reaches the card, the offer or the switch.** They are
  app-target views with no `TEST_HOST`; CI proves they compile. The domain
  behind them is tier-1 (ADR-0048), and the surface is tier 3 on a
  simulator with seeded Health data — every range, the folds at `.xLarge`
  and `accessibility-extra-extra-extra-large`, both appearances, the offer's
  one-time behaviour across a relaunch, and the read revoked in Settings
  leaving nothing on the screen and nothing in the App Group but the
  switch's boolean, the offer's and the breadcrumb — and tier 4 on the
  owner's phone.
- **Five of the design README's strings changed in the build**, listed once
  here. The source note: "No drinks means every other night" became "No
  drinks means nights you recorded as no alcohol; a night with nothing
  logged is in neither column", with "A night without a reading is not
  counted" added and "on this iPhone" made "on this device" — the domain's
  bucket (ADR-0048), and the README's own instruction to rewrite the note to
  it; the app runs on iPad (ADR-0049's consequence). The spoken row: "On
  other nights" became "On nights recorded as no alcohol", the same reason.
  The offer's caption: "31 without" became "48 recorded as no alcohol". The
  offer's body: "Your watch already records these. Tallyist can show them
  here… They are read from Apple Health on this iPhone" became "Apple Watch
  records this every day. Tallyist can show it here… It is read from Apple
  Health on this device" — singular because one metric ships, "Apple Watch"
  because the offer is shown on the log alone (ADR-0051), and the same
  device wording. The Settings footnote: "Each switch" became "This switch",
  "this iPhone" became "this device", and its third sentence (wearing the
  watch to bed) waits for a metric it is true of. The button "Show these on
  Trends" is "Show this on Trends" for the same reason as the body.

## How to reopen

- **If a reader asks for the difference** — "just tell me the number" — the
  answer is this record's first decision, and the cost above is the cost.
  The reopen would be a sentence, not a figure: never a signed delta, never
  a colour, and only if constraint 3 (`docs/tallyist-1.2-spec.md`, "Project
  constraints") is reargued there first. There is no smaller version.
- **If a later metric wants a picker after all** (four rows are a tall
  card), the reopen is a reader-chosen picker in the Settings section, not
  on Trends, and never a selection the app makes. ADR-0038's refusals apply.
- **If the gate should differ per metric** (heart rate variability is
  noisier and may want more), that is ADR-0048's constant becoming a
  parameter of `figures`, and this record's third decision — nothing below
  it, at every range — does not change.
- **If the Month range should ever show a row**, nothing here prevents it:
  the gate is the only condition, and a month with fourteen marked nights
  and fourteen drinking nights is arithmetically possible. It is not a
  design goal.

## Amendment — 2026-09-22 (Phase 4: the second row, sleep)

The card is now what this record said it would become: one row per metric
the reader has switched on, in the Settings order — resting heart rate, then
sleep — each the same two averages with their night counts, a hairline
between rows (the weekday table's lighter rule), one source line and one
note for the card. Every decision above holds for the second row without
change; four things are new, recorded here.

**What sleep's row shows.** Time asleep, as `HealthPairing.timeAsleep`
assembles it (ADR-0048: the asleep stages merged, filed by the middle under
the night whose sleep day holds them, naps summed in, in bed and awake never
counted), averaged over each bucket's nights that have a value, behind the
same fourteen-night gate. Printed as "6h 12m" with the minutes zero-padded
so a column of them aligns — the design's figure format — from
`HealthPairing.hoursAndMinutes`, one rounding to the nearest minute (half
up, carrying into the hour) that both the printed figure and the spoken
"6 hours, 12 minutes" read, so the two never disagree by a minute (tier 1).
The figure carries its own unit, so no "bpm"-style word sits beside it. The
spoken row: "Sleep. On nights you logged drinks, 6 hours, 12 minutes asleep,
over 36 nights. On nights recorded as no alcohol, 7 hours, 4 minutes asleep,
over 48 nights." — "asleep" is the state the figure measures, the Health
app's own word, and no word relates the two.

**The rows are the reader's, and there is still no line between them.**
Two rows about two nights' bodies, read together, are a story a reader may
tell; the card does not tell it. Each row is switched on by its own switch,
nothing spans the rows, and the note is written for any number of them:
"Each row is two averages of your own Health data over the nights counted
here…" — one phrase changed from Phase 3's, and no sentence about sleep in
it, because the switch's caption in Settings ("Time asleep on nights you
wear your watch") already says what the figure is and a sentence about a row
the reader switched off would be a sentence about nothing.

**The widths, measured again.** With both rows, the numeric columns are the
widest cell in each: "6h 12m" is 58.5pt in the card's tabular figures, wider
than "62 bpm" (49.2) and DRINKS (45.2), narrower than NO DRINKS (67.0). On a
375pt phone the leading column keeps 161.5pt against "Resting heart rate" at
122.1, and 149.0 with three-digit heart rates and a ten-hour sleep — one
line everywhere, still. The header row is unchanged at 213.9.

**Only the metrics that are built get a switch**, still: two now, "Resting
heart rate" and "Sleep", in one section, with the footnote in the design's
three-sentence shape for the first time — "Each switch…", "Read on this
device…", and "Sleep comes from nights you wear your watch to bed", the
README's third sentence cut to the one metric it is true of, and the one
place the app says it (the README names it as the only one). Phase 3's list
of the design strings that changed, in the consequences above, is that
phase's record: the offer's singulars in it are reversed by this phase, and
the footnote's third sentence has arrived, cut. How a switch that arrives
later is set, and how its sheet is shown, are ADR-0051's and ADR-0049's
amendments of the same date.

The reopen paths above stand. One is nearer: with four rows the card is a
tall one, and the picker the second bullet describes would live in Settings.
