import Foundation

/// The home-screen widget's row (`QuickLogWidget`, ADR-0057): the day's count
/// over its words, and the ＋.
///
/// The small family is not one size. iOS 26 gives it from 146pt on an iPhone
/// SE to 176.67 on a 17 Pro Max, and draws the content inside margins that
/// grow with it, so the content is 114 to 138pt wide. The row as it was built
/// left the words the content less the ＋ and *two* gaps of 12, because the
/// Spacer that pushed the ＋ to the trailing edge keeps a gap on each side of
/// itself: 38 to 62pt. "drinks today" is 64.5pt on one line — 74.7 on the
/// Plus and Pro Max phones, which draw the widget's text larger — so on every
/// iPhone iOS 26 supports the words were cut short or shrunk: "drinks tod…" in
/// the owner's screenshot from a 17 Pro-size simulator.
///
/// The count and the ＋ keep their sizes, so the words give: they take the
/// whole column beside the ＋ — the Spacer goes, and its second gap with it —
/// and they may take a second line. They wrap before they shrink, and the
/// floor stays 0.8. Where the words fit on one line, which is every medium
/// widget, nothing moves.
///
/// Arithmetic only, and here rather than in the widget so it is pinned at
/// tier 1 against every iPhone's real width; most of those widths can only
/// be seen on hardware or a simulator of that size. Points throughout.
public enum QuickLogWidgetRow {
  /// The ＋'s disc on the small family, a touch target, unchanged.
  public static let smallPlusSide: Double = 52

  /// …and on the medium, unchanged.
  public static let mediumPlusSide: Double = 60

  /// Between the count's column and the ＋: the row's own spacing, unchanged.
  public static let gap: Double = 12

  /// The floor the words may shrink to. Wrapping comes first; this is what is
  /// left when a single word is wider than its column, which no iPhone's
  /// column is at any text size the widget draws (the tests' table).
  public static let minimumScale: Double = 0.8

  /// "drinks" over "today", on a small widget too narrow for one line. The
  /// medium family never needs the second line, so it never takes it.
  public static let wordsLineLimit = 2

  /// The ＋'s side in the family the widget is drawn in.
  public static func plusSide(isSmall: Bool) -> Double {
    isSmall ? smallPlusSide : mediumPlusSide
  }

  /// What the row as it was left the words: the content less the ＋ and two
  /// gaps — the Spacer between them keeps one on each side of itself.
  public static func spacerRowColumn(forContentWidth width: Double, isSmall: Bool) -> Double {
    width - plusSide(isSmall: isSmall) - 2 * gap
  }

  /// What the row leaves the words now: everything but the ＋ and its one gap.
  public static func wordsColumn(forContentWidth width: Double, isSmall: Bool) -> Double {
    width - plusSide(isSmall: isSmall) - gap
  }
}
