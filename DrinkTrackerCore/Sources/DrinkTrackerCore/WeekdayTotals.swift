import Foundation

/// One weekday's share of a range (ADR-0032): what was logged on, say, the
/// Fridays of the last 30 days. Facts about the user's own log with no
/// external figure and no rank — the same rule as a Trends bar's detail
/// (ADR-0028): nothing here is expressed against another weekday.
public struct WeekdayTotal: Identifiable, Hashable, Sendable {
  /// `Calendar.component(.weekday)`: 1 is Sunday whatever the first weekday.
  public let weekday: Int
  /// Total standard drinks on this weekday's days in the range, in the
  /// caller's region.
  public let standardDrinks: Double
  /// How many of this weekday's days had at least one entry.
  public let daysWithDrinks: Int
  /// How many of this weekday fell in the range at all.
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
  /// (`days(in:)`) and the per-day table, so the seven totals sum to the
  /// range's total and the seven day counts to its length.
  public static func weekdayTotals(
    range: TrendRange,
    endingOn endDate: Date,
    drinks: [LoggedDrink],
    region: Region,
    calendar: Calendar = .current
  ) -> [WeekdayTotal] {
    let keys = days(in: range, endingOn: endDate, calendar: calendar)
    let inRange = Set(keys)
    var totals: [Date: Double] = [:]
    for drink in drinks {
      let day = calendar.startOfDay(for: drink.loggedAt)
      guard inRange.contains(day) else { continue }
      totals[day, default: 0] += drink.standardDrinks(in: region)
    }

    var sums: [Int: (drinks: Double, withDrinks: Int, days: Int)] = [:]
    for key in keys {
      let weekday = calendar.component(.weekday, from: key)
      var entry = sums[weekday, default: (0, 0, 0)]
      entry.days += 1
      if let total = totals[key] {
        entry.drinks += total
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
