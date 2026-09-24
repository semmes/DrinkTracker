# 0038 — The comparisons on Trends are the reader's to show, and the weekend rate waits for four weeks of range

**Status:** accepted · **Date:** 2026-09-08 · **Amends:** ADR-0031 (the
drinking-days lines gain a switch), ADR-0032 (the weekend comparison gains a
switch and a floor) · **Relates to:** ADR-0018 and ADR-0030 (the volume
comparison and the year view, which share the first switch), ADR-0026 (a
choice, one at a time, persisted — the model this follows), ADR-0039 (the
column the weekly average reads), spec constraints 3 and 5

## Context

Trends has carried three published comparisons since ADR-0030, ADR-0031 and
ADR-0032 — the weekly average against a survey distribution, the days with
drinks against a published mean, the Friday-to-Sunday split against a
published rate — and every reader saw all three, in the same order, on
every range. The owner asked (2026-09-08) whether the insights could instead
be *cycled* or *chosen from the user's own data*, so that what a reader sees
is the comparison best suited to them rather than one static set.

The assessment separated three things the word "personalised" can mean here,
because the app's rules treat them very differently:

1. **Personalised data.** Every figure on the page is already the reader's
   own; nothing to do.
2. **A personalised reference** — being compared against people more like
   you. That is a sourcing question, and it is ADR-0039.
3. **Personalised selection** — the app deciding which comparison to show.
   This is the one the question was really about, and it splits again.

   - Selection by *how much record exists* is allowed and already the
     pattern: the population card hides under four weeks (ADR-0018) and
     widens to twelve months once it can (ADR-0030). A gate on sufficiency
     says nothing about the reader.
   - Selection by *the reader's own choice* is allowed and has a model:
     ADR-0026's summary window, a persisted choice with one thing shown at a
     time, and ADR-0030's own reopen clause ("as a *choice*, one window shown
     at a time").
   - Selection by *what the figures say* — showing the weekend card because
     the weekends are heavy, or leading with whichever comparison the reader
     lands lowest on — is refused. Choosing a fact *because of* its direction
     is the app characterising the reader, which is a verdict by another
     route; the 1.4.3 copy review already bans the word "insight" on Trends
     for exactly this reason ("each would characterise a bar"). The 1.2
     spec's own evidence note for Feature C is the sharper version: normative
     feedback works by correcting a misperception, and a selection rule that
     surfaces the flattering or the alarming comparison is a thumb on that
     scale in either direction.
   - **Rotation** — a different comparison on each visit, keyed to nothing —
     is refused separately: a fact that appears one visit and not the next
     cannot be found again, the App Review notes describe a fixed surface,
     and a rotation hides two of three facts at any moment for no reason a
     reader chose.

So the shape that survives is the reader choosing, plus one sufficiency gate
the review turned up on the way.

**The competing option** was a per-card control on the card itself (a "hide"
in a menu, or a chevron that collapses the comparison). It loses on
discoverability in the other direction: a comparison collapsed months ago
has no way back that a reader would look for, and a Settings section that
names all three with their sources is also the one place that says what
they are.

## Decision

**A Comparisons section in Settings, three switches, all on by default:**
"Weekly average" (Alcohol Research Group, 2020 National Alcohol Survey),
"Drinking days" (NIAAA, NESARC-III, 2012–13) and "Weekend and weekdays"
(Liang and Chikritzhs, 2015). Each names its source in its caption, because
the section's rule is that a published figure is never shown without saying
where it came from, and that holds for the switch that shows it. The
footnote states what the figures are and are not, in the card notes' own
words.

- **Weekly average** governs the volume sentences on the Trends card *and*
  the year view's comparison (ADR-0030) — one switch, because a reader who
  turned the comparison off and then met it on the year view would have been
  told the setting did nothing. Off removes the reader's own average line
  with it: the line exists to be placed against the survey, and the chart
  above already shows the average.
- **Drinking days** governs the two day-count lines (ADR-0031). The card's
  source line and note name only what is shown; with both switches off the
  card is not rendered.
- **Weekend and weekdays** governs the comparison table under the seven
  weekday rows (ADR-0032). The rows are the reader's own log and never
  depend on it.

**All three default to shown.** The 1.2 spec's "optional and off" rule is
for behavioural surfaces; a published figure beside the reader's own, which
every install has shown since 1.2 and 1.3, is neutral, and turning it off by
default would be a change in what everyone sees under the name of a
preference. A stored value wins; "never set" reads as shown
(`AppSettings.storedFlag`, because `bool(forKey:)` cannot tell never-set
from off).

