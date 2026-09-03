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

/// One bar on the quarter/year charts: a calendar week or month of totals.
///
/// `dayCount` is the number of days of the period that fall inside the range —
/// the trailing period is usually partial ("this month so far"), and carrying
/// the count keeps that fact computable instead of implied.
public struct PeriodTotal: Identifiable, Hashable, Sendable {
  public let start: Date
  public let standardDrinks: Double
  public let dayCount: Int

  public var id: Date { start }

  public init(start: Date, standardDrinks: Double, dayCount: Int) {
    self.start = start
    self.standardDrinks = standardDrinks
    self.dayCount = dayCount
  }
}

/// The range a trend screen is showing.
///
/// Two models, on purpose. `week` and `month` are rolling windows of trailing
/// days, as they always were. `quarter` and `year` are calendar-bucketed — the
/// last 13 calendar weeks and the last 12 calendar months, current bucket
/// partial — because at that length people think in named weeks and months,
/// not day offsets, and a bar should mean "the week of the 4th", not "days
/// 63–70 before today". The chart label states which model is showing.
public enum TrendRange: String, CaseIterable, Identifiable, Sendable {
  case week
  case month
  case quarter
  case year

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .week: "Week"
    case .month: "Month"
    case .quarter: "Quarter"
    case .year: "Year"
    }
  }

  /// The calendar unit one chart bar aggregates. Daily bars stay readable to
  /// ~30 days; beyond that a bar per day is noise, so quarter buckets by week
  /// and year by month.
  public var bucket: Calendar.Component {
    switch self {
    case .week, .month: .day
    case .quarter: .weekOfYear
    case .year: .month
    }
  }

  /// How many buckets the range spans.
  public var bucketCount: Int {
    switch self {
    case .week: 7
    case .month: 30
    case .quarter: 13
    case .year: 12
    }
  }

  /// First day of the range, given its last day.
  ///
  /// Rolling ranges count trailing days. Bucketed ranges snap to the start of
  /// the calendar period `bucketCount - 1` periods back, so the range is
  /// N − 1 complete buckets plus the current partial one — and week starts
  /// follow the user's calendar (Sunday-first and Monday-first both work,
  /// like the calendar grid).
  public func startDate(endingOn endDate: Date, calendar: Calendar) -> Date {
    let lastDay = calendar.startOfDay(for: endDate)
    switch self {
    case .week, .month:
      return calendar.date(byAdding: .day, value: -(bucketCount - 1), to: lastDay) ?? lastDay
    case .quarter, .year:
      guard
        let back = calendar.date(byAdding: bucket, value: -(bucketCount - 1), to: lastDay),
        let interval = calendar.dateInterval(of: bucket, for: back)
      else { return lastDay }
      return interval.start
    }
  }
}

/// Pure aggregation over logged drinks. Kept free of SwiftUI and SwiftData
/// queries so the numbers behind the charts are directly testable.
public enum TrendSummary {

  /// Total standard drinks logged on a given calendar day, in `region`'s units.
  public static func total(
    for day: Date,
    in drinks: [LoggedDrink],
    region: Region,
    calendar: Calendar = .current
  ) -> Double {
    drinks
      .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
      .reduce(0) { $0 + $1.standardDrinks(in: region) }
  }

  /// One `DayTotal` per day across the range ending on `endingOn`, oldest first.
  ///
  /// Days with nothing logged are included with a total of zero so the chart
  /// keeps a continuous axis rather than collapsing empty days. Totals are
  /// summed once into a per-day table rather than filtering the whole log per
  /// day — a year of range over a long log would otherwise be quadratic.
  public static func dailyTotals(
    range: TrendRange,
    endingOn endDate: Date,
    drinks: [LoggedDrink],
    region: Region,
    calendar: Calendar = .current
  ) -> [DayTotal] {
    let lastDay = calendar.startOfDay(for: endDate)
    let firstDay = calendar.startOfDay(for: range.startDate(endingOn: endDate, calendar: calendar))

    var byDay: [Date: Double] = [:]
    for drink in drinks {
      let day = calendar.startOfDay(for: drink.loggedAt)
      guard day >= firstDay, day <= lastDay else { continue }
      byDay[day, default: 0] += drink.standardDrinks(in: region)
    }

    return dayKeys(from: firstDay, through: lastDay, calendar: calendar).map { day in
      DayTotal(date: day, standardDrinks: byDay[day] ?? 0)
    }
  }

