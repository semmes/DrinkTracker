import SwiftUI

/// The counter's measurements (`docs/design/watch/README.md`, "Design
/// tokens"), watch-local by design: watchOS's layout units are not the
/// phone's, and `GlassTokens` stays the phone's. Points, all of them.
///
/// The two ratios that derived the tile from the phone's hero are recorded
/// beside their results, so a resize — another case, an accessibility step —
/// re-derives rather than picks new numbers:
///
///     radius  = side × 36 / 126  →  86 × 0.2857 = 24.6 → 25
///     numeral = side × 68 / 126  →  86 × 0.5397 = 46.4 → 46
enum WatchLayout {
  static let screenMargin: CGFloat = 8
  static let counterGap: CGFloat = 4

  /// Both controls the same size on purpose: 44 · 86 · 44 at 4pt gaps is the
  /// one arrangement that fits the usable width with both targets legal, and
  /// the ＋ is told apart by being *filled*, not by being bigger — the rule
  /// `CountStepper` already establishes on the phone.
  static let discSide: CGFloat = 44
  static let tileSide: CGFloat = 86
  static let tileRadius: CGFloat = 25

  static let numeralSize: CGFloat = 46
  /// On an unlogged day there is no tile, and the numeral takes its room — the
  /// same trade `CountStepper` makes between 68 in a band and 84 without one.
  static let bareNumeralSize: CGFloat = 56

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

  /// The struck-out number that stands in for the numeral while it is hidden
  /// — a bar, deliberately, so the screen reads as withheld and not as loading.
  static let hiddenBar = CGSize(width: 40, height: 8)
  static let hiddenBarRadius: CGFloat = 4

  /// The glyph inside the tile on a no-alcohol day, and under Always-On.
  static let tileGlyphSize: CGFloat = 34
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
