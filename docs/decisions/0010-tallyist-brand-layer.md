# 0010 — The Tallyist brand layer: one hue, three named jobs

**Status:** accepted · **Date:** 2026-08 · **Relates to:** ADR-0007, PRD invariant 10
· **Spec:** [design-system.md](../design-system.md)

## Context

The app shipped deliberately brandless: `GlassTokens` defines no colours, the
accent was Apple's system blue, and everything inherited Liquid Glass behaviour.
That was the right start — and the README's own theme comment kept a door open:
*"swap this single value if the app ever takes on a brand color of its own."*

With the product renamed Tallyist and heading for the App Store, it takes on a
brand. The question was how to add one without breaking what the brandless
approach bought: automatic light/dark, vibrancy, Reduce Transparency, and the
tone rules that keep colour from becoming a verdict.

## Decision

**One hue family — the already-validated blue ramp — with every permitted blue
named and assigned exactly one job.**

| Job | Steps | Where defined |
|---|---|---|
| Interactive accent (text/glyphs) | 500 light / 400 dark | `AccentColor` asset, both targets |
| Interactive fills | 500, both modes | `AppTheme` (ComponentsKit) |
| Data (intensity ramp) | 250/450/700/**800** light · 600/400/200/**100** dark | `IntensityPalette` |
| Icon field | 650 | `scripts/make-app-icon.py` |

Chosen by measurement, not eye: 450 — the draft accent — fails AA as normal text
(4.30:1) and under a white label (4.42:1); 500 passes both (5.26 / 5.39:1), and
400 passes as text on the dark surface (4.79:1). The numbers live in
design-system.md §2 and §8.

**`GlassTokens` still defines no colours.** The brand layer lives in exactly two
code locations (the asset catalogs and `AppTheme`) plus the data palette that
ADR-0007 already governs. Everything non-branded stays system semantic colour.

**Typography signature:** user-made numerals are SF Rounded; all other text is
default SF. No custom fonts — recognisability without licensing, bundle weight,
or Dynamic Type risk.

## Consequences

- The whole app re-tints from system blue to Tallyist Blue in one change, because
  every interactive colour already routed through `Color.accentColor` or the
  ComponentsKit theme. The brandless discipline is what made branding cheap.
- The data ramp and the interactive accent now share a family but not a step.
  That is deliberate (review R1): they are different jobs with different contrast
  requirements, and sharing 450 between them was the draft's error.
- Any future second hue has to argue with this document, and with ADR-0007's
  observation that a second hue eventually becomes a verdict.
- Slightly less "stock iOS" look; the accent is a step deeper than system blue.
  That is the brand, on purpose, and it is the entire visible cost.

## How to reopen

If Apple's accessibility guidance or a future surface (watch, dark widgets on
tinted home screens) pushes a role below AA, re-run the measurements and move
that role to an adjacent step — the ramp has fourteen. (The one exception is the data ramp's deepest step, light 800 `#05172e`, which is the family's floor: it has no step below it, so re-spacing the ramp is the only route there.) A new hue, as opposed to a
new step, reopens ADR-0007's reasoning, not just this document.


---

## Amendment (2026-09-06, ADR-0034)

The ramp gained a fourth data band, so the table's data row is now
250/450/700/**800** light and 600/400/200/**100** dark, and the family itself
grew to fourteen steps with the new light 800 `#05172e`. The dark fourth step is
the family's existing 100 `#cde2fb` — no new dark value was invented. Validated
arithmetic is in ADR-0007's amendment; nothing about the brand/data separation
this record draws changes.
