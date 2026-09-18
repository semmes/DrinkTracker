# Handoff Spec: Circular complication, rounded tile

Status: design ready for build. Scope is the `accessoryCircular` watch complication only. The rectangular complication does not change.

Source of values: pixel measurements of four 46 mm screenshots (416 × 496 px, 2x) plus the Tallyist Design System token sheet. I could not read the repo for this pass, so every number marked "measured" should be replaced by the constant already used in the rectangular complication wherever one exists. The repo wins.

## Overview

Today the circular complication fills the whole circle with the state color and sets the count at about 34 pt. The rectangular complication shows the same count inside a 44 pt rounded tile at 23 pt, which reads smaller and cleaner, and the tile shape matches the calendar marks.

The change: inside the circular slot, draw the same rounded tile instead of a full-circle fill. The slot itself stays clear, so on the face the complication reads as a rounded tile, not a disc. Numeral and symbol sizes come straight from the rectangular tile.

## Layout

| Item | Value | Notes |
|---|---|---|
| Slot | 51 pt diameter (measured, 46 mm, this face) | The system masks the widget to this circle |
| Slot background | Clear | Nothing drawn outside the tile. No `AccessoryWidgetBackground`, no full-circle fill |
| Tile side | `floor(slotDiameter × 0.83 × 2) / 2` | 42 pt in a 51 pt slot |
| Tile corner radius | `side × 13 / 44`, `.continuous` | 12.4 pt at 42 pt. Same proportion as the rectangular tile (13 pt on 44 pt, measured) |
| Tile position | Centered in the slot, both axes | |
| Content position | Centered in the tile, both axes | |
| Corner clearance | 0.9 pt between tile corner and slot mask at 51 pt | Never below 0.65 pt at any slot size (table below) |

Why 0.83: a 44 pt tile with 13 pt continuous corners reaches 25.75 pt from center on the diagonal. The slot radius is 25.5 pt, so an exact-size copy of the rectangular tile would have its four corners shaved by the mask. At 0.83 the corners keep at least 0.65 pt of clearance at every slot size checked, enough that antialiasing never touches the mask.

### Slot sizes

The slot diameter changes with watch size and face. Read it from the view's geometry, do not hardcode 51.

| Slot diameter | Tile side | Radius | Clearance to mask |
|---|---|---|---|
| 51 pt | 42 pt | 12.4 pt | 0.92 pt |
| 50 pt | 41.5 pt | 12.3 pt | 0.71 pt |
| 47 pt | 39 pt | 11.5 pt | 0.67 pt |
| 44.5 pt | 36.5 pt | 10.8 pt | 0.89 pt |
| 42 pt | 34.5 pt | 10.2 pt | 0.81 pt |
| 40 pt | 33 pt | 9.8 pt | 0.68 pt |

## Design tokens used

| Token | Value | Usage |
|---|---|---|
| Tallyist 600 (`--t600`, `data-low` in dark) | `#184F95` | Tile fill at 1 drink (measured match) |
| Tallyist 100 (`--t100`) | `#CDE2FB` | Tile fill at 16 drinks (measured match). Note: the design system's dark ramp lists 600 / 400 / 200, so this step is outside the documented ramp. Keep whatever the shipping ramp function returns |
| Rectangular tile neutral | `#252526` (measured) | Tile fill at 0 drinks and on an alcohol-free day. Today the circle uses a darker `#191919`. Use the rectangular tile's value so the two match |
| Numeral rule | SF Rounded, user-made numerals only | Count numeral |
| Numeral size | 23 pt, Bold (measured) | Same font as the rectangular tile. Was about 34 pt in the circle |
| Symbol | `checkmark.circle`, 12.5 pt across, about 1.5 pt stroke (measured) | Alcohol-free state. Was 18 pt in the circle |
| On-fill colors | White on `#252526` and `#184F95`, black on `#CDE2FB` | Unchanged from the rectangular tile |

Contrast, recomputed: white on `#252526` 15.3:1, white on `#184F95` 8.1:1, black on `#CDE2FB` 15.9:1.

## Components

