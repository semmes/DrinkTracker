import Foundation

/// One bar on the weekly/monthly trend chart.
public struct DayTotal: Identifiable, Hashable, Sendable {
  public let date: Date
  public let standardDrinks: Double

  public var id: Date { date }

  public init(date: Date, standardDrinks: Double) {
    self.date = date
    self.standardDrinks = standardDrinks
  }
}

/// The range a trend screen is showing.
public enum TrendRange: String, CaseIterable, Identifiable, Sendable {
  case week
  case month

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .week: "Week"
    case .month: "Month"
    }
  }

  public var dayCount: Int {
    switch self {
    case .week: 7
    case .month: 30
    }
  }
}

/// Pure aggregation over logged drinks. Kept free of SwiftUI and SwiftData
/// queries so the numbers behind the charts are directly testable.
public enum TrendSummary {

  /// Total standard drinks logged on a given calendar day.
  public static func total(
    for day: Date,
    in drinks: [LoggedDrink],
    calendar: Calendar = .current
  ) -> Double {
    drinks
      .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
      .reduce(0) { $0 + $1.standardDrinks }
  }

  /// One `DayTotal` per day across the range ending on `endingOn`, oldest first.
  ///
  /// Days with nothing logged are included with a total of zero so the chart
  /// keeps a continuous axis rather than collapsing empty days.
  public static func dailyTotals(
    range: TrendRange,
    endingOn endDate: Date,
    drinks: [LoggedDrink],
    calendar: Calendar = .current
  ) -> [DayTotal] {
    let lastDay = calendar.startOfDay(for: endDate)
    return (0..<range.dayCount).reversed().compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: lastDay) else {
        return nil
      }
      return DayTotal(date: day, standardDrinks: total(for: day, in: drinks, calendar: calendar))
    }
  }

  /// Mean standard drinks per day across the range, including zero days.
  public static func dailyAverage(_ totals: [DayTotal]) -> Double {
    guard !totals.isEmpty else { return 0 }
    return totals.reduce(0) { $0 + $1.standardDrinks } / Double(totals.count)
  }

  public static func sum(_ totals: [DayTotal]) -> Double {
    totals.reduce(0) { $0 + $1.standardDrinks }
  }

  /// Number of days in the range with nothing logged.
  public static func daysWithoutDrinks(_ totals: [DayTotal]) -> Int {
    totals.count { $0.standardDrinks == 0 }
  }
}
