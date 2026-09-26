# 0057 — The small widget's words wrap before they shrink

**Status:** accepted · **Date:** 2026-09-26 · **Relates to:** ADR-0046 (its second
amendment of 2026-09-18, the watch card's same repair); ADR-0047 (the widget's
unavailable state); ADR-0009 (count-first; the widget's count and ＋);
`docs/design-system.md` (the Widget row)

## Context

The owner's screenshot for the marketing site (the design handoff,
`docs/design/marketing-design-handoff/`, untracked in the owner's checkout) shows the
small Home Screen widget on an iPhone 17 Pro-size simulator reading "2" over "drinks
tod…". The widget is `DrinkTrackerWidget/QuickLogWidget.swift`: an `HStack` at 12 of
the count over its words, a `Spacer`, and the ＋ — a 52pt disc on the small family, 60
on the medium. The words were caption2 on one line, allowed to shrink to 0.8.

**The small family is not one size, and its words have never had the room.** What the
system gives the family was read from chronod's own host metrics (`chrono.sql`, table
`HostConfigs`, the `SpringBoard-Homescreen` host, `metricsByFamily["1"]`) on an iOS 26.5
simulator of every one of the 31 iPhones iOS 26 supports, created, booted, read and
deleted on 2026-09-24. They fall into eleven sizes, and iOS 27.0 gives the same eleven.
The content margins are 9/82 of the side on every one, so the content is square:

| Small widget | Content | iPhones | The row as it was | The row now |
|---|---|---|---|---|
| 146 | 113.95 | SE (2nd and 3rd generation) | 37.95 | 49.95 |
| 159 | 124.10 | 11 Pro, 12 mini, 13 mini | 48.10 | 60.10 |
| 162 | 126.44 | 12, 12 Pro, 13, 13 Pro, 14, 16e, 17e | 50.44 | 62.44 |
| 162.67 | 126.96 | 14 Pro, 15, 15 Pro, 16 | 50.96 | 62.96 |
| 164.33 | 128.26 | 16 Pro, 17, 17 Pro | 52.26 | 64.26 |
| 166.5 | 129.95 | 11 | 53.95 | 65.95 |
| 171.33 | 133.72 | 11 Pro Max | 57.72 | 69.72 |
| 172.67 | 134.76 | Air | 58.76 | 70.76 |
| 174.33 | 136.07 | 12 Pro Max, 13 Pro Max, 14 Plus | 60.07 | 72.07 |
| 174.67 | 136.33 | 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus | 60.33 | 72.33 |
| 176.67 | 137.89 | 16 Pro Max, 17 Pro Max | 61.89 | 73.89 |

These are not the sizes in Apple's published table, which predates iOS 26 (it gives the
SE 148 and the 12 to 14 158). The last two columns are what each row left the words: the
content less the ＋ and, as it was, **two** gaps of 12 — a Spacer keeps a gap on each
side of itself, the watch card's lesson (ADR-0046) — and now one.

