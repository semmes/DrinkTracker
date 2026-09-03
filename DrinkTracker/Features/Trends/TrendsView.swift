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
/// Tap or drag across the bars to select one (ADR-0028): the selected bar keeps
/// its accent, the rest dim, and a block under the chart reports that bar's own
/// facts — never its distance from the average line. The selection is view
/// state only: nothing about it is persisted, synced, or logged.
///
/// Tone: the average line is described as "your average", never as a target,
/// and nothing here congratulates or warns. It reports, and stops.
struct TrendsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var range: TrendRange = .week
  @Query(sort: \DrinkEntry.loggedAt, order: .reverse) private var allEntries: [DrinkEntry]
  // Read here for the first time: a zero bar has to say whether it is a day
  // recorded as no alcohol or a day with nothing logged, the distinction
  // ADR-0006 and the calendar's five-case DayIntensity exist to keep.
  @Query(sort: \AlcoholFreeDay.day, order: .forward) private var alcoholFreeDays: [AlcoholFreeDay]

  /// The raw x value the selection gesture hands back — a Date, never an index
  /// and never a `PeriodDetail` snapshot. A Date survives inserts, re-sorts,
  /// and data changes; a snapshot goes stale the moment a drink is logged.
  @State private var selectedDate: Date?

  private var calendar: Calendar { .current }

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
    // A day selected on Week would silently become a whole week on Quarter —
    // the app choosing which bucket the user meant.
    .onChange(of: range) { _, _ in selectedDate = nil }
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

  private var markedDays: Set<Date> {
    Set(alcoholFreeDays.map(\.day))
  }

  /// The subset another app's Health zero put there (ADR-0025).
  private var healthMarkedDays: Set<Date> {
    Set(alcoholFreeDays.filter(\.isImportedFromHealth).map(\.day))
  }

  /// Derived every render, never stored. A drink logged from Today, a marker
  /// arriving over CloudKit, an undo, or a region change all re-express it on
  /// the next render; a selected day that leaves a rolling window at midnight
  /// resolves to nil.
  private var selection: PeriodDetail? {
    guard let selectedDate else { return nil }
    return TrendSummary.periodDetail(
      containing: selectedDate,
      range: range,
      endingOn: Date(),
      drinks: allEntries.loggedDrinks,
      alcoholFreeDays: markedDays,
      healthMarkedDays: healthMarkedDays,
      region: settings.effectiveRegion,
      calendar: calendar
    )
  }

  private func isDimmed(_ barStart: Date) -> Bool {
    guard let selection else { return false }
    return selection.start != barStart
  }

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

        chart

        Divider().opacity(0.5)

        // The block describes the bar it sits under and moves with the card;
        // the bars never move under the finger, the cards below slide down.
        if let selection {
          PeriodDetailView(
            detail: selection,
            region: settings.effectiveRegion,
            isToday: selection.unit == .day && calendar.isDateInToday(selection.start),
            calendar: calendar,
            onClear: { selectedDate = nil }
          )
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
        } else {
          // Discoverability for a gesture with no visible affordance — the
          // calendar's own precedent. One line, one key for all four ranges.
          Text("Tip: tap or drag across the bars to see what each one holds")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .animation(.smooth(duration: 0.25), value: selection?.start)
    }
  }

  private var chart: some View {
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
          .opacity(isDimmed(period.start) ? 0.35 : 1)
        }
      } else {
        ForEach(totals) { day in
          BarMark(
            x: .value("Day", day.date, unit: .day),
            y: .value(unitNounPlural, day.standardDrinks)
          )
          .foregroundStyle(Color.accentColor.gradient)
          .cornerRadius(6)
          .opacity(isDimmed(day.date) ? 0.35 : 1)
        }
      }

      // The line matches the bars' scale: per day on daily charts, per
      // completed week/month on bucketed ones — a daily line under weekly
      // bars would hug the floor and read as meaningless. Never dimmed and
      // never annotated relative to the selection: the eye can compare
      // without the app putting the comparison into words.
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
    // Tap selects, drag scrubs; the domain snaps the continuous x value to
    // the bar it lands in. Only opacity changes inside the plot — no
    // annotation, no second rule, no colour (invariant 10).
    .chartXSelection(value: $selectedDate)
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
    // A tick as the selection crosses a bar, as the calendar drag does.
    .sensoryFeedback(.selection, trigger: selection?.start)
    // One adjustable VoiceOver element — the CountStepper pattern, and the
    // year view's "twelve summaries, not 365 stops" applied to bars. Swipe
    // up and down step through the bars via the same selection sighted
    // users see, so the accessible path never depends on whether a
    // double-tap on a mark reaches the selection gesture.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(chartAccessibilityLabel)
    .accessibilityValue(spokenSelection)
    .accessibilityAdjustableAction { direction in step(direction) }
    .accessibilityAction(.escape) { selectedDate = nil }
    .accessibilityAction(named: Text("Clear selection")) { selectedDate = nil }
  }

  // MARK: - Selection accessibility

  /// The selected bar, spoken: composed verbatim from parts that arrive
  /// localized (the IntensityCell precedent) — a locale date, the day-count
  /// caption, and either the amount phrase or the legend's description of a
  /// zero day.
  private var spokenSelection: Text {
    guard let selection else { return Text("No bar selected") }
    let title = PeriodDetailView.titleString(for: selection, calendar: calendar)
    let amount: String
    switch selection.dayRecord {
    case .alcoholFree?: amount = DayIntensity.alcoholFree.accessibilityDescription
    case .unlogged?: amount = DayIntensity.unlogged.accessibilityDescription
    case .drinks?, nil: amount = StandardDrink.amountPhrase(selection.standardDrinks, region: settings.effectiveRegion)
    }
    if selection.unit == .day, calendar.isDateInToday(selection.start) {
      return Text("Today, \(title), \(amount)")
    }
    var parts = [title]
    if selection.unit != .day {
      let days = selection.summary.dayCount
      parts.append(days == 1 ? String(localized: "1 day") : String(localized: "\(days) days"))
    }
    parts.append(amount)
    return Text(verbatim: parts.joined(separator: ", "))
  }

  /// Swipe up (`.increment`) moves to the next bar in time, swipe down to the
  /// previous; from nothing selected, down lands on the newest bar and up on
  /// the oldest. Ends clamp, never wrap.
  private func step(_ direction: AccessibilityAdjustmentDirection) {
    let now = Date()
    let forward = direction == .increment
    if let current = selection?.start {
      if let next = TrendSummary.adjacentBucketStart(
        from: current, direction: forward ? 1 : -1, range: range, endingOn: now, calendar: calendar
      ) {
        selectedDate = next
      }
      return
    }
    if isBucketed {
      selectedDate = forward ? buckets.first?.start : buckets.last?.start
    } else {
      selectedDate = forward ? totals.first?.date : totals.last?.date
    }
  }

  // LocalizedStringKey, not String: `Text(String)` is the *verbatim*
  // initializer, so a String-returning helper is invisible to the extractor
  // and never reaches the catalog. Returning the key type puts these literals
  // back in front of the translator (ADR-0020's step 2).
  private var chartTitle: LocalizedStringKey {
    switch range {
    case .week: "Last 7 days"
    case .month: "Last 30 days"
    case .quarter: "Last 13 weeks"
    case .year: "Last 12 months"
    }
  }

  private var averageLineLabel: LocalizedStringKey {
    switch range {
    case .week, .month: "Your average"
    case .quarter: "Your weekly average"
    case .year: "Your monthly average"
    }
  }

  /// Whole phrases with the unit interpolated, so a translation controls
  /// word order rather than inheriting English's.
  private var chartAccessibilityLabel: LocalizedStringKey {
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
      //
      // "No drinks logged", not "nothing logged": `daysWithoutDrinks` counts
      // every zero-total day, markers included, and once the block above can
      // say "Recorded as no alcohol" for such a day the old label
      // contradicted it on one screen. The new one is literally what is
      // counted (ADR-0028).
      SUCard(model: .glass) {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Text("Days with no drinks logged")
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

  private var sumLabel: LocalizedStringKey {
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
  let label: LocalizedStringKey

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
