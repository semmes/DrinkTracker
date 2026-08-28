import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The last 30 days, as facts.
///
/// This is where a competitor puts a "sobriety score". It deliberately isn't one.
/// A single composite number is a number that goes up and down, which makes it a
/// target; and the cheapest way to protect a target is to stop logging, which
/// destroys the only thing this app actually offers. See ADR-0006.
///
/// So: four independent figures, each checkable against the log, none combined into
/// a verdict. No arrow, no delta against last month, no colour that grades them.
struct RecentSummaryCard: View {
  let summary: RecentSummary
  let region: Region

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        Text("Last \(summary.dayCount) days")
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)

        HStack(alignment: .top, spacing: GlassTokens.Spacing.regular) {
          figure(
            value: "\(summary.daysWithDrinks)",
            label: summary.daysWithDrinks == 1 ? "day with drinks" : "days with drinks"
          )
          figure(
            value: "\(summary.daysAlcoholFree)",
            label: summary.daysAlcoholFree == 1 ? "day with none" : "days with none"
          )
        }

        Divider().opacity(0.5)

        HStack(alignment: .top, spacing: GlassTokens.Spacing.regular) {
          figure(
            value: StandardDrink.formatted(summary.totalStandardDrinks),
            label: "\(unitNoun) total"
          )
          figure(
            value: StandardDrink.formatted(summary.averageOnDrinkingDays),
            label: "on days you drank"
          )
        }

        if summary.daysUnlogged > 0 {
          // Named rather than hidden. Without it the two day-counts look like they
          // should add to 30, and a reader would reasonably assume the difference
          // was alcohol-free rather than unrecorded.
          Text(
            summary.daysUnlogged == 1
              ? "\(summary.daysUnlogged) day has nothing logged either way."
              : "\(summary.daysUnlogged) days have nothing logged either way."
          )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var unitNoun: String {
    region.unitNamePlural
  }

  private func figure(value: String, label: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(GlassTokens.Typography.cardValue)
        .foregroundStyle(.primary)
      Text(label)
        .font(GlassTokens.Typography.cardLabel)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}
