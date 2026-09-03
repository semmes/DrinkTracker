import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// A window of days, as facts: the last 30, the month shown, or the year shown
/// (ADR-0026). "Recent" predates the choice of window.
///
/// This is where a competitor puts a "sobriety score". It deliberately isn't one.
/// A single composite number is a number that goes up and down, which makes it a
/// target; and the cheapest way to protect a target is to stop logging, which
/// destroys the only thing this app actually offers. See ADR-0006.
///
/// So: four independent figures, each checkable against the log, none combined into
/// a verdict. No arrow, no delta against another window, no colour that grades them.
struct RecentSummaryCard: View {
  let summary: RecentSummary
  let region: Region
  let heading: SummaryHeading

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        titleRow
        RecentSummaryFigures(summary: summary, region: region)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      // The window changed, not the value: the figures crossfade. Never a
      // digit roll — a roll from 27 down to 1 draws a direction between two
      // windows, which is the delta ADR-0006 forbids (design-system §5).
      .animation(.smooth(duration: 0.25), value: summary)
    }
  }

  /// The window's name, with its day count beside it for the month and year
  /// windows. One VoiceOver element: "September 2026, through today, 2 days".
  private var titleRow: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline) {
        title
        Spacer(minLength: GlassTokens.Spacing.regular)
        dayCount
      }
      VStack(alignment: .leading, spacing: 2) {
        title
        dayCount
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var title: some View {
    heading.titleText
      .font(GlassTokens.Typography.cardLabel)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var dayCount: some View {
    if heading.showsDayCount {
      Text(RecentSummaryCaptions.dayCount(summary.dayCount))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// ADR-0006's four figures plus the named unlogged count — the part of the
/// card every summarising surface shares, so the copy, the plural keys, and
/// the spoken labels cannot drift between the calendar card and anything
/// else that reports a window of days.
struct RecentSummaryFigures: View {
  let summary: RecentSummary
  let region: Region

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      HStack(alignment: .top, spacing: GlassTokens.Spacing.regular) {
        figure(
          value: "\(summary.daysWithDrinks)",
          label: RecentSummaryCaptions.daysWithDrinks(summary.daysWithDrinks),
          spoken: RecentSummaryCaptions.spokenDaysWithDrinks(summary.daysWithDrinks)
        )
        figure(
          value: "\(summary.daysAlcoholFree)",
          label: RecentSummaryCaptions.daysWithNone(summary.daysAlcoholFree),
          spoken: RecentSummaryCaptions.spokenDaysWithNone(summary.daysAlcoholFree)
        )
      }

      Divider().opacity(0.5)

      HStack(alignment: .top, spacing: GlassTokens.Spacing.regular) {
        figure(
          value: StandardDrink.formatted(summary.totalStandardDrinks),
          label: RecentSummaryCaptions.total(summary.totalStandardDrinks, region: region)
        )
        figure(
          value: RecentSummaryCaptions.averageValue(summary),
          label: RecentSummaryCaptions.averageCaption,
          spoken: summary.daysWithDrinks == 0 ? RecentSummaryCaptions.spokenNoAverage : nil
        )
      }

      if let unlogged = RecentSummaryCaptions.unlogged(summary.daysUnlogged) {
        Text(unlogged)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// One figure: a large number with a caption naming it. The captions carry
  /// no count, and the spoken forms do — see `RecentSummaryCaptions`.
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
        .contentTransition(.opacity)
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
