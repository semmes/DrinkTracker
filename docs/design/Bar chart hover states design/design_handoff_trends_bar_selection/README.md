# Handoff: Trends bar selection — scrub readout in the card header

## Overview

`TrendsView` already lets the user tap or drag across the bars to select one (ADR-0028), and reports that bar's own facts in a block **under** the chart. In use, that placement fails the gesture it belongs to: the reading hand covers the block, and the card grows when a bar is selected — so the figures the user is reaching for move down toward the hand as they appear.

This change **moves the selected-bar readout into the chart card's own header row, above the plot**, and gives it a fixed height so a selection never reflows the card. Selection becomes a live scrub that reverts on release. Nothing about the data, the average line, or ADR-0028's refusal to phrase a bar against that line changes.

## About the design files

The files in this bundle are **design references created in HTML** — prototypes of the intended look and behaviour, not production code to copy. The target codebase is **SwiftUI + Swift Charts** (`semmes/DrinkTracker`), and the work is to express these designs there using the app's existing patterns: `SUCard(model: .glass)`, `GlassTokens`, `chartXSelection`, `TrendSummary`/`PeriodDetail`. Do not port CSS. The HTML's hex values and pixel numbers are documentation of intent — where a token already exists in `GlassTokens` or the system semantic colours, **use the token**.

## Fidelity

**High-fidelity.** Final layout, type roles, spacing, colours, transitions and copy. Recreate faithfully, in the app's own components.

## Screens / Views

### Trends — Quarter (13 weekly bars)

**Purpose.** The user scans a quarter for spikes and dips, then drags across the bars to read what any one week holds, without lifting their hand or losing their place.

**Layout.** Unchanged from today: `ScrollView` → `VStack(spacing: .section)` of range picker, chart card, summary cards, `PopulationReferenceCard`, inside `.screenMargin()` (20pt). The change is entirely inside the chart card.

**Chart card** — `SUCard(model: .glass)`, `GlassTokens.Radius.card` (26), `GlassTokens.Spacing.cardPadding` (16):

1. **Readout block — fixed height, 76pt.** Two states occupying the same box, cross-faded. This is the whole change: the block that is under the chart today lives here instead. The height is fixed so the card's total height is identical selected or not.

   *Idle state:*
   - Row 1, `HStack` with `Spacer()` between:
     - `Text("Last 13 weeks")` — `.cardLabel` (footnote regular), `.secondary`
     - the average-line legend, trailing: a 14×1pt dashed rule in `Color.accentColor`, then `Text("Your weekly average · ")` at caption2 `.secondary` with the value **3.5** in rounded semibold tabular at 11pt, `.label` at 62% opacity. This legend moved out of the plot (it was a `RuleMark.annotation`) — inside the plot it collided with the bars; on the header row it reads at a glance.
   - Row 2, `.top` 5pt: the range total, `GlassTokens.Typography.cardValue` (title, rounded, semibold) at 28pt, tabular; then `Text("standard drinks · 30 days with drinks")` at `.cardLabel` `.secondary`.
   - Row 3, `.top` 6pt: `Text("Tip: drag across the bars to read one week")` — caption2, `.tertiary`. ADR-0028's discoverability line, reworded for the scrub and moved up here with the rest.

   *Scrubbing state:*
   - Row 1, `HStack` + `Spacer()`: the period title (`PeriodDetailView.titleString`) at subheadline **semibold**, `.primary`; trailing, the day-count note at caption2 `.secondary` — `"7 days"`, or `"7 days, through today"` for the trailing bucket. **Keep this note**: it is the ADR-motivated disclosure that a short trailing bar is a short week, not a fall.
   - Row 2, `.top` 4pt: the bar's total, `.cardValue` 28pt rounded semibold tabular, tinted **`var(--data-high)` — `#0d366b` light, `#9ec5f4` dark** (the intensity ramp's top step, an already-named job for the hue; 11:1 on white, with a correct dark step) so the live figure is distinguishable from the idle one without a second colour; then `Text("standard drinks")` at `.cardLabel` `.secondary`.
   - Row 3, `.top` 6pt, `HStack(spacing: 14)`: three caption2 facts, each a rounded-semibold numeral in `.label` 78% followed by a `.secondary` noun —
     `5 with drinks` · `2.1 on those days` · `0 none in a row`.
     Day counts are plain integers, never suffixed (`0`, not `0d`) — factual and countable at zero.
   - `contentTransition(.opacity)` on each figure, per ADR-0026: a crossfade, never a roll.

   **Dropped from the scrub deliberately:** the drink-type share rows (`DrinkShare`). Four figures read at a glance; four figures plus a type list does not, and the list is what forced the block to grow. Keep `PeriodDetailView`'s share rows for a *persistent* selection (see State) — they are not lost, only off the scrub.

