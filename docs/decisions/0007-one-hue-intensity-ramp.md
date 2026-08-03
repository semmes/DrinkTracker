# 0007 — The calendar's intensity ramp is one hue, validated

**Status:** accepted · **Date:** 2026-08 · **Relates to:** PRD invariants 8 and 10

## Context

The calendar and year view shade each day by how much was logged. That needs a
palette, and `GlassTokens` deliberately defines no colours at all — everything
inherits system semantic colours so Liquid Glass handles light, dark, and vibrancy.

The obvious ramp, and the one comparable apps use, is **green → yellow → orange →
red**, with a fifth dark step for the heaviest days. It was asked for explicitly,
with the note that colourblind readers should be able to tell alcohol-free days from
1–2 drink days.

That ramp cannot be fixed by adjusting its shades. It fails twice, structurally.

**It is unreadable for a large minority.** Under protanopia and deuteranopia —
together around 8% of men — green, yellow, orange, and red converge toward the same
yellow-brown. Worse, all four sit at similar lightness, so once hue collapses there
is nothing left to separate them. The single worst pair in the ramp is exactly the
one that matters most here: no-alcohol green against 1–2-drinks yellow, adjacent in
hue and near-identical in lightness.

**It delivers a verdict.** Red for a heavy day and green for a clear one tells the
user what to think about their own month. `QuickLogWidget` already commits, in its
doc comment, to "no colour that reads as a verdict", and PRD §1 rules out
congratulation and warning alike.

## Decision

**One hue — blue — stepped light to dark.** Magnitude is carried by *lightness*,
which survives every form of colour vision deficiency and greyscale printing. A
darker cell reads as *more*, not as *worse*.

| | 1–2 | 3–5 | 6+ |
|---|---|---|---|
| Light | `#86b6ef` | `#2a78d6` | `#0d366b` |
| Dark | `#184f95` | `#3987e5` | `#9ec5f4` |

Dark mode is stepped independently against the dark surface rather than inverted:
an inverted light ramp falls outside the usable band at both ends.

**Alcohol-free is not a step in that ramp.** The palest blue would say *a small
amount of drinking*; it is the absence of the measured quantity, not the bottom of
it. It takes a neutral fill instead, which also puts the maximum available distance
between it and the 1–2 bucket.

**A second, non-colour channel.** Alcohol-free days carry an outline. Anyone who
cannot separate the fills at all still gets a shape difference, and that is what
actually answers the original request rather than merely improving the odds.

**Unlogged days get no fill.** Absence of information is drawn as absence, and the
legend names it so a blank cell is not misread as a zero.

**Changes are validated, not eyeballed** — monotone lightness, adjacent ΔL ≥ 0.06,
light-end contrast ≥ 2:1 against the surface, single hue, checked in both modes. The
values above pass all four. This is invariant 10.

## Consequences

- `IntensityPalette` is the only literal-colour file in the app. That is a real
  exception to a deliberate rule, so it is scoped to the calendar surfaces and its
  doc comment says why it exists.
- The calendar looks less immediately "alarming" than the competitor's. That is the
  intended outcome, not a side effect.
- Blue is the accent colour, so the ramp sits inside the app's existing palette
  rather than introducing a second one.
- Anyone changing these values has to re-run the checks. A hue-based ramp reads fine
  to a reviewer with normal colour vision, which is exactly why the gate is
  mechanical rather than editorial.

## How to reopen

If the calendar ever needs to encode something genuinely *diverging* — two
directions from a meaningful midpoint — a single sequential hue would be the wrong
form and this should be revisited. Nothing about "how much was logged" is diverging:
it starts at none and goes up.
