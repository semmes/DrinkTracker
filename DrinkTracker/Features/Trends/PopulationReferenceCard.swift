import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// The population reference on Trends (1.2 spec, Feature C; ADR-0018), over
/// the window the record supports (ADR-0030) with the drinking-days
/// reference beside it (ADR-0031).
///
/// A neutral, descriptive comparison against bundled published statistics —
/// no other Tallyist users, no network, no thresholds. Renders nothing until
/// four weeks of history exist (below that the average is noise), and
/// nothing at all if a bundled file is missing — never a placeholder number.
/// Once the first recorded fact is a year old the average covers the last
/// twelve months, and the note says which.
struct PopulationReferenceCard: View {
  @Environment(AppSettings.self) private var settings

  @Query(sort: \DrinkEntry.loggedAt, order: .forward) private var entries: [DrinkEntry]
  @Query(sort: \AlcoholFreeDay.day, order: .forward) private var freeDays: [AlcoholFreeDay]

  private var calendar: Calendar { .current }

  var body: some View {
    let now = Date()
    if let reference = PopulationReference.bundled,
      let window = PopulationReference.window(firstRecord: firstRecord, now: now) {
      card(reference, window: window, now: now)
    }
  }

  /// The first recorded fact — an entry or an alcohol-free marker.
  private var firstRecord: Date? {
    [entries.first?.loggedAt, freeDays.first?.day].compactMap { $0 }.min()
  }

  private func card(_ reference: PopulationReference, window: PopulationReference.Window, now: Date) -> some View {
    let region = settings.effectiveRegion
    let drinks = entries.loggedDrinks
    let units = PopulationReference.weeklyAverage(drinks, window: window, endingAt: now, region: region)
    let grams = units * region.gramsPureAlcoholPerStandardDrink
    let comparison = reference.comparison(gramsPerWeek: grams)
    let frequency = FrequencyReference.bundled
    let drinkingDays = FrequencyReference.drinkingDays(in: drinks, last: window.days, endingOn: now, calendar: calendar)

    return SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        Text(units > 0 ? PopulationReferenceCopy.averageLine(units, region: region) : PopulationReferenceCopy.noDrinks(in: window))
          .font(.body)
          .foregroundStyle(.primary)

        if let comparison {
          Text(PopulationReferenceCopy.comparisonLine(comparison))
            .font(.body)
            .foregroundStyle(.primary)
        }

        // The second figure: days, beside the survey's mean of days. Two
        // numbers and no percentile — a mean is all the source publishes.
        if let frequency {
          Text(PopulationReferenceCopy.drinkingDaysLine(drinkingDays, of: window.days))
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.top, GlassTokens.Spacing.tight)
          Text(PopulationReferenceCopy.drinkingDaysReferenceLine(frequency, windowDays: window.days))
            .font(.body)
            .foregroundStyle(.primary)
        }

        SourceDisclosure(sources: frequency == nil ? PopulationReferenceCopy.yearSource : PopulationReferenceCopy.trendsSources) {
          Text(PopulationReferenceCopy.explainer)
          Text(PopulationReferenceCopy.windowNote(window))
          if frequency != nil {
            Text(PopulationReferenceCopy.drinkingDaysNote)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
