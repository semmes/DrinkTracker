import Charts
import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Trends across four ranges: rolling 7- and 30-day windows with daily bars,
/// and calendar-bucketed quarter (13 weeks) and year (12 months) views.
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
        PopulationReferenceCard()
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

  /// Chart bars for the bucketed ranges — weekly for quarter, monthly for year.
  private var buckets: [PeriodTotal] {
    TrendSummary.bucketed(totals, by: range.bucket)
  }

  /// The average line's value on bucketed charts: mean per completed bucket,
  /// nil while no bucket is complete (no line beats a misleading one).
  private var bucketAverage: Double? {
    TrendSummary.bucketAverage(buckets, unit: range.bucket)
  }

  private var isBucketed: Bool { range.bucket != .day }

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
        Text(chartTitle)
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)

        Chart {
          if isBucketed {
            // A bar per calendar week or month. Daily bars past ~30 days are
            // noise; the trailing bucket is simply "so far", like the current
            // month in the year calendar.
            ForEach(buckets) { period in
              BarMark(
                x: .value("Period", period.start, unit: range.bucket),
                y: .value(unitNounPlural, period.standardDrinks)
              )
              .foregroundStyle(Color.accentColor.gradient)
              .cornerRadius(6)
            }
          } else {
            ForEach(totals) { day in
              BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value(unitNounPlural, day.standardDrinks)
              )
              .foregroundStyle(Color.accentColor.gradient)
              .cornerRadius(6)
            }
          }

          // The line matches the bars' scale: per day on daily charts, per
          // completed week/month on bucketed ones — a daily line under weekly
          // bars would hug the floor and read as meaningless.
          if let lineValue = isBucketed ? bucketAverage : (average > 0 ? average : nil),
            lineValue > 0 {
            RuleMark(y: .value("Average", lineValue))
              .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
              .foregroundStyle(.secondary)
              .annotation(position: .top, alignment: .leading) {
                Text(averageLineLabel)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
          }
        }
        .chartYAxis {
          AxisMarks(position: .leading)
        }
        .chartXAxis {
          switch range {
          case .week:
            AxisMarks(values: .stride(by: .day, count: 1)) { _ in
              AxisGridLine()
              AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
          case .month:
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
              AxisGridLine()
              AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
          case .quarter:
            AxisMarks(values: .stride(by: .month, count: 1)) { _ in
              AxisGridLine()
              AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
          case .year:
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
              AxisGridLine()
              AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
          }
        }
        .frame(height: GlassTokens.Layout.chartHeight)
        .accessibilityLabel(chartAccessibilityLabel)
      }
    }
  }

  private var chartTitle: String {
    switch range {
    case .week: "Last 7 days"
    case .month: "Last 30 days"
    case .quarter: "Last 13 weeks"
    case .year: "Last 12 months"
    }
  }

  private var averageLineLabel: String {
    switch range {
    case .week, .month: "Your average"
    case .quarter: "Your weekly average"
    case .year: "Your monthly average"
    }
  }

  private var chartAccessibilityLabel: String {
    switch range {
    case .week, .month: "\(unitNounPlural) per day"
    case .quarter: "\(unitNounPlural) per week"
    case .year: "\(unitNounPlural) per month"
    }
  }

  // MARK: - Summary cards

  private var summaryCards: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      HStack(spacing: GlassTokens.Spacing.regular) {
        StatCard(
          value: StandardDrink.formatted(periodSum),
          label: sumLabel
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

  private var sumLabel: String {
    switch range {
    case .week: "this week"
    case .month: "this month"
    case .quarter: "last 13 weeks"
    case .year: "last 12 months"
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
