import Foundation

/// One cell in a month grid.
public struct CalendarDay: Identifiable, Hashable, Sendable {
  public let date: Date
  public let standardDrinks: Double
  public let isMarkedAlcoholFree: Bool
  public let hasEntries: Bool

  public var id: Date { date }

  public var intensity: DayIntensity {
    DayIntensity.bucket(
      standardDrinks: standardDrinks,
      isMarkedAlcoholFree: isMarkedAlcoholFree,
      hasEntries: hasEntries
    )
  }

  public init(
    date: Date,
    standardDrinks: Double,
    isMarkedAlcoholFree: Bool,
    hasEntries: Bool
  ) {
    self.date = date
    self.standardDrinks = standardDrinks
    self.isMarkedAlcoholFree = isMarkedAlcoholFree
    self.hasEntries = hasEntries
  }
}

/// One month laid out for a calendar grid.
public struct MonthGrid: Identifiable, Hashable, Sendable {
  /// First of the month, at the start of the day.
  public let month: Date

  /// Empty cells before the 1st, so it lands under the right weekday column.
  ///
  /// Derived from the calendar's `firstWeekday`, which is locale-dependent — weeks
  /// start on Monday in most of the world and Sunday in the US. Hardcoding either
  /// would put every date in the wrong column for half the planet.
  public let leadingBlanks: Int

  public let days: [CalendarDay]

  public var id: Date { month }

  public init(month: Date, leadingBlanks: Int, days: [CalendarDay]) {
    self.month = month
    self.leadingBlanks = leadingBlanks
    self.days = days
  }

  /// Days in this month that were recorded at all, in either direction.
  public var recordedDayCount: Int {
    days.count { $0.intensity.isRecorded }
  }

  /// This month's cells up to and including the day containing `date`: the
  /// whole month once it has ended, the 1st through today while it is in
  /// progress, and nothing for a month that has not begun (ADR-0026).
  ///
  /// A summary counts days that have happened. A future day is not "nothing
  /// logged either way" — it is not in the window — so clipping here is what
  /// keeps a card's unlogged line honest and its day count equal to the days
  /// it names. Both sides of the comparison are `startOfDay` values (cells
  /// are built that way in `monthGrid`), so a midnight-DST day compares
  /// correctly and no date arithmetic is introduced. Callers pass the clock
  /// in; nothing here reads it.
  public func days(through date: Date, calendar: Calendar = .current) -> [CalendarDay] {
    let cutoff = calendar.startOfDay(for: date)
    return days.filter { $0.date <= cutoff }
  }

  /// The month as rows of seven cells, first weekday first, with `nil` for
  /// the leading blanks before the 1st and the trailing blanks after the last
  /// day (ADR-0027).
  ///
  /// For layouts that place cells row by row (`Grid`/`GridRow`) rather than
  /// flowing them — what an offscreen render needs: nothing lazy, nothing
  /// skipped. Always a multiple of seven cells, four to six rows. The in-app
  /// `LazyVGrid`s keep using `leadingBlanks` + `days`; this and
  /// `dayIndex(row:column:)` agree by construction, and a test says so.
  public var rows: [[CalendarDay?]] {
    guard !days.isEmpty else { return [] }
    let cells: [CalendarDay?] = Array(repeating: nil, count: leadingBlanks) + days.map { $0 }
    let trailing = (7 - cells.count % 7) % 7
    let padded = cells + Array(repeating: nil, count: trailing)
    return stride(from: 0, to: padded.count, by: 7).map { Array(padded[$0..<$0 + 7]) }
  }

  // MARK: - Drag selection

  /// Maps a grid position — row and weekday column — to an index into `days`.
  ///
  /// This is the arithmetic behind the calendar's drag-to-select: the view turns a
  /// touch point into a row and column, and this answers which day (if any) sits
  /// there. `nil` for the leading blanks, for positions past the month's end, and
  /// for anything outside the seven columns — a drag that wanders off the grid
  /// selects nothing extra rather than clamping to a day the finger isn't on.
  public func dayIndex(row: Int, column: Int) -> Int? {
    guard row >= 0, (0..<7).contains(column) else { return nil }
    let index = row * 7 + column - leadingBlanks
    return days.indices.contains(index) ? index : nil
  }

  /// The contiguous run of days between two indices, inclusive, in either order.
  ///
  /// Order-insensitive because a drag can move backwards past its anchor — selecting
  /// the 12th through the 8th is the same run as the 8th through the 12th. Indices
  /// are clamped to the month, so a drag that leaves the grid keeps its last valid
  /// extent instead of failing.
  public func days(between first: Int, and second: Int) -> [CalendarDay] {
    guard !days.isEmpty else { return [] }
    let lower = max(0, min(first, second))
    let upper = min(days.count - 1, max(first, second))
    guard lower <= upper else { return [] }
    return Array(days[lower...upper])
  }
}

extension TrendSummary {

  /// Per-day totals, keyed by start-of-day.
  ///
  /// Built once and indexed into, rather than re-filtering the whole array per day.
  /// A year grid asks about 365 days; `total(for:in:)` per cell would walk the full
  /// drink list 365 times.
  public static func totalsByDay(
    _ drinks: [LoggedDrink],
    region: Region,
    calendar: Calendar = .current
  ) -> [Date: Double] {
    drinks.reduce(into: [:]) { totals, drink in
      let day = calendar.startOfDay(for: drink.loggedAt)
      totals[day, default: 0] += drink.standardDrinks(in: region)
    }
  }

  /// The month containing `date`, laid out for a calendar grid.
  public static func monthGrid(
    containing date: Date,
    totalsByDay: [Date: Double],
    alcoholFreeDays: Set<Date>,
    calendar: Calendar = .current
  ) -> MonthGrid {
    let components = calendar.dateComponents([.year, .month], from: date)
    guard
      let monthStart = calendar.date(from: components),
      let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
    else {
      return MonthGrid(month: calendar.startOfDay(for: date), leadingBlanks: 0, days: [])
    }

    let weekday = calendar.component(.weekday, from: monthStart)
    let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7

    let days = dayRange.compactMap { dayOfMonth -> CalendarDay? in
      guard
        let day = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: monthStart)
      else { return nil }
      let startOfDay = calendar.startOfDay(for: day)
      let total = totalsByDay[startOfDay]
      return CalendarDay(
        date: startOfDay,
        standardDrinks: total ?? 0,
        isMarkedAlcoholFree: alcoholFreeDays.contains(startOfDay),
        hasEntries: total != nil
      )
    }

    return MonthGrid(month: monthStart, leadingBlanks: leadingBlanks, days: days)
  }

  /// All twelve months of `year`, January first.
  public static func yearGrids(
    _ year: Int,
    totalsByDay: [Date: Double],
    alcoholFreeDays: Set<Date>,
    calendar: Calendar = .current
  ) -> [MonthGrid] {
    (1...12).compactMap { month in
      guard
        let date = calendar.date(from: DateComponents(year: year, month: month, day: 1))
      else { return nil }
      return monthGrid(
        containing: date,
        totalsByDay: totalsByDay,
        alcoholFreeDays: alcoholFreeDays,
        calendar: calendar
      )
    }
  }
}
