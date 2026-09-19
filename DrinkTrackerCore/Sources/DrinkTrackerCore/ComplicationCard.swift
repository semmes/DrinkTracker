import Foundation

/// The row of the rectangular card on the watch (ADR-0046, amended a second
/// time on 2026-09-18): the 44pt tile, the day's words, the 44pt ＋.
///
/// The family is not one size. The system gives it 181pt of content on a 46mm
/// face and 138 in a 40mm Smart Stack, and the row drawn for the first
/// truncated its words on the second — "drinks t…", "Recorded as no al…".
/// The tile and the ＋ keep their 44 everywhere, so the words are what gives:
/// below a width they wrap instead of shrinking, and the gaps tighten.
///
/// Arithmetic only, and here rather than in the complication so the rule is
/// pinned at tier 1 against every case size's real width. Most of those
/// widths can never be checked by eye — a simulator's Smart Stack opens only
/// under a hand — so the table in the tests is what stands in for a render.
/// Points throughout.
public enum ComplicationCard {
  /// The ＋'s disc: the tile's own 44, which is also the smallest legal target.
  public static let plusSide: Double = 44

  /// Between the row's parts on a card wide enough for the words on one line.
  public static let gap: Double = 8

  /// …and on a narrow one: the watch counter's own gap, between its discs and
  /// its tile. It is what the 40mm Smart Stack needs. "Recorded" — the one
  /// word that cannot wrap — is 45pt, and that card's column is 34 at a gap
  /// of 8 (under the word's 36 at the scale floor), 38 at 6, 42 at 4. At 6 it
  /// drew on the floor, at 0.81, and beside a dots row was cut short again;
  /// at 4 it draws at 0.90 and is whole in both (emulated on a face,
  /// 2026-09-18).
  public static let narrowGap: Double = 4

  /// The floor the words may shrink to on any card: 11pt becomes 8.8, beside
  /// the counter's own 9pt legend. Wrapping comes first; this is what is left
  /// when a single word is wider than its column.
  public static let minimumScale: Double = 0.8

  /// The least the wide row may leave the words. "drinks today" on one line
  /// at full size is 58pt of ink (measured on the 46mm, 2026-09-18), and a
  /// card that cannot give it that is narrow.
  public static let wideColumnMinimum: Double = 60

  /// What the wide row leaves the words: the content less the tile, the ＋
  /// and *three* gaps — the Spacer that pushes the ＋ to the trailing edge
  /// keeps a gap on each side of itself.
  public static func wideColumn(forContentWidth width: Double) -> Double {
    width - ComplicationTile.cardSide - plusSide - 3 * gap
  }

  /// Whether the card takes the narrow row. Every context on the 45, 46 and
  /// 49mm faces and the 46 and 49mm Smart Stacks is wide, and is drawn exactly
  /// as it was before this rule existed; nothing to measure is wide too.
  public static func isNarrow(contentWidth width: Double) -> Bool {
    guard width.isFinite, width > 0 else { return false }
    return wideColumn(forContentWidth: width) < wideColumnMinimum
  }

  /// The words' column in the row the width selects. Narrow, the words take
  /// everything between the tile and the ＋, so the Spacer goes and one gap
  /// with it.
  public static func wordsColumn(forContentWidth width: Double) -> Double {
    isNarrow(contentWidth: width)
      ? width - ComplicationTile.cardSide - plusSide - 2 * narrowGap
      : wideColumn(forContentWidth: width)
  }

  /// How many lines the words may take. Wide is what the card always had: one
  /// for the unit words, two for the no-alcohol sentence. Narrow, each gets
  /// the lines its longest word leaves it: "drinks" over "today", and the
  /// sentence a word or two to a line.
  public static func lineLimit(isMarker: Bool, isNarrow: Bool) -> Int {
    switch (isMarker, isNarrow) {
    case (false, false): 1
    case (true, false): 2
    case (false, true): 2
    case (true, true): 4
    }
  }
}
