import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The population comparison for a year that has ended (ADR-0030): the
/// year's weekly average — its total over its weeks, from the same summary
/// the card above shows — against the same bundled distribution, by the same
/// bracket rule, in the same words. In the app only: no share card carries
/// it (ADR-0018's stop condition, ADR-0027's rule).
///
/// It follows the Trends card's own switch and column (ADR-0038, ADR-0039):
/// a reader who turned the weekly-average comparison off sees no year
/// comparison either, and one who chose the men's or women's column reads
/// the year against it, with the note naming which.
struct YearComparisonCard: View {
  let year: Int
  let summary: RecentSummary
  let region: Region

  @Environment(AppSettings.self) private var settings

  var body: some View {
    if settings.showsWeeklyAverageComparison, let reference = PopulationReference.bundled {
      let column = settings.comparisonColumn
      let units = PopulationReference.weeklyAverage(of: summary)
      let comparison = reference.comparison(gramsPerWeek: units * region.gramsPureAlcoholPerStandardDrink, in: column)
      SUCard(model: .glass) {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Text(units > 0 ? PopulationReferenceCopy.yearAverageLine(units, year: year, region: region) : PopulationReferenceCopy.noDrinks(inYear: year))
            .font(.body)
            .foregroundStyle(.primary)

          if let comparison {
            Text(PopulationReferenceCopy.comparisonLine(comparison, in: column))
              .font(.body)
              .foregroundStyle(.primary)
          }

          SourceDisclosure(sources: PopulationReferenceCopy.yearSource) {
            Text(PopulationReferenceCopy.explainer(in: column, drinkersPercent: reference.drinkersPercent(in: column)))
            Text(PopulationReferenceCopy.yearWindowNote(year))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}
