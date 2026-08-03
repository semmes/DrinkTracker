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