**The weekend comparison waits for four weeks of range.** A Week range
placed three Friday-to-Sunday days beside a rate per hundred person-days,
which is the noise the population card's own four-week gate exists to keep
off the screen. `WeekendReference.minimumDays` is 28 and
`WeekendSplit.isComparable` is the predicate; below it the comparison
section is silent, as the population card is below its gate, and the seven
rows stay. Applied to the *range*, not to the record, because the split is a
fact about the range shown.

**Not built, by the reasoning above:** any rule that reads a figure to
decide whether to show it; any rotation; any ordering of the cards by the
reader's own numbers.

## Consequences

- Three new device-local settings in the App Group defaults, not synced
  (every setting here is about the device's reader). No schema change, no
  CloudKit step, no network.
- Nothing changes for an existing install until the reader opens Settings:
  the defaults are the shipped behaviour. The one visible change without a
  choice is the Week range, which loses the comparison table ADR-0032 gave
  it — its amendment records the floor.
- The Trends card's source line now has three forms (both sources, the
  survey alone, NESARC alone); a reader who shows only the drinking days
  reads "Source: NIAAA, NESARC-III, 2012–13".
- Copy: three switch titles, three source captions, two footnote forms, the
  days-only source line — all through the 1.4.3 review. None recommends a
  setting.
- Tier 1 pins the floor (`weekendComparisonGate`); tier 2 pins the defaults
  and the round-trips (`AppSettingsTests`). The switches' effect on the
  cards is app-target SwiftUI that no test tier reaches, so CI proves
  compilation; the proof is the tier-3 pass recorded in the commit.

## How to reopen

If real use asks for the app to choose — "show me the one that matters" —
the rule to engage is the direction rule above: reopening it means arguing
that a selection keyed to a figure's direction is not a verdict, and that
argument has to answer the 1.2 spec's evidence note. Rotation reopens only
with a way for a reader to reach every fact deliberately, which is what the
switches already are. Moving the switches onto the cards themselves is a
layout change under this record, not a reopen. If the four-week floor reads
as the app withholding something on the Week range, the reopen is a
sentence in the card's place saying why, not a lower floor.

---

## Amendment (2026-09-10) — the three comparisons are named where they are shown

**Status:** accepted. The decision above is unchanged: same three
comparisons, same three switches, same sources, same gates, same refusals.
This is a naming and layout change under this record, which its own "How to
reopen" already classifies as such.

The owner used the shipped screen and reported the gap: *"We're missing a
title for Comparisons. Can you setup a Comparisons section and then headlines
where we have 'Weekly average, Drinking days, and weekends and weekdays' …
It's important to title these as they have titles and toggles within the
settings page to turn them on or off."*

The record above created three named comparisons and gave each a switch, a
title and a source caption — **in Settings only**. On Trends the same three
were unnamed: two unlabelled pairs of sentences in one card, and a block
inside the By weekday card. A reader could flip "Drinking days" and watch two
anonymous lines vanish from a card that also held two other anonymous lines.
The setting named a thing the screen did not.

**What shipped.** The bottom of Trends carries a `COMPARISONS` heading — the
app's shared `SectionLabel`, in the same footnote-medium uppercase secondary
treatment `SettingsSection` gives its own section title (it inlines that
treatment rather than using the component, so the two render alike but only
`SectionLabel` carries the header trait — noted here because a reader is meant
to recognise the same label in both places) — and under it one card
per switch, in the switches' own order, each titled with that switch's exact
words: **Weekly average**, **Drinking days**, **Weekend and weekdays**. No new
strings: all four were already in the catalog and already through the 1.4.3
review as the Settings titles.

**The heading cannot outlive its content, and that is structural.**
`ComparisonsSection` resolves all three gates once and the heading's condition
is the literal disjunction of the three; no card re-checks its own switch. A
reader with every comparison off, or under the four-week gate, sees no heading
— because there is no way to write one without deleting the `if` the cards
live in. This is ADR-0034's `asksType` lesson applied: what a surface asks for
is a property of the surface, and the answer must never be able to withdraw
the question.

**The seven weekday rows stay outside the section**, which is what forced the
weekend comparison to move (ADR-0032's amendment records the move and what it
costs). The rows are the reader's own log, gated by nothing — this record says
so in as many words — so a heading spanning them would misdescribe them. It
would also do something worse: ADR-0032 refuses in its Decision to name a
busiest day or relate one weekday to another, and the card's own aligned
columns exist so that *alignment does the comparing the copy refuses to do*.
Printing the word **Comparisons** over seven weekday figures instructs the
reader to rank them, in the app's own voice.

