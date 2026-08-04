import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Month calendar. The pattern over weeks, and the way to record a day you missed.
///
/// Complements Trends rather than duplicating it: the chart answers "how much", the
/// calendar answers "which days". Neither frames an answer as good or bad.
struct CalendarView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.modelContext) private var context

  @Query(sort: \DrinkEntry.loggedAt, order: .reverse) private var allEntries: [DrinkEntry]
  @Query private var alcoholFreeDays: [AlcoholFreeDay]

  @State private var visibleMonth: Date = Calendar.current.startOfDay(for: Date())
  @State private var selectedDay: SelectedDay?
  @State private var editingDraft: DrinkDraft?

  // Drag-to-select. The anchor is set once per gesture, where the long press
  // landed; the current index follows the finger. Both clear on release.
  @State private var dragAnchorIndex: Int?
  @State private var dragCurrentIndex: Int?
  @State private var bulkSelection: BulkSelection?

  private var calendar: Calendar { .current }

  var body: some View {
    ScrollView {
      VStack(spacing: GlassTokens.Spacing.section) {
        monthHeader
        weekdayHeader
        monthGrid
        selectionHint
        IntensityLegend()
        RecentSummaryCard(summary: summary, region: settings.effectiveRegion)
      }
      .screenMargin()
      .padding(.vertical, GlassTokens.Spacing.section)
    }
    .navigationTitle("Calendar")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
          YearView()
        } label: {
          Image(systemName: "square.grid.3x3")
        }
        .accessibilityLabel("Year view")
      }
    }
    .sheet(item: $selectedDay) { selection in
      DayLogSheet(
        day: selection.date,
        existingDrinks: drinks(on: selection.date),
        isMarkedAlcoholFree: markedDays.contains(calendar.startOfDay(for: selection.date)),
        seed: seedDrink,
        onLogDrinks: { count in log(count, on: selection.date) },
        onMarkAlcoholFree: { store.markAlcoholFree(selection.date) },
        onClearAlcoholFree: { store.unmarkAlcoholFree(selection.date) },
        onEditDrink: { drink in
          selectedDay = nil
          editingDraft = DrinkDraft(editing: drink)
        }
      )
    }
    .sheet(item: $editingDraft) { draft in
      DrinkDetailSheet(draft: draft, showsTimeControl: true) { _ in
        editingDraft = nil
      } onCancel: {
        editingDraft = nil
      }
    }
    .sheet(item: $bulkSelection) { selection in
      BulkFillSheet(
        days: selection.days,
        seed: seedDrink,
        onApply: { count, dates in bulkFill(count, on: dates) }
      )
    }
  }

  // MARK: - Data

  private var store: DrinkStore {
    DrinkStore(context: context, health: health)
  }

  private var markedDays: Set<Date> {
    Set(alcoholFreeDays.map(\.day))
  }

  private var totalsByDay: [Date: Double] {
    TrendSummary.totalsByDay(
      allEntries.loggedDrinks,
      region: settings.effectiveRegion,
      calendar: calendar
    )
  }

  private var grid: MonthGrid {
    TrendSummary.monthGrid(
      containing: visibleMonth,
      totalsByDay: totalsByDay,
      alcoholFreeDays: markedDays,
      calendar: calendar
    )
  }

  private var summary: RecentSummary {
    TrendSummary.recentSummary(
      endingOn: Date(),
      totalsByDay: totalsByDay,
      alcoholFreeDays: markedDays,
      calendar: calendar
    )
  }

  /// What a calendar log should look like: the type logged most often, at the size
  /// and strength it was last logged at. Falls back to the type's own defaults.
  private var seedDrink: LoggedDrink? {
    let drinks = allEntries.loggedDrinks
    guard let type = TrendSummary.mostLoggedType(in: drinks) else { return nil }
    if let recent = TrendSummary.mostRecentDrink(ofType: type, in: drinks) {
      return recent
    }
    return DrinkDraft(type: type).makeLoggedDrink(region: settings.effectiveRegion)
  }

  private func drinks(on day: Date) -> [LoggedDrink] {
    allEntries.loggedDrinks
      .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
      .sorted { $0.loggedAt > $1.loggedAt }
  }

  private func log(_ count: Int, on day: Date) {
    // Noon rather than the start of the day: a midnight timestamp sits on the
    // boundary, and any timezone shift afterwards moves it to the day before.
    let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    // Same seeding rule as Today's counter — one definition of what "N drinks"
    // records, wherever it's said. See DrinkDraft.quickCount.
    let drinks = DrinkDraft
      .quickCount(count, from: allEntries.loggedDrinks, at: noon)
      .makeLoggedDrinks(region: settings.effectiveRegion)
    Task { await store.save(drinks) }
  }

  /// One answer, applied to every date the bulk sheet decided to write.
  ///
  /// The sheet has already dropped days with any record, so this only ever touches
  /// blank days — but `markAlcoholFree` still refuses a day with entries, so even a
  /// stale selection can't produce a contradiction. Seeding is captured once before
  /// the loop: "the same value" on every day means the same drink, not a seed that
  /// drifts as the loop's own writes change what's most recent.
  private func bulkFill(_ count: Int, on dates: [Date]) {
    if count == 0 {
      for date in dates { store.markAlcoholFree(date) }
      return
    }
    let history = allEntries.loggedDrinks
    let region = settings.effectiveRegion
    let store = store
    Task {
      for date in dates {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let drinks = DrinkDraft
          .quickCount(count, from: history, at: noon)
          .makeLoggedDrinks(region: region)
        await store.save(drinks)
      }
    }
  }

  // MARK: - Header

  private var monthHeader: some View {
    HStack {
      Button {
        shiftMonth(by: -1)
      } label: {
        Image(systemName: "chevron.left")
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .accessibilityLabel("Previous month")

      Spacer()

      Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
        .font(GlassTokens.Typography.sheetTitle)
        .contentTransition(.numericText())

      Spacer()

      Button {
        shiftMonth(by: 1)
      } label: {
        Image(systemName: "chevron.right")
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .accessibilityLabel("Next month")
      .disabled(isShowingCurrentMonth)
      .opacity(isShowingCurrentMonth ? 0.3 : 1)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.accentColor)
  }

  /// There is nothing to see in the future, and a calendar that scrolls into it
  /// invites logging drinks that haven't happened.
  private var isShowingCurrentMonth: Bool {
    calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
  }

  private func shiftMonth(by months: Int) {
    guard let shifted = calendar.date(byAdding: .month, value: months, to: visibleMonth) else {
      return
    }
    withAnimation(.snappy(duration: 0.2)) { visibleMonth = shifted }
  }

  private var weekdayHeader: some View {
    HStack(spacing: 0) {
      ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
        Text(symbol)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .accessibilityHidden(true)
  }

  /// Rotated to the locale's first weekday, so the labels line up with the grid's
  /// own leading blanks.
  private var orderedWeekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let offset = calendar.firstWeekday - 1
    return Array(symbols[offset...] + symbols[..<offset])
  }

  // MARK: - Grid

  private var monthGrid: some View {
    GeometryReader { proxy in
      let spacing: CGFloat = 6
      let side = (proxy.size.width - spacing * 6) / 7

      LazyVGrid(
        columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: 7),
        spacing: spacing
      ) {
        ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
          Color.clear.frame(width: side, height: side)
        }
        ForEach(grid.days) { day in
          IntensityCell(
            day: day,
            side: side,
            isToday: calendar.isDateInToday(day.date),
            isSelected: selectedDates.contains(day.date)
          )
          .onTapGesture {
            guard day.date <= Date() else { return }
            selectedDay = SelectedDay(date: day.date)
          }
          .opacity(day.date > Date() ? 0.3 : 1)
        }
      }
      .coordinateSpace(.named("monthGrid"))
      .gesture(dragSelectGesture(side: side, spacing: spacing))
      // A tick as the selection grows or shrinks a cell, so the finger can feel
      // the extent without the eye leaving the far end of the run.
      .sensoryFeedback(.selection, trigger: dragCurrentIndex)
    }
    .frame(height: gridHeight)
  }

  /// Discoverability for a gesture with no visible affordance. One quiet line —
  /// the tap path works without ever reading it.
  private var selectionHint: some View {
    Text("Touch and hold a day, then drag to fill several at once.")
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Drag selection

  /// Long-press first, so the drag doesn't fight the scroll view: a pan scrolls,
  /// a still quarter-second claims the gesture for selection. The drag then takes
  /// zero further movement to start, because the press point itself is the anchor.
  private func dragSelectGesture(side: CGFloat, spacing: CGFloat) -> some Gesture {
    LongPressGesture(minimumDuration: 0.25)
      .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("monthGrid")))
      .onChanged { value in
        guard case .second(true, let drag?) = value else { return }
        if dragAnchorIndex == nil {
          dragAnchorIndex = dayIndex(at: drag.startLocation, side: side, spacing: spacing)
        }
        // Off-grid positions return nil and keep the last extent, so a finger
        // that wanders past an edge doesn't drop the selection it built.
        if let current = dayIndex(at: drag.location, side: side, spacing: spacing) {
          dragCurrentIndex = current
        }
      }
      .onEnded { value in
        let selection = selectedDays
        dragAnchorIndex = nil
        dragCurrentIndex = nil
        guard case .second = value, !selection.isEmpty else { return }
        bulkSelection = BulkSelection(days: selection)
      }
  }

  /// The dragged-over run, oldest first, without future days. A drag whose anchor
  /// never landed on a day (a leading blank) selects nothing.
  private var selectedDays: [CalendarDay] {
    guard let anchor = dragAnchorIndex else { return [] }
    let current = dragCurrentIndex ?? anchor
    let now = Date()
    return grid.days(between: anchor, and: current).filter { $0.date <= now }
  }

  private var selectedDates: Set<Date> {
    Set(selectedDays.map(\.date))
  }

  /// Point → (row, column) → day index, using the same `side` and `spacing` the
  /// grid was laid out with. The arithmetic that decides which day that is lives
  /// in `MonthGrid.dayIndex(row:column:)`, where it has tests.
  private func dayIndex(at point: CGPoint, side: CGFloat, spacing: CGFloat) -> Int? {
    guard point.x >= 0, point.y >= 0 else { return nil }
    let column = Int(point.x / (side + spacing))
    let row = Int(point.y / (side + spacing))
    return grid.dayIndex(row: row, column: column)
  }

  private var gridHeight: CGFloat {
    let rows = ceil(Double(grid.leadingBlanks + grid.days.count) / 7.0)
    // Cells are square and sized off the width, so the height has to be reserved
    // ahead of layout. 52 covers a 7-column grid at the widest current iPhone.
    return CGFloat(rows) * 52 + CGFloat(max(0, rows - 1)) * 6
  }
}

// MARK: - Sheet presentation

/// Wraps the tapped date for `.sheet(item:)`.
///
/// A retroactive `Identifiable` on `Date` would be the shorter route and the wrong
/// one: it is a conformance on a type this app doesn't own, visible everywhere it
/// imports Foundation, to satisfy one sheet.
struct SelectedDay: Identifiable, Hashable {
  let date: Date
  var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Wraps a drag-selected run of days for `.sheet(item:)`, same reasoning as above.
struct BulkSelection: Identifiable, Hashable {
  /// Chronological, past days only — filtered before the sheet is presented.
  let days: [CalendarDay]
  var id: Date { days.first?.date ?? .distantPast }
}
