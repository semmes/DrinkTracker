import Foundation

/// The watch counter's row — the − disc, the day's tile, the ＋ disc — sized to
/// the screen it is on (ADR-0042, amended 2026-09-19).
///
/// The design drew it once, on a 198pt screen: 44 · 86 · 44 at 4pt gaps inside
/// 8pt margins, "the one arrangement that fits the usable width". That is the
/// 45mm's width. A 40mm screen is 162pt and a 41mm's 176, where the same row
/// ran off both edges and took the rest of the column with it; on the 42 and
/// 44mm it fitted the glass and not its margins.
///
/// Both discs are touch targets and keep their 44 on every case. So the rest
/// gives, in the order that costs the reader least: the margins first, until
/// the row stands as far from the glass as it does from itself, and then the
/// tile. Everything inside the tile follows its side by the design's own
/// ratios — it records two, the corner and the numeral, "so the tile can be
/// resized honestly" — and the pieces it gives no ratio for scale from their
/// drawn size on the drawn 86. At 86 every value here is the design's, to the
/// point.
///
/// Two widths are in play and they are not the same. watchOS keeps a little of
/// the glass clear on each side before the app lays anything out (2pt on every
/// case, measured 2026-09-19), so the view is narrower than the screen: 158 on
/// a 40mm, not 162. The functions take what the view is given and what the
/// system has already kept clear, and assume neither.
///
/// Arithmetic only, and here rather than in the watch target so it is pinned
/// at tier 1 against every case's width. Points throughout.
public enum CounterRow {
  /// Each disc: the smallest legal touch target, never less on any case.
  public static let discSide: Double = 44

  /// Between a disc and the tile — and the least the row may stand from the
  /// glass: tighter to the edge than it is to itself, it would read as clipped.
  public static let gap: Double = 4

  /// The tile as drawn, and the most it ever is.
  public static let drawnTileSide: Double = 86

  /// The column's own margin as built on the drawn screen, and the most it
  /// ever is.
  public static let drawnMargin: Double = 8

  /// The row as drawn: 182pt.
  public static var drawnRowWidth: Double { 2 * discSide + 2 * gap + drawnTileSide }

  /// The column's horizontal margin in a view this wide, where the system
  /// already keeps `edgeInset` of the glass clear on each side: the drawn 8
  /// where the drawn row fits inside it, and otherwise what is left — down to
  /// whatever still stands the row a gap's width from the glass.
  public static func margin(forWidth width: Double, edgeInset: Double = 0) -> Double {
    guard width.isFinite, width > 0 else { return drawnMargin }
    let inset = edgeInset.isFinite ? max(0, edgeInset) : 0
    let floor = max(0, gap - inset)
    let spare = (width - drawnRowWidth) / 2
    return min(drawnMargin, max(floor, spare))
  }

  /// The tile's side in a view this wide: the drawn 86 wherever the row fits
  /// with at least the least margin, and otherwise what the discs, the gaps
  /// and that margin leave — floored to the half point, a whole pixel at the
  /// watch's 2x.
  public static func tileSide(forWidth width: Double, edgeInset: Double = 0) -> Double {
    guard width.isFinite, width > 0 else { return drawnTileSide }
    let room = width - 2 * margin(forWidth: width, edgeInset: edgeInset) - 2 * discSide - 2 * gap
    return min(drawnTileSide, max(0, (room * 2).rounded(.down) / 2))
  }

  // MARK: Inside the tile

  /// The design's first ratio, the phone's hero: radius = side × 36 / 126,
  /// to the point — 25 on the drawn 86.
  public static func cornerRadius(forSide side: Double) -> Double {
    (side * 36 / 126).rounded()
  }

  /// The design's second ratio: numeral = side × 68 / 126, to the point — 46
  /// on the drawn 86.
  public static func numeralSize(forSide side: Double) -> Double {
    (side * 68 / 126).rounded()
  }

  /// The numeral on an unlogged day, when there is no tile and it takes the
  /// tile's room: drawn at 56 on 86.
  public static func bareNumeralSize(forSide side: Double) -> Double {
    scaled(56, toSide: side).rounded()
  }

  /// The glyph inside the tile on a no-alcohol day and under Always-On: drawn
  /// at 34 on 86.
  public static func glyphSize(forSide side: Double) -> Double {
    scaled(34, toSide: side).rounded()
  }

  /// The struck-out bar that stands in for a hidden count: drawn 40 × 8 at
  /// radius 4 on 86, to the half point.
  public static func hiddenBarWidth(forSide side: Double) -> Double { half(scaled(40, toSide: side)) }
  public static func hiddenBarHeight(forSide side: Double) -> Double { half(scaled(8, toSide: side)) }
  public static func hiddenBarRadius(forSide side: Double) -> Double { hiddenBarHeight(forSide: side) / 2 }

  private static func scaled(_ drawn: Double, toSide side: Double) -> Double {
    drawn * side / drawnTileSide
  }

  private static func half(_ value: Double) -> Double { (value * 2).rounded() / 2 }
}
