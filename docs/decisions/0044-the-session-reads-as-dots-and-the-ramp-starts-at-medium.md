# 0044 — The session reads as dots, and the ramp starts at medium

**Status:** accepted · **Date:** 2026-09-14 · **Relates to:** ADR-0017 (the
session pace card and its three hard rules); ADR-0034 (the counter carries
the day's colour; the chip reads the ramp); ADR-0007 (the outline as the
off-ramp channel); ADR-0045 (the watch hides its numbers by default); PRD
invariant 10; `docs/tallyist-watch-plan.md` (divergence 2, Phase 5);
`docs/design/watch/README.md` (screen 4)

## Context

The phone's session pace card shows four values — drinks this session, when
it started, time since the last, and the rolling two-hour count as a chip
shaded by the ramp — because the phone has room. The wrist does not, and it
has a different reader: someone glancing, not reading. The plan reduces the
card to the one number the feature exists for, the count, and one supporting
figure, the time since the session started, drawn as a row of dots over a
short line.

Five questions had to be settled to build it.

**How many dots.** Dots stop being countable past about eight. Width is not
the constraint — at the drawn sizes eight dots take 107pt of the smallest
watch's 162 — countability is. And a session count can be fractional: a
Health import contributes its own count, which another app may have written
as 1.5, and the line beside the dots prints that count to one decimal
through `StandardDrink.displayed`.

**What colour, and from which band.** The dots should read the rolling
window's band the way the phone's chip does — a shade on the wrist meaning
exactly what it means on the calendar (ADR-0034's argument, invariant 10's
"one hue, one scale"). But the phone's `.high`-and-above floor cannot be
copied. The chip is text on a fill and answers to 4.5:1 of its ink against
that fill; a dot is a graphical object and answers to 3:1 against its
*background*. The watch renders against the dark ground only, so only the
dark ramp is in question — against pure black, the OLED ground, and against
`#1C1C1E`, the design system's reference for a dark surface. Computed for
this record with WCAG 2 relative luminance from the four dark colours as an
8-bit display renders them (the hex values `IntensityPalette` documents, which
its `Color(red:green:blue:)` literals quantise to):

| Band | Dark fill | vs `#000000` | vs `#1C1C1E` |
|---|---|---|---|
| `.low` | `#184f95` | 2.59 : 1 | 2.10 : 1 |
| `.medium` | `#3987e5` | 5.77 : 1 | 4.68 : 1 |
| `.high` | `#9ec5f4` | 11.75 : 1 | 9.52 : 1 |
| `.veryHigh` | `#cde2fb` | 15.87 : 1 | 12.86 : 1 |

Two of these rows check against figures the project already published by a
different route, which is the reason to trust the other two: `IntensityPalette`
documents `#9ec5f4` at 11.75:1 on black and 9.52:1 on `#1C1C1E`, and
`#cde2fb` at 15.87:1 on black, and `SessionPaceCard.paceBand` states the same
two ink-on-fill figures (the dark ink is black from `.medium` up, so
ink-on-fill and fill-on-black are one quantity). The plan's own table reads
11.76, 15.86, 9.53 and 12.85 for the same cells: it was computed from the
unquantised three-decimal component literals rather than the 8-bit colours
they render as, and the two bases differ by a unit in the second decimal
everywhere. Neither basis moves any cell across a threshold. `.low` fails
3:1 against either ground, worse against the grey than the black;
everything above it clears it with room.

**What a neutral dot looks like.** A grey fill would be a fifth shade on a
scale that has four. The design system already has a second channel for
"off the ramp": the outline (ADR-0007). But a 9pt ring has to clear 3:1 on
its own, and the tile border's `.primary` at 35% sits on the line — white at
35% over black is 3.01:1 unquantised and 2.998:1 as the `#595959` an 8-bit
display renders it — while the secondary label colour,
`rgba(235,235,245,0.6)` over black, `#8d8d93`, measures 6.36:1 (5.16:1 on
`#1C1C1E`).

**What the row shows when the count is hidden.** The design's hidden state
draws the dots' fill falling to outlines and says nothing about their
number. But a row of rings at the count is still the count, readable across
a table up to eight — more precise than the "3–5" label ADR-0045 refuses to
leave visible while the numeral is hidden, on the very screen the hide
exists to protect.

**Where the switch lives.** The phone's card is off by default behind
Settings → "Show session pace", and the plan's divergence 2 makes the watch's
setting its own: per device, in the watch's App Group, never crossing the
settings bridge, because it changes what is shown and not what is computed.
The watch has no Settings screen, and adding one for a single switch would
put chrome on a surface the design keeps bare.

## Decision

**Dots up to eight, the rule in the domain package, decided on the displayed
figure.** `SessionPace.dotRow(forCount:maximum:)` returns the dots to draw
and whether the cap hid any; above the cap the row draws the cap and the
count line carries the truth. No truncation mark. The dots are decided on
`StandardDrink.displayed(count)` — the one-decimal figure the line prints —
rounded to the nearest dot with a half up, so the dots and the figure cannot
disagree: 2.45 prints "2.5" over three dots, as 2.5 does, where the raw
value would have drawn two. This is the rule `StandardDrink.displayed` states
for anything that has to agree with the digits on screen, and the one
`DayIntensity.bucket` follows. Nothing for zero, a negative or a non-finite
count, except that a count beyond any bound is simply more than the cap.
Pinned at tier 1.