  /// Start-of-day keys from `first` through `last`, oldest first — the one day
  /// walk every window in the package shares (ADR-0026): the chart's daily
  /// series, the rolling summary's trailing days, and a bucket's days.
  ///
  /// Re-normalised every step, never chained. In a zone whose clocks change
  /// at midnight (Santiago, Havana, Cairo, Beirut) the transition day has no
  /// 00:00 and `startOfDay` returns 01:00; adding a day to that keeps the
  /// 01:00, and a chained key never again equals a key built from
  /// `startOfDay`. Every later day read zero and the range lost its last day.
  /// US zones switch at 02:00 and never showed it. The rolling summary had
  /// the mirror image of the same bug — offsets chained *backwards* from the
  /// transition day — until it was routed through here. The guard that the
  /// walk advances is belt and braces: a calendar that returned the same day
  /// would otherwise never terminate.
  static func dayKeys(from first: Date, through last: Date, calendar: Calendar) -> [Date] {
    let lastDay = calendar.startOfDay(for: last)
    var keys: [Date] = []
    var day = calendar.startOfDay(for: first)
    while day <= lastDay {
      keys.append(day)
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      let normalized = calendar.startOfDay(for: next)
      guard normalized > day else { break }
      day = normalized
    }
    return keys
  }

  /// Groups daily totals into calendar buckets (weeks or months), oldest first.
  ///
  /// The quarter and year charts draw these instead of daily bars. Each
  /// bucket's `dayCount` is how many of the range's days landed in it, which
  /// is what lets `bucketAverage` tell a completed week from the partial one
  /// still in progress.
  public static func bucketed(
    _ totals: [DayTotal],
    by unit: Calendar.Component,
    calendar: Calendar = .current
  ) -> [PeriodTotal] {
    guard unit != .day else {
      return totals.map { PeriodTotal(start: $0.date, standardDrinks: $0.standardDrinks, dayCount: 1) }
    }
    var order: [Date] = []
    var sums: [Date: (drinks: Double, days: Int)] = [:]
    for total in totals {
      guard let start = calendar.dateInterval(of: unit, for: total.date)?.start else { continue }
      if sums[start] == nil { order.append(start) }
      sums[start, default: (0, 0)].drinks += total.standardDrinks
      sums[start]!.days += 1
    }
    return order.map { start in
      let entry = sums[start]!
      return PeriodTotal(start: start, standardDrinks: entry.drinks, dayCount: entry.days)
    }
  }

  /// Mean total per *completed* bucket — the average line on bucketed charts.
  ///
  /// The trailing bucket is usually partial ("this week" two days in), and a
  /// mean that included it would sag every time the period rolled over —
  /// reading as a drop that never happened. A bucket counts as completed when
  /// every day of its calendar period is inside the range. Returns nil when
  /// no bucket is complete, in which case the chart draws no line.
  public static func bucketAverage(
    _ buckets: [PeriodTotal],
    unit: Calendar.Component,
    calendar: Calendar = .current
  ) -> Double? {
    let completed = buckets.filter { bucket in
      guard let length = periodLength(of: unit, containing: bucket.start, calendar: calendar)
      else { return false }
      return bucket.dayCount == length
    }
    guard !completed.isEmpty else { return nil }
    return completed.reduce(0) { $0 + $1.standardDrinks } / Double(completed.count)
  }

  /// How many calendar days the period containing `date` holds.
  ///
  /// Counted in whole days, not elapsed time. A week that starts on a
  /// midnight-DST day begins at 01:00, and measured as an interval it is six
  /// days and twenty-three hours — `.day` said 6, the bucket held 7, and the
  /// week was never "complete". Day ordinals count the days that exist.
  static func periodLength(
    of unit: Calendar.Component,
    containing date: Date,
    calendar: Calendar
  ) -> Int? {
    guard let interval = calendar.dateInterval(of: unit, for: date),
      let first = calendar.ordinality(of: .day, in: .era, for: interval.start),
      let next = calendar.ordinality(of: .day, in: .era, for: interval.end)
    else { return nil }
    return next - first
  }

  /// Mean standard drinks per day across the range, including zero days.
  public static func dailyAverage(_ totals: [DayTotal]) -> Double {
    guard !totals.isEmpty else { return 0 }
    return totals.reduce(0) { $0 + $1.standardDrinks } / Double(totals.count)
  }

  public static func sum(_ totals: [DayTotal]) -> Double {
    totals.reduce(0) { $0 + $1.standardDrinks }
  }

  /// Number of days in the range whose total is zero — days with nothing
  /// logged, days marked no alcohol, and days whose only drinks are 0% ABV.
  /// Backs the "Days with no drinks logged" card (ADR-0028).
  public static func daysWithoutDrinks(_ totals: [DayTotal]) -> Int {
    totals.count { $0.standardDrinks == 0 }
  }
}
