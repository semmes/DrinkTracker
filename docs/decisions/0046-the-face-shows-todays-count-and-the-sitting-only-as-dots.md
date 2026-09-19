# 0046 — The face shows today's count, and the sitting only as dots

**Status:** accepted · **Date:** 2026-09-14 · **Relates to:** ADR-0017 (the
session's three hard rules); ADR-0034 (the counter carries the day's colour);
ADR-0044 (the session as dots, and its switch); ADR-0045 (the watch hides
its numbers by default); ADR-0019 (`LogOneDrinkIntent`, the widget's
parameterless ＋); ADR-0041 (the watch store fills from CloudKit); PRD
invariants 1 and 10; `docs/tallyist-watch-plan.md` (Phase 6);
`docs/design/watch/README.md` (the complications table and its decisions)

## Context

The plan gives the four complication families one content rule: "the session
count while a session is running, today's count otherwise — the same thing
the home-screen widget shows, no more." The two halves of that sentence do
not agree. The home-screen widget shows today's count and nothing about a
sitting (`QuickLogProvider.currentEntry` reads `drinks(on: now)`), and the
plan and design both use it as the reference the face should match.

Read literally, the rule also produces two things the rest of the product
refuses. A number on the face that means one thing during a sitting and
another after it — with only a small unit word to say which — is a numeral
whose meaning changes under the reader, and at the moment a session ends the
face would *rise*, from "3 this session" to "4 today", which is the standing
number the tone rules exist to prevent, arriving by another door. And a
numeral in a band has to be described by the band (invariant 10, ADR-0034's
"nothing out of sync"): a session count inside the day's colour would put a
3 in the 6–9 fill.

The face also has a hidden state drawn for it, and the owner has answered
that the per-glance hide does not govern complications (the design's fourth
question): the system's redaction is what protects a public surface.

Two things the drawing could not know. The real rectangular family is about
177 × 80pt on a 46mm watch, not the 264 × 118 the design drew; built at the
drawn sizes, the card truncated its words to "drin…" and "≈ 3 st…" on the
simulator's Smart Stack. And the unit noun the drawing sets at 62% of the
band's ink composites to 4.17:1 on the 1–2 fill and 3.51:1 on the 3–5 fill —
under 4.5:1 for text that size, a new unvalidated ink (invariant 10).