| Component | Variant | Props | Notes |
|---|---|---|---|
| Count tile (shared) | zero, alcoholFree, count | `state`, `side` | Extract the tile that the rectangular complication already draws into one view. Radius derives from `side`. Both families render this view, so they cannot drift apart again |
| Circular complication | `accessoryCircular` | reads slot size | Clear container, one count tile at `0.83 × diameter` |
| Rectangular complication | `accessoryRectangular` | none new | Passes its existing 44 pt side. No visual change |

## States

| State | Tile fill | Content | Notes |
|---|---|---|---|
| 0 drinks | `#252526` | "0", white | |
| Alcohol-free | `#252526` | `checkmark.circle`, white | Shape and words carry the status, color does not |
| 1 drink | `#184F95` | "1", white | |
| 16 drinks | `#CDE2FB` | "16", black | Two digits fit with the 23 pt numeral: about 23.5 pt wide in a 42 pt tile |
| Counts between | Shipping ramp | Shipping on-fill color | No change to ramp logic or thresholds |

Tap behavior, Double Tap and deep link are unchanged.

## Rendering modes

The circular complication should inherit whatever the rectangular tile does today, since it is now the same view.

| Mode | Expectation |
|---|---|
| Full color | As drawn on the canvas |
| Accented (tinted faces) | The tile must still read as a tile. If the rectangular tile marks its fill `widgetAccentable()`, the circular one gets that for free. Check one tinted face before merging |
| Vibrant / Always On (`isLuminanceReduced`) | Same treatment as the rectangular tile. No separate rule for the circle |

## Edge cases

- Three digits ("100"): keep the rectangular tile's behavior. If it has none, add `minimumScaleFactor(0.6)` and `lineLimit(1)` to the numeral in the shared tile.
- Smaller slots: tile side and radius scale from the slot. The numeral uses the rectangular tile's font on that device and is not scaled separately. At a 40 pt slot the tile is 33 pt, and "16" at 23 pt leaves about 4.75 pt each side.
- Placeholder / redacted: the tile shape stays, the numeral redacts. No full-circle fallback.
- No data yet: same as 0 drinks.
- Faces that draw their own ring or bezel around circular slots: the clear background lets the face show through around the tile. That is intended.

## Animation / motion

None added. Timeline reloads swap the state with the system default transition, as today.

## Accessibility

- `accessibilityLabel` is unchanged: "N drinks today", "1 drink today", "Recorded as no alcohol today".
- The 23 pt numeral is the size already shipping in the rectangular complication, so legibility on the wrist is known.
- Status never depends on color alone: count is a numeral, alcohol-free is a symbol.

## Implementation sketch

Names are placeholders. Match the existing views in the watch widget target.

```swift
struct CountTile: View {
    let state: ComplicationState   // existing model
    let side: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: side * 13 / 44, style: .continuous)
            .fill(state.tileFill)              // existing ramp / neutral
            .frame(width: side, height: side)
            .overlay { TileContent(state: state) }   // existing 23 pt numeral or checkmark.circle
    }
}

struct CircularComplicationView: View {
    let state: ComplicationState

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height)
            let side = (diameter * 0.83 * 2).rounded(.down) / 2
            CountTile(state: state, side: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(.clear, for: .widget)
    }
}
```

## Acceptance checks

1. On the 46 mm face from the screenshots, the circular tile measures 42 pt with no clipped corners at 2x zoom.
2. Numeral and symbol in the circular tile are pixel-identical in size to the rectangular tile on the same face.
3. 0 drinks and alcohol-free tiles are the same grey in both complications.
4. All four states checked on 46 mm and on the smallest supported watch.
5. One tinted face and Always On checked.
6. If `docs/design-system.md` documents complications, add the 0.83 and 13/44 rules there first, then re-sync the design system cards.

## Measurement notes

- Screenshots are 416 × 496 px at 2x, so 1 pt = 2 px.
- Circle today: 102 px = 51 pt. Rectangular tile: 88 px = 44 pt.
- Tile corner: fitted against Apple's continuous-corner curve, best fit 13.0 pt.
- Numeral heights: 47 px in the circle (about 34 pt font), 32 to 33 px in the tile (23 pt font).
- Fills sampled directly: `#191919` circle neutral, `#252526` tile neutral, `#184F95`, `#CDE2FB`.