**The population card became two cards**, and the joined source line went with
it. Under the old shape one card's source line was a *function of which
switches were on* — "Sources: A · B", or A alone, or B alone — which was
itself the sign that the card was two things. Each card now names, once, the
one body of work behind it, one-to-one with the caption on its switch.

### Consequences

- One key retires: the joined `"Sources: Alcohol Research Group, 2020 National
  Alcohol Survey · NIAAA, NESARC-III, 2012–13"` (app catalog 323 → 322). No
  key is added. `PopulationReferenceCopy.yearSource` is renamed
  `surveySource` — identical string, identical key — and is now read by both
  the Trends card and the year view, so the two cannot drift.
- Three collapsed source rows where there were two, and four card wrappers
  where there were two. Counting the constants at the default type size — the
  tables and the sentences are identical before and after, so they cancel —
  the bottom of Trends grows by roughly **190pt** with all three shown: two
  extra card wrappers, one extra 44pt source row, the heading and its gap, and
  three 12pt inter-card gaps, less the 31pt divider block that left
  `WeekdayCard`. That is a count, not a measurement, and nothing here could
  render it; the height is on the tier-3 list. It shrinks as switches go off,
  and with one comparison shown the screen is shorter than it was. Accepted as
  the price of the one-to-one with Settings.
- The year view's comparison card takes the same **Weekly average** title. It
  is governed by the same switch, and leaving it anonymous would make the year
  view the one surface where that setting's effect has no name. Beyond the
  literal ask, and one line to drop.
- Two heading levels now sit close together, told apart by **weight and
  case** — `COMPARISONS` in footnote medium uppercase over "Weekly average" in
  footnote regular sentence case, exactly the relationship Settings already
  draws between its section title and its switch rows. Nothing is re-inked to
  separate them (invariant 10, design-system §3). The card title is the
  `cardLabel` role every other card on Trends already uses, so the four new
  titles sit at the same weight as the summary cards above them rather than a
  step louder; `CardTitle` adds only the header trait and the wrapping rule.
- **One state where the heading stands over a card that compares nothing**,
  named rather than gated: with four weeks of record but no drinks in the
  window, the weekly-average card states an absence — "No drinks in the last 4
  weeks." — because `comparison(gramsPerWeek:in:)` returns nil at zero, and a
  reader with the other two comparisons off then sees COMPARISONS over that
  alone. It is accepted. The card is still that switch's own surface, and
  hiding it exactly when a reader has stopped drinking would both make the
  switch look broken and read as the app withholding — the thing the four-week
  floor's own silence is careful not to do. The sentence is the honest answer
  to the comparison, not a placeholder for one.
- No schema change, no CloudKit step, no new setting, no new figure, no
  network. No share card is touched.
- No test tier reaches any of this — app target, and `DrinkTrackerTests` has
  no `TEST_HOST` — so CI proves compilation and nothing more. The gate
  equivalence is argued from the code, not observed.

### How to reopen

If the two heading levels read as a stutter rather than a hierarchy on real
hardware, the fallback is to give the card titles more presence rather than
less — footnote medium, or the uppercase-tracked form `WeekdayCard` used to
carry — one line, and it is a render question, not a decision. If
the three source rows read as chrome, the reopen is one card with three
headlined blocks and dividers, which is `WeekdayCard`'s own former pattern;
what may **not** come back is a source line whose wording depends on which
switches are on.

---

### Note (2026-09-10, later the same day) — one card is titled by its measure

The third card is now titled **"Days with a drink"**, not its switch's words:
the owner read "Weekend and weekdays" over the "Days with a drink" head as one
long title, and the rows already say Friday to Sunday and Monday to Thursday.
The switch keeps "Weekend and weekdays". The rule above — one card per switch,
titled with the switch's words — holds for the first two and is recorded here
as having one exception, taken by the owner; ADR-0032's same-day amendment
has the change and the measurements.

---

### Note (2026-09-23) — the Settings footnote, in plainer words

The owner asked for the section's footnote without em dashes and in more
natural language, so it no longer uses the card notes' words. It still says
what the figures are and are not, and its two forms
still split as the Decision has them: "Your figures are compared on this device
with published US statistics built into the app, never with data from other
Tallyist users." Then, while the weekly average is on, what Compare with picks,
ADR-0039's "a choice of reference, not a question about you, and it stays on
this device" word for word, and that the other two sources publish figures for
all adults only. While it is off, "A comparison that's off doesn't appear on
Trends or the year view." One claim changed shape on purpose: "nothing about
your log leaves this device" was true of a comparison but reads, alone, as
untrue of a log that syncs to iCloud, so the sentence now says where the
comparing happens. `docs/copy-review-1.4.3.md` has both forms.

