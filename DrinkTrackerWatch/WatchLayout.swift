import DrinkTrackerCore
import SwiftUI

/// The counter's measurements (`docs/design/watch/README.md`, "Design
/// tokens"), watch-local by design: watchOS's layout units are not the
/// phone's, and `GlassTokens` stays the phone's. Points, all of them.
///
/// What is here is what is the same on every case. The row's tile, the
/// column's margin and everything inside the tile follow the screen's width,
/// and are `CounterMetrics` (below): the design drew 44 · 86 · 44 on a 198pt
/// screen, and a 40mm's is 162.
enum WatchLayout {
  /// Both controls the same size on purpose, and the ＋ is told apart by being
  /// *filled*, not by being bigger — the rule `CountStepper` already
  /// establishes on the phone. A touch target: 44 on every case, whatever
  /// else has to give (`CounterRow`).
  static let discSide = CGFloat(CounterRow.discSide)
  static let counterGap = CGFloat(CounterRow.gap)

  /// The glyphs keep the phone's two-point optical offset: the ＋ sits on a
  /// solid fill and matching them optically means matching apparent weight.
  static let minusGlyphSize: CGFloat = 19
  static let plusGlyphSize: CGFloat = 21

  static let unitWordSize: CGFloat = 12
  static let estimateSize: CGFloat = 11
  static let legendLabelSize: CGFloat = 9
  static let legendSwatch: CGFloat = 9
  static let legendSwatchRadius: CGFloat = 3
  static let hintSize: CGFloat = 10

  static let stripRadius: CGFloat = 14
  static let toastRadius: CGFloat = 12

  /// Beneath the row: 7 to the unit word, 1 to the ≈ line, 11 to the legend.
  static let rowToUnitWord: CGFloat = 7
  static let unitWordToEstimate: CGFloat = 1
  static let estimateToLegend: CGFloat = 11

  /// The empty day's button: 14 under the unit word, the disc's 44 tall,
  /// 13pt medium.
  static let unitWordToRecordButton: CGFloat = 14
  static let recordButtonTextSize: CGFloat = 13

  /// The marked day's two lines: 9 under the row, 11pt then 10pt, 4 apart.
  static let rowToMarkedLine: CGFloat = 9
  static let markedLineSize: CGFloat = 11
  static let markedLineGap: CGFloat = 4

  /// The session row (the design's screen 4): 9pt dots at 5pt gaps, the
  /// count line at 11pt, 4 beneath them; the toggle that shows the row sits
  /// 14 under the slot, below the fold.
  static let dotSize: CGFloat = 9
  static let dotGap: CGFloat = 5
  static let dotsToSessionLine: CGFloat = 4
  static let sessionLineSize: CGFloat = 11
  static let slotToToggle: CGFloat = 14

  /// The type picker (the design's screen 5): two columns of 62pt tiles at
  /// radius 14 on `.primary` at 10%, 8 apart; the glyph at 20 in the accent
  /// over the name at 11, 4 between them.
  static let pickerMargin: CGFloat = 10
  static let pickerGap: CGFloat = 8
  static let pickerTileHeight: CGFloat = 62
  static let pickerTileRadius: CGFloat = 14
  static let pickerGlyphSize: CGFloat = 20
  static let pickerNameSize: CGFloat = 11
  static let pickerGlyphToName: CGFloat = 4
}

/// The counter's measurements that follow the screen: the column's margin,
/// the tile's side, and everything drawn inside the tile.
///
/// The design drew the row once — 44 · 86 · 44 at 4pt gaps inside 8pt margins,
/// 198pt, the 45mm's width — and on a 40mm (162pt) or a 41mm (176) it ran off
/// both edges and took the column with it. The discs are touch targets and
/// keep their 44, so the margins give first, until the row stands its own 4pt
/// gap from the glass, and then the tile; inside the tile the design's own two
/// ratios re-derive the corner and the numeral, as it asks ("re-derive from
/// these rather than picking new numbers"). All of it is `CounterRow` in the
/// core package, pinned at tier 1 against every case's width. On a 45, 46 or
/// 49mm the counter is drawn exactly as it was before this existed — rendered,
/// pixel for pixel.
///
/// Both inputs are the view's own, read from its geometry, never a device
/// table: its width, and what the system has already kept clear of the glass
/// on each side — 2pt on every case measured, so a 40mm's view is 158pt wide
/// and not the screen's 162.
struct CounterMetrics: Equatable {
  let margin: CGFloat
  let tileSide: CGFloat
  let tileRadius: CGFloat
  let numeralSize: CGFloat
  /// On an unlogged day there is no tile, and the numeral takes its room — the
  /// same trade `CountStepper` makes between 68 in a band and 84 without one.
  let bareNumeralSize: CGFloat
  /// The glyph inside the tile on a no-alcohol day, and under Always-On.
  let tileGlyphSize: CGFloat
  /// The struck-out number that stands in for the numeral while it is hidden
  /// — a bar, deliberately, so the screen reads as withheld and not as loading.
  let hiddenBar: CGSize
  let hiddenBarRadius: CGFloat

  init(width: CGFloat, edgeInset: CGFloat) {
    let width = Double(width)
    let inset = Double(edgeInset)
    let side = CounterRow.tileSide(forWidth: width, edgeInset: inset)
    margin = CGFloat(CounterRow.margin(forWidth: width, edgeInset: inset))
    tileSide = CGFloat(side)
    tileRadius = CGFloat(CounterRow.cornerRadius(forSide: side))
    numeralSize = CGFloat(CounterRow.numeralSize(forSide: side))
    bareNumeralSize = CGFloat(CounterRow.bareNumeralSize(forSide: side))
    tileGlyphSize = CGFloat(CounterRow.glyphSize(forSide: side))
    hiddenBar = CGSize(
      width: CounterRow.hiddenBarWidth(forSide: side),
      height: CounterRow.hiddenBarHeight(forSide: side)
    )
    hiddenBarRadius = CGFloat(CounterRow.hiddenBarRadius(forSide: side))
  }
}