**The ramp starts at `.medium`.** The dots take `IntensityPalette.fill` for
the band of the rolling two-hour window's standard drinks —
`DayIntensity.bucket` over `SessionPace.rollingStandardDrinks`, the chip's
exact rule — from `.medium` up. Below that they are rings in the secondary
label colour, 1pt. Four states — a ring and three fills — where the phone's
chip has three; the floors differ because the objects differ under WCAG, and
each is measured.

**The line is `N · 1h 12m`**: the count in rounded semibold (the user's own
figure) and the elapsed time since the session's first drink in default SF
(the clock's), from `DateComponentsFormatter`. No start timestamp, no "last
drink N ago", no rolling chip.

**Concealed, the row keeps its shape and not its number.** Under the
per-glance hide (ADR-0045) and under Always-On redaction alike, the row
draws eight rings whatever the count, and the line is gone — not
placeholdered: `.privacySensitive()` on its own would draw redaction blocks
the width of the digits. Eight rings say a sitting is on and nothing else.
This departs from the drawing, which outlined the dots at their count, for
the reason above; it is one expression to reverse.

**The switch is the last thing on the counter's scroll**, below the hint, out
of sight until the wrist scrolls — the phone's exact words, "Show session
pace", off until set, stored under the phone's own key in the watch's App
Group through `AppSettings.storedShowsSessionPace()` / `store(showsSessionPace:)`.
The screen a user raises stays the counter. It is not offered while the
storage strip owns the slot: a switch for a row that cannot appear would be
a promise.

**Amended 2026-09-15, on the owner's device pass: the switch appears only on
a day with a drink in it.** The row it governs cannot exist without one, so
on a dry day the switch is a control for nothing — and the argument is not
only tidiness: this app does not put a session surface in front of someone
who is not having a session. Someone who logs nothing for a week never meets
the control at all. The one exception is the switch's own reachability: once
it has been turned on it stays on screen, so the setting can never be
stranded out of reach on a dry day. A reader who has never turned it on —
every reader, by default — sees it only after logging.

**The three hard rules hold on the wrist.** The row exists only while
`SessionPace.currentSession` returns a value; nothing about a gap is written
anywhere; no notification code path exists in the target. It recomputes
inside a sixty-second `TimelineView`, never a `Timer`. The counter's query
reaches back to the start of the previous day so a sitting that began before
midnight is still one sitting; a run longer than that is cut at the day, and
accepted.

**The dots are decorative to VoiceOver.** The row is one element whose label
is the phone card's own sentence ("5 drinks this session") and whose value is
the elapsed time spelled out — concealed or not, since a screen reader is not
the audience the hide protects. The colour adds nothing a reader needs
twice, the argument `SessionPaceCard` already makes.

## Consequences

- A `.low` window — under 2.5 standard drinks in two hours — shows rings at
  the count. On a screen this small that is a visible state, not a missing
  one, and it is the same shape the alcohol-free tile uses to say "off the
  ramp".
- The phone's chip starts at `.high` and the watch's dots at `.medium`. The
  two floors differ because the objects differ under WCAG, and each is
  measured; neither should be "aligned" to the other by copying.
- A count and its dots agree to the displayed tenth: the line prints "2.5"
  and three dots stand over it, for every count that prints "2.5".
- Concealing the count changes the row's width: three dots become eight
  rings, crossfaded. The design's "do not animate the gap" rule was written
  for the legend's swatches shifting as a side effect of labels leaving;
  here the change *is* the hide, and a row that kept its count would keep
  the number it was asked to put away.
- The switch is discoverable only by scrolling. Off by default, that is a
  feature the wrist opts into once, the way the phone does in Settings.
- A session longer than the query's reach — drinks under four hours apart
  from before yesterday's midnight — reads as starting at the day's edge.
  Stated rather than fixed: widening the query is one constant.

## How to reopen

- If field use shows eight dots are too few or too many, the cap is
  `SessionPace.dotMaximum`, one constant with tests behind it; the row has
  room for more.
- If the ringed `.low` state reads as "no colour yet" rather than "a small
  amount", the reopen is a fill for `.low` that clears 3:1 on black — which
  means a new ramp step, validated the way ADR-0034 validated `#05172e`, not a
  lighter tint of the existing one.
- If eight constant rings read as "eight drinks" on a real wrist, the reopen
  is a row that vanishes when concealed rather than one that keeps its
  count — the count is the thing the hide is for.
- If a real watch's ground is not black — a face-derived tint behind the app
  is the one case — the table's second column is the one to re-derive, and
  `#1C1C1E` is a stand-in until a device says otherwise.
- If a stored hide preference ever governs the watch (ADR-0045's reopen),
  this row follows it: eight rings, no line.
