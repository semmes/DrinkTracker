import Foundation

/// Logged drinks for one calendar day, newest first.
public struct DayGroup: Identifiable, Hashable, Sendable {
  public let day: Date
  public let drinks: [LoggedDrink]

  public var id: Date { day }

  public init(day: Date, drinks: [LoggedDrink]) {
    self.day = day
    self.drinks = drinks
  }

  /// The day's total, expressed in `region`'s units.
  public func total(in region: Region) -> Double {
    drinks.reduce(0) { $0 + $1.standardDrinks(in: region) }
  }
}

extension TrendSummary {
  /// Groups drinks into calendar days, newest day first and newest drink first
  /// within each day.
  ///
  /// Unlike `dailyTotals`, days with nothing logged are omitted — this backs a
  /// list of real entries rather than a chart axis, and blank rows would be noise.
  public static func groupedByDay(
    _ drinks: [LoggedDrink],
    calendar: Calendar = .current
  ) -> [DayGroup] {
    let buckets = Dictionary(grouping: drinks) { calendar.startOfDay(for: $0.loggedAt) }
    return buckets
      .map { day, drinks in
        DayGroup(day: day, drinks: drinks.sorted { $0.loggedAt > $1.loggedAt })
      }
      .sorted { $0.day > $1.day }
  }
}
