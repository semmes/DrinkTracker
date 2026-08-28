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
            label: summary.daysWithDrinks == 1 ? "day with drinks" : "days with drinks",
            spoken: summary.daysWithDrinks == 1
              ? Text("\(summary.daysWithDrinks) day with drinks")
              : Text("\(summary.daysWithDrinks) days with drinks")
          )
          figure(
            value: "\(summary.daysAlcoholFree)",
            label: summary.daysAlcoholFree == 1 ? "day with none" : "days with none",
            spoken: summary.daysAlcoholFree == 1
              ? Text("\(summary.daysAlcoholFree) day with none")
              : Text("\(summary.daysAlcoholFree) days with none")
          )
        }

        Divider().opacity(0.5)

        HStack(alignment: .top, spacing: GlassTokens.Spacing.regular) {
          figure(
            value: StandardDrink.formatted(summary.totalStandardDrinks),
            label: totalLabel
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

  /// The totals caption, as a whole phrase per region and number.
  ///
  /// It used to be `"\(region.unitNamePlural) total"`, which handed the noun in
  /// already inflected and always plural — so a total of exactly one read
  /// "1 standard drinks total". The two day figures above had always agreed with
  /// their number; this one simply had not been made to follow.
  private var totalLabel: LocalizedStringKey {
    let isSingular = StandardDrink.readsAsOne(summary.totalStandardDrinks)
    switch region {
    case .unitedStates, .australia:
      return isSingular ? "standard drink total" : "standard drinks total"
    case .unitedKingdom:
      return isSingular ? "unit total" : "units total"
    }
  }

  /// One figure: a large number with a caption naming it.
  ///
  /// **The captions carry no count, and that is deliberate.** A catalog key can
  /// only take plural variations if the count is inside it, so a language with
  /// more than two plural forms gets two slots here and has to pick the one that
  /// reads best. The alternative is a caption that repeats the number standing
  /// 40 points above it, or dismantling the four-figure layout ADR-0006 exists to
  /// protect. A caption under a number is doing different work from a sentence:
  /// the number carries the meaning and the caption names it. Same kind of
  /// documented limit as `Region.unitName(for:)`.
  ///
  /// `spoken` is where that trade is *not* accepted. VoiceOver fuses the number
  /// and its caption into one sentence, with no adjacency left to carry the
  /// meaning, so the two whole-number figures pass a single key holding the count
  /// — genuinely pluralisable. The fractional figures pass nil: their value
  /// reaches the catalog as `%@`, which no plural rule can select on, so a
  /// separate key there would add nothing but another string to translate.
  @ViewBuilder
  private func figure(
    value: String,
    label: LocalizedStringKey,
    spoken: Text? = nil
  ) -> some View {
    let figure = VStack(alignment: .leading, spacing: 2) {
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

    if let spoken {
      figure.accessibilityLabel(spoken)
    } else {
      figure
    }
  }
}
