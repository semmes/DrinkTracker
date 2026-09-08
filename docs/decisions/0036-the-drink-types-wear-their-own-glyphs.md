# 0036 — The drink types wear their own glyphs, and the sheet's type control shows glyph and name

**Status:** accepted · **Date:** 2026-09-07 · **Relates to:** ADR-0007 (the
outline as the off-ramp signal, inherited by the alcohol-free glyph),
ADR-0026 (why a native segmented control was right there and a ComponentsKit
one was not), ADR-0034 (the persistent chooser this control replaces; the
previous bundle's "all icons are SF Symbols" note is superseded on this point),
ADR-0035 (the fifth segment) · **Source:** the owner's *Drink Icons* canvas,
dropped in by hand as `docs/design/icons/` (the design project cannot be read
from this environment — see CLAUDE.md), and the owner's request that the type
control show "text and icons".

## Context

Every drink surface drew its type with an SF Symbol — `mug.fill`,
`wineglass.fill`, `flask.fill`, `cup.and.saucer.fill`, `drop.fill` for the
untyped drink — with `heart.text.square` for a Health mirror and
`checkmark.circle` for a day recorded as no alcohol. The owner redrew the set,
and the canvas says why: a cup and saucer reads as a hot drink, "not alcohol",
the opposite of what the row records; a flask reads as laboratory; and the
seven did not read as one hand. The new set is eight 24×24 filled silhouettes
on a shared baseline — beer, wine, spirit, cocktail, other, a drop for the
standard drink, a heart for Health, and an outlined ring-and-check for no
alcohol — with a README naming them `tally.*` and mapping each to the symbol it
replaces.

Two things made this more than a rename. First, **the type control was text
only**: a native segmented `Picker` over five names. The owner asked for glyph
and text together, and the canvas draws each segment as the glyph *above* the
label. `UISegmentedControl`, which a segmented Picker bridges to, holds a title
or an image per segment and cannot stack them — whatever SwiftUI renders for a
`Label` there, the drawn layout is unreachable natively. ADR-0026 had already
disqualified ComponentsKit's segmented control (no button trait, no selected
trait, a fixed height under Dynamic Type), so the control has to be the app's
own. Second, **there is no SF Symbols app on the build Mac**, so the templates
Xcode's asset compiler requires could not be exported; they had to be
generated.

## Decision

**Eight custom symbols in the app's asset catalog**, `tally.beer` … 
`tally.alcoholfree`, built by `scripts/make-drink-symbols.py` from the bundle's
SVGs. The script is the source of truth for the derivation, as
`make-app-icon.py` is for the icon: it lays each glyph onto Apple's template
sheet with the art's baseline (y 20 of 24) on `Baseline-M` and its vessel tops
on `Capline-M` — aligned to the capital-letter height, as Apple's own glyphs
are — with one em equal to the whole 24-unit box, the size the canvas renders
them at. It re-orients every contour so outer shapes wind one way and holes the
other (correct under both fill rules, so the mug's foam line and the cup's
dots survive whatever the compiler assumes), outlines the alcohol-free stroke
analytically (a capsule per segment, one round join), strips the bundle's
C2PA metadata, and writes all 27 weight-and-scale variants with the same
geometry, because the art has no weight axis. **Regenerate; never hand-edit a
`.symbolset`.** A changed glyph is a changed SVG in the bundle and a rerun.

