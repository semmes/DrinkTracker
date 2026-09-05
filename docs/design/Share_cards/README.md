# Handoff: Tallyist calendar share cards

## Overview
Three shareable image cards for Tallyist (repo `semmes/DrinkTracker`): a **month card**, a **year card**, and a new **year-in-review card**. Each is a one-way PNG the user shares from the calendar surfaces (e.g. into Messages). The month and year cards follow the shipped spec (ADR-0027, `ShareCardParts.swift`); the year-in-review card is a NEW design extending that system — one complete past year at a time, with the four figures plus a monthly bar chart. Past years remain available as history (a picker chooses which year to render).

## About the Design Files
The files in this bundle are **design references created in HTML** — prototypes showing intended look and behavior, not production code. Recreate them in the target codebase's existing environment: **SwiftUI, alongside the existing `ShareCardParts.swift` / `MonthShareCard.swift` / `YearShareCard.swift`**, reusing `ShareCardInk`, `ShareCardLayout`, `ShareCardFrame`, `ShareCardHeader`, `ShareCardFigures`, `ShareCardLegend`, `ShareCardRenderer`, `RecentSummaryCaptions`, and `IntensityPalette`. Only the year-in-review card requires new code.

## Fidelity
**High-fidelity.** Colors, type roles, spacing, and copy are exact and grounded in the repo + Tallyist design system. Recreate pixel-perfectly with the codebase's existing tokens (`GlassTokens`, `IntensityPalette`, `ShareCardInk`) — never restate literals where a token exists.

## Shared card anatomy (all three cards)
- Fixed 360pt-wide document, 24pt padding (`GlassTokens.Spacing.section`), content width 312pt, rendered to PNG at 3x, type pinned to .large (`ShareCardRenderer`).
- Ground/ink (`ShareCardInk`): light — ground #FFFFFF, primary #000000, secondary black 55%; dark — ground #1C1C1E (0.11/0.11/0.12), primary #FFFFFF, secondary white 55%. Hairlines = secondary at 30%.
- Vertical stack, 12pt gaps (`GlassTokens.Spacing.regular`).
- Header: period name, title2 semibold, primary ink. Under it, caption secondary: "Through <Month Day> · " (only while the period is in progress) + day count ("31 days").
- Four figures, 2×2 grid, 12pt gaps, 0.5pt hairline between rows:
  1. days with drinks — caption "day(s) with drinks"
  2. days with none — caption "day(s) with none"
  3. total — caption "standard drink(s) total" (region-aware via `RecentSummaryCaptions.total`)
  4. average — caption "on days with drinks" (share-card-specific key); value "—" when no days with drinks
  Values: `GlassTokens.Typography.cardValue` (title semibold **rounded** — user-made numerals are rounded, everything else default SF). Captions: caption size, secondary ink.
- Unlogged sentence when non-zero, caption secondary: "N day(s) have nothing logged either way."
- Wordmark "Tallyist", caption semibold, secondary ink, trailing-aligned, last element. Text only — never the tally mark.
- Figures from `TrendSummary` summaries only; `today` read once and shared by the summary, the "Through" line, and the future-day fade.

## Screens / Views

### 1. Month card (shipped — reference only)
Weekday header (very-short symbols, caption2 secondary, rotated to firstWeekday) over the month grid: 7 columns of 41pt cells, 4pt gaps, radius 8 continuous. Cell fills from `IntensityPalette`: low #86B6EF / medium #2A78D6 / high #0D366B (light); #184F95 / #3987E5 / #9EC5F4 (dark). Alcohol-free: af-fill (black 10% light / white 16% dark) + 1.5pt secondary outline. Unlogged: no fill, no outline, number in secondary. Day numbers 12pt medium rounded; ink per `ShareCardInk.cellInk` (low: black light / white dark; medium+high: white light / black dark). Future days at 30% opacity. Then the five-entry legend (`legendOrder`: No alcohol, 1–2, 3–5, 6+, Not logged; 12pt swatches radius 3; unlogged swatch gets a hairline so something sits beside its label).