One thing the plan could not know either: on the wrist the phone is the
dominant writer. A drink logged on the phone reaches the watch's store by
CloudKit in seconds (ADR-0041's measured latency) and updates the counter's
query — and nothing in that path would reload a complication. "Reload after
every write on the watch" covers the watch's own writes only; without more,
an evening logged on the phone never reaches the face until midnight, when it
resets to zero.

## Decision

**Every family shows today's count in the day's band** — the tile shrunk to
a disc, keeping its job, the same `DayIntensity.bucket` over the same total
as the counter and the calendar cell. The circular family carries the numeral
and the unit noun in the band's ink at full strength; the corner the numeral
in the disc and the day's words along its curve — the words, never the
count; the inline family the glyph and "N drinks today"; the rectangular card
the tile at 44, the unit word and a 44pt ＋, the ≈ line not shown (the
home-screen widget's small family makes the same trade). The home-screen
widget's two reviewed strings name the complication. A day recorded as no
alcohol shows the alcohol-free glyph in place of the numeral, with Today's
own sentence beside it — on the inline line, the corner's curve and the
card, and spoken by every family; the circular disc shows the glyph alone,
having no room for words.

**Amended 2026-09-15, on the owner's device pass: the circular family shows
the numeral and nothing else.** It had carried the design's unit noun
beneath the count, and on a real face a 50pt disc reading "1 drink" is a
sentence where a glance wants a number. The noun is not lost — the face
draws its own label under a complication, the corner's curve and the card
still carry "drinks today", and every family speaks the full "N drinks
today" to VoiceOver. The numeral takes the room the noun had (30 → 34).
Both bare nouns retire from the complication's catalog.

**Amended 2026-09-18, on the owner's design: the circular family draws the
card's tile, not a disc**, in a clear slot, with the figure at the card's own
size (34 → 24) — and on a tinted face every family's ground goes translucent
so the count can be read. The amendment of that date, below, is the record;
"the tile shrunk to a disc" now describes the corner family alone.

**Amended 2026-09-18, a second time: the rectangular card's words wrap on a
narrow card.** "The tile at 44, the unit word and a 44pt ＋" was drawn for one
width, and the family has fourteen; under 172pt of content — every card but
the 45mm's face and the 46 and 49mm — the words take the whole column between
the tile and the ＋, the gaps close to 4, and the words wrap before they
shrink. The 46mm is drawn exactly as it was, in both of its contexts. The
second amendment of that date, below, is the record.

**The sitting appears only as dots**, on the rectangular card, on a row of
its own beneath, while `SessionPace.currentSession` returns a value **and the
watch's own "Show session pace" is on** — the sitting is a surface the wrist
opts into (ADR-0044, ADR-0017), and the card follows the counter's switch.
Through the same `SessionDots` view and the same band rule as the counter.
Never as a number on the face.

**The timeline carries an entry at each moment the face would change on its
own.** While a sitting runs: one at each drink's exit from the two-hour
window, where the dots' band drains (the counter recomputes it every minute;
the face must not lag it by up to two hours), and one at `lastDrinkAt +
gapThreshold` carrying the post-session state — nothing else wakes a
complication when a session ends, and without it a dead sitting's dots would
sit on the face. The refresh is the earlier of the session's end and the
next midnight. All entries derive from one read of the store: the session
and its band are functions of the drinks and the clock.

**The face follows the store, not only the wrist's writes.** Every write on
the watch reloads all timelines — the counter's ＋, −, the picker's log and
the no-alcohol record, which the phone's store skips because its widget
draws nothing for a marker and the face does. And the watch app observes
`NSPersistentStoreRemoteChange` and reloads once a CloudKit import settles
(coalesced over two seconds), plus on every raise of the app. The residual,
stated: an evening logged entirely on the phone with the watch app never
launched reaches the face when the system next runs the app for a CloudKit
push, or at the next raise — not within seconds.

**The ＋ is the rectangular card's, through `LogOneDrinkIntent`** — the
owner's answer to the design's second question, and the one intent that is
parameterless and so cannot repeat the dispatch bug a promptable parameter
once caused. Invariant 1 extends to the face with no new argument: the intent
reads the seed and the region from the App Group, the same rule as every ＋.

**Redacted, each family shows the drop glyph and the plural words with the
figure gone**, never a blank; the band's fill goes with the figure, since
once the digits are gone the colour is the figure (ADR-0045), and the words
are the plural because a singular noun under a glyph is a count of one. The
same form when the store cannot be opened, with no ＋: the face prints no
figure it cannot back.

**Redaction wins over the marker, and over the spoken label.** A day
recorded as no alcohol redacts to the same drop glyph and the same words as
every other day: if the drinking days went behind the glyph while the dry
ones kept their check, the glyph itself would state what the reader did, and
a locked watch on a table would sort their days into two kinds. For the same
reason the accessibility label follows the pixels — the system redacts a
numeral it draws, not a label written by hand, and a locked face that speaks
"5 drinks today" is the disclosure the glyph exists to close. ADR-0045's
"hiding does not change what VoiceOver speaks" governs the user's own tap on
the counter, where the audience is the user; this is the system's lock,
where it is not. The hidden state the design drew for the circular
family is not built.

**No relevance-based surfacing.** The card appears in the Smart Stack because
the user put it there; nothing pushes it forward by time or place.

## Consequences

- A VoiceOver user with the watch off the wrist hears "drinks today" and not
  the count, which is a real loss of information to the one reader who most
  needs it spoken. It is the same loss the screen takes, and it lasts until
  the watch is back on the wrist.
- The face never contradicts the counter, given a reload: the number on the
  wrist's face is the number on the wrist's screen, and the dots' band on the
  card is the row's band at that minute.
- A reader who wants the sitting's count reads it on the counter; the face
  shows the sitting's shape, not its number — and only if they turned the
  row on.
- A phone-logged drink reaches the face seconds after the counter while the
  watch app is running or is run for the push, and at the next raise
  otherwise. That is the platform's shape, not the product's choice.
- The plan's Phase 6 sentence is superseded by this record; its second half
  was the intent.
- The design's "… hidden" circular is unbuilt by the owner's own decision;
  the record for that is ADR-0045. The design's 62% noun and its 70pt tile
  are not built, for the measured reasons above.

## Amendment, 2026-09-16 — the unavailable entry covers a failed read, not only a failed open

This record says a store the complication cannot read shows the glyph and no ＋.
Only a failed `SharedModelContainer.make()` reached that entry: a failed fetch of
today's rows drew a confident empty day, a failed fetch of the sitting's rows drew
no dots, and a failed marker read drew a count and a band on a day recorded as no
alcohol. `CounterProvider.load(at:)` now reads through `drinksOrThrow(on:)`, a
throwing fetch and `isMarkedAlcoholFreeOrThrow(_:)`, and checks the App Group first
(without it, `make()` opens a private empty store and returns normally). Any of
them failing returns nil, which is the existing unavailable entry. The view is
unchanged. ADR-0047 is the change that found it.

## Amendment, 2026-09-18 — the circular slot draws the card's tile, and a tinted face keeps the count

Two changes, separable, in two commits. The first is the owner's design
(`docs/design/watch/circular-complication-handoff.md`); the second is what
that design's own acceptance check — "one tinted face" — found.

### The tile

The circular family filled its whole slot with the band and set the count at
34. Beside the card's 44pt tile with its 24pt figure it read larger and
louder than the surface it belongs to, and a disc is not the shape this
product marks a day with: the calendar cell, the counter's tile and the card
are all the rounded square. Now the slot is clear and holds **the card's own
tile**: side `floor(d × 0.83 × 2) / 2` for a slot of diameter `d`, corner
`side × 13 / 44`, continuous, centred; the numeral at the card's 24 and the
glyphs at its 18, whatever the side — a smaller tile is a smaller ground,
not a smaller number. One function, `tile(side:)`, draws it for both
families, so they cannot drift apart again; the geometry is
`ComplicationTile` in the core package, pinned at tier 1. The neutral ground
is the card's `.quaternary`, no longer `AccessoryWidgetBackground`. The slot
is read from the view's geometry and never assumed.

**Why 0.83, checked rather than taken.** Flattening SwiftUI's own
`RoundedRectangle(cornerRadius:style: .continuous)` path, a 44pt tile at 13
reaches 25.753pt from its centre (25.728 if the corner were an arc); the 46mm
slot's radius is 25.5, so a copy of the card's tile would lose four corners
to the system's mask. At 0.83, against every size the system asks for — read
from its own log on the simulators, 51 and 46 on the 46mm, 42 and 37 on the
40mm — and the design's other rows:

| Slot | Tile | Corner | Clear of the mask |
|---|---|---|---|
| 51 | 42 | 12.41 | 0.92 |
| 50 | 41.5 | 12.26 | 0.71 |
| 47 | 39 | 11.52 | 0.67 |
| 46 | 38 | 11.23 | 0.76 |
| 44.5 | 36.5 | 10.78 | 0.89 |
| 42 | 34.5 | 10.19 | 0.81 |
| 40 | 33 | 9.75 | 0.68 |
| 37 | 30.5 | 9.01 | 0.65 |

The design's six rows agree with it to the hundredth. Its "never below 0.65"
holds for the rows and not between them: the least over 37 to 51pt in
quarter points is 0.56, at 38 — still more than a pixel, which is what
matters, and what the tier-1 sweep asserts (half a point, 36 to 56pt). The
extra-large family is requested at the circular's own size and scaled by the
face, so it needs no rule of its own.

**Where the repository won, by the design's own instruction** ("the repo
wins"; its numbers were measured from screenshots without the code). The
numeral is the card's 24 semibold, not the measured 23 bold. The no-alcohol
mark is the app's own `tally.alcoholfree` at 18 — 13pt across as drawn, where
12.5 was measured — not `checkmark.circle` (ADR-0036 reserves that glyph's
meaning). The neutral is the *style* `.quaternary`, which measures `#252526`
on a black face — exactly the value the design sampled from the card — so the
two match without a literal colour (invariant 10). Redacted, the tile keeps
its shape, as the design asks, and shows the drop glyph with the band's fill
gone, which is this record's rule, rather than "the numeral redacts". And the
numeral gained `lineLimit(1)` beside its existing `minimumScaleFactor(0.6)`,
the design's own edge case: "100" shrinks onto one line, edge to edge in the
tile, as it already did on the card.

**Measured on the simulators** (Series 11 46mm and SE 3 40mm, Modular, both
families on one face; pixel boxes read from screenshots by script). The tile
is 84 × 84px = 42.0pt in the 51pt slot and 69px = 34.5pt in the 42pt one,
centred, no lit pixel within 0.7pt of the mask. The figure's pixel box is
identical in the circular tile and the card's on the same face in every
state: "0" 12.0 × 17.0pt, "1" 7.5 × 16.5, "16" 24.5 × 17.0, the mark 13.0 ×
13.0. Grounds: `#252526` at 0 and on a day recorded as no alcohol, `#184F95`
at 1, `#3987E5` at 3, `#9EC5F4` at 6, `#CDE2FB` at 16 — the ramp, untouched.
And the card's row is pixel-identical between `main`'s build and this one in
full colour: the rectangular complication does not change.

**Not changed:** the corner family keeps its disc. It was outside the
design's scope, its slot is 32 to 34pt, and a tile there is a separate
drawing.

### A tinted face

On a tinted face WidgetKit keeps each view's alpha and nothing else of its
colour: everything accentable is drawn in the face's tint and everything
else in one flat ink. The band's solid fill therefore became a bright block
with the count on it in the tint — measured on a Modular tinted pale teal,
**1.34:1** in the circular slot and **1.64:1** on the card, and on California's
cream all but invisible — and the card's ＋ became a blank disc, its white
glyph and blue fill being one ink there (**1.29:1**). A control build of
`main` draws the same 1.34:1 on its full-circle disc, so this predates the
tile: Phase 6 listed tinted rendering as unverified, and the device pass of
2026-09-15 looked at a tinted face without recording which tint or which
day — a neutral day, or a strong tint, reads.

`CounterComplicationView.isTinted` (`widgetRenderingMode != .fullColor`) now
makes every ground translucent and leaves every figure solid: the tile and
the corner's disc take the neutral ground whatever the band, and the ＋'s
disc takes the tile's. After: **9.18:1**, **7.53:1** and **11.55:1** on the
same face, and California reads. Full colour is pixel-identical with and
without the rule.

**The cost: a tinted face shows no band.** The system has taken the colour,
and opacity cannot stand in for it. The translucent ground is 16% of the
flat ink; four steps a reader could tell apart would have to climb to about
50%, where a pale-teal numeral computes to 2.85:1 and cream to 3.31:1 (30% —
5.67 and 6.59; 40% — 3.96 and 4.59). The count is what survives a tint, which
is the design's own accessibility rule: status never depends on colour
alone.

### Found, and left alone

On the 40mm the rectangular family is 152 to 162pt wide (194 to 196 on the
46mm) and the card's words truncate — "drinks t…", "Recorded as no al…".
Phase 6 listed the 40mm card as unverified; the design for this change says
the rectangular complication does not change, so it does not here. The
likely repair is two lines for the unit words, as the marker's sentence
already has. **Repaired the same day — the next amendment.** "152 to 162pt"
are the family's two *sizes* on the 40mm, the Smart Stack's and the face's,
not a range of one; its content is 138 and 150.

### Not verified

Always-On and redaction off the wrist (the simulator offers neither); the
X-Large face; tints other than the two above; anything on hardware.

## Amendment, 2026-09-18 (second) — the card's words wrap on a narrow card, and the 46mm does not change

The amendment above found the rectangular card's words cut short on a 40mm
watch and left them. This is the repair. It changes no copy and neither 44.

### The card is not one size

The row was the tile at 44, the words, a `Spacer` and the ＋ at 44 in an
`HStack` at 8 — and a Spacer keeps a gap on each side of itself, so the words
were left the content less 112pt. What the content *is* had never been
measured: this record's Context has "about 177 × 80pt on a 46mm watch", one
figure for a family that has two sizes there and twelve elsewhere.

The system's own figures, read from chronod's host metrics (`chrono.sql`,
`HostConfigs`: the face's host is `com.apple.nanotimekit.WidgetHost`, the
Smart Stack's `com.apple.NanoHomeScreen.WidgetHost`) on a throwaway watchOS
26.5 simulator of every case size — the family's size less its safe-area
insets. A logging build measured the two it could reach, the 40mm's face and
the 46mm's, at 150 × 57 and 181 × 65.5: the metrics, exactly. watchOS 27.0
gives the 40, 42, 44, 46 and 49mm the same.

| Case | On a face | In the Smart Stack | The words' column as it was |
|---|---|---|---|
| 40mm | 150 × 57 | 138 × 55.5 | 38 · 26 |
| 41mm | 158.5 × 60 | 151 × 55.5 | 46.5 · 39 |
| 42mm | 163 × 59.5 | 162 × 55.5 | 51 · 50 |
| 44mm | 171 × 65 | 158 × 58.5 | 59 · 46 |
| 45mm | 179 × 68 | 165 × 58.5 | 67 · 53 |
| 46mm | 181 × 65.5 | 175 × 58.5 | 69 · 63 |
| 49mm | 184 × 69.5 | 176 × 60 | 72 · 64 |

The words, as ink at the card's 11pt, measured from renders: "drinks today"
is 58.0pt on one line ("drinks" 28.5, "today" 26.5), "drink today" 52.5, and
the sentence's "Recorded" — the one thing on the card that cannot wrap — 45.0,
with "Recorded as no", the longer line of its two-line break, 72.4 (67.5 at
the 0.93 the 46mm draws it). At the 0.8 floor one line of the unit words
needs 46.4 and the sentence's two lines 58.

So the old row cut the unit words short on the 40mm — rendered on its face:
"drinks t…", "drink to…", "Recorded / as no al…"; emulated in its Smart
Stack's box (below): **"drink…" under a 3**, the plural's own "s" gone — and
by the same arithmetic in the 41mm's and the 44mm's Smart Stacks. It shrank
them on the 41mm's face, the 42mm and the 45mm's stack. And it cut the
sentence short on eight of the fourteen cards, everything under 170pt. The
defect was never the 40mm's alone; it was seen there because that is where
someone looked.

### The decision

**One width decides, and the 46mm is on the far side of it.** A card is
*wide* when the old row would leave the words 60pt — "drinks today" on one
line at full size, and a point — which is 172pt of content: the 45mm's face,
and the 46 and 49mm in both contexts. A wide card is drawn by the same views,
in the same order, with the same modifiers as before. Every other card is
*narrow*: nine, from 171pt down to 138. The 46mm's stack is three points over
the line. The card a point under it is the 44mm's face, the one card where
either row holds the words — the old row left it 59pt — so it is the right
card to have beside it.

**Narrow, the words give, because nothing else may.** The tile is the day's
mark and the ＋ is a touch target; both keep their 44. So the words take the
whole column between them — the Spacer goes, and its second gap with it; the
gaps close from 8 to **4**, the watch counter's own gap between its discs and
its tile; the unit words may take two lines and the sentence four. They wrap
before they shrink, and the floor stays 0.8. The column is the content less
96: 42 to 75pt.

**Why 4 and not 6.** Only the 40mm's Smart Stack needs it. "Recorded" is
45pt, and that card's column is 34 at a gap of 8 — under the word's 36 at the
floor, so the sentence could not be whole there at all — 38 at 6, and 42 at
4. Six was built first and rendered: the sentence drew at 0.81, on the floor
with nothing to spare, and beside a dots row (a sitting that began before
midnight, on a day since recorded as no alcohol) SwiftUI stopped fitting four
lines and cut it to "Recorded / as no al…" again. At 4 it draws at 0.90, and
at 0.86 beside the dots, whole in both.

**The width is read, never assumed** — the card's own `GeometryReader`, as
the circular family reads its slot. The arithmetic is `ComplicationCard` in
the core package, pinned at tier 1 against all fourteen widths: which cards
are wide; that a wide card's column is the old one; that every narrow column
holds "drinks" at full size and "Recorded" within a tenth of it; why the gap
is 4; where the threshold sits among the cards; and that the narrow row
never leaves the words less than the wide one would.

### The 46mm does not change

Measured, not argued. On a throwaway 46mm simulator, the card in a Modular
face's centre slot in full colour, `main` at 89c276b against this change,
every pixel beneath the clock — 132,288 of them, every channel, no tolerance
— in ten states: 0, 1, 3, 6, 16 and 100 drinks, a day recorded as no alcohol,
and 1, 3 and 16 with a running sitting's dots beneath. **None differs.** The
two binaries do differ, and the same comparison flags 7,924 pixels between
two different states, so it is not blind.

That is the face. The 46mm's other context is its Smart Stack, which no
simulator shows without a hand (below), so its content box — 175 × 58.5 — was
emulated on the face with `main`'s row and with this one under one wrapper,
in nine states, and the 49mm stack's box and the 45mm face's in two each:
**thirteen frames, none differs.** The control: in the 40mm stack's box the
same two builds differ by 1,121 pixels, all of them in the words.

### Rendered

**For real, on a throwaway 40mm simulator's Modular face** (150 × 57), full
colour. "drinks / today" on two lines at full size — the same 28.5 and 26.5pt
of ink as on the 46mm. "drink today" on one line: 52.5 in a 54pt column,
4.5pt from the tile and 5 from the ＋ — so on this face the words go to two
lines as the count goes to 2. The sentence on four lines at full size, its
block 49.5pt tall inside the 57. Ten states in all: 0, 1, 3, 6, 16 and 100
drinks, the recorded day, and 1, 3 and 16 with a running sitting's dots
beneath. Against `main`, every changed pixel on the 40mm lies inside the
words' box: the tile and the ＋ are where they were. And on a tinted face
(`gossamer.color4`), where the words wrap the same and the tinted rule above
holds.

**Emulated, for the contexts no simulator will show.** A scratch build —
never committed; it lived in a copy of the tree — pads the card down to a
content size named in the App Group's defaults and outlines the box, so the
46mm's face can stand in for any smaller card. It was checked against the
real thing first: the 40mm face's 150 × 57 emulated on the 46mm puts the
words within a pixel of where the real 40mm puts them. Then all nine narrow
cards, with the unit words, the singular, the sentence, and the sentence
beside a dots row — 36 frames, all whole:

- The unit words are at full size on every narrow card: one line on six (the
  41mm's face, the 42mm, the 44mm, the 45mm's stack), two on the 40mm's pair
  and the 41mm's stack.
- The sentence is at full size on every card but the 40mm's Smart Stack
  (0.90): four lines on the 40mm and in the 41mm's stack; three on the 41mm's
  face, the 42mm, and in the 44 and 45mm's stacks; two on the 44mm's face.
- Beside a dots row it shrinks to fit the height, 0.84 to 1.00, and is whole
  on all nine.

### What it costs

- The mid-sized watches change too, not only the 40mm. On the 41, 42 and
  44mm, and in the 45mm's Smart Stack, the words now sit 4pt from the tile
  instead of 8 and are drawn at full size where the old row shrank them. On
  some of those cards the unit words were whole as they were — smaller on the
  42mm and in the 45mm's stack, full size on the 44mm's face — and those
  change anyway, because one rule is better than three and what the first
  two get is larger type.
- On the 40mm's face and in the 41mm's stack the singular fits one line and
  the plural does not, so the words change shape between 1 and 2. They wrap
  only when they must; a forced break would be a change to reviewed copy.
- Four lines of 11pt are 49.5pt, taller than the 44pt tile beside them. It
  fits every content box it occurs in; the least room is 1.5pt, in the 41mm's
  stack.
- The widths are English's. A translation re-measures the four constants in
  the tests; the rule does not care what the words are.

### Not verified

Any Smart Stack for real. A simulator opens it only under a swipe or the
crown; the tool that drives taps asks the owner for each device, and the
owner was away — so every stack above is its *content box, emulated on a
face*, which cannot show the stack's own ground and corner, or anything the
stack does to a card while it scrolls. The 41, 42, 44, 45 and 49mm on their
own simulators: their metrics were read from their own, their boxes emulated
on the 46mm. Bold Text, which widens "Recorded" (the tightest card gives it
42pt where the floor needs 36). Redaction and the unavailable state on a
narrow card — the same "drinks today", and when unavailable no ＋ beside it,
so a wider column. Always-On; VoiceOver, where no label changed; anything on
hardware.

## How to reopen

- If the owner wants the session count on the face after all, it is one
  rule in `CounterProvider.Snapshot.entry`: the numeral and the band would
  both switch to the sitting's drinks together, never the numeral alone.
- If the ＋ is wanted in the circular family, the whole circle becomes the
  button and the count goes — the trade the design named.
- If the corner should be a tile too, it is `tile(side:)` at
  `ComplicationTile.side(forSlotDiameter:)` of its 32 to 34pt slot — 26.5 to
  28pt — and its figure (22 today) has to come down with it: "16" at 22 is
  about 22pt wide. That is a drawing to make, not a constant to change.
- If a tinted face should show the band after all, opacity is not the route
  (the 2026-09-18 amendment has the arithmetic). The one that keeps a solid
  tile readable in any tint is to cut the numeral *out* of it — the tile and
  the figure in one accent group, the figure drawn with `.destinationOut` in
  a compositing group — which is untried against WidgetKit's flattening, and
  on a photo face makes the numeral whatever is behind it. Reversing the
  tinted rule itself is one expression, `isTinted`.
- ~~If the card's words should fit the 40mm, give the unit words the second
  line the marker's sentence has; the card's width there is 152 to 162pt.~~
  **Answered 2026-09-18**, in the second amendment of that date — and the
  second line alone would not have done it: in the 40mm's Smart Stack the old
  row left the words 26pt, and "drinks" is 28.5.
- If the narrow row's 4pt gaps read as cramped on a mid-sized watch, the row
  can take a middle tier — 8 wherever the column still holds "Recorded" at
  full size, which is every narrow card but the 40mm's Smart Stack. The cost
  is the one-line unit words on the 41mm's face and in the 44mm's stack,
  which need the 4. It is `ComplicationCard.narrowGap` and one more
  threshold; the tests' table says which cards move.
- If four lines beside a 44pt tile is too tall, the limit is
  `ComplicationCard.lineLimit(isMarker:isNarrow:)`. Three lines shrinks the
  sentence to about 0.93 on the 40mm's face, and cannot hold the 40mm's
  Smart Stack at all: "Recorded as" is 58pt in a 42pt column, 0.72.
- If a real Smart Stack on a small watch disagrees with its emulated box, the
  width the card was given is one log line away — the geometry is already
  read — and the fourteen widths in `ComplicationCardTests` are what to
  correct first.
- ~~If the face lags the phone on hardware more than a raise away, the reopen
  is Phase 7's channel used for a reload signal rather than a row — a
  `WCSession` message that asks the watch to reload, carrying no data.~~
  **Answered and closed, 2026-09-15.** It cannot work, for a reason this
  record should have seen: `DrinkTrackerWatchWidget` holds no `WCSession` and
  cannot — WatchConnectivity is delivered to the *watch app*, and the face is
  only ever redrawn by `WidgetCenter.reloadAllTimelines()` from there — so a
  reload ping reaches the face only in the case where the app is already
  running and already reloading. And a reload of a store CloudKit has not
  updated yet is the same stale figure drawn again: the signal would arrive
  ahead of the fact it is signalling. If the face lags on hardware, the two
  things to examine are the sixty-second floor in `StoreChangeReloader` and
  the second `NSPersistentCloudKitContainer` the provider opens on every
  timeline build (`CounterComplication.swift:173`), both recorded as open in
  `CLAUDE.md`. The full argument is in ADR-0041's 2026-09-15 amendment.