2. **Divider** — `Divider().opacity(0.5)`; 12pt above, 14pt below.

3. **Chart** — `GlassTokens.Layout.chartHeight` (200), leading y-axis gutter ~22–24pt. All marks unchanged from today:
   - `BarMark` per `PeriodTotal`, `cornerRadius(6)`, bar width ~12pt, `Color.accentColor.gradient` (design reference: `#3987e5` → `#1c5cab`, i.e. `--t400` → `--t550`, light top to dark bottom).
   - **Zero weeks keep their outline** rather than a fill: a ~3pt stub, no gradient, `inset 0 0 0 1.5px` in `.secondary`. Alcohol-free is the absence of the measured quantity, not the bottom of the ramp (ADR-0007) — so it must not read as a very small amount.
   - Unselected bars → `opacity(0.35)`. Selected keeps the ramp. No colour change, no annotation, no second rule (PRD invariant 10).
   - `RuleMark` for `bucketAverage`, `StrokeStyle(lineWidth: 1, dash: [4,4])`, `.secondary` — **keep the line, drop its `.annotation`** (the label is now the header legend).
   - **No grid.** The horizontal `AxisGridLine`s and the dashed month verticals are removed: `AxisMarks(position: .leading)` keeps the 0/5/10/15 **labels** with `AxisValueLabel()` only, and the x-axis month stride keeps its labels with `AxisGridLine()` dropped. The only rules behind the bars are the zero baseline and the dashed average — so the average line reads as the single reference on the chart instead of one line among seven.

4. **Selection indicators in the plot** — two subtle, non-occluding marks that replace nothing:
   - a **rail**: a 26pt-wide column behind the selected bar, full plot height, top-radius 9, `linear-gradient(180deg, accent@14%, accent@3%)` (dark: 22% → 4%). Behind the bars, so it never covers data.
   - a **hairline**: 1pt from the plot's top edge down to the selected bar's top, `linear-gradient` from transparent to accent@50%. It ties the header readout to the bar the finger is on.
   - Both animate `left` over **160ms `cubic-bezier(.32,.72,0,1)`** as the scrub crosses bars.

5. **X-axis label row** — 7pt below the plot; `Jun / Jul / Aug / Sep` at caption `.secondary`.

**Summary cards below** — unchanged in structure; the two shown in the prototype are `longest run with none` (9) and `on days you drank` (2.1), `.cardValue` 26pt rounded semibold over `.cardLabel` `.secondary`. Wire these to the range figures the screen already computes; they are the permanent home of the two figures the scrub row abbreviates.

## Interactions & behaviour

- **Gesture:** `chartXSelection` as today. Tap selects; drag scrubs continuously, snapping to the bar whose x-band is under the finger. On macOS/Catalyst or with a pointer, hover previews the same selection.
- **Release clears.** The selection reverts to the idle readout the moment the finger lifts (`onEnded` → `selectedDate = nil`). This is a change from today's sticky selection, and it is what makes the fixed-height header safe: the user never has to reach *down* to dismiss anything. Confirmed as the intended behaviour by the design owner.
- **The ✕ is retained, for the VoiceOver-stepped selection.** Decided. With release-to-clear the ✕ has no job on the touch path, but the adjustable-action path *does* hold a selection between steps, and ADR-0028 makes the ✕ the contract. So: render the 44pt ✕ in the readout's trailing position **only while a selection is being held** — i.e. when it arrived via `accessibilityAdjustableAction`, not while a finger is down. It stays a real `Button` (an `onTapGesture` on an `SUCard` never fires — `PopulationReferenceCard`'s precedent), keeps `accessibilityLabel("Clear selection")`, and sits on the title's first text baseline so it holds position when the title wraps at AX sizes. `.accessibilityAction(.escape)` and the named "Clear selection" action both remain.
  - Layout note: in the held state the trailing day-count note yields to the ✕ — put the note under the title (`VStack`, 2pt) as `PeriodDetailView` does today, rather than competing for the trailing slot. The scrub state is unaffected and keeps the note trailing.
