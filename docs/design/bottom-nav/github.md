repo: semmes/DrinkTracker
branch: main

## Last sync
date: 2026-08-04T10:56:03Z

### Updated in this project
- Recreated every app screen as a clickable prototype (Tallyist iOS Prototype.dc.html)
- Design values lifted verbatim from GlassTokens, AppTheme, IntensityPalette, design-system.md
- New design work awaiting implementation (specs in design_handoff_tallyist_ui_updates/): enlarged month calendar, onboarding personality refresh + doctor-sharing row, calendar drag-to-prefill

## Screen map
| Screen | Repo files |
|---|---|
| Today | DrinkTracker/Features/Today/TodayView.swift, DesignSystem/CountStepper.swift, DesignSystem/GlassTokens.swift |
| Drink detail sheet | DrinkTracker/Features/DrinkDetail/DrinkDetailSheet.swift, DesignSystem/FlowLayout.swift |
| Calendar (month) | DrinkTracker/Features/Calendar/CalendarView.swift, IntensityCell.swift, RecentSummaryCard.swift, DesignSystem/IntensityPalette.swift |
| Day log sheet | DrinkTracker/Features/Calendar/DayLogSheet.swift |
| Year view | DrinkTracker/Features/Calendar/YearView.swift |
| Trends | DrinkTracker/Features/Trends/TrendsView.swift |
| History | DrinkTracker/Features/History/HistoryView.swift, DrinkRow.swift |
| Settings | DrinkTracker/Features/Settings/SettingsView.swift |
| Onboarding | DrinkTracker/Features/Onboarding/OnboardingFlow.swift, WelcomeView.swift, HealthContextView.swift, RegionView.swift |
| Domain values | DrinkTrackerCore/Sources/DrinkTrackerCore/DrinkType.swift, Region.swift, StandardDrink.swift, DayIntensity.swift |
