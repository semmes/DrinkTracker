import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The reader's Friday-to-Sunday split beside the published rate (ADR-0032),
/// in its own card since ADR-0038's 2026-09-10 amendment.
///
/// It sat under the seven weekday rows until then, in `WeekdayCard`, as its
/// second labelled block. It moved because the three published comparisons now
/// sit under one heading that names them, and the seven rows — the reader's own
/// log, which no switch gates — must stay outside that heading. What it costs
/// is adjacency: the split no longer sits directly beneath the rows it is
/// folded from, and can end up two cards below them. It never referenced their
/// figures and states its own denominators, so nothing is lost in meaning, but
/// the nearness is real and is gone.
///
/// Nothing is recomputed, normalised, subtracted or ranked — the table only
/// puts two published denominators where they can be seen to be different ones.
/// The user's own counts are rounded and tabular; the published rates stay in
/// default SF. That numeral difference is the only channel available for "your
/// fact" against "a published fact" — the design system allows no second hue
/// for it (PRD invariant 10), so it must not be softened.
struct WeekendComparisonCard: View {
  let split: WeekendSplit
  let reference: WeekendReference

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The same threshold the weekday table folds at, read from one place so the
  /// two cannot drift now that they are two views.
  private var isStacked: Bool { ComparisonTable.folds(dynamicTypeSize) }

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: 0) {
        CardTitle("Weekend and weekdays")

        // The measure, named once. It headed this block before the split, and
        // it is still load-bearing: without it the table reads "6 of 13" and
        // "31 of every 100" under heads saying only YOUR LOG and US ADULTS,
        // and nothing says what is counted. (The weekday table's own
        // "Days with a drink" column head is in another card now.)
        //
        // Only in the table form: the stacked sentences below say "days with a
        // drink" themselves, and so does the table's spoken label, which is
        // why this is hidden from VoiceOver rather than read twice.
        if !isStacked {
          Text("Days with a drink")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
            .accessibilityHidden(true)
        }

        if isStacked {
          stackedComparison
        } else {
          comparisonTable
        }

        SourceDisclosure(sources: PopulationReferenceCopy.weekdaySource) {
          Text(PopulationReferenceCopy.weekendNote)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Two rows on the paper's own definition of the weekend, two columns for
  /// whose figure it is.
  ///
  /// The two numeric columns take their own content's width — the head or the
  /// widest cell, whichever is wider — rather than a fixed one. A fixed width
  /// here bought nothing (both heads are one line) and cost the label column
  /// the room "Monday to Thursday" needs: at 74 and 100 the label had 113pt on
  /// a 375pt screen at the default size, and the phrase is 125.
  private var comparisonTable: some View {
    Grid(alignment: .trailing, horizontalSpacing: GlassTokens.Spacing.tight, verticalSpacing: 0) {
      GridRow(alignment: .bottom) {
        ComparisonTable.emptyHeadCell
        ComparisonTable.columnHead(Text("Your log"))
        ComparisonTable.columnHead(Text("US adults"))
      }
      .padding(.bottom, 7)

      Divider()
      comparisonRow(
        Text("Friday to Sunday"),
        mine: ComparisonTable.ratioCell(split.weekendDaysWithDrinks, of: split.weekendDays),
        published: reference.weekendEpisodesPer100Days
      )

      Divider().opacity(0.7)
      comparisonRow(
        Text("Monday to Thursday"),
        mine: ComparisonTable.ratioCell(split.otherDaysWithDrinks, of: split.otherDays),
        published: reference.otherEpisodesPer100Days
      )
    }
    .padding(.top, GlassTokens.Spacing.regular)
    // One element, labelled with the three reviewed sentences the table's
    // cells are the parts of: the table is a compact way to *show* them, and
    // nothing a screen reader hears is newly worded.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(comparisonLabel)
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
  private var stackedComparison: some View {
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

  private var comparisonLabel: Text {
    Text(PopulationReferenceCopy.weekendLine(split))
      + Text(verbatim: " ")
      + Text(PopulationReferenceCopy.weekdaysLine(split))
      + Text(verbatim: " ")
      + Text(PopulationReferenceCopy.weekendReferenceLine(reference))
  }
}
