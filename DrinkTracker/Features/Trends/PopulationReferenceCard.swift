import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// The population reference line on Trends (1.2 spec, Feature C; ADR-0018).
///
/// A neutral, descriptive comparison against a bundled published statistic —
/// no other Tallyist users, no network, no thresholds. Renders nothing until
/// four weeks of history exist (below that the average is noise), and
/// nothing at all if the bundled file is missing — never a placeholder
/// number.
///
/// Copy rules from the spec, kept literally: "lower than", never "better
/// than"; no congratulation and no warning in either direction; source and
/// year always visible; the expanded note says what this is and is not.
struct PopulationReferenceCard: View {
  @Environment(AppSettings.self) private var settings

  @Query(sort: \DrinkEntry.loggedAt, order: .forward) private var entries: [DrinkEntry]
  @Query(sort: \AlcoholFreeDay.day, order: .forward) private var freeDays: [AlcoholFreeDay]

  @State private var isExpanded = false

  var body: some View {
    if let reference = PopulationReference.bundled, hasFourWeeksOfHistory {
      card(reference)
    }
  }

  // MARK: - Gate

  /// The first recorded fact — an entry or an alcohol-free marker — must be
  /// at least four weeks old.
  private var hasFourWeeksOfHistory: Bool {
    let firstEntry = entries.first?.loggedAt
    let firstMarker = freeDays.first?.day
    let first = [firstEntry, firstMarker].compactMap { $0 }.min()
    guard let first else { return false }
    return Date().timeIntervalSince(first) >= PopulationReference.minimumHistory
  }

  // MARK: - Numbers

  /// Average per week over the last four weeks, in the current region's units.
  private var unitsPerWeek: Double {
    let cutoff = Date().addingTimeInterval(-PopulationReference.minimumHistory)
    let region = settings.effectiveRegion
    let total = entries
      .filter { $0.loggedAt >= cutoff }
      .reduce(0.0) { $0 + $1.logged.standardDrinks(in: region) }
    return total / 4
  }

  // MARK: - Card

  private func card(_ reference: PopulationReference) -> some View {
    let units = unitsPerWeek
    let grams = units * settings.effectiveRegion.gramsPureAlcoholPerStandardDrink
    let comparison = reference.comparison(gramsPerWeek: grams)

    return SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        Text(averageLine(units))
          .font(.body)
          .foregroundStyle(.primary)

        if let comparison {
          Text(comparisonLine(comparison))
            .font(.body)
            .foregroundStyle(.primary)
        }

        // A Button, not onTapGesture on the card: gestures on glass-backed
        // containers get swallowed (the session-pace toggle taught the same
        // lesson); real buttons receive their taps.
        Button {
          withAnimation(.smooth(duration: 0.25)) { isExpanded.toggle() }
        } label: {
          HStack(spacing: GlassTokens.Spacing.tight) {
            Text("Source: Alcohol Research Group, 2020 National Alcohol Survey")
              .font(.caption)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "chevron.down")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
              .rotationEffect(.degrees(isExpanded ? 180 : 0))
          }
          .contentShape(.rect)
          .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Source: Alcohol Research Group, 2020 National Alcohol Survey")
        .accessibilityHint("Explains this comparison")

        if isExpanded {
          Text("A published population statistic, not data from other Tallyist users — nothing about your log leaves this device. Percentages come from the survey's distribution of weekly drinks among US adults, recalculated to cover only the 72% who reported drinking, and compared by grams of alcohol. Your average covers your last 4 weeks.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // These return LocalizedStringKey rather than String so the sentences reach
  // the string catalog: Text(someString) uses the verbatim initializer, and a
  // translated sentence also needs to be free to reorder the interpolations.
  private func averageLine(_ units: Double) -> LocalizedStringKey {
    guard units > 0 else { return "No drinks in the last 4 weeks." }
    let region = settings.effectiveRegion
    return "Your average is about \(StandardDrink.formatted(units)) \(region.unitName(for: units)) a week."
  }

  private func comparisonLine(_ comparison: PopulationReference.Comparison) -> LocalizedStringKey {
    switch comparison {
    case .lowerThan(let percent):
      "That's lower than roughly \(percent)% of US adults who drink."
    case .moreThan(let percent):
      "That's more than roughly \(percent)% of US adults who drink."
    }
  }
}
