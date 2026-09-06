# 0007 — The calendar's intensity ramp is one hue, validated

**Status:** accepted · **Date:** 2026-08 · **Relates to:** PRD invariants 8 and 10 ·
**Amended by:** ADR-0027 (`ShareCardInk`, the exported image's ground and inks, is
the named second literal-colour site; every fill and outline still comes from here)

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

- `IntensityPalette` is the only literal-colour file in the app, with one named
  companion since ADR-0027 (`ShareCardInk`, for exported images, which have no
  host surface). That is a real exception to a deliberate rule, so it is scoped
  to the calendar surfaces and its doc comment says why it exists.
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

---

## Amendment (2026-09-06, ADR-0034) — a fourth step, and a second surface

Two changes, both requested by the owner while reviewing the Home v2 design.

**The ramp gains a fourth drinking step.** `6+` was open-ended, so a six-drink
evening and a fourteen-drink one drew the same cell and the top of the scale
stopped describing anything. `DayIntensity` now buckets 1–2 / 3–5 / **6–9** /
**10+**, and the new `.veryHigh` step is:

| | 1–2 | 3–5 | 6–9 | 10+ |
|---|---|---|---|---|
| Light | `#86b6ef` (250) | `#2a78d6` (450) | `#0d366b` (700) | `#05172e` (**800**) |
| Dark | `#184f95` (600) | `#3987e5` (400) | `#9ec5f4` (200) | `#cde2fb` (**100**) |

Re-validated, not eyeballed. CIE L\* from sRGB; contrast by WCAG relative
luminance:

- **Monotone** — light 72.73 → 50.43 → 22.95 → 7.61; dark 33.89 → 55.94 →
  78.30 → 89.08.
- **Adjacent ΔL ≥ 0.06** — light 0.223 / 0.275 / **0.153**; dark 0.221 / 0.224 /
  **0.108**.
- **Light-end ≥ 2:1 against the surface** — unchanged at both ends of the
  scale that touches a surface (`#86b6ef` 2.11:1 on card white; `#184f95`
  2.10:1 on `#1C1C1E`), because neither pale end moved.
- **Single hue** — light 800 sits at 278.1°, inside the family's own
  262.6–283.0° span.
- **Ink** — white on `#05172e` is 17.97:1; black on `#cde2fb` is 15.87:1. Both
  follow the existing flip rule, so `.veryHigh` joins `.medium, .high` in
  `IntensityPalette.ink`.

Two things a later session should know. The **dark** step is step 100 of the
documented family rather than a new value — step 150 `#b7d3f6` was the obvious
pick and fails, at ΔL 0.053. And `#05172e` is the ramp's **floor**: at L\* 7.6
there is no room for a fifth step beneath it, so a future "20+" bucket would
mean re-spacing the whole ramp, not extending it. Luminance contrast between
the two deepest fills is 1.50:1 light and 1.35:1 dark, below the 2.04–2.71 of
the pairs above them — luminance compresses at both ends of a lightness ramp,
which is why the stated gate is the perceptual one. The outline channel that
separates "recorded as none" from "not logged" is untouched.

**Everything that shows the ramp moves together, deliberately.** The legend goes
from five entries to six, on the calendar, the year view and both share cards,
because all three iterate `DayIntensity.legendOrder`. The cost is real and is
accepted: a day that drew `#0d366b` yesterday now needs 6–9 rather than 6+, so
every existing user's calendar and every future share card re-shade at the top
end. Nothing about the underlying record changes — this is a resolution change
in the display lens, like a region change (ADR-0002).

**The scope sentence in Consequences now has a second named surface.** Today's
hero band paints the counter with `fill`/`ink`/`isOutlined`, unchanged, over
`DayIntensity.bucket` of the same region-lensed total the calendar cell for that
day uses. It is reached by name — an accessor over existing constants, the
`liveFigure(scheme:)` precedent exactly — so no value is copied and
`IntensityPalette` stays the only place the app defines literal colours. The
argument for allowing it is the one that makes the ramp legitimate anywhere: the
colour *is* the data, the legend states the boundaries, and the figure it
qualifies is printed in digits directly beneath it.

The third consumer is the session-pace chip — see ADR-0017's amendment, which is
where the harder argument lives.
