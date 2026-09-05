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
/// Drag across the bars to read one (ADR-0028 and its 2026-09-05 amendment):
/// the touched bar keeps its accent, the rest dim, and the card's header —
/// above the plot, so nothing appears under the reading hand — reports that
/// bar's own facts, never its distance from the average line. A touch
/// selection lasts the touch; a stepped selection persists and keeps the
/// shipped block below the chart. The selection is view state only: nothing
/// about it is persisted, synced, or logged.
///
/// Tone: the average line is described as "your average", never as a target,
/// and nothing here congratulates or warns. It reports, and stops.
struct TrendsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.colorScheme) private var colorScheme

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

  /// True only for a selection the accessibility stepper put there. The touch
  /// gesture never sets it: on iOS 26 `chartXSelection` writes nil itself the
  /// moment the finger lifts, so a scrub is over before a control could be
  /// reached, and the ✕ belongs to the selection that actually persists.
  @State private var selectionIsHeld = false

  /// The readout's floor. A scaled metric, not a fixed height: the card must
  /// not change height with the selection, which this delivers at the sizes the
  /// design was drawn at — but a fixed height clips (design-system §3, and the
  /// fault that disqualified `SUSegmentedControl` in ADR-0026).
  ///
  /// 84, not the design's 76. Measured on a 402pt screen at the default text
  /// size the idle state's own content is 76.2pt — the design's number, drawn
  /// from the idle state — but the scrub state's is 81.4pt, because its title
  /// is subheadline where the idle title is footnote. At 76 the floor bound
  /// neither, and the card moved 5pt on every selection: the exact fault this
  /// readout exists to remove. At 84 the floor binds both and the height is
  /// identical. Above the floor, at the accessibility sizes, the box grows
  /// rather than clips and the two states may differ again.
  @ScaledMetric(relativeTo: .footnote) private var readoutHeight: CGFloat = 84

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
    /// ADR-0006's figures over the whole range — the header's idle line. Read
    /// only for `daysWithDrinks`: the printed total stays `sum`, the fold the
    /// StatCard below already prints, so one number has one source.
    let rangeSummary: RecentSummary

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
      ),
      rangeSummary: TrendSummary.rangeSummary(
        range: range, endingOn: today, drinks: drinks,
        alcoholFreeDays: markedDays, region: region, calendar: calendar
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
        // Framework writes — including the nil it writes on release — are the
        // touch path, which is never "held". Cleared before the assignment so
        // the stepper's own write can set it afterwards and win.
        selectionIsHeld = false
        withAnimation(.smooth(duration: 0.22)) { selectedDate = newValue }
      }
    )
  }

  private func clearSelection() {
    withAnimation(.smooth(duration: 0.22)) {
      selectedDate = nil
      selectionIsHeld = false
    }
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
        selectionIsHeld = false
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
        readout(snapshot)

        Divider().opacity(0.5)

        chart(snapshot)

        // A stepped selection holds between actions, so it keeps the shipped
        // block: composition rows, the named unlogged count, and the ✕ that
        // clears it. A scrub never reaches here — it ends when the finger lifts.
        if selectionIsHeld, let selection = snapshot.selection {
          Divider().opacity(0.5)
          PeriodDetailView(
            detail: selection,
            region: settings.effectiveRegion,
            isToday: selection.unit == .day && calendar.isDate(selection.start, inSameDayAs: today),
            calendar: calendar,
            onClear: clearSelection
          )
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
        }
      }
    }
  }

  // MARK: - Readout

  /// The card's header: the range's own figures when nothing is being scrubbed,
  /// the touched bar's while a finger is on the chart (ADR-0028 amendment).
  ///
  /// Both states share one box with a floor, so the card's height does not
  /// change with the selection — the property the design asked a fixed 76
  /// points for, without the fixed height Dynamic Type rules out. The header
  /// stays idle for a stepped selection, because the block below the chart
  /// already says all of it and more.
  @ViewBuilder
  private func readout(_ snapshot: Snapshot) -> some View {
    let live = selectionIsHeld ? nil : snapshot.selection
    let offset: CGFloat = reduceMotion ? 0 : 6

    ZStack(alignment: .topLeading) {
      idleReadout(snapshot)
        .opacity(live == nil ? 1 : 0)
        .offset(y: live == nil ? 0 : -offset)
        .accessibilityHidden(live != nil)
        .allowsHitTesting(live == nil)

      if let live {
        PeriodReadout(
          detail: live,
          region: settings.effectiveRegion,
          isToday: live.unit == .day && calendar.isDate(live.start, inSameDayAs: today),
          calendar: calendar
        )
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: offset)))
      }
    }
    .frame(maxWidth: .infinity, minHeight: readoutHeight, alignment: .topLeading)
  }

  private func idleReadout(_ snapshot: Snapshot) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        Text(chartTitle)
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)
        Spacer(minLength: GlassTokens.Spacing.tight)
        if let line = averageLineValue(snapshot) { averageLegend(line) }
      }

      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Text(StandardDrink.formatted(snapshot.sum))
          .font(GlassTokens.Typography.cardValue)
          .monospacedDigit()
          .foregroundStyle(.primary)
          .contentTransition(.opacity)
        rangeCaption(snapshot)
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, 5)

      // Discoverability for a gesture with no visible affordance — the
      // calendar's own precedent. One line, one key for all four ranges.
      // "tap" is gone because on iOS 26 an instantaneous tap does not select:
      // selection needs the short dwell that begins a scrub.
      Text("Tip: drag across the bars to see what each one holds")
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  /// "standard drinks · 30 days with drinks" — the noun from the package and
  /// the count from the calendar card's own count-bearing key, joined as
  /// separate `Text` values. A key made of a placeholder and punctuation is
  /// never looked up (ADR-0020), so the middle dot is never part of one.
  private func rangeCaption(_ snapshot: Snapshot) -> Text {
    Text(verbatim: settings.effectiveRegion.unitName(for: snapshot.sum))
      + Text(verbatim: " · ")
      + RecentSummaryCaptions.daysWithDrinksPhrase(snapshot.rangeSummary.daysWithDrinks)
  }

  /// The dashed line's own value, beside the range's own — an independent fact,
  /// never a delta, never signed, no direction word (ADR-0028). Drawn only when
  /// the line is: a legend for a line that is not there is a caption for
  /// nothing (ADR-0029's rule for the year-in-review caption).
  private func averageLegend(_ value: Double) -> some View {
    HStack(spacing: 6) {
      DashedRule()
        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .foregroundStyle(.secondary)
        .frame(width: 14, height: 1)
      (Text(averageLineLabel)
        + Text(verbatim: " · ")
        + Text(verbatim: StandardDrink.formatted(value)))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .fixedSize()
    .accessibilityElement(children: .combine)
  }

  /// One expression behind both the `RuleMark` and the header legend, so the
  /// legend can never describe a line that is not drawn. The gate is `> 0`,
  /// never `!= nil`: `bucketAverage` returns `Optional(0.0)` for an empty log
  /// on both bucketed ranges, so nil is practically unreachable.
  private func averageLineValue(_ snapshot: Snapshot) -> Double? {
    let value: Double? = isBucketed ? snapshot.bucketAverage : snapshot.average
    guard let value, value > 0 else { return nil }
    return value
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
      // bars would hug the floor and read as meaningless. Never dimmed, never
      // annotated relative to the selection — and no longer annotated at all:
      // its label is the header legend, where it reads at a glance instead of
      // colliding with the bars.
      if let lineValue = averageLineValue(snapshot) {
        RuleMark(y: .value("Average", lineValue))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
          .foregroundStyle(.secondary)
      }
    }
    // Tap selects, drag scrubs; the value is the continuous x under the
    // finger, and the domain resolves it to the bar it lands on — a touch on
    // any part of a drawn bar, including a trailing bar's days after today.
    // Only opacity changes inside the plot — no annotation, no second rule,
    // no colour (invariant 10).
    .chartXSelection(value: selectionBinding)
    // A rail behind the bars and a hairline in front of them — the two marks
    // that say where the finger is. Neither encodes anything about the data,
    // which is why they are a selected state (design-system §2) rather than a
    // second colour role, and why no annotation, no second rule and no colour
    // on the bars themselves is needed (invariant 10).
    .chartBackground { proxy in
      GeometryReader { geo in
        if let selection = snapshot.selection,
          let anchor = proxy.plotFrame,
          let slot = selectedBarSlot(selection, proxy: proxy) {
          let plot = geo[anchor]
          UnevenRoundedRectangle(
            topLeadingRadius: 9,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 9,
            style: .continuous
          )
          .fill(
            LinearGradient(
              colors: [
                Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14),
                Color.accentColor.opacity(colorScheme == .dark ? 0.04 : 0.03),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: slot.width, height: plot.height)
          .position(x: plot.minX + slot.centre, y: plot.midY)
          .animation(.smooth(duration: 0.16), value: selection.start)
        }
      }
      .allowsHitTesting(false)
    }
    .chartOverlay { proxy in
      GeometryReader { geo in
        if let selection = snapshot.selection,
          let anchor = proxy.plotFrame,
          let slot = selectedBarSlot(selection, proxy: proxy),
          let barTop = proxy.position(forY: selection.standardDrinks) {
          let plot = geo[anchor]
          let height = max(0, barTop)
          Rectangle()
            .fill(
              LinearGradient(
                colors: [Color.accentColor.opacity(0), Color.accentColor.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(width: 1, height: height)
            .position(x: plot.minX + slot.centre, y: plot.minY + height / 2)
            .animation(.smooth(duration: 0.16), value: selection.start)
        }
      }
      // Mandatory: without it the overlay's content intercepts the touch that
      // drives `chartXSelection`.
      .allowsHitTesting(false)
    }
    .chartYAxis {
      // Labels only, plus the zero rule. The zero baseline *is* a y-axis grid
      // line, so dropping the grid wholesale would leave the plot with no
      // floor at all — measured, not assumed.
      AxisMarks(position: .leading) { value in
        AxisValueLabel()
        if let raw = value.as(Double.self), raw == 0 { AxisGridLine() }
      }
    }
    .chartXAxis {
      // Labels only. With the grid gone the dashed average is the single
      // reference behind the bars instead of one line among a dozen.
      switch range {
      case .week:
        AxisMarks(values: .stride(by: .day, count: 1)) { _ in
          AxisValueLabel(format: .dateTime.weekday(.narrow))
        }
      case .month:
        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
          AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
      case .quarter:
        AxisMarks(values: .stride(by: .month, count: 1)) { _ in
          AxisValueLabel(format: .dateTime.month(.abbreviated))
        }
      case .year:
        AxisMarks(values: .stride(by: .month, count: 2)) { _ in
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

  /// The selected bar's slot inside the plot, in the plot's own coordinates:
  /// the two edges of its bucket, and the centre between them.
  ///
  /// `position(forX:)` returns the position of that *instant*, and a bar is
  /// drawn centred on its bin — so the bucket's start alone lands half a bucket
  /// to the left of the bar it names (measured at 21.9 of a 44.1pt weekly
  /// pitch, which puts a rail almost entirely over the previous bar). The last
  /// bar has no adjacent start, so its trailing edge comes from the calendar.
  /// These are plot coordinates: callers add `plotFrame`'s minX, because the
  /// y-label gutter widens with the digits and is not a constant.
  ///
  /// The width is the slot's own, not the design's literal 26 points. That
  /// number was drawn against 13 weekly bars, where it is slightly *wider* than
  /// the 24.7pt pitch — the rail fills the slot, which is what makes it read as
  /// a column behind the bar. Fixed at 26 it would be narrower than a Week
  /// bar and read as a stripe inside one instead.
  private func selectedBarSlot(_ detail: PeriodDetail, proxy: ChartProxy) -> (centre: CGFloat, width: CGFloat)? {
    let next = TrendSummary.adjacentBucketStart(
      from: detail.start, direction: 1, range: range, endingOn: today, calendar: calendar
    ) ?? calendar.date(byAdding: range.bucket, value: 1, to: detail.start)
    guard let next,
      let leading = proxy.position(forX: detail.start),
      let trailing = proxy.position(forX: next)
    else { return nil }
    return ((leading + trailing) / 2, max(12, abs(trailing - leading)))
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
    withAnimation(.smooth(duration: 0.22)) {
      selectedDate = next
      selectionIsHeld = true
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
