import DrinkTrackerCore
import SwiftUI

/// The two population comparisons on Trends, as segments of the one
/// Comparisons card (1.2 spec Feature C and ADR-0018, with the drinking-days
/// reference beside it — ADR-0031), over the range the picker chose: the
/// days the chart card's header folds, cut at the first record while the log
/// is younger than the range (ADR-0058, which retired ADR-0030's window of 28
/// days and then 364). Both read the fold `TrendsView` already made, so their
/// figures are the header's figures.
///
/// They were one card until ADR-0038's 2026-09-10 amendment split them — a
/// source line whose wording depended on which switches were on was the sign
/// that the card held two things — and one card per comparison until its
/// 2026-09-23 amendment, when the owner asked for the three to sit in a single
/// card segmented by their titles: the reopen that amendment's "How to reopen"
/// had already named, "one card with three headlined blocks and dividers". Each
/// segment still carries the title of the switch that shows it and names, once,
/// the one body of work behind it; `ComparisonsSection` resolves the gates and
/// draws the dividers, so a segment never knows about a switch.
///
/// At the default sizes the weekly average sets its figure large over its
/// sentence, and the drinking days draw their two counts as bars
/// (`ComparisonCardParts`); from `.xLarge` up — the threshold both of Trends'
/// tables fold at — each shows the reviewed sentences instead, and those
/// sentences are what VoiceOver reads at every size, so nothing a reader hears
/// or sees at a large size is newly worded.
///
/// Neutral, descriptive comparisons against bundled published statistics — no
/// other Tallyist users, no network, no thresholds.

// MARK: - Weekly average

/// The reader's weekly average against the survey's distribution, in whichever
/// of its columns Settings chose — the total unless told otherwise (ADR-0039).
/// The sentence and the note both name that column.
struct WeeklyAverageComparison: View {
  let reference: PopulationReference
  /// The window's figures — the chart card's own fold (ADR-0058).
  let fold: TrendWindowFold
  let region: Region
  let column: PopulationReference.Column
  /// Whether another segment follows, below a rule an open note must not sit on.
  var isFollowed = false

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var window: TrendWindow { fold.window }

  var body: some View {
    // The window's total over its weeks — the number the Quarter line's legend
    // prints, and seven times the per-day average before rounding — compared
    // in grams, so the region lens cannot skew the bracket. At Week it is the
    // week's own total.
    let units = fold.weeklyFigure
    let grams = units * region.gramsPureAlcoholPerStandardDrink
    let comparison = reference.comparison(gramsPerWeek: grams, in: column)

    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      ComparisonSegmentHeader(title: "Weekly average", span: PopulationReferenceCopy.spanTitle(window))

      if units <= 0 {
        // Nothing to draw and nothing to compare: the absence, stated.
        Text(PopulationReferenceCopy.noDrinks(in: window))
          .font(isFolded ? .body : .subheadline)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
      } else if isFolded {
        sentences(units: units, comparison: comparison)
      } else {
        compact(units: units, comparison: comparison)
      }

      // The same source line the year view reads, from the same constant, so
      // the two surfaces cannot drift.
      SourceDisclosure(
        sources: PopulationReferenceCopy.surveySource,
        openNoteInset: isFollowed ? SegmentDivider.gapAbove : 0
      ) {
        Text(PopulationReferenceCopy.explainer(
          in: column,
          drinkersPercent: reference.drinkersPercent(in: column),
          isWeekTotal: PopulationReferenceCopy.isWeekTotal(window)
        ))
        Text(PopulationReferenceCopy.windowNote(window))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var isFolded: Bool { ComparisonTable.folds(dynamicTypeSize) }

  /// The figure and the sentence that places it — no drawing: the twenty
  /// figures this segment first drew for the sentence's share were removed at
  /// the owner's review (2026-09-23), and the sentence says the share itself.
  /// One VoiceOver stop, speaking the two reviewed sentences the accessibility
  /// sizes show.
  private func compact(units: Double, comparison: PopulationReference.Comparison?) -> some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      PopulationReferenceCopy.averageFigure(units, region: region)
        .font(.subheadline)
        .foregroundStyle(.secondaryInk)

      if let comparison {
        Text(PopulationReferenceCopy.comparisonLine(comparison, in: column))
          .font(.subheadline)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    // One stop, speaking the two reviewed sentences — the same views the
    // accessibility sizes draw, so what is heard is never newly worded.
    .accessibilityRepresentation {
      sentences(units: units, comparison: comparison)
        .accessibilityElement(children: .combine)
    }
  }

  /// The two sentences as they were reviewed, for the sizes above the
  /// default, and for VoiceOver at every size. At Week the first is the
  /// week's total, because seven days are not averaged (ADR-0058).
  private func sentences(units: Double, comparison: PopulationReference.Comparison?) -> some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      Text(PopulationReferenceCopy.weeklyLine(units, window: window, region: region))
      if let comparison {
        Text(PopulationReferenceCopy.comparisonLine(comparison, in: column))
      }
    }
    .font(.body)
    .foregroundStyle(.primary)
    .fixedSize(horizontal: false, vertical: true)
  }
}

