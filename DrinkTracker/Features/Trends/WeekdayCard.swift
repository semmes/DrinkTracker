import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The range by weekday (ADR-0032): for each day of the week, what was
/// logged on those days and how many of them had a drink. Facts about the
/// user's own log, seven rows in the calendar's order, with no rank, no
/// "most", and no external figure — ADR-0028's rule applied to weekdays.
struct WeekdayCard: View {
  let totals: [WeekdayTotal]
  let region: Region
  let calendar: Calendar

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        Text("By weekday")
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)

        ForEach(totals) { total in
          row(total)
        }

        // The user's own weekend, on the paper's definition, beside the
        // published rate — two facts about days, no rank and no threshold.
        if let reference = WeekendReference.bundled {
          let split = TrendSummary.weekendSplit(totals, weekend: reference.weekendWeekdays)
          Text(PopulationReferenceCopy.weekendLine(split))
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.top, GlassTokens.Spacing.tight)
          Text(PopulationReferenceCopy.weekdaysLine(split))
            .font(.body)
            .foregroundStyle(.primary)
          Text(PopulationReferenceCopy.weekendReferenceLine(reference))
            .font(.body)
            .foregroundStyle(.primary)

          SourceDisclosure(sources: PopulationReferenceCopy.weekdaySource) {
            Text(PopulationReferenceCopy.weekendNote)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Name leading, the two figures stacked on the trailing edge so the
  /// amount phrase keeps its line at every type size; the row reads as one
  /// VoiceOver element.
  private func row(_ total: WeekdayTotal) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.regular) {
      Text(verbatim: calendar.weekdaySymbols[total.weekday - 1])
        .font(.body)
        .foregroundStyle(.primary)
      Spacer(minLength: GlassTokens.Spacing.tight)
      VStack(alignment: .trailing, spacing: 2) {
        // The package's own amount phrase: the noun follows the displayed digits.
        Text(verbatim: StandardDrink.amountPhrase(total.standardDrinks, region: region))
          .font(.body)
          .foregroundStyle(.primary)
        Text(daysLine(total))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.trailing)
    }
    .accessibilityElement(children: .combine)
  }

  /// "4 of 4 days" — how many of this weekday's days had a drink. One key
  /// per plural of the second count, chosen on the displayed integer.
  private func daysLine(_ total: WeekdayTotal) -> LocalizedStringKey {
    total.dayCount == 1
      ? "\(total.daysWithDrinks) of 1 day"
      : "\(total.daysWithDrinks) of \(total.dayCount) days"
  }
}
