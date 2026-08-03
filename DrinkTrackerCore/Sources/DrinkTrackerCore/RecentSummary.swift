import Foundation

/// A factual account of the last N days.
///
/// This is deliberately **not** a score. A single number summarising your drinking
/// is a number that can go up and down, and a number that can go up and down is a
/// target — which is what the tone rules and App Store guideline 1.4.3 rule out.
/// It also creates a reason to under-log in order to protect it, and under-logging
/// is the specific failure this app exists to prevent. See ADR-0006.
///
/// So: counts and totals, each independently checkable against the log, with no
/// composite figure and no direction of travel.
public struct RecentSummary: Hashable, Sendable {
  /// How many days the window covers.
  public let dayCount: Int

  /// Days with at least one drink logged.
  public let daysWithDrinks: Int

  /// Days explicitly recorded as having no alcohol.
  public let daysAlcoholFree: Int

  /// Days with nothing recorded either way.
  public let daysUnlogged: Int

  public let totalStandardDrinks: Double

  /// Mean across days something was logged, ignoring alcohol-free and unlogged days.
  ///
  /// Averaging over the whole window instead would let a stretch of unlogged days
  /// quietly drag the figure down — an average that falls because you stopped
  /// recording is worse than no average.
  public let averageOnDrinkingDays: Double

  public init(
    dayCount: Int,
    daysWithDrinks: Int,
    daysAlcoholFree: Int,
    daysUnlogged: Int,
    totalStandardDrinks: Double,
    averageOnDrinkingDays: Double
  ) {
    self.dayCount = dayCount
    self.daysWithDrinks = daysWithDrinks
    self.daysAlcoholFree = daysAlcoholFree
    self.daysUnlogged = daysUnlogged
    self.totalStandardDrinks = totalStandardDrinks
    self.averageOnDrinkingDays = averageOnDrinkingDays
  }
}

extension TrendSummary {

  /// Summarises the `dayCount` days ending on `endingOn`, inclusive.
  public static func recentSummary(
    dayCount: Int = 30,
    endingOn endDate: Date,
    totalsByDay: [Date: Double],
    alcoholFreeDays: Set<Date>,
    calendar: Calendar = .current
  ) -> RecentSummary {
    let lastDay = calendar.startOfDay(for: endDate)
    let days = (0..<max(0, dayCount)).compactMap {
      calendar.date(byAdding: .day, value: -$0, to: lastDay)
    }

    var withDrinks = 0
    var alcoholFree = 0
    var unlogged = 0
    var total = 0.0

    for day in days {
      if let dayTotal = totalsByDay[day] {
        withDrinks += 1
        total += dayTotal
      } else if alcoholFreeDays.contains(day) {
        alcoholFree += 1
      } else {
        unlogged += 1
      }
    }

    return RecentSummary(
      dayCount: days.count,
      daysWithDrinks: withDrinks,
      daysAlcoholFree: alcoholFree,
      daysUnlogged: unlogged,
      totalStandardDrinks: total,
      averageOnDrinkingDays: withDrinks == 0 ? 0 : total / Double(withDrinks)
    )
  }

  /// The drink type logged most often, for seeding the calendar's quick log.
  ///
  /// `nil` when nothing has been logged yet, so the caller picks its own starting
  /// point rather than inheriting an arbitrary one from here.
  public static func mostLoggedType(in drinks: [LoggedDrink]) -> DrinkType? {
    let counts = drinks.reduce(into: [DrinkType: Int]()) { counts, drink in
      counts[drink.type, default: 0] += 1
    }
    // Ties break on DrinkType.allCases order rather than dictionary order, so the
    // same log always seeds the same type instead of shuffling between launches.
    return counts
      .max { a, b in
        if a.value != b.value { return a.value < b.value }
        let order = DrinkType.allCases
        return (order.firstIndex(of: a.key) ?? 0) > (order.firstIndex(of: b.key) ?? 0)
      }?
      .key
  }

  /// The most recently logged drink of `type`, for repeating its size and strength.
  public static func mostRecentDrink(
    ofType type: DrinkType,
    in drinks: [LoggedDrink]
  ) -> LoggedDrink? {
    drinks.filter { $0.type == type }.max { $0.loggedAt < $1.loggedAt }
  }
}
