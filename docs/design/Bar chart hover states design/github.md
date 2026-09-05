repo: semmes/DrinkTracker
branch: main
path: DrinkTracker/Features/Trends

## Last sync

date: 2026-09-05T19:00:42Z

### Updated in this project

- Read TrendsView, PeriodDetailView, GlassTokens and ADR-0028 to ground the bar-selection redesign.
- Built three tap/scrub readout treatments that move the selected-bar facts above the plot.
- Kept ADR-0028's rule: no delta against the "Your average" line — the line's value shows as an independent fact.

## Screen map

| Project screen | Repo files |
| --- | --- |
| Trends Bar Interaction.dc.html — 1a, 1b, 1c | DrinkTracker/Features/Trends/TrendsView.swift, DrinkTracker/Features/Trends/PeriodDetailView.swift, DrinkTracker/DesignSystem/GlassTokens.swift, docs/decisions/0028-a-trends-bar-reports-its-own-facts.md |
