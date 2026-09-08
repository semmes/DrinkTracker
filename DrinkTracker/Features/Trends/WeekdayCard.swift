import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The range by weekday (ADR-0032): for each day of the week, what was
/// logged on those days and how many of them had a drink. Facts about the
/// user's own log, seven rows in the calendar's order, with no rank, no
/// "most", and no external figure — ADR-0028's rule applied to weekdays.
///
/// ## The layout, and why it is a table
///
/// The card used to print the unit noun seven times ("3 standard drinks",
/// "1 standard drink", …) and stack each row's two figures, so nothing lined
/// up down the card. Three changes, no new figures (ADR-0032 amendment):
///
/// 1. **The noun moves to the column head.** Stated once over the column
///    instead of once per row. `StandardDrink.amountPhrase` still supplies
///    the digits and still drives VoiceOver — only the *visible* noun moved.
/// 2. **Two aligned numeric columns.** Alignment does the comparing that the
///    copy refuses to do: the reader sees the shape of their own week without
///    a sentence naming a largest day.
/// 3. **The three trailing sentences become one small table.** They carried
///    three different denominators in running prose ("20 of 39", "10 of 52",
///    "31 of every 100"); as a table the rows are the paper's own definition
///    of the weekend and the columns are whose figure it is.
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
  /// hold. The comparison table below carries no such width: its heads are
  /// one line each, so its columns size to their own content and the label
  /// column keeps whatever is left (the 2026-09-07 amendment to ADR-0032).
  @ScaledMetric(relativeTo: .caption2) private var figureColumn: CGFloat = 88

  /// Above the default size the tables fold back to the stacked rows and the
  /// three reviewed sentences — the form the card had before, which reads
  /// correctly at any width. The figures are identical either way; only their
  /// arrangement changes.
  ///
  /// `xLarge`, not `isAccessibilitySize`, and the threshold was rendered rather
  /// than reasoned about (ADR-0032's 2026-09-07 amendment). The label column
  /// is what the numeric columns leave, and that shrinks faster than the
  /// names grow: on a 402pt screen the shipped table already broke
  /// "Wednesday" and "Thursday" mid-word at xLarge, and at xxLarge every
  /// weekday hyphenated ("Sat-/ur-/day"). A 375pt screen has 27pt less, so
  /// no width for the numeric columns holds the widest weekday name at xLarge
  /// on both screens without squeezing the two-line heads into three. The
  /// fold therefore happens at the first size above the default, before
  /// anything fragments; xSmall through large keep the table on every screen.
  private var isStacked: Bool { dynamicTypeSize >= .xLarge }

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: 0) {
        sectionLabel("By weekday")

        if isStacked {
          stackedWeekdays
        } else {
          weekdayTable
        }

        // The user's own weekend, on the paper's definition, beside the
        // published rate — two facts about days, no rank and no threshold.
        if let reference = WeekendReference.bundled {
          let split = TrendSummary.weekendSplit(totals, weekend: reference.weekendWeekdays)

          Divider()
            .padding(.top, GlassTokens.Spacing.cardPadding)
            .padding(.bottom, 14)

          sectionLabel("Days with a drink")

          if isStacked {
            stackedComparison(split, reference)
          } else {
            comparisonTable(split, reference)
          }

          SourceDisclosure(sources: PopulationReferenceCopy.weekdaySource) {
            Text(PopulationReferenceCopy.weekendNote)
          }
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
        emptyHeadCell
        // The region's own plural, uppercased for display: the head is the
        // one place the unit is named, so it has to follow the lens like the
        // rows it heads (a UK reader reads "UNITS").
        columnHead(Text(verbatim: region.unitNamePlural), width: figureColumn)
        columnHead(Text("Days with a drink"), width: figureColumn)
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

          ratioCell(total.daysWithDrinks, of: total.dayCount)
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

  // MARK: - The split, beside the published rate

  /// Two rows on the paper's own definition of the weekend, two columns for
  /// whose figure it is. Nothing is recomputed, normalised, subtracted or
  /// ranked — the table only puts two published denominators where they can
  /// be seen to be different ones.
  ///
  /// The two numeric columns take their own content's width — the head or the
  /// widest cell, whichever is wider — rather than a fixed one. A fixed width
  /// here bought nothing (both heads are one line) and cost the label column
  /// the room "Monday to Thursday" needs: at 74 and 100 the label had 113pt on
  /// a 375pt screen at the default size, and the phrase is 125.
  private func comparisonTable(_ split: WeekendSplit, _ reference: WeekendReference) -> some View {
    Grid(alignment: .trailing, horizontalSpacing: GlassTokens.Spacing.tight, verticalSpacing: 0) {
      GridRow(alignment: .bottom) {
        emptyHeadCell
        columnHead(Text("Your log"))
        columnHead(Text("US adults"))
      }
      .padding(.bottom, 7)

      Divider()
      comparisonRow(
        Text("Friday to Sunday"),
        mine: ratioCell(split.weekendDaysWithDrinks, of: split.weekendDays),
        published: reference.weekendEpisodesPer100Days
      )

      Divider().opacity(0.7)
      comparisonRow(
        Text("Monday to Thursday"),
        mine: ratioCell(split.otherDaysWithDrinks, of: split.otherDays),
        published: reference.otherEpisodesPer100Days
      )
    }
    .padding(.top, GlassTokens.Spacing.regular)
    // One element, labelled with the three reviewed sentences the table's
    // cells are the parts of: the table is a compact way to *show* them, and
    // nothing a screen reader hears is newly worded.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(comparisonLabel(split, reference))
  }

  private func comparisonRow(_ label: Text, mine: some View, published: Double) -> some View {
    GridRow(alignment: .firstTextBaseline) {
      label
        .font(.footnote)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridColumnAlignment(.leading)

      mine

      // Default SF, deliberately: a published rate is not a numeral the user
      // made, and the rounded face is reserved for the ones that are.
      Text("\(Int(published.rounded())) of every 100")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, GlassTokens.Spacing.tight)
  }

  /// The three sentences as they were reviewed, for the sizes above the default.
  private func stackedComparison(_ split: WeekendSplit, _ reference: WeekendReference) -> some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      Text(PopulationReferenceCopy.weekendLine(split))
      Text(PopulationReferenceCopy.weekdaysLine(split))
      Text(PopulationReferenceCopy.weekendReferenceLine(reference))
    }
    .font(.body)
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, GlassTokens.Spacing.regular)
  }

  // MARK: - Parts

  private func sectionLabel(_ key: LocalizedStringKey) -> some View {
    Text(key)
      .font(GlassTokens.Typography.sectionLabel)
      .textCase(.uppercase)
      .tracking(0.8)
      .foregroundStyle(.secondary)
  }

  /// A head over a numeric column. With a `width` it is held to that width so
  /// a two-word head breaks onto two lines; without one it sizes to its text
  /// and the column follows.
  private func columnHead(_ text: Text, width: CGFloat? = nil) -> some View {
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
  /// edge when the rows are short.
  private var emptyHeadCell: some View {
    Color.clear
      .frame(height: 0)
      .frame(maxWidth: .infinity)
      .gridColumnAlignment(.leading)
  }

  /// "5 of 13" — the count that had a drink over the days available. The
  /// leading numeral is the fact and sits a step darker; the denominator names
  /// what it is out of. One key with both numbers, so a translation can
  /// reorder them.
  private func ratioCell(_ value: Int, of total: Int) -> some View {
    Text(
      "\(Text(verbatim: String(value)).font(GlassTokens.Typography.rowCount).foregroundColor(.primary)) of \(total)"
    )
    .font(.footnote)
    .monospacedDigit()
    .foregroundStyle(.secondary)
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

  private func comparisonLabel(_ split: WeekendSplit, _ reference: WeekendReference) -> Text {
    Text(PopulationReferenceCopy.weekendLine(split))
      + Text(verbatim: " ")
      + Text(PopulationReferenceCopy.weekdaysLine(split))
      + Text(verbatim: " ")
      + Text(PopulationReferenceCopy.weekendReferenceLine(reference))
  }

  /// "4 of 4 days" — how many of this weekday's days had a drink. One key
  /// per plural of the second count, chosen on the displayed integer.
  private func daysLine(_ total: WeekdayTotal) -> LocalizedStringKey {
    total.dayCount == 1
      ? "\(total.daysWithDrinks) of 1 day"
      : "\(total.daysWithDrinks) of \(total.dayCount) days"
  }
}
