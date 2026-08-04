# Handoff: Tallyist UI updates — calendar enlargement, onboarding refresh, multi-day prefill

## Overview
This bundle documents the Tallyist (DrinkTracker) UI as recreated in an interactive HTML prototype, plus **three design changes to implement**:

1. **Larger, more tappable month calendar** (`CalendarView.swift`)
2. **Onboarding personality refresh** — new copy, animated tally hero, privacy badge, progress dots, doctor-sharing row (`Features/Onboarding/*.swift`)
3. **Calendar drag-to-prefill** — press-and-drag across days to mark a stretch as no-drink days (`CalendarView.swift` + day store)

Everything else in the prototype is a faithful reference of the shipping SwiftUI app and needs no code changes.

Source of truth for the app: `semmes/DrinkTracker` @ `main`. The prototype was built by reading that repo file-by-file; screen → source mapping is at the bottom.

## About the Design Files
The files here are **design references created in HTML** — a clickable prototype showing intended look and behavior, not production code. The task is to **implement the design changes in the existing SwiftUI codebase** (iOS 26, Liquid Glass, ComponentsKit), using its established tokens (`GlassTokens`, `IntensityPalette`, `AppTheme`) — not to ship any HTML.

## Fidelity
**High-fidelity.** Colors, spacing, radii, and type are lifted verbatim from the repo's design system (`docs/design-system.md`, `DesignSystem/*.swift`). Recreate pixel-perfectly with existing code patterns.

---

## Change 1: larger month calendar

Target file: `DrinkTracker/Features/Calendar/CalendarView.swift` (grid + weekday header only; `IntensityCell` already scales from `side`).

Current behavior: the grid sits inside the 20pt `screenMargin`, so cells are `(width − 40 − 6×6) / 7` ≈ 45pt on a 402pt device.

New behavior:
1. **Bleed the grid 10pt past the screen margin on each side** — effective horizontal inset becomes 10pt while every other element on the screen keeps the 20pt margin. In SwiftUI: `.padding(.horizontal, -10)` on the weekday header and the `LazyVGrid` (or give those two views their own 10pt margin instead of `screenMargin()`).
2. Cell spacing stays **6pt** → cell side becomes `(width − 20 − 36) / 7` ≈ **49.4pt** on a 402pt device (was ~45). Comfortably above the 44pt `GlassTokens.Layout.minimumTouchTarget`.
3. `IntensityCell` consequences (no code change; verify visually): corner radius `side * 0.28` ≈ 13.8pt; day-number font `side * 0.38` ≈ 18.8pt. The prototype uses radius 14 / font 19 — matching what the existing formulas produce at the new size.
4. `gridHeight` reserve in `CalendarView` uses a hardcoded `52` per row — bump to cover the new side (rows × ~50 + spacing) or compute from the actual side.
5. Nothing else changes: today ring (`side * 0.06` accent stroke), alcohol-free outline (`side * 0.04`, `Color.primary.opacity(0.35)`), future-day `0.3` opacity, legend, and `RecentSummaryCard` all stay as-is.
6. Year view (`MiniMonth`, 11pt cells) is untouched — a reading surface, deliberately not tappable.

Accessibility: cells keep their existing combined VoiceOver label (date + amount). Larger targets are pure win; no new traits needed.

## Change 2: onboarding personality refresh

Target: `Features/Onboarding/*.swift`. Same 3-step structure, bottom-pinned primary CTA; new copy, hero imagery, and motion. All copy below is final — use verbatim.

**Shared elements**
- **Progress dots** at the top of the content area, centered, 6pt gap: three 8pt circles; the active step is a 24×8pt capsule in accent; inactive dots `Color.secondary.opacity(~0.35)` (prototype: `rgba(60,60,67,0.22)`). Animate the width/color change (`.smooth`, 0.3s).
- **Step entrance**: content fades in and slides up ~16pt, 0.5s ease-out, on step change.
- Gate all decorative motion behind `accessibilityReduceMotion` (ADR-0006 spirit: functional, never celebratory).

**Step 1 — the tally hero**
- Hero glyph centered above the headline: a hand-drawn tally-mark "5" — four vertical strokes + one diagonal slash. Geometry (from a 112×118 canvas rendered ~148×132pt, whole glyph tilted −4°): verticals at even spacing, stroke width 11, round caps, accent `#256ABF`; the slash runs corner-to-corner in lighter tint `#7FA9DD`.
- Draw-on animation: strokes draw in sequence (SwiftUI `Shape.trim` + `.easeOut(0.35s)`), staggered ~0.17s apart; the slash lands last (~0.9s in, 0.4s duration).
- Caption fades in after the slash: **"(that's five)"** — footnote, tertiary label color.
- Headline (largeTitle bold): **"Your drinks, tallied"**
- Body (body, secondary): **"One tap per drink, like tick marks on a napkin, except this napkin does charts. No goals, no lectures, no judgement."**
- CTA: **"Start tallying"**

