import Foundation

extension SessionPace {
  /// What the wrist's session row draws (watch Phase 5, ADR-0044): whole
  /// dots up to a cap, and whether the cap hid any.
  public struct DotRow: Hashable, Sendable {
    /// Dots to draw, `0...maximum`.
    public let dots: Int
    /// True when the count exceeds the cap. The row then draws the cap and
    /// the count line beside it carries the truth — never a truncation mark.
    public let isTruncated: Bool

    public init(dots: Int, isTruncated: Bool) {
      self.dots = dots
      self.isTruncated = isTruncated
    }
  }

  /// Dots stop being countable past about eight. That is the whole reason
  /// for the cap: at the row's drawn sizes eight dots take 107pt of the
  /// smallest watch's 162, so width is not the constraint.
  public static let dotMaximum = 8

  /// The dots for a session count.
  ///
  /// Decided on the *displayed* count — `StandardDrink.displayed`, the
  /// one-decimal figure the line beside the dots prints — never the raw
  /// total, so the dots and the figure cannot disagree: a fraction rounds to
  /// the nearest whole dot with a half up, and 2.45 is "2.5" over three dots
  /// just as 2.5 is. (`DayIntensity.bucket` decides its band the same way,
  /// for the same reason.) Above the cap the row draws the cap and is marked
  /// truncated. Nothing is drawn for zero, a negative or a non-finite count,
  /// except that a count beyond any bound (+∞) is simply more than the cap.
  public static func dotRow(forCount count: Double, maximum: Int = dotMaximum) -> DotRow {
    let cap = max(0, maximum)
    // `NaN` fails this comparison, as it should.
    guard count > 0 else { return DotRow(dots: 0, isTruncated: false) }
    let rounded = StandardDrink.displayed(count).rounded()
    guard rounded > 0 else { return DotRow(dots: 0, isTruncated: false) }
    guard rounded <= Double(cap) else { return DotRow(dots: cap, isTruncated: true) }
    return DotRow(dots: Int(rounded), isTruncated: false)
  }
}
