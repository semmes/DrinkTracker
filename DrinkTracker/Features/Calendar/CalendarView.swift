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

  private var calendar: Calendar { .current }

  var body: some View {
    ScrollView {
      VStack(spacing: GlassTokens.Spacing.section) {
        monthHeader
        weekdayHeader
        monthGrid
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
    let type = seedDrink?.type ?? .beer

    var draft = DrinkDraft(type: type, loggedAt: noon)
    if let seed = seedDrink {
      draft.selectedSize = type.sizeOptions.first { $0.volumeOunces == seed.volumeOunces } ?? .custom
      draft.customVolumeOunces = seed.volumeOunces
      draft.abvPercent = seed.abvPercent
    }
    draft.quantity = count

    let drinks = draft.makeLoggedDrinks(region: settings.effectiveRegion)
    Task { await store.save(drinks) }
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
            isToday: calendar.isDateInToday(day.date)
          )
          .onTapGesture {
            guard day.date <= Date() else { return }
            selectedDay = SelectedDay(date: day.date)
          }
          .opacity(day.date > Date() ? 0.3 : 1)
        }
      }
    }
    .frame(height: gridHeight)
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
