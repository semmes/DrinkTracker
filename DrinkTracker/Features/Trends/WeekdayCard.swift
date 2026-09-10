import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The range by weekday (ADR-0032): for each day of the week, what was
/// logged on those days and how many of them had a drink. Facts about the
/// user's own log, seven rows in the calendar's order, with no rank, no
/// "most", and no external figure — ADR-0028's rule applied to weekdays.
///
/// ## One table, and why the other one left
///
/// The card held two tables until ADR-0038's 2026-09-10 amendment: these seven
/// rows, then the weekend split beside a published rate. The split moved to
/// `WeekendComparisonCard`, under the new Comparisons heading, because that
/// heading names the three published comparisons and **these rows are not one
/// of them** — they are the reader's own log, gated by nothing, and ADR-0038
/// says so in as many words. A heading spanning them would also do the thing
/// this card is built to refuse: naming a comparison over seven weekday
/// figures instructs the reader to rank them, when the point of the aligned
/// columns is that alignment does the comparing the copy will not.
///
/// Two consequences, both deliberate. The card no longer holds a switch of any
/// kind — `showsComparison` is gone, so nothing here can be gated by accident.
/// And its title dropped to `CardTitle` — the sentence-case `cardLabel` every
/// other card on Trends already titles itself with. The uppercase-tracked form
/// it used to carry was scoped to "a card that holds more than one table", and
/// this one no longer does; that token had no other caller and retired with it.
///
/// ## The layout, and why it is a table
///
/// The card used to print the unit noun seven times ("3 standard drinks",
/// "1 standard drink", …) and stack each row's two figures, so nothing lined
/// up down the card. Two changes, no new figures (ADR-0032 amendment):
///
/// 1. **The noun moves to the column head.** Stated once over the column
///    instead of once per row. `StandardDrink.amountPhrase` still supplies
///    the digits and still drives VoiceOver — only the *visible* noun moved.
/// 2. **Two aligned numeric columns.** Alignment does the comparing that the
///    copy refuses to do: the reader sees the shape of their own week without
///    a sentence naming a largest day.
///
/// Still refused, and the reason is unchanged: the seven weekdays are **not**
/// charted. A chart of seven bars invites "which is highest", and the tallest
/// bar named is a rank.
///
/// The user's own counts are rounded and tabular; the published rates stay in
/// default SF. That numeral difference is the only channel available for
/// "your fact" against "a published fact" — the design system allows no second
/// hue for it (PRD invariant 10), so it must not be softened.
struct WeekdayCard: View {
  let totals: [WeekdayTotal]
  let region: Region
  let calendar: Calendar

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The weekday table's numeric column width. It is what makes a two-word
  /// column head wrap onto two lines instead of running the width of the card
  /// and pushing its neighbour into it — the head has to be narrow enough to
  /// break. Scaled rather than fixed, so the columns grow with the type they
  /// hold. It stays here and is not shared: the comparison table carries no
  /// such width, because its heads are one line each, so its columns size to
  /// their own content and the label column keeps whatever is left (the
  /// 2026-09-07 amendment to ADR-0032).
  @ScaledMetric(relativeTo: .caption2) private var figureColumn: CGFloat = 88

  /// Above the default size the table folds back to the stacked rows — the
  /// form the card had before, which reads correctly at any width. The figures
  /// are identical either way; only their arrangement changes. The threshold
  /// is `ComparisonTable.folds`, shared with the weekend card so the two fold
  /// together now that they are two views; it was rendered, not reasoned.
  private var isStacked: Bool { ComparisonTable.folds(dynamicTypeSize) }

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: 0) {
        CardTitle("By weekday")

        if isStacked {
          stackedWeekdays
        } else {
          weekdayTable
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - The log by weekday

  /// Seven rows over two right-aligned numeric columns. One `Grid` holds the
  /// heads and the rows so they share column widths; the leading column takes
  /// the slack, so the numerals sit against the trailing edge at every width.
  private var weekdayTable: some View {
    Grid(alignment: .trailing, horizontalSpacing: GlassTokens.Spacing.tight, verticalSpacing: 0) {
      GridRow(alignment: .bottom) {
        ComparisonTable.emptyHeadCell
        // The region's own plural, uppercased for display: the head is the
        // one place the unit is named, so it has to follow the lens like the
        // rows it heads (a UK reader reads "UNITS").
        ComparisonTable.columnHead(Text(verbatim: region.unitNamePlural), width: figureColumn)
        ComparisonTable.columnHead(Text("Days with a drink"), width: figureColumn)
      }
      .padding(.bottom, 7)
      .accessibilityHidden(true)

      ForEach(Array(totals.enumerated()), id: \.element.id) { index, total in
        // The first rule is the card's own separator; the rest are a lighter
        // step of it, so the block reads as one table rather than seven bands.
        Divider().opacity(index == 0 ? 1 : 0.7)

        // One VoiceOver stop per row, and the modifiers that make it one sit
        // on the *cells*, never on the `GridRow`: a modifier on a GridRow is
        // applied to each of its cells in turn, so an element-and-label pair
        // there produced three identical stops per weekday (measured: six
        // elements for two rows). The name cell carries the whole row's
        // sentence and the two figures are hidden, because the sentence
        // already speaks them.
        GridRow(alignment: .firstTextBaseline) {
          Text(verbatim: calendar.weekdaySymbols[total.weekday - 1])
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridColumnAlignment(.leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(weekdayLabel(total))

          Text(verbatim: StandardDrink.formatted(total.standardDrinks))
            .font(GlassTokens.Typography.rowFigure)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .accessibilityHidden(true)

          ComparisonTable.ratioCell(total.daysWithDrinks, of: total.dayCount)
            .accessibilityHidden(true)
        }
        .padding(.vertical, GlassTokens.Spacing.tight)
      }
    }
  }

  /// The pre-table form, kept for the sizes above the default: the noun returns
  /// to the row because there is no head above it to carry it.
  private var stackedWeekdays: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      ForEach(totals) { total in
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: calendar.weekdaySymbols[total.weekday - 1])
            .font(.subheadline)
            .foregroundStyle(.primary)
          Text(verbatim: StandardDrink.amountPhrase(total.standardDrinks, region: region))
            .font(GlassTokens.Typography.rowFigure)
            .monospacedDigit()
            .foregroundStyle(.primary)
          Text(daysLine(total))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekdayLabel(total))
      }
    }
    .padding(.top, GlassTokens.Spacing.regular)
  }

  // MARK: - Spoken

  /// The weekday row's one sentence: the noun the column head carries visually
  /// is spoken here, so nothing is lost by moving it out of the row. In the
  /// table it is the label of the name cell — the row's single element, the
  /// two figure cells being hidden — and in the stacked form the label of the
  /// whole row.
  private func weekdayLabel(_ total: WeekdayTotal) -> Text {
    Text(verbatim: calendar.weekdaySymbols[total.weekday - 1])
      + Text(verbatim: ", ")
      + Text(verbatim: StandardDrink.amountPhrase(total.standardDrinks, region: region))
      + Text(verbatim: ", ")
      + Text(daysLine(total))
  }

  /// "4 of 4 days" — how many of this weekday's days had a drink. One key
  /// per plural of the second count, chosen on the displayed integer.
  private func daysLine(_ total: WeekdayTotal) -> LocalizedStringKey {
    total.dayCount == 1
      ? "\(total.daysWithDrinks) of 1 day"
      : "\(total.daysWithDrinks) of \(total.dayCount) days"
  }
}
