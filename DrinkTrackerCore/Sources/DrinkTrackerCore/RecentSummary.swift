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
    // Imported Health entries are count-only shells (type .other, zero volume);
    // seeding from one would template future drinks on data nobody entered.
    //
    // Untyped standard drinks are excluded for the mirror-image reason
    // (ADR-0023): the user declined to state a type, so counting that as a
    // vote would let "no answer" win the plurality and then hand itself back
    // as the seed. A log of nothing but untyped drinks returns nil here, and
    // the caller falls to its own starting point — which for the counter is
    // another untyped drink, and for the typed path is beer.
    let counts = drinks.lazy.filter { !$0.isImportedFromHealth && !$0.isTypeUnspecified }
      .reduce(into: [DrinkType: Int]()) { counts, drink in
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
    drinks
      .filter { $0.type == type && !$0.isImportedFromHealth }
      .max { $0.loggedAt < $1.loggedAt }
  }

  /// The most recently logged drink on `day`, for the day sheet's minus.
  ///
  /// The sheet lists that day newest-first, so removing the most recent means the
  /// tap takes away the row the user sees on top — the same rule Today's counter
  /// follows.
  public static func mostRecentDrink(
    on day: Date,
    in drinks: [LoggedDrink],
    calendar: Calendar = .current
  ) -> LoggedDrink? {
    drinks
      .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
      .max { $0.loggedAt < $1.loggedAt }
  }

  /// When a single counted drink lands on `day` (the day sheet's plus, ADR-0013).
  ///
  /// Today logs at `now`, exactly as Today's own counter does. A past day anchors
  /// at noon — a midnight stamp sits on the boundary, and a later timezone shift
  /// would move it to the day before — but always lands *after* the day's existing
  /// entries: the drink a plus creates must be the day's most recent, so a minus
  /// right after removes that drink and never a real one. The strictly increasing
  /// stamps this produces also keep tied-row ordering deterministic (ADR-0003).
  /// Clamped to the day's last second so the stamp can never spill into the next
  /// day.
  public static func backfillTimestamp(
    on day: Date,
    existing drinks: [LoggedDrink],
    calendar: Calendar = .current,
    now: Date = Date()
  ) -> Date {
    if calendar.isDate(day, inSameDayAs: now) { return now }

    let startOfDay = calendar.startOfDay(for: day)
    let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    let latest = drinks
      .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
      .map(\.loggedAt)
      .max()
    guard let latest else { return noon }

    let lastSecond = calendar.date(byAdding: .day, value: 1, to: startOfDay)?
      .addingTimeInterval(-1) ?? noon
    return min(max(noon, latest.addingTimeInterval(1)), lastSecond)
  }
}
