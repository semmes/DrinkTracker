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
        // Titled by its measure, not by its switch (owner's review,
        // 2026-09-10). The rows already say "Friday to Sunday" and "Monday to
        // Thursday", so "Weekend and weekdays" over a "Days with a drink" head
        // read as one two-line title — same ink, same case, one point of size
        // apart. The title now does the job the head did, saying what
        // "46 of 147" and "31 of every 100" count, so the head is gone rather
        // than demoted. The Settings switch keeps the split's name; this is
        // the one card whose title is not its switch's words, and ADR-0038's
        // amendment records the exception.
        CardTitle("Days with a drink")

        if isStacked {
          stackedComparison
        } else {
          comparisonTable
            .padding(.top, GlassTokens.Spacing.regular)
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
    // No top padding here: the call site carries the card's 12pt gap below
    // the title, as the weekday table's does.
    // One element, labelled with the three reviewed sentences the table's
    // cells are the parts of: the table is a compact way to *show* them, and
    // nothing a screen reader hears is newly worded.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(comparisonLabel)
  }

  /// One row at the weekday table's own sizes, cell for cell: `.subheadline`
  /// for the label, the shared `ratioCell` for the reader's count, `.footnote`
  /// for the published rate — the size the ratio cell's own "of 147" already
  /// takes. Until the owner's review (2026-09-10) the label was footnote and
  /// the rate caption, a step below the table directly above, and the two read
  /// as different instruments. The label column is what the two numeric
  /// columns leave; the fit of "Monday to Thursday" at this size is measured
  /// in ADR-0032's amendment.
  private func comparisonRow(_ label: Text, mine: some View, published: Double) -> some View {
    GridRow(alignment: .firstTextBaseline) {
      label
        .font(.subheadline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridColumnAlignment(.leading)

      mine

      // Default SF, deliberately: a published rate is not a numeral the user
      // made, and the rounded face is reserved for the ones that are.
      Text("\(Int(published.rounded())) of every 100")
        .font(.footnote)
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