**The words, measured on the simulator** with a logging build that was never committed
(it recorded each view's laid-out frame into a file in the App Group container): at the
default text size "drinks today" is 64.5pt on one line, "drink today" 58.9, and "drinks",
the longer word, 32.0. **The Plus and Pro Max phones draw the widget's text larger** —
1.158 times, with the environment still reporting the default size: 74.7, 68.0 and about
37. The count is a fixed 44pt and the same on every phone.

So the old row never drew the plural whole at full size. Rendered on all eleven sizes
with the logging copy of the old view, which draws what it does: **it cut "drinks today"
short on nine** — "drinks…" on the SE,
"drinks to…" on the 11 Pro Max and the 159pt phones, "drinks tod…" on the rest — and only
shrank it on the iPhone 11 and the Air. It cut "drink today" short on the SE ("drink t…")
and the 159pt phones ("drink tod…") and shrank it everywhere else. The linear floor,
64.5 × 0.8, says the 17 Pro's 52.26 should have held the plural at 0.81; it did not,
presumably because the system font sets small sizes relatively wider. Only a render says
what a floor holds.

The words also follow the reader's text size, **but only so far**: on both kinds of
phone "drinks today" stopped growing at 93.5pt on one line — reached at AX1 on the SE and
at xxLarge on the 17 Pro Max, unchanged up to AX5. The old row cut it short at every
larger size on both.

The watch card's other state, a sentence for a day recorded as no alcohol, **does not
exist on this widget**: its provider reads drinks only, so such a day draws "0 drinks
today". The unavailable state (ADR-0047) draws "drinks today" with no ＋ and so has the
whole row.

## Decision

**The count and the ＋ keep their sizes; the words give.** They take the whole column
beside the ＋ — the Spacer goes, and its second gap with it, with the column framed to
the leading edge so the ＋ still sits at the trailing one — and they may take a **second
line**. They wrap before they shrink, and the floor stays 0.8. No copy changed.

**One row for both families, and no width is read.** Where the old row already held the
count and the words whole at full size, the new row draws the same pixels: the count at
the leading edge, the ＋ at the trailing edge, the words left-aligned. That is every
medium widget (its narrowest column is 214.95). On the iPhone 11 and the Air the plural
now fits one line too, but the old row drew it shrunk there, so the words draw at full
size and the count sits slightly higher. SwiftUI's own wrapping is the threshold, so
unlike the watch card there is no width to read and nothing to emulate.

The constants the widget reads — the two ＋ sides, the gap, the line limit, the floor —
are `QuickLogWidgetRow` in the core package, pinned at tier 1 against the eleven widths
above: that no phone's old column held the plural at full size; that every new column
holds "drinks" at full size, so two lines are always enough; which phones keep the plural
on one line (the iPhone 11 and the Air) and the singular (all but the SE); that two lines
under the count fit every widget's height; that at the largest text the widget draws two
lines still fit on every phone; and that the medium family never needs a second line.

## Consequences

**Rendered with the logging copy of the new view.** At the default size the words are
whole on all eleven sizes: the plural on two full-size lines everywhere but the iPhone 11 and the Air, where
it now fits one line at full size; the singular on one line everywhere but the SE. At
every larger size from xLarge to AX5, on the SE and the 17 Pro Max, "drinks / today" is
whole.

**Before against after, the real builds reading a seeded store** (2026-09-26), in two
passes. First the SE, the 17 Pro and the 17 Pro Max — the smallest widget, the
screenshot's, and the largest — in light and dark, at 0, 1, 2 and 12 drinks. Then, after
review, the owner's own phone, an iPhone 15 Pro (the 162.67pt row), on iOS 27, beside a
17 Pro on iOS 26.5, in light and dark, at 1, 2, 16, 20, 80 and 111 drinks. On every frame
the small widget changes only to the left of the ＋: the words, and the count. The
**medium widget does not change**: across the 48 before-and-after pairs no pixel differs
by more than one unit in one colour channel, 31 pairs not at all, and the 571
single-unit pixels sit on the glass ground and rim; the same comparison between two
states of one build flags 7,859 pixels. One "before" frame of the second pass caught the
widget before its first redraw on iOS 27 (it still read 0) and was taken again.

What it costs:

- **The count rises when the words wrap.** The block — count over words — stays centred
  on the ＋, as it always was, so the count rises by half of what the words gain: the
  second line, and the first line's return from the 0.8 floor the old row drew it at.
  That is 7.0pt on the SE and the 17 Pro and 9.3pt on the 17 Pro Max, measured from the
  renders. Its size and its left edge do not change.
- **A count too wide for one line loses the room it had below.** The old row could break
  100 over two lines under a single line of words, "10" over "0" on the 17 Pro; with the
  words on two lines there is no height left, so it is cut short, "1…". It takes a
  hundred drinks in a day, and neither drawing was right.
- **The words change shape between 1 and 2 on most phones.** The singular fits one line
  where the plural does not. They wrap only when they must; a forced break would be a
  change to reviewed copy — the watch card's cost, accepted there too.
- **The widths are English's.** A translation re-measures the constants in the tests;
  the rule does not care what the words are.

**The count changes too, though it was to be kept as it is.** It shares the words'
column, and the old column was too narrow for most two-digit counts. On the SE the old
row drew any count from 10 as "…" — the widget's own figure, gone. On the 159 to
166.5pt phones, eighteen iPhones with the owner's iPhone 15 Pro among them, it broke a
wide pair over two lines — rendered on the 15 Pro and the 17 Pro, computed for the other
three sizes: 20 as "2" over "0", 80 as "8" over "0", and 111 as "11" over "1", while a
narrow pair such as 16 (48.8pt) stayed whole. The new column holds every two-digit count
on one line on every phone but the SE (the widest, 80, measures 56.6pt with CoreText,
against the 159pt phones' 60.1), and 111 from the 162.67pt phones up — rendered whole on
both. What is left is the SE and three-digit counts: the
SE now holds 10 to 19 ("16" in 49.95) but not a wider pair such as 20 (54.7, computed
from its two digits' measured widths), and no small widget holds 100 (77.7). That repair
is its own change: the amendment of the same day, below.

StandBy shows the small family with narrower margins than the Home Screen on every phone
(116.43 on the SE against 113.95), so the Home Screen is the case that binds.

## Not verified

A real device, where a widget change needs the widget removed and added again; any iPad,
whose small widget is another set of sizes (the rule reads no width, so it wraps wherever
it must, but nothing was rendered there); StandBy and the tinted and clear Home Screen
styles (layout does not change with the rendering mode); Bold Text, which widens the
words; VoiceOver, whose label is unchanged; and the phones whose frames were measured by
the logging build but not photographed with the real one — every size but the SE, the
162.67pt row (the owner's 15 Pro), the 17 Pro and the 17 Pro Max.

## Amendment, 2026-09-26 — the count shrinks on one line

**Context.** The decision above kept the count as it was, and the count was where the
row still failed. It shares the words' column, 49.95pt on an SE to 73.89 on a 17 Pro
Max, at a fixed 44pt in SF Rounded semibold with proportional digits. Measured with
CoreText, whose digits agree with the simulator's frames to the hundredth ("0" 28.42,
"16" 48.84, "100" 77.74), every two-digit count fits every column but the SE's, where
20 (54.66) and every wider pair does not, and 100 fits none. With no line limit, the
count wraps into whatever height the widget has left. The words' second line took that
height, so a count too wide was cut short. Rendered before this change on a scratch SE,
20, 80, 100, 199 and 999 all drew as a bare "…". The 17 Pro and the 17 Pro Max draw
100 as "1…".

**Decision (the owner's, asked the same day).** The count is one line and may shrink to
a floor of **0.6**. That is the rule every other count numeral in the app already uses:
Today's hero (`CountStepper`), the watch counter (`CounterTile`) and the complication's
tile. The words and the ＋ do not change. Two other answers were offered and not taken.
One let the count run into the 12pt gap before the ＋, the only width beside the column
(the count and the words already share it): it would have held every two-digit count on
the SE with the digits touching the ＋'s disc, and never 100. The other left the count as
ADR-0057 drew it.

The owner also kept the **proportional digits**, though the other three counts are
tabular. Tabular digits would redraw every count with a 1 in it wider (11 from 41.8pt to
56.3). On the SE they would shrink every count from 10, and 100 would need 0.59, under
the floor.

**A count that fits is drawn exactly as before, and one that shrinks keeps the full-size
line.** A `ViewThatFits` picks between two views. The first is the old `Text`, untouched,
which it takes whenever the count's natural width fits the column. The second draws the
count as an overlay on a hidden "0" as wide as the column, aligned by baseline, with the
line limit and the floor. So a shrunk count sits on the baseline the full-size count sat
on, and the words under it do not move. Each part was needed, and each was found by
rendering, not reasoning:

- A plain one-line text drew a shrunk count on a shorter line, and the words rose 7.5pt
  with it (measured in a SwiftUI harness sized like the SE's widget).
- The first build held the line with a baseline-aligned `ZStack` of the same two texts.
  The simulator showed it shrinking counts that fit, "16" on the medium widget among
  them, and a zero-width `HStack` placeholder did the same in the harness.
- The overlay alone proposes the count the column's exact width and drew every fitting
  count unchanged on the SE. On the 17 Pro Max it moved each one up a pixel, a third of
  a point, which the harness could not reproduce. `ViewThatFits` keeps the overlay off
  every count that fits.

**What SwiftUI actually draws.** It does not scale continuously. Measured by matching the
harness's pixels against fixed sizes, a shrunk count is set on a **quarter-point grid**
with about a tenth of a point to spare, never under **26.5pt** (0.6 × 44 is 26.4). In the
SE's column: 20 at 40.0pt, 80 at 38.75, 99 at 39.0, 100 at 28.0, 111 at 34.75, 199 at
28.25 and 250 at 26.5. **200 is cut short**, because it needs 26.43pt. So the SE holds
every count to **199**, and some counts above it. Every other small widget holds every
count to 999, the 159pt phones' widest (800) at 0.71. On the 17 Pro Max, 100 draws at
about 0.95. Every two-digit count stays at full size on every phone but the SE, and the
SE's two-digit counts draw at 0.88 (80) to full size: 21, 31 and the other pairs ending in
1 fit at 44. The medium family never shrinks a count of four digits or fewer.

**Pinned at tier 1**, beside ADR-0057's constants in `QuickLogWidgetRow`:
`countLineLimit`, `countMinimumScale`, and `countScale(forWidth:inColumn:)`, the rule as
a function. The tests read each digit's measured advance. A count is never wider than
the sum of its digits' advances, since pairs kern only tighter (by up to 3.4pt, never
looser), so the tests use that sum as an upper bound. They claim a count whole only where
it clears the floor by 0.02, the grid's margin. What they pin: every two-digit count at
full size on every phone but the SE, 10 to 19 at full size there and 20 not; the SE's
two-digit counts at 0.88 or more; every count whole to 199 on the SE and to 999
elsewhere; 100 shrunk on every small widget, about 0.64 on the SE and 0.95 on the
largest; and the medium never shrinking.

**Rendered, before against after,** with the real builds reading a seeded store on
scratch SE and 17 Pro Max simulators (iOS 26.5). Light mode at 1, 2, 16, 19, 20, 21, 80,
99, 100, 111, 199, 299 and 999 drinks, dark at 2, 20 and 100, and 200 in the after build
only. **Before,** the SE drew every count from 20 as a bare "…", and the Pro Max drew
100, 199, 299 and 999 as "1…", "2…" and "9…".

**After:**
- Every count that fits is pixel-identical to before: 1 to 19 and 21 on the SE, and
  every rendered count to 111 on the Pro Max.
- On the SE, 20, 80, 99, 100, 111 and 199 shrink. 200, 299 and 999 are cut short ("2…",
  "9…"), as the grid predicts. On the Pro Max, 100, 199, 299 and 999 shrink.
- The sizes read from the ink agree with the harness to a pixel's precision: on the SE
  20 at about 39.9pt and 100 and 199 at about 28.2; on the Pro Max 100 at about 41.7.
  Every count's ink ends on the same baseline.
- Every changed pixel is inside the count's box, left of the ＋, and nothing outside the
  small widget changed.
- The medium widget is identical in all 32 pairs: no pixel differs by more than one unit
  in one channel.

The first two builds were rendered the same way, and the renders are what showed their
defects.

**Costs.**
- **On the SE the count's size changes between neighbours.** 19 and 21 draw at 44pt,
  20 at 40 and 22 at 41.5, because proportional digits make each pair its own width. The
  change is at most 12% of the size, and only on the SE's two-digit counts. Tabular
  digits would draw all of them at one size (0.89), at the costs above.
- **A count past the floor is still cut short:** 200 and some counts above it on the
  SE, and four-digit counts on the smaller phones (from 1,000 on the 159 to 162.67pt
  ones). Neither is a day anyone logs.
- **The change from full size to shrunk is abrupt.** A count one drink wider changes
  size in the same step as its digits change. The numeric content transition animates
  the digits, and the size change was seen only in end states.

**Not verified:** hardware (remove and re-add the widget); the transition between a
full-size and a shrunk count, seen only as end states; the other nine small sizes, which
were computed from their columns and not rendered; StandBy; any iPad; Bold Text, which
does not touch a fixed-size count.

## How to reopen

- If the count's rise reads as a jump, the block can be aligned to the count rather than
  centred on the ＋, so the second line hangs below. That is a drawing to make, and the
  words then sit lower than the ＋'s centre.
- If one line is wanted on more phones, the gap is the lever the watch card used. At 8,
  computed from the table, the plural would fit one line on the 162 to 164.33pt phones
  and the 174.33pt Plus and Pro Max sizes and up, still not on the SE, the 159pt phones
  or the 11 Pro Max, and the words would come within 8pt of the ＋. It is
  `QuickLogWidgetRow.gap` and the tests' table. A shorter phrase is a copy change and
  goes through the 1.4.3 review.
- If a new iPhone arrives, read its small family from `chrono.sql` on a simulator of it —
  one create, boot, read and delete — and add its row to the tests; if its text is drawn
  at a third size, measure the words on it first.
- The count's own truncation was a separate decision, made in the amendment above. If
  its size changing between neighbours on an SE reads as noise, tabular digits
  (`.monospacedDigit()` on the count, as the other three counts have) draw every
  two-digit count there at one size, 0.89. The cost is in the amendment: every count
  with a 1 redraws wider, and 100 on the SE needs 0.59, so the floor would go to 0.55.
- If a count past the floor turns up in use (200 on an SE), the floor is the lever:
  `QuickLogWidgetRow.countMinimumScale`, the tests' `wholeAtLeast`, and a render, since
  SwiftUI's grid, not the arithmetic, decides the edge. Running the count into the ＋'s
  gap was declined, and it would not reach three digits anyway.