**`DrinkType.symbolName` names these**, with `DrinkType.Symbol` holding the two
companions (`health`, `alcoholFree`) and the generator's list, so the package
and the script cannot disagree without a tier-1 test saying so. Every surface
loads them with `Image(_:)` or `Label(_:image:)`, never `Image(systemName:)`,
which renders nothing for a catalog name. **A catalog glyph beside text is
always decorative** — `Image(decorative:)` — because a catalog `Image` otherwise
speaks its asset name to VoiceOver, and "tally dot cocktail" is not a word a
reader chose. Two sites keep a system symbol. The App Shortcut's tile icon,
which the system requires to be an SF Symbol, keeps `checkmark.circle`. So
does the bulk-fill sheet's "N days already have a record" note, which the
bundle's own list names as a companion site: a skipped day is one with drinks
*or* a marker, and the alcohol-free glyph is reserved for the marker's meaning
(ADR-0007's channel), so that note is a "done" mark over a count and stays the
system checkmark. The four marker sites — Today, the day sheet, and both of
the Trends readout's — take `tally.alcoholfree`.

**The type control is `DrinkTypePicker`**: five real Buttons in a
`tertiarySystemFill` track (radius 9, 2pt padding, 2pt gaps), each the glyph at
body size over the name at caption2 (semibold when selected), equal widths,
44pt minimum height, the selected one on a `systemBackground` tile (radius 7)
that slides between segments under the sheet's existing animation and simply
crossfades under Reduce Motion. The selection is the sheet's binding, so
changing type still resets size and strength exactly as before, and every
segment stays for the whole presentation (`asksType`). At accessibility sizes
it folds into the region picker's rows — glyph, name, a check — on interactive
glass. VoiceOver reads each segment as a button by its name with the selected
trait, inside a container labelled "Drink". `SectionLabel` gained the header
trait for that — and it is shared, so every section label in the app (the day
sheet, bulk fill, Support, the privacy policy) is now a VoiceOver heading the
rotor can move between; an improvement everywhere, recorded so nobody hunts
for why. The sheet's header shows the type's glyph beside its name, as drawn.

## Consequences

### What this buys

- The set reads as one hand, and the two glyphs that lied — the saucer and the
  flask — are gone. Every surface changed at once, because every surface read
  `symbolName`.
- The type control shows what a type looks like as well as what it is called,
  which is what the owner asked for, and it does so with real buttons: a
  selected trait, a 44pt target, a height that follows Dynamic Type.
- The glyphs take the accent and secondary inks through `foregroundStyle`
  exactly as system symbols did, so the design system's contrast table still
  describes them and no colour is added anywhere.

### What it costs, honestly

- **No weight axis.** Every variant is the same geometry, so a glyph next to
  bold text is not bolder. The art is a filled silhouette and does not want
  one; if it ever does, the reopening is an SF Symbols export.
- **The glyphs are cap-height sized**, by the canvas's own scale table, which
  makes them a little smaller than `mug.fill` was at the same font. Deliberate,
  and worth one look on hardware.
- **A catalog name is a string.** A typo in `symbolName` compiles and renders
  nothing; tier 1 pins the names against the generator's list, and a simulator
  render is the only proof of drawing. Custom symbols also do not reach the
  widget, whose catalog has none; it draws no type glyph today, and a future
  one means copying the symbolsets across.
- **The dark-mode tile is the inverse of a native control's** — a black tile in
  a lighter groove, kept because it is the measured accent pair (4.79:1) and
  the plus-mode pill's own choice; the canvas's darker tile would take accent
  to 4.46:1. The one appearance detail worth a human eye.
- **"Cocktail" fits the segment only by the 0.8 scale floor** at the largest
  non-accessibility size (64.8pt semibold in a 64.2pt segment on a 393pt
  screen), and fails it one step up — which is why the fold is at
  `isAccessibilitySize` and why a longer localized name may push it down a
  step when translation arrives.
- **Three drawings deliberately not built:** the tile's drop shadow (depth is
  the material's, design-system §4), the darker dark-mode tile above, and any
  weight variation.
- **Verification is tier 3.** `DrinkTypePicker` and the sheet are app-target
  code no test tier can reach; CI green proves compilation. Verified on a
  booted iPhone 17 Pro: all eight glyphs on Today, History and the sheet in
  both appearances; the picker at the default size, at
  `extra-extra-extra-large` (five labels on one line, one baseline) and folded
  at `accessibility-extra-large`; the header glyph following the selection.
  Two defects were found by rendering rather than reasoning: the alcohol-free
  check's caps first bulged inward (a sign-convention error in the outline
  builder, fixed by a numeric test), and the five labels sat at five heights
  because each glyph laid out at its own drawn height (fixed by a scaled slot).
  **For the owner's pass:** the sliding tile on hardware and under Reduce
  Motion, VoiceOver reading one segment (it must not say "tally"), and the
  glyph size against the row text on a real display.

## How to reopen

- Weight variation, or a glyph that should differ by scale, means exporting
  the set through the SF Symbols app and replacing the generator's output with
  its templates — the names and the call sites stay.
- If UIKit ever stacks a title over an image in a segment, the control could
  return to a native `Picker`; until then the drawn layout needs this one.
- A redrawn glyph is a new SVG in `docs/design/icons/icons/` and a rerun of the
  script, with the preview it writes looked at before the build.
