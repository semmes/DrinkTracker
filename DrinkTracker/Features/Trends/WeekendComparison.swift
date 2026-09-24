import DrinkTrackerCore
import SwiftUI

/// The reader's Friday-to-Sunday split beside the published rate (ADR-0032),
/// the third segment of the Comparisons card since ADR-0038's 2026-09-23
/// amendment — its own card from 2026-09-10 until then, and before that the
/// second block of `WeekdayCard`.
///
/// It stays out of the By weekday card for the reason it left: the seven rows
/// there are the reader's own log, which no switch gates, and the Comparisons
/// heading must not span them. What that costs is adjacency — the split does
/// not sit directly beneath the rows it is folded from — and the segment's
/// header now names the span it covers, the range the picker chose, so the
/// reader can see that it is the same range as the rows above.
///
/// Nothing is recomputed, subtracted or ranked. The table's two published
/// denominators stay printed — "7 of 12" beside "31 of every 100" — so the two
/// remain visibly different kinds of figure; what is new since the 2026-09-23
/// amendment is a bar under each, every one its figure's share of its own
/// days over a track that is all of them, so all four are on one scale. The user's own counts are rounded and
/// tabular; the published rates stay in default SF (PRD invariant 10 allows no
/// second hue for "your fact" against "a published fact", and the bars' accent
/// and secondary ink never carry it alone — every bar sits in a labelled row).
struct WeekendComparison: View {
  let split: WeekendSplit
  let reference: WeekendReference
  /// The range the split covers — the Trends picker's — named in the header.
  let range: TrendRange

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The row labels' column, shared in value with the drinking-days segment so
  /// the two segments' bars start on one edge.
  @ScaledMetric(relativeTo: .subheadline) private var labelWidth = ComparisonRowLabel.defaultWidth

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      // Titled by its measure, not by its switch (owner's review, 2026-09-10):
      // the Settings switch keeps "Weekend and weekdays", and ADR-0038's
      // amendment records the exception.
      ComparisonSegmentHeader(title: "Days with a drink", span: Text(PopulationReferenceCopy.rangeTitle(range)))

      if ComparisonTable.folds(dynamicTypeSize) {
        stackedComparison
      } else {
        comparisonBars
      }

      SourceDisclosure(sources: PopulationReferenceCopy.weekdaySource) {
        Text(PopulationReferenceCopy.weekendNote)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Two columns on the paper's own definition of the weekend, two rows for
  /// whose figure it is — the table the segment has always been, turned so
  /// that each column's two bars sit one above the other and are read against
  /// each other directly. Rows and columns swapped for width: the row labels
  /// are now "Your log" and "US adults", short enough to leave each column the
  /// room "31 of every 100" needs on a 375pt screen (92.4pt of 103.5).
  private var comparisonBars: some View {
    let lengths = split.sharesOfDays(beside: reference)

    return VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      // The heads may break onto two lines ("MONDAY TO / THURSDAY" is 141.9pt
      // at the default size); bottom-aligned, so a one-line head sits on the
      // same line as the second line of the other, over its column.
      HStack(alignment: .bottom, spacing: GlassTokens.Spacing.regular) {
        Color.clear.frame(width: labelWidth, height: 0)
        ComparisonTable.leadingColumnHead(Text("Friday to Sunday"))
        ComparisonTable.leadingColumnHead(Text("Monday to Thursday"))
      }

      HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.regular) {
        ComparisonRowLabel("Your log", width: labelWidth)
        ComparisonBarCell(length: lengths[0], isReaders: true) {
          ComparisonTable.ratioCell(split.weekendDaysWithDrinks, of: split.weekendDays)
        }
        ComparisonBarCell(length: lengths[2], isReaders: true) {
          ComparisonTable.ratioCell(split.otherDaysWithDrinks, of: split.otherDays)
        }
      }

      HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.regular) {
        ComparisonRowLabel("US adults", width: labelWidth)
        ComparisonBarCell(length: lengths[1], isReaders: false) {
          publishedRate(reference.displayedWeekendPer100Days)
        }
        ComparisonBarCell(length: lengths[3], isReaders: false) {
          publishedRate(reference.displayedOtherPer100Days)
        }
      }
    }
    // One element, speaking the three reviewed sentences the rows are the
    // parts of — the same views the accessibility sizes draw, so nothing a
    // screen reader hears is newly worded.
    .accessibilityRepresentation {
      stackedComparison
        .accessibilityElement(children: .combine)
    }
  }

  /// Default SF, deliberately: a published rate is not a numeral the user
  /// made, and the rounded face is reserved for the ones that are.
  private func publishedRate(_ per100: Int) -> some View {
    Text("\(per100) of every 100")
      .font(.footnote)
      .foregroundStyle(.secondaryInk)
  }

  /// The three sentences as they were reviewed, for the sizes above the
  /// default, and for VoiceOver at every size.
  private var stackedComparison: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      Text(PopulationReferenceCopy.weekendLine(split))
      Text(PopulationReferenceCopy.weekdaysLine(split))
      Text(PopulationReferenceCopy.weekendReferenceLine(reference))
    }
    .font(.body)
    .foregroundStyle(.primary)
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