- **Range picker** still clears the selection in the same update it changes the range.
- **Haptics:** keep `.sensoryFeedback(.selection, trigger: selectedStart)` — one tick per bar crossed.
- **Animation:**
  - header crossfade — opacity **200ms ease**, plus a 6pt vertical offset over **220ms `cubic-bezier(.32,.72,0,1)`** (idle exits up, live enters from below). SwiftUI: `.smooth(duration: 0.22)`.
  - bar dimming — opacity **200ms `cubic-bezier(.4,0,.2,1)`**.
  - rail/hairline `left` — **160ms `cubic-bezier(.32,.72,0,1)`**.
  - **Reduce Motion:** drop the vertical offsets, keep the opacity crossfade. The prototype's `reduceMotion` tweak shows this state.
- **Thumb placement (the reason for the change):** on a 393×852pt screen the readout occupies roughly y 240–363, and comfortable thumb reach for either hand starts around y 520. Every figure sits ~160pt above the highest point the reading hand covers, and because the block's height is fixed, nothing moves into that zone when a selection appears. Mirrored — the layout has no handedness.

## State management

- `@State private var selectedDate: Date?` — unchanged. Still the raw x `Date`, never an index or a snapshot; still view state only, never persisted, synced or logged.
- `Snapshot.selection: PeriodDetail?` — unchanged, derived once per render.
- New: nothing. The design adds no state. `selectedDate == nil` drives the idle readout; non-nil drives the live one.
- The prototype's `sel = {i, cx, w}` is only bookkeeping for the HTML's hand-rolled hit-testing; in SwiftUI, `chartXSelection` plus `chartXScale` positioning supplies the equivalent.

## Design tokens

Everything below already exists in `GlassTokens` / `styles.css` — no new tokens.

| Role | Value | Token |
| --- | --- | --- |
| Interactive fill (picker) | `#256abf` | `--t500` / `--accent-fill` |
| Bar gradient, light | `#3987e5` → `#1c5cab` | `--t400` → `--t550` |
| Bar gradient, dark | `--data-high` → `--data-medium` | `#9ec5f4` → `#3987e5` |
| Live figure tint | `#0d366b` light · `#9ec5f4` dark | `--data-high` (ramp top step) |
| Average rule + legend swatch | accent @75% dashed `[4,4]` 1pt | `--accent` |
| Rail | accent @14% → @3% | `--accent` |
| Zero-bar outline | `.secondary` @55%, 1.5pt inset | `--label-secondary` |
| Zero baseline | `rgba(60,60,67,.3)` | `--label-tertiary` |
| Card surface | `#ffffff` | `--surface-card` (use `.glassSurface()`) |
| Dim (unselected bars) | `0.35` | ADR-0028 |
| Spacing | 8 / 12 / 24 / 32; screen 20; card 16 | `GlassTokens.Spacing` |
| Radius | control 14 · pill 22 · card 26 · sheet 34 | `GlassTokens.Radius` |
| Readout block height | 76pt fixed | — new constant |
| Chart height | 200pt | `GlassTokens.Layout.chartHeight` |
| Bar width / radius | 12pt / 6pt | — |
| Type — range + bar total | title, rounded, semibold, tabular (28pt) | `Typography.cardValue` |
| Type — period title | subheadline semibold | — |
| Type — labels/nouns | footnote regular, secondary | `Typography.cardLabel` |
| Type — facts row, legend, tip | caption2 | — |

**Numeral rule:** every figure the user's own logging produced is rounded + tabular (`--font-rounded`); axis labels, month labels and all prose stay default SF.