Later the same day the owner asked for the same change in the weekly
average's note, which Trends and the year view share. Its first sentence now
reads "Your average is compared on this device with a published population
statistic, never with data from other Tallyist users." Its derivation sentence
is unchanged, so the part ADR-0018 quotes still holds. The drinking-days and
weekend notes had no em dash and did not make the claim, so they are unchanged.

---

## Amendment (2026-09-23) — one card, segmented by the titles, and the day counts drawn as bars

**Status:** accepted. The decision above is unchanged: the same three
comparisons, the same three switches, the same sources, gates, order and
refusals. This is a layout and presentation change under this record, and
its first half is the reopen the 2026-09-10 amendment already named.

The owner, looking at the three cards: *"On the Trends page under
'Comparisons' can you organize the comparisons into a single card segmented
by the titles of Weekly average, drinking days, days with a drink. You can
also organize the data visualizations to be more concise, clear and visually
interesting."* "Segmented by the titles" was read as three headed segments in
one card — the 2026-09-10 amendment's own reopen, "one card with three
headlined blocks and dividers" — and not as a segmented control showing one
comparison at a time, which would hide two of three facts behind a tap this
record's rotation clause exists to avoid. The owner reviewed a first build
before anything was committed and ruled on it: *"The categories in a single
card look great. Let's keep that."*, *"Remove the people visualization from
the weekly average data visualization."*, and *"When showing the bar chart.
Can you add full 100% background fill. Similar effect to when your tapping
and holding on the top trends chart … That way users can see where the bar
chart ends and how much of it they have or haven't filled."* What follows is
the build after those rulings.

**One card.** `COMPARISONS` over a single glass card; the segments in the
switches' order, each headed by its title (`CardTitle`, the same words as
before), a hairline between one shown segment and the next. Every segment
keeps its **own** source line — the thing that reopen said may not come
back is a source line whose wording depends on which switches are on, and no
line here does. The rule that a heading cannot outlive its content extends
to the card and the rules: `ComparisonsSection` still resolves all three
gates once, and each divider is drawn by the segment below it only when a
segment above it is shown, so a card with one comparison has no rule at all.

**Each segment names its span**, right-aligned on its title row: the weekly
average and the drinking days "Last 28 days" or "Last 12 months" (the
population window, ADR-0030); days with a drink the range the picker chose
("Last 30 days", "Last 13 weeks", "Last 12 months"). In one card a reader now
sees "16 of 28" a few lines above "7 of 12" and "10 of 18" — 17 of 30 — and the
two segments do cover different days; the headers say so. All five strings
are existing keys (the chart card's titles and the calendar's "Last %lld
days").

**At the default sizes:**

- **Weekly average** sets the reader's figure large and rounded — "19.3
  standard drinks a week", the reader's own numeral (design system §3) — over
  the reviewed sentence, "That's lower than roughly 10% of US adults who
  drink." No drawing: a row of twenty figures, five in a hundred of the
  column's drinkers each with the sentence's share in full ink, was built and
  **removed at the owner's review**; the sentence states the share itself.
- **Drinking days** is two rows — "Your log · 16 of 28" and "US adults who
  drink · average about 7 in 28", the reviewed sentence split at its verb —
  each over a bar. Still two counts and no percentile (ADR-0031); the
  published bar is drawn from the rounded mean the row prints.
- **Days with a drink** is the table turned: columns are the paper's weekend
  definition, rows are whose figure — "Your log" and "US adults", short
  enough to leave each column the width "31 of every 100" needs on a 375pt
  screen (92.4pt of 103.5, measured with CoreText) — and each figure over a
  bar.

From `.xLarge` up every segment folds to the reviewed sentences, exactly as
the cards did (`ComparisonTable.folds`), with the span under the title. And
the sentences are what VoiceOver reads at every size: each segment's
accessibility representation is the same sentence views the large sizes show,
so nothing heard is newly worded — and the deprecated `Text` `+` the old
spoken labels were built with is gone from these files.

### The bars, and their tracks

**A bar is its figure's share of its own days**, and it sits on **a track
that is all of them** — a capsule the full width of its column, in the bar's
own ink as a wash. The track is the owner's ruling, quoted above, and its
look is the owner's reference: the wash the Trends chart's selection rail
draws behind a touched bar, at the rail's strongest (the ink at 14% in light
mode, 22% in dark). The bars are 8pt, with their tracks the same.