// MARK: - Drinking days

/// How many of the window's days had a drink, beside a published mean. Two
/// counts and no percentile — a mean is all the source publishes (ADR-0031) —
/// drawn as two bars, each its count's share of the window's days over a
/// track that is all of them (`ComparisonFigures` says why). The reader's
/// count is the chart card header's own "days with drinks" (ADR-0058).
struct DrinkingDaysComparison: View {
  let frequency: FrequencyReference
  /// The window's figures — the chart card's own fold (ADR-0058).
  let fold: TrendWindowFold
  /// Whether another segment follows, below a rule an open note must not sit on.
  var isFollowed = false

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The row labels' column, shared in value with the weekend segment so the
  /// two segments' bars start on one edge.
  @ScaledMetric(relativeTo: .subheadline) private var labelWidth = ComparisonRowLabel.defaultWidth

  /// Every count here is out of the window's days.
  private var windowDays: Int { fold.window.dayCount }

  var body: some View {
    let drinkingDays = fold.summary.daysWithDrinks
    let referenceDays = frequency.displayedDrinkingDays(per: windowDays)

    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      ComparisonSegmentHeader(title: "Drinking days", span: PopulationReferenceCopy.spanTitle(fold.window))

      if ComparisonTable.folds(dynamicTypeSize) {
        sentences(drinkingDays: drinkingDays)
      } else {
        bars(drinkingDays: drinkingDays, referenceDays: referenceDays)
      }

      SourceDisclosure(
        sources: PopulationReferenceCopy.daysSource,
        openNoteInset: isFollowed ? SegmentDivider.gapAbove : 0
      ) {
        Text(PopulationReferenceCopy.drinkingDaysNote)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Two rows, each whose figure it is, the figure, and its bar. The reader's
  /// count is the header's own days with drinks out of the window's days, "46
  /// of 88"; the published row reads as the
  /// reviewed sentence split at its verb — "US adults who drink" / "average
  /// about 21 in 88".
  private func bars(drinkingDays: Int, referenceDays: Int) -> some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.regular) {
        ComparisonRowLabel("Your log", width: labelWidth)
        ComparisonBarCell(length: ComparisonBars.share(drinkingDays, of: windowDays), isReaders: true) {
          ComparisonTable.ratioCell(drinkingDays, of: windowDays)
        }
      }

      HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.regular) {
        ComparisonRowLabel("US adults who drink", width: labelWidth)
        ComparisonBarCell(length: ComparisonBars.share(referenceDays, of: windowDays), isReaders: false) {
          // Default SF, deliberately: a published figure is not a numeral the
          // reader made, and the rounded face is reserved for the ones that are.
          Text(PopulationReferenceCopy.drinkingDaysReferenceFigure(frequency, windowDays: windowDays))
            .font(.footnote)
            .foregroundStyle(.secondaryInk)
        }
      }
    }
    // One element, speaking the two reviewed sentences the rows are made from.
    .accessibilityRepresentation {
      sentences(drinkingDays: drinkingDays)
        .accessibilityElement(children: .combine)
    }
  }

  /// The two sentences as they were reviewed, for the sizes the bars do not
  /// fit, and for VoiceOver at every size.
  private func sentences(drinkingDays: Int) -> some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      Text(PopulationReferenceCopy.drinkingDaysLine(drinkingDays, of: windowDays))
      Text(PopulationReferenceCopy.drinkingDaysReferenceLine(frequency, windowDays: windowDays))
    }
    .font(.body)
    .foregroundStyle(.primary)
    .fixedSize(horizontal: false, vertical: true)
  }
}