### 2. Year card (shipped — reference only)
Twelve mini months, 3 columns × 4 rows always drawn; column width 96pt, gutter 12pt, row gap 16pt. Each mini: abbreviated month name (caption2 semibold secondary) over a 12pt-cell grid, 2pt gaps, radius 3, six rows reserved (82pt) so rows align. No day numbers. Future days blank. Same figures, legend, wordmark.

### 3. Year-in-review card (NEW — implement this)
Shown once a first full calendar year is on record; **one year at a time**, each past complete year selectable from history (never the year in progress).
- Header: the year as text ("2025"), sub "365 days" (no "Through" line — the year is whole).
- The four figures + unlogged sentence, identical components to the other cards.
- **Chart — "Standard drinks by month"**:
  - Caption above (caption size, secondary): "Standard drinks by month · the dashed line is your average, <value>" where <value> = total ÷ 12, formatted like all drink figures (1 decimal, trailing .0 dropped).
  - Plot: 88pt tall, full content width minus a 20pt y-axis label column (6pt gap).
  - Y axis: ticks 0 / max÷2 / max at bottoms 0 / 38 / 80pt, 9pt medium rounded, secondary, right-aligned. Max = monthly max rounded up to a whole number; bars scale against it.
  - Gridline: one hairline at mid (44pt). Baseline: 1pt line in secondary at bottom. (No top gridline — deliberately removed.)
  - Bars: 12, equal flex width, 4pt gaps, radius 3pt top corners only, fill **#256ABF (accent-fill t500) in both modes** (R2: fills stay 500).
  - Average line: 1pt dashed, secondary ink, at (average ÷ max) × 88pt from baseline. No label on the line — the caption carries it. Never called a target.
  - X axis: month initials J F M A M J J A S O N D, 9pt secondary, centered under each bar, offset past the y-axis column.
- Voice guardrails (ADR-0006/0027): counts and totals only; no deltas between years, no ranking, no grade, no trend arrow, no per-week rate. "Your average" is the Trends chart's own possessive-factual register.

## Interactions & Behavior
- Cards are static images; all interaction is at share time (system share sheet), user-initiated, nothing persisted or logged about sharing.
- Year-in-review entry point: suggested from the year view once ≥1 complete year exists; a year picker (chronological) selects which past year — every past year stays available.
- Suggested filename pattern: `tallyist-<year>-review.png` (month: `tallyist-YYYY-MM.png`, year: `tallyist-YYYY.png`).
- Prototype tweaks (design-review only, not product): light/dark scheme, complete vs in-progress month, review year, data seed.

## State Management
None beyond existing app state. Figures must come from the same folds as the on-screen calendar summary (`TrendSummary.monthSummary` / `yearSummary`; a year-in-review uses the same yearly fold over a past year). Monthly totals for the chart: sum of standard drinks per calendar month from the log.

## Design Tokens
- Blue ramp jobs: accent-fill #256ABF (t500, both modes); data ramp light 250/450/700 (#86B6EF/#2A78D6/#0D366B), dark 600/400/200 (#184F95/#3987E5/#9EC5F4); icon field t650.
- Share ink: see anatomy above (the one literal-colour site beside IntensityPalette).
- Spacing: tight 8 / regular 12 / card 16 / screen 20 / section 24 / block 32.
- Radius: control 14 / pill 22 / card 26 / sheet 34; share-card cells 8 (month), 3 (mini/swatch/bars), continuous corners.
- Type: SF (text) + SF Rounded for user-made numerals; title2 semibold headers; cardValue (title semibold rounded) figures; caption/caption2 secondary for everything supporting.

## Assets
None. Wordmark is set as text; no images or icons. The tally mark is deliberately absent from share cards.

## Files
- `Share Card.dc.html` — the interactive design reference (all three cards, light/dark, sample data generator).
- `styles.css` — the Tallyist design-system token sheet the reference loads.
- Repo ground truth: `DrinkTracker/Features/Calendar/ShareCardParts.swift`, `MonthShareCard.swift`, `YearShareCard.swift`, `RecentSummaryCaptions.swift`, `IntensityCell.swift`, `docs/decisions/0027-*.md`.