**One hue, one job.** Every blue used here already has a named role in ADR-0010 — accent/fill `--t500` (`#256abf`), bar ramp `--t400`→`--t550`, live figure `--data-high`. No new colour role is introduced; if a value below is not in the table, it is a bug, not a choice.

## Voice

All copy is factual and countable, describes the system not the person, and carries no exclamation marks. Exact strings used:

- `Last 13 weeks` · `Your weekly average · 3.5` · `47.2 standard drinks · 30 days with drinks`
- `Tip: drag across the bars to read one week`
- `Jul 5–11, 2026` · `7 days` · `7 days, through today`
- `10.6` + `standard drinks` · `5 with drinks` · `2.1 on those days` · `0 none in a row`
- `longest run with none` · `on days you drank`

**The one thing to preserve above all:** nothing here is phrased against the average line. The line's value appears as its **own** independent fact in the legend, beside the range's own — never as a delta, never signed, never with a direction word. ADR-0028 rules that out by name, and the design owner asked for "bar vs. the average line"; this legend is the compliant answer. If a delta is ever genuinely wanted, that is a decision to reopen upstream in the ADR, not a layout change.

## ADR impact

ADR-0028 stands, with two of its stated consequences superseded:

- *"The chart card grows when a bar is selected and the summary cards move down"* — no longer true; the readout is a fixed-height header and the card's height is constant.
- *"the hint line … is one more sentence on the screen"* — the hint moved into the readout block, so it costs no extra height.
- The selection lifetime changes from sticky-until-dismissed to live-while-touched. Worth a short amendment. The ✕ survives the change but narrows to the held/VoiceOver selection — record that scope explicitly, since the ADR currently names the ✕ as the contract for all paths.
- The chart drops its `AxisGridLine`s in both axes; the average `RuleMark` and the zero baseline are the only rules left behind the bars.

## Screenshots

| File | State |
| --- | --- |
| `screenshots/01-final-resting.png` | Final design, nothing selected — range figures + average legend + tip line |
| `screenshots/02-final-scrubbing.png` | Final design, finger on the Jul 5–11 spike — readout swapped, other bars at 35%, rail + hairline |
| `screenshots/03-ds-card.png` | The design-system card: light resting / dark scrubbing |
| `screenshots/04-options-explored.png` | All three explored options with the rationale column |

## Assets

None. No images, no new SF Symbols. The status bar, back chevron and dynamic island in the prototypes are drawn only so the mock reads as a phone — the app uses the real system chrome.

## Files

| File | What it is |
| --- | --- |
| `Trends Bar Selection.dc.html` | **The final design.** Live prototype — drag or hover across the bars. Has tweaks for dim amount, Reduce Motion and the tip line. |
| `Trends Bar Interaction.dc.html` | The three explored options (`1a` floating callout, `1b` **chosen**, `1c` reserved grid + neighbour lens), with the design rationale in the left-hand column. Useful for the "why not that instead" question. |
| `ds/components/trends-bar-selection.card.html` | Design-system card for the Tallyist system — light/dark, resting/scrubbing. Drop into `components/` in the design-system project (its `../styles.css` link resolves there as-is), and mirror it into `docs/design-system.md` per the sync contract. |
| `ds/styles.css` | The Tallyist token sheet the prototypes and card are built on. Reference only — the app's source of truth is `GlassTokens.swift` + the system semantic colours. |

## Repo files to change

| File | Change |
| --- | --- |
| `DrinkTracker/Features/Trends/TrendsView.swift` | Move the detail block into the card header as a fixed-height two-state readout; drop the `RuleMark.annotation` in favour of the header legend; add the rail + hairline; clear the selection on gesture end. |
| `DrinkTracker/Features/Trends/PeriodDetailView.swift` | Split: a compact header variant (title + note + total + three facts) for the scrub; keep the full version, share rows included, for the persistent/VoiceOver selection. |
| `docs/design-system.md` | Add the "Trends bar selection" component card. |
| `docs/decisions/0028-a-trends-bar-reports-its-own-facts.md` | Amend the consequences listed under **ADR impact**. |
