import SwiftUI

/// The table parts the two weekday surfaces share, after the weekend
/// comparison left `WeekdayCard` for its own card (ADR-0032's 2026-09-10
/// amendment).
///
/// Every value here was **rendered, not reasoned** when ADR-0032's 2026-09-07
/// amendment established it, so these move byte-identical and are shared
/// rather than copied: a second copy is a second thing to re-measure, and
/// nothing in a remote session can re-measure it.
///
/// What deliberately does *not* live here is `WeekdayCard`'s
/// `@ScaledMetric figureColumn` (88). Two reasons, both load-bearing: a
/// property wrapper needs a `DynamicProperty` context and would not compile as
/// a static, and the comparison table never referenced it — its numeric columns
/// size to their own content precisely so the label column keeps the 125pt
/// "Monday to Thursday" needs against the 113pt a fixed 74/100 left it on a
/// 375pt screen.
enum ComparisonTable {

  /// Above the default size both tables fold back to stacked rows and the
  /// reviewed sentences. One threshold, read by both cards, so the constant
  /// cannot fork into two drifting copies.
  ///
  /// `xLarge`, not `isAccessibilitySize`: the label column is what the numeric
  /// columns leave, and that shrinks faster than the weekday names grow. On a
  /// 402pt screen the shipped table already broke "Wednesday" and "Thursday"
  /// mid-word at xLarge, and at xxLarge every weekday hyphenated
  /// ("Sat-/ur-/day"). Rendered, not reasoned.
  static func folds(_ size: DynamicTypeSize) -> Bool { size >= .xLarge }

  /// A head over a numeric column. With a `width` it is held to that width so
  /// a two-word head breaks onto two lines; without one it sizes to its text
  /// and the column follows.
  ///
  /// `.primary` ink, never `.secondary`: it carries the noun the rows dropped,
  /// and secondary at caption2 lands near 3.4:1 (design-system §3, invariant 10).
  static func columnHead(_ text: Text, width: CGFloat? = nil) -> some View {
    text
      .font(GlassTokens.Typography.columnHead)
      .textCase(.uppercase)
      .tracking(0.6)
      .foregroundStyle(.primary)
      .multilineTextAlignment(.trailing)
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: width, alignment: .trailing)
  }

  /// The leading column's head is empty — the rows name themselves — but it
  /// still has to claim the slack so the numeric columns stay at the trailing
  /// edge when the rows are short. Nothing may be drawn in it: it is
  /// zero-height on purpose, and text here takes width from the label column,
  /// which has none to give.
  static var emptyHeadCell: some View {
    Color.clear
      .frame(height: 0)
      .frame(maxWidth: .infinity)
      .gridColumnAlignment(.leading)
  }

  /// "5 of 13" — the count that had a drink over the days available. The
  /// leading numeral is the fact and sits a step darker; the denominator names
  /// what it is out of. One key with both numbers, so a translation can
  /// reorder them.
  static func ratioCell(_ value: Int, of total: Int) -> some View {
    Text(
      "\(Text(verbatim: String(value)).font(GlassTokens.Typography.rowCount).foregroundColor(.primary)) of \(total)"
    )
    .font(.footnote)
    .monospacedDigit()
    .foregroundStyle(.secondary)
  }
}