**Step 2 — privacy**
- Hero: 76pt glass circle (`glassSurface()`, standard control shadow) containing a 36pt accent lock (`lock.fill`). Pop-in: scale 0.4 → 1.08 → 1.0, 0.5s, slight delay.
- Headline: **"Your tab is nobody's business"**
- Body: **"Your log lives in your own iCloud and Apple Health. No account, no server, no ads. We couldn't peek even if we wanted to."**
- Feature rows (subheadline, secondary, 15pt symbols, 8pt gap):
  1. `lock` — **"Private by default"**
  2. `stethoscope` (or `person.badge.shield.checkmark` — pick the SF Symbol that reads "provider") — **"Share with a doctor if you choose. Your Apple Health data can give a provider the full picture of your drinking, daily to yearly"** (two-line row, top-aligned icon)
  3. `sun.max` — **"Change access anytime in Settings"**
- CTA: **"Sounds good"**

**Step 3 — region**
- Headline: **"How big is a drink, anyway?"**
- Body: **"A \"standard drink\" isn't standard everywhere. Pick your region so the math pours right. Not sure? Skip it, no quiz later."**
- Region radio rows unchanged (min 60pt glass rows, radius 14, accent `checkmark.circle.fill`).
- CTA: **"Finish up"**; skip button: **"I'll decide later"**

## Change 3: calendar drag-to-prefill (multi-day no-drink marking)

Purpose: someone who doesn't log daily can backfill a week or month of no-drink days in one gesture instead of tapping each day.

Target: `Features/Calendar/CalendarView.swift` + the store method behind "Record no alcohol" (same semantics as `markAF`).

**Gesture**
- Press a day cell and drag: selection is the contiguous day range between the anchor day and the day under the finger (min…max, same month). Implement with a `DragGesture` in the grid's coordinate space, mapping location → column/row → day index.
- A plain tap (no movement) keeps today's behavior: open the day-log sheet.
- Future days can't anchor or extend a selection; `sensoryFeedback(.selection)` as the range grows or shrinks.

**Selection visuals (live during drag)**
- Every selected cell gains an inset accent ring, 2.5pt (match today-ring weight `side * 0.06`).
- Unrecorded (blank) cells in the selection also get an accent fill at 15% opacity (`#256ABF` @ 0.15).
- Recorded cells (drinks or alcohol-free) keep their existing fill — ring only.

**Action bar** (appears once the drag moves; stays after release; live count during drag)
- Bottom-pinned glass bar: 16pt horizontal insets, radius 22, padding ~12–16pt, drop shadow (`0 8 24 @ 18%`), slides up 0.3s.
- Left column: **"N days selected"** (subheadline semibold) over **"Prefill as no-drink days · days with drinks are kept"** (caption, secondary).
- Right: accent filled button **"Mark no drinks"** (40pt tall, radius 14) + 32pt circular dismiss (`xmark`, `Color.primary.opacity(0.06)` fill).
- Apply: for each selected non-future day, mark alcohol-free **only if the day has no logged drinks** (existing `markAF` guard); days already alcohol-free stay so. Then clear the selection.
- Cancel, navigating away, or switching screens clears the selection.

**Discoverability**
- Caption line under the legend (caption2, tertiary): **"Tip: press and drag across days to mark a stretch of no-drink days"**

Accessibility: the drag gesture is an accelerator, not the only path — single-day marking via the day sheet remains. Expose an equivalent "Mark range…" action via the calendar's rotor/menu if VoiceOver testing shows the drag is unreachable.

---

## Screens / Views (reference — already shipping, no changes)
All measurements from `GlassTokens.swift` unless noted.