**The ruling reverses what the first build argued, and the cost is
recorded.** The first build drew the bars with no track, because the 1.4.3
copy review's second finding took a progress bar off Trends' day count: a bar
that fills a drawn container has a full state, and the review called a full
state a target. The owner saw that reasoning with the build and ruled for the
track, so that a reader can see where the scale ends and how much of it a
figure fills. What keeps these bars from being that progress bar is what was
already true of them: no segment draws a bar alone — every track's scale is
shared by the reader's figure and a published one, printed above each — and
the day-count card that finding changed keeps its bare number. A reader who
drank every day of the window sees a full bar; one who drank on none sees an
empty track beside the published bar. Both are the facts the figures state.

**Built first and rejected: every bar against the largest figure in its
chart.** Rendered, it drew "7 of 12" the column's full width and "31 of every
100" at 53% — a bar that reads as "every day" for a figure that is not.
`ComparisonBars.share` is pinned at tier 1 (a share never past its track, a
zero draws none).

**The reader's figure takes the accent, a published figure secondary ink,**
and each track is its own bar's ink as a wash. The accent already marks the
reader's own data on Trends — the chart's bars, and the rail behind a touched
one — so no new colour enters (invariant 10), and the distinction never rests
on colour alone: every bar sits in a labelled row, and the numeral rule is
unchanged (the reader's counts rounded, the published figures default SF).

**Measured on the rendered pixels** (iOS 27 simulator, iPhone 17 Pro; card
ground white in light and black in dark). `secondaryInk` is a translucent
label colour, so a published bar composites over its track and renders a
little darker in light mode and lighter in dark than the bare ink:

| Ink | Light | Dark |
| --- | --- | --- |
| The reader's bar (accent 500 / 400), on the card | #256ABF, 5.39:1 | #3987E5, 5.77:1 |
| — against its own track | 4.44:1 | 4.62:1 |
| The reader's track (accent at 14% / 22%) | #E0EAF6, 1.22:1 | #0D1E32, 1.25:1 |
| A published bar (`secondaryInk`, over its track), on the card | #848488, 3.73:1 | #9999A0, 7.42:1 |
| — against its own track | 3.24:1 | 5.82:1 |
| A published track (`secondaryInk` at 14% / 22%) | #EFEFEF, 1.15:1 | #1F1F20, 1.28:1 |

Every bar clears 3:1 against both the card and its own track. The tracks are
under 3:1 on purpose, as the rail they come from is: a track shows the
scale's extent, which the figure's own "of 28" also states in words.

### Consequences

- **Six app-catalog keys in, none out** (372 → 378 after the owner's Settings
  copy pass the same day): the four figure lines ("%@ standard drinks a week",
  "%@ standard drink a week", "%@ units a week", "%@ unit a week" — one per
  region and number, the figure a `Text` so a translation can place it), "US
  adults who drink", and "average about %lld in %lld". Synced with
  `xcstringstool` from a fresh generic full build into a scratch copy and
  diffed: exactly those six against `main`, and the merged catalog identical
  to the synced one. Reviewed under 1.4.3, as are the bars and their tracks.
- **A little shorter, not much.** Measured on one log in light mode at Month:
  the section is 612pt where the three cards were 620. What the one card saves
  in chrome — two card wrappers and two gaps — the bars and their rows spend.
  "More concise" is in what is read: at the default sizes one sentence remains
  where there were four, and every other figure sits beside a short label and
  its bar.
- **The drinking-days row label wraps** ("US adults / who drink") because the
  label column is shared with the weekend segment so the two segments' bars
  start on one edge; a per-segment width would save a line and lose the edge.
- `SourceDisclosure` gains `openNoteInset` (0 by default, so its other callers
  are unchanged): a segment followed by another keeps 14pt under an open note,
  which the first render drew touching the rule.
- **The year view's comparison is unchanged** — still its own card, still the
  sentences, the same words. The two surfaces now differ in form, not in copy.
- No schema change, no CloudKit step, no new setting, no network, no share
  card touched. **No new figure**: every length drawn is a figure the card
  already printed, rounded as it printed it.
- No test tier reaches the views (app target, no `TEST_HOST`); the arithmetic
  is tier 1 (`ComparisonFiguresTests`, six tests). The proof of the rest is
  tier 3 on a scratch simulator over a seeded log, recorded in the commit.

### How to reopen

If a bar reads as a goal in real use — the finding the track was ruled past —
the tracks go first and the bars second, and the rows stay, which is the table
this card held before. If the weekly average wants a drawing again, it should
draw the sentence's share, never a marker for the reader: a marker on a line
from least to most is a gauge, and a gauge is a score (ADR-0006). If
"segmented" meant a picker, one comparison at a time, that is this record's
rotation clause to engage: a reader's choice at the card is ADR-0026's model
and allowed, but it hides two published facts behind a tap, and the switches
already let a reader choose which are shown.
