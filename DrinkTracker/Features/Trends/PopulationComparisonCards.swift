import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The two population comparisons on Trends, one card each (1.2 spec Feature C
/// and ADR-0018, over the window the record supports — ADR-0030 — with the
/// drinking-days reference beside it — ADR-0031).
///
/// They were one card until ADR-0038's 2026-09-10 amendment, sharing a source
/// line whose wording was a function of which switches were on. Now each
/// carries the title of the switch that shows it and names, once, the one body
/// of work behind it. Neither card knows about a switch: `ComparisonsSection`
/// resolves all three gates and renders only what is shown, so a title can
/// never head a comparison that is not there.
///
/// Neutral, descriptive comparisons against bundled published statistics — no
/// other Tallyist users, no network, no thresholds.

// MARK: - Weekly average

/// The reader's weekly average against the survey's distribution, in whichever
/// of its columns Settings chose — the total unless told otherwise (ADR-0039).
/// The sentence and the note both name that column.
struct WeeklyAverageCard: View {
  let reference: PopulationReference
  let window: PopulationReference.Window
  let drinks: [LoggedDrink]
  let region: Region
  let column: PopulationReference.Column
  let now: Date
  let calendar: Calendar

  var body: some View {
    // Compared in grams, so the region lens cannot skew the bracket.
    let units = PopulationReference.weeklyAverage(
      drinks, window: window, endingAt: now, region: region, calendar: calendar
    )
    let grams = units * region.gramsPureAlcoholPerStandardDrink
    let comparison = reference.comparison(gramsPerWeek: grams, in: column)

    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        CardTitle("Weekly average")

        Text(units > 0
          ? PopulationReferenceCopy.averageLine(units, region: region)
          : PopulationReferenceCopy.noDrinks(in: window))
          .font(.body)
          .foregroundStyle(.primary)

        if let comparison {
          Text(PopulationReferenceCopy.comparisonLine(comparison, in: column))
            .font(.body)
            .foregroundStyle(.primary)
        }

        // The same source line the year view reads, from the same constant, so
        // the two surfaces cannot drift.
        SourceDisclosure(sources: PopulationReferenceCopy.surveySource) {
          Text(PopulationReferenceCopy.explainer(in: column, drinkersPercent: reference.drinkersPercent(in: column)))
          Text(PopulationReferenceCopy.windowNote(window))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Drinking days

/// How many of the window's days had a drink, beside a published mean. Two
/// counts and no percentile — a mean is all the source publishes (ADR-0031).
struct DrinkingDaysCard: View {
  let frequency: FrequencyReference
  let window: PopulationReference.Window
  let drinks: [LoggedDrink]
  let now: Date
  let calendar: Calendar

  var body: some View {
    let drinkingDays = FrequencyReference.drinkingDays(
      in: drinks, last: window.days, endingOn: now, calendar: calendar
    )

    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        CardTitle("Drinking days")

        Text(PopulationReferenceCopy.drinkingDaysLine(drinkingDays, of: window.days))
          .font(.body)
          .foregroundStyle(.primary)

        Text(PopulationReferenceCopy.drinkingDaysReferenceLine(frequency, windowDays: window.days))
          .font(.body)
          .foregroundStyle(.primary)

        SourceDisclosure(sources: PopulationReferenceCopy.daysSource) {
          Text(PopulationReferenceCopy.drinkingDaysNote)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
