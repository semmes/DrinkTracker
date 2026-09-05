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
  @Environment(\.scenePhase) private var scenePhase

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

  /// The clock the chart is drawn against, refreshed on the day-change
  /// notification and on every foregrounding (the calendar's pattern,
  /// ADR-0026). Read for the range's end, the selected bar, and "Today", so
  /// a screen left open across midnight moves its window, re-resolves its
  /// selection, and drops a stale "Today" together.
  @State private var today = Date()

  private var calendar: Calendar { .current }

  var body: some View {
    // Everything a render needs, derived once. The selection in particular
    // is a pass over the whole log; deriving it per bar (once for every
    // dimming decision) would multiply that by the bar count on every frame
    // of a scrub.
    let snapshot = snapshot()

    ScrollView {
      VStack(spacing: GlassTokens.Spacing.section) {
        rangePicker
        chartCard(snapshot)
        summaryCards(snapshot)
        WeekdayCard(totals: snapshot.weekdays, region: settings.effectiveRegion, calendar: calendar)
        PopulationReferenceCard()
      }
      .screenMargin()
      .padding(.vertical, GlassTokens.Spacing.section)
    }
    .navigationTitle("Trends")
    .navigationBarTitleDisplayMode(.large)
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { today = Date() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      today = Date()
    }
  }

  // MARK: - Data

  /// One render's worth of figures, computed from the store once.
  private struct Snapshot {
    let totals: [DayTotal]
    /// Chart bars for the bucketed ranges — weekly for quarter, monthly for year.
    let buckets: [PeriodTotal]
    /// The average line's value on bucketed charts: mean per completed
    /// bucket, nil while no bucket is complete (no line beats a misleading one).
    let bucketAverage: Double?
    /// The selected bar's facts, or nil when nothing is selected or the
    /// selected date no longer falls on a bar (a rolling window has moved on).
    let selection: PeriodDetail?
    /// The range by weekday (ADR-0032), seven rows in the calendar's order.
    let weekdays: [WeekdayTotal]

    var average: Double { TrendSummary.dailyAverage(totals) }
    var sum: Double { TrendSummary.sum(totals) }
    var restDays: Int { TrendSummary.daysWithoutDrinks(totals) }
  }

  private func snapshot() -> Snapshot {
    let drinks = allEntries.loggedDrinks
    let region = settings.effectiveRegion
    let totals = TrendSummary.dailyTotals(
      range: range, endingOn: today, drinks: drinks, region: region, calendar: calendar
    )
    let buckets = TrendSummary.bucketed(totals, by: range.bucket, calendar: calendar)
    // Derived, never stored: a drink logged from Today, a marker arriving
    // over CloudKit, an undo, or a region change all re-express it on the
    // next render.
    let selection = selectedDate.flatMap { date in
      TrendSummary.periodDetail(
        containing: date,
        range: range,
        endingOn: today,
        drinks: drinks,
        alcoholFreeDays: markedDays,
        healthMarkedDays: healthMarkedDays,
        region: region,
        calendar: calendar
      )
    }
    return Snapshot(
      totals: totals,
      buckets: buckets,
      bucketAverage: TrendSummary.bucketAverage(buckets, unit: range.bucket, calendar: calendar),
      selection: selection,
      weekdays: TrendSummary.weekdayTotals(
        range: range, endingOn: today, drinks: drinks, region: region, calendar: calendar
      )
    )
  }

  private var isBucketed: Bool { range.bucket != .day }

  private var markedDays: Set<Date> {
    Set(alcoholFreeDays.map(\.day))
  }

  /// The subset another app's Health zero put there (ADR-0025).
  private var healthMarkedDays: Set<Date> {
    Set(alcoholFreeDays.filter(\.isImportedFromHealth).map(\.day))
  }

  // MARK: - Selection state

  /// Selection changes animate explicitly — the dimming and the block's
  /// transition — rather than through an `.animation(value:)` on the card,
  /// which would also put the chart's data change inside the animation when
  /// the range switches and morph the bars from one range into the next.
  private var selectionBinding: Binding<Date?> {
    Binding(
      get: { selectedDate },
      set: { newValue in
        withAnimation(.smooth(duration: 0.25)) { selectedDate = newValue }
      }
    )
  }

  private func clearSelection() {
    withAnimation(.smooth(duration: 0.25)) { selectedDate = nil }
  }

  /// The range picker clears the selection in the same update it changes
  /// the range: a day selected on Week would otherwise be resolved as a whole
  /// week on Quarter for one render — the app choosing which bucket the user
  /// meant.
  private var rangeBinding: Binding<TrendRange> {
    Binding(
      get: { range },
      set: { newRange in
        selectedDate = nil
        range = newRange
      }
    )
  }

  // MARK: - Range picker

  private var rangePicker: some View {
    SUSegmentedControl(
      selectedId: rangeBinding,
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

  private func chartCard(_ snapshot: Snapshot) -> some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        Text(chartTitle)
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)

        chart(snapshot)

        Divider().opacity(0.5)

        // The block describes the bar it sits under and moves with the card;
        // the bars never move under the finger, the cards below slide down.
        if let selection = snapshot.selection {
          PeriodDetailView(
            detail: selection,
            region: settings.effectiveRegion,
            isToday: selection.unit == .day && calendar.isDate(selection.start, inSameDayAs: today),
            calendar: calendar,
            onClear: clearSelection
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
    }
  }

  private func chart(_ snapshot: Snapshot) -> some View {
    let selectedStart = snapshot.selection?.start
    func isDimmed(_ barStart: Date) -> Bool {
      selectedStart.map { $0 != barStart } ?? false
    }

    return Chart {
      if isBucketed {
        // A bar per calendar week or month. Daily bars past ~30 days are
        // noise; the trailing bucket is simply "so far", like the current
        // month in the year calendar.
        ForEach(snapshot.buckets) { period in
          BarMark(
            x: .value("Period", period.start, unit: range.bucket),
            y: .value(unitNounPlural, period.standardDrinks)
          )
          .foregroundStyle(Color.accentColor.gradient)
          .cornerRadius(6)
          .opacity(isDimmed(period.start) ? 0.35 : 1)
        }
      } else {
        ForEach(snapshot.totals) { day in
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
      if let lineValue = isBucketed
        ? snapshot.bucketAverage
        : (snapshot.average > 0 ? snapshot.average : nil),
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
    // Tap selects, drag scrubs; the value is the continuous x under the
    // finger, and the domain resolves it to the bar it lands on — a touch on
    // any part of a drawn bar, including a trailing bar's days after today.
    // Only opacity changes inside the plot — no annotation, no second rule,
    // no colour (invariant 10).
    .chartXSelection(value: selectionBinding)
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
    .sensoryFeedback(.selection, trigger: selectedStart)
    // One adjustable VoiceOver element — the CountStepper pattern, and the
    // year view's "twelve summaries, not 365 stops" applied to bars. Swipe
    // up and down step through the bars via the same selection sighted
    // users see, so the accessible path never depends on whether a
    // double-tap on a mark reaches the selection gesture.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(chartAccessibilityLabel)
    .accessibilityValue(spokenSelection(snapshot.selection))
    .accessibilityAdjustableAction { direction in step(direction) }
    .accessibilityAction(.escape) { clearSelection() }
    .accessibilityAction(named: Text("Clear selection")) { clearSelection() }
  }

  // MARK: - Selection accessibility

  /// The selected bar, spoken: composed verbatim from parts that arrive
  /// localized (the IntensityCell precedent) — a locale date, the day-count
  /// caption, and either the amount phrase or the legend's description of a
  /// zero day.
  private func spokenSelection(_ selection: PeriodDetail?) -> Text {
    guard let selection else { return Text("No bar selected") }
    let title = PeriodDetailView.titleString(for: selection, calendar: calendar)
    let amount: String
    switch selection.dayRecord {
    case .alcoholFree?: amount = DayIntensity.alcoholFree.accessibilityDescription
    case .unlogged?: amount = DayIntensity.unlogged.accessibilityDescription
    case .drinks?, nil: amount = StandardDrink.amountPhrase(selection.standardDrinks, region: settings.effectiveRegion)
    }
    if selection.unit == .day, calendar.isDate(selection.start, inSameDayAs: today) {
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
  /// the oldest. Ends clamp, never wrap. Runs on an event, so deriving a
  /// snapshot here is one pass, not one per frame.
  private func step(_ direction: AccessibilityAdjustmentDirection) {
    let snapshot = snapshot()
    let forward = direction == .increment
    let next: Date?
    if let current = snapshot.selection?.start {
      next = TrendSummary.adjacentBucketStart(
        from: current, direction: forward ? 1 : -1, range: range, endingOn: today, calendar: calendar
      )
    } else if isBucketed {
      next = forward ? snapshot.buckets.first?.start : snapshot.buckets.last?.start
    } else {
      next = forward ? snapshot.totals.first?.date : snapshot.totals.last?.date
    }
    guard let next else { return }
    withAnimation(.smooth(duration: 0.25)) { selectedDate = next }
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

  private func summaryCards(_ snapshot: Snapshot) -> some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      HStack(spacing: GlassTokens.Spacing.regular) {
        StatCard(
          value: StandardDrink.formatted(snapshot.sum),
          label: sumLabel
        )
        StatCard(
          value: StandardDrink.formatted(snapshot.average),
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

          Text("\(snapshot.restDays) of \(snapshot.totals.count)")
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
