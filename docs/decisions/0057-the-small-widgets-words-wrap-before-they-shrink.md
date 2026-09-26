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
is its own change.

StandBy shows the small family with narrower margins than the Home Screen on every phone
(116.43 on the SE against 113.95), so the Home Screen is the case that binds.

**Passed on the owner's phone** (2026-09-26, after PR #140 merged), in the owner's
words: "Working as expected on the widget." The report does not say which counts or which
appearance were read.

## Not verified

Anything on a device beyond that report; any iPad, whose small widget is another set of
sizes (the rule reads no width, so it wraps wherever
it must, but nothing was rendered there); StandBy and the tinted and clear Home Screen
styles (layout does not change with the rendering mode); Bold Text, which widens the
words; VoiceOver, whose label is unchanged; and the phones whose frames were measured by
the logging build but not photographed with the real one — every size but the SE, the
162.67pt row (the owner's 15 Pro), the 17 Pro and the 17 Pro Max.

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
- The count's own truncation on the SE is a separate decision, above.
