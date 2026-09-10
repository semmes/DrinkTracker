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
- Three collapsed source rows where there were two, so the bottom of Trends
  grows by roughly one card's chrome with all three shown, and shrinks when
  switches are off. Accepted as the price of the one-to-one with Settings.
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
