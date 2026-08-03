import Charts
import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Weekly / monthly trends.
///
/// The chart is real Swift Charts — `BarMark` plus a dashed `RuleMark` for the
/// average — deliberately staying inside the mark set Swift Charts renders well
/// natively. The surrounding KPI cards and progress bars are ComponentsKit,
/// themed to sit inside the same Liquid Glass material as everything else.
///
/// Tone: the average line is described as "your average", never as a target,
/// and nothing here congratulates or warns. It reports, and stops.
struct TrendsView: View {
  @Environment(AppSettings.self) private var settings

  @State private var range: TrendRange = .week
  @Query(sort: \DrinkEntry.loggedAt, order: .reverse) private var allEntries: [DrinkEntry]

  var body: some View {
    ScrollView {
      VStack(spacing: GlassTokens.Spacing.section) {
        rangePicker
        chartCard
        summaryCards
      }
      .screenMargin()
      .padding(.vertical, GlassTokens.Spacing.section)
    }
    .navigationTitle("Trends")
    .navigationBarTitleDisplayMode(.large)
  }

  // MARK: - Data

  private var totals: [DayTotal] {
    TrendSummary.dailyTotals(
      range: range,
      endingOn: Date(),
      drinks: allEntries.loggedDrinks,
      region: settings.effectiveRegion
    )
  }

  private var average: Double { TrendSummary.dailyAverage(totals) }
  private var periodSum: Double { TrendSummary.sum(totals) }
  private var restDays: Int { TrendSummary.daysWithoutDrinks(totals) }

  // MARK: - Range picker

  private var rangePicker: some View {
    SUSegmentedControl(
      selectedId: $range,
      model: SegmentedControlVM<TrendRange> {
        $0.items = TrendRange.allCases.map { range in
          SegmentedControlItemVM(id: range) { $0.title = range.title }
        }
        $0.isFullWidth = true
        $0.size = .medium
        $0.color = .accent
      }
    )
  }

  // MARK: - Chart

  private var chartCard: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        Text(range == .week ? "Last 7 days" : "Last 30 days")
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)

        Chart {
          ForEach(totals) { day in
            BarMark(
              x: .value("Day", day.date, unit: .day),
              y: .value(unitNounPlural, day.standardDrinks)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(6)
          }

          if average > 0 {
            RuleMark(y: .value("Average", average))
              .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
              .foregroundStyle(.secondary)
              .annotation(position: .top, alignment: .leading) {
                Text("Your average")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
          }
        }
        .chartYAxis {
          AxisMarks(position: .leading)
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { value in
            AxisGridLine()
            AxisValueLabel(format: range == .week
              ? .dateTime.weekday(.narrow)
              : .dateTime.month(.abbreviated).day())
          }
        }
        .frame(height: GlassTokens.Layout.chartHeight)
        .accessibilityLabel("\(unitNounPlural) per day")
      }
    }
  }

  // MARK: - Summary cards

  private var summaryCards: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      HStack(spacing: GlassTokens.Spacing.regular) {
        StatCard(
          value: StandardDrink.formatted(periodSum),
          label: range == .week ? "this week" : "this month"
        )
        StatCard(
          value: StandardDrink.formatted(average),
          label: "per day on average"
        )
      }

      // No progress bar here, deliberately.
      //
      // It used to carry one, filling as the count rose toward the whole period.
      // A bar that fills has a full state, a full state is a target, and a target
      // for "days you didn't drink" is a goal — which is the thing this app says
      // in its own About screen that it doesn't do. The count says everything the
      // bar said, without implying a direction to move in.
      SUCard(model: .glass) {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Text("Days with nothing logged")
            .font(GlassTokens.Typography.cardLabel)
            .foregroundStyle(.secondary)

          Text("\(restDays) of \(totals.count)")
            .font(GlassTokens.Typography.cardValue)
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      }
    }
  }

  private var unitNounPlural: String {
    settings.effectiveRegion.unitNamePlural
  }
}

/// A single KPI figure. Neutral by construction: a number and a noun, no verdict.
private struct StatCard: View {
  let value: String
  let label: String

  var body: some View {
    SUCard(model: .glass) {
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
    }
    .accessibilityElement(children: .combine)
  }
}
