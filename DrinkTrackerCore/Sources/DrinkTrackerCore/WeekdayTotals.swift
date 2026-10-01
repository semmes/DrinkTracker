import Foundation

/// One weekday's share of a Trends window (ADR-0032, ADR-0058): what was logged
/// on, say, the Fridays of the last 30 days — or of the days since the first
/// record, while the log is younger than the range. Facts about the user's own log with no
/// external figure and no rank — the same rule as a Trends bar's detail
/// (ADR-0028): nothing here is expressed against another weekday.
public struct WeekdayTotal: Identifiable, Hashable, Sendable {
  /// `Calendar.component(.weekday)`: 1 is Sunday whatever the first weekday.
  public let weekday: Int
  /// Total standard drinks on this weekday's days in the window, in the
  /// caller's region.
  public let standardDrinks: Double
  /// How many of this weekday's days had at least one entry.
  public let daysWithDrinks: Int
  /// How many of this weekday fell in the window at all.
  public let dayCount: Int

  public var id: Int { weekday }

  public init(weekday: Int, standardDrinks: Double, daysWithDrinks: Int, dayCount: Int) {
    self.weekday = weekday
    self.standardDrinks = standardDrinks
    self.daysWithDrinks = daysWithDrinks
    self.dayCount = dayCount
  }
}

extension TrendSummary {

  /// The range's days folded by weekday, ordered from the calendar's first
  /// weekday, one entry per weekday always — a weekday with no days in a
  /// short range reports zero of zero. Built from the range's own day walk
  /// (`rangeDays`), so the seven totals sum to the range's total and the seven
  /// day counts to its length.
  public static func weekdayTotals(
    range: TrendRange,
    endingOn endDate: Date,
    drinks: [LoggedDrink],
    region: Region,
    calendar: Calendar = .current
  ) -> [WeekdayTotal] {
    weekdayTotals(
      of: rangeDays(
        range: range, endingOn: endDate, drinks: drinks,
        alcoholFreeDays: [], region: region, calendar: calendar
      ),
      calendar: calendar
    )
  }

  /// Any run of classified days folded by weekday, in the same order and with
  /// the same zero-of-zero rows — the form Trends reads since ADR-0058, over
  /// its window's days, so the rows divide by the days since the first record
  /// while the log is younger than the range. A day with drinks is a day with
  /// an entry, a 0% one included: `summary(of:)`'s definition.
  public static func weekdayTotals(of days: [CalendarDay], calendar: Calendar = .current) -> [WeekdayTotal] {
    var sums: [Int: (drinks: Double, withDrinks: Int, days: Int)] = [:]
    for day in days {
      let weekday = calendar.component(.weekday, from: day.date)
      var entry = sums[weekday, default: (0, 0, 0)]
      entry.days += 1
      if day.hasEntries {
        entry.drinks += day.standardDrinks
        entry.withDrinks += 1
      }
      sums[weekday] = entry
    }

    let first = calendar.firstWeekday
    return (0..<7).map { offset in
      let weekday = (first - 1 + offset) % 7 + 1
      let entry = sums[weekday] ?? (0, 0, 0)
      return WeekdayTotal(
        weekday: weekday, standardDrinks: entry.drinks, daysWithDrinks: entry.withDrinks, dayCount: entry.days
      )
    }
  }
}