- **Today** — hero `CountStepper` (64pt glass circle buttons, 68pt semibold SF Rounded numeral, 24pt gap), caption "drinks today" (subheadline, secondary), "≈ N standard drinks" (footnote), disclosure "Log by type — size and strength" (footnote + rotating chevron), quick-add row (4 glass buttons, 88pt tall, radius 14, SF Symbol title2 in accent + caption label), repeat row ("Another beer · 12oz · 5%", glass, radius 14, min 44pt), "Logged today" list (plain style, tap to edit, swipe to remove).
- **Drink detail sheet** — native sheet, medium/large detents, radius 34, regular material. Title2 semibold header + 30pt glass close. Uppercase footnote-medium section labels (SIZE / STRENGTH / DRINK / WHEN). Size pills: min 44pt, radius 22, selected = accent capsule with white text; wrap via FlowLayout (8pt spacing). ABV: ComponentsKit slider, accent, step 0.5, range per type (beer 0–15, wine 0–20, spirit/other 0–60). Pinned footer outside the scroll: live "≈ N standard drinks" (title, semibold, rounded) + primary button.
- **Calendar (month)** — see changes 1 and 3 above. Header: month title (title2 semibold) between 44pt chevron buttons, next-month disabled at current month (0.3 opacity). Legend always present. `RecentSummaryCard`: glass card radius 26, padding 16, four figures (title rounded semibold + footnote label), hairline divider, unlogged-days note.
- **Year view** — 2-column grid of MiniMonths (11pt cells, 2pt gap, radius 3), compact legend, recorded-days summary sentence.
- **Trends** — segmented Week/Month (accent, full width), chart card (glass, radius 26): BarMark bars in accent gradient, radius 6, 200pt tall, dashed secondary RuleMark labeled "Your average" (caption2), leading axis. Stat cards: value (title rounded semibold) + noun (footnote secondary). No deltas, no progress bars.
- **History** — inset-grouped list, day sections with header (caption secondary: weekday date left, monospaced-digit total right). `DrinkRow`: type symbol in accent (28pt column), name (body), "time · oz · %ABV" (caption secondary), per-region value (callout medium monospaced-digit secondary). `+` toolbar adds a back-dated drink (sheet gains type picker + date control).
- **Settings** — sheet with sections (uppercase footnote-medium titles + caption footnotes): region radio rows (min 60pt, glass radius 14, `checkmark.circle.fill` accent when selected), iCloud + Health status rows (symbol + factual state), About copy.
- **Onboarding** — see change 2 above. Copy verbatim in the prototype.

## Interactions & Behavior
- Counter + logs a drink immediately (seeded from most-logged type at last-logged size/strength); − removes the most recent entry with a 10-second undo bar (glass, bottom inset, radius 14, 48pt).
- Value changes animate `.snappy` with `.numericText` content transitions; structure changes `.smooth(duration: 0.25)`; `sensoryFeedback(.selection)` on stepper taps. No celebratory motion (ADR-0006 applied to motion).
- Calendar: tap past/today cell → day-log sheet (prominent stepper, 0 = "Record no alcohol"); future cells inert at 0.3 opacity; drag → multi-day prefill (change 3).
- Region change re-expresses every displayed total instantly (display lens, ADR-0002).

## Design Tokens (from the repo — use the existing constants, don't redeclare)
- Accent: `#256ABF` (light / fills both modes), `#3987E5` (dark text/glyphs). Icon field `#104281`. Onboarding tally slash tint `#7FA9DD` (light-mode value; derive dark from accent ramp).
- Intensity ramp (light): 1–2 `#86B6EF`, 3–5 `#2A78D6`, 6+ `#0D366B`; dark: `#184F95` / `#3987E5` / `#9EC5F4`. Alcohol-free: `Color.primary` at 10% (16% dark) + 0.35-opacity outline. Changes must be re-validated, never eyeballed.
- Selection tint (change 3): accent @ 15%.
- Spacing: 8 / 12 / 24 / 32; screen margin 20; card padding 16.
- Radii: control 14, pill 22, card 26, sheet 34 (continuous).
- Type: SF; user-made numerals in SF Rounded (hero 76/68 semibold, card values title semibold rounded); everything else default SF with Dynamic Type styles.
- Surfaces: system Liquid Glass (`glassSurface()`), system semantic colors only.

## Assets
None bundled. All icons are SF Symbols already used by the app: `mug.fill`, `wineglass.fill`, `flask.fill`, `cup.and.saucer.fill`, `list.bullet`, `calendar`, `chart.bar.xaxis`, `gearshape`, `square.grid.3x3`, `plus`, `minus`, `checkmark.circle`, `arrow.trianglehead.clockwise`, `checkmark.icloud`, plus `lock.fill` and a provider symbol (`stethoscope` or similar) for onboarding. The prototype's inline SVGs are stand-ins — always use the real SF Symbols. The tally hero is the one custom drawing (simple `Shape` paths, geometry above).

## Files
- `Tallyist iOS Prototype.dc.html` — the interactive prototype (open in a browser; chips above the frame jump between screens; Onboarding, the enlarged month grid, and drag-to-prefill are all live — drag across calendar days to see the selection bar).
- `ios-frame.jsx`, `support.js` — prototype scaffolding (not part of the design).

## Screen → source map
| Screen | Repo files |
|---|---|
| Today | `Features/Today/TodayView.swift`, `DesignSystem/CountStepper.swift` |
| Drink sheet | `Features/DrinkDetail/DrinkDetailSheet.swift`, `DesignSystem/FlowLayout.swift` |
| Calendar | `Features/Calendar/CalendarView.swift`, `IntensityCell.swift`, `RecentSummaryCard.swift`, `DesignSystem/IntensityPalette.swift` |
| Day sheet | `Features/Calendar/DayLogSheet.swift` |
| Year | `Features/Calendar/YearView.swift` |
| Trends | `Features/Trends/TrendsView.swift` |
| History | `Features/History/HistoryView.swift`, `DrinkRow.swift` |
| Settings | `Features/Settings/SettingsView.swift` |
| Onboarding | `Features/Onboarding/*.swift` |
