import Foundation

/// A factual account of a window of days — the 30 trailing days, a calendar
/// month, or a calendar year (ADR-0026). The name predates the choice of
/// window; `dayCount` is the days the window actually covers after any clip
/// at today.
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

/// Which span the calendar's summary card covers (ADR-0026).
///
/// A display choice over the same figures, never a change to how a day is
/// counted. Stored by raw value in `AppSettings` — the raw strings are the
/// stored contract, so a rename is a migration, not a refactor. Carries no
/// display names on purpose: the picker's labels are app-catalog `Text`
/// literals (ADR-0020's presentational clause), so no core key can collide
/// by case. Two cases and no third: the year view has exactly one window —
/// the year shown — and offers no choice, so nothing here names it.
public enum CalendarSummaryWindow: String, CaseIterable, Identifiable, Sendable {
  /// The 30 days ending today, wherever the grid is paged. The shipped
  /// behaviour, the window ADR-0006 was decided on, and the default.
  case lastThirtyDays
  /// The month the grid shows: whole once it has ended, the 1st through
  /// today while in progress.
  case monthShown

  public var id: String { rawValue }
}

extension TrendSummary {

  /// ADR-0006's figures over a set of grid cells: three day-counts that
  /// partition the cells, the total, and the mean over drinking days only.
  ///
  /// One classification, shared with `DayIntensity.bucket` and therefore with
  /// the grid's colours: a cell with entries is a day with drinks — even at a
  /// total of 0.0, which a 0% drink produces — else a marked cell is
  /// alcohol-free, else it is unlogged. Because the month card and the year
  /// card hand in the very cells the grids draw, the card cannot disagree
  /// with the picture above it. `dayCount` is `days.count`; an empty list
  /// yields all zeros and no division — which is also what a window that
  /// ends before it starts produces.
  public static func summary(of days: [CalendarDay]) -> RecentSummary {
    var withDrinks = 0
    var alcoholFree = 0
    var unlogged = 0
    var total = 0.0

    for day in days {
      if day.hasEntries {
        withDrinks += 1
        total += day.standardDrinks
      } else if day.isMarkedAlcoholFree {
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

  /// One `CalendarDay` per start-of-day key — the construction `monthGrid`
  /// already uses, with the same predicate for "has entries": a key present
  /// in `totalsByDay`, whatever its total. Every window that is not a grid
  /// (the rolling 30 days, a chart bucket) is built through here, so there
  /// is one definition of a day for the summary to fold.
  static func calendarDays(
    _ keys: [Date],
    totalsByDay: [Date: Double],
    alcoholFreeDays: Set<Date>
  ) -> [CalendarDay] {
    keys.map { key in
      let total = totalsByDay[key]
      return CalendarDay(
        date: key,
        standardDrinks: total ?? 0,
        isMarkedAlcoholFree: alcoholFreeDays.contains(key),
        hasEntries: total != nil
      )
    }
  }

  /// The `count` days ending on `endingOn`, inclusive, oldest first — each one
  /// re-normalised with `startOfDay`, never trusted from the offset arithmetic.
  ///
  /// The reason is the midnight-DST rule `dayKeys` documents: on the day
  /// Santiago, Havana, Cairo or Beirut move their clocks at 00:00, `startOfDay`
  /// is 01:00, and `date(byAdding: .day, value: -k, to:)` from it lands on
  /// 01:00 of every earlier day — keys that match nothing in `totalsByDay`.
  /// The shipped `recentSummary` had exactly this: on that one day, 29 of 30
  /// days read unlogged. `count <= 0` is empty.
  static func trailingDays(count: Int, endingOn endDate: Date, calendar: Calendar) -> [Date] {
    guard count > 0 else { return [] }
    let lastDay = calendar.startOfDay(for: endDate)
    guard let first = calendar.date(byAdding: .day, value: -(count - 1), to: lastDay) else {
      return [lastDay]
    }
    return dayKeys(from: first, through: lastDay, calendar: calendar)
  }

  /// Summarises the `dayCount` days ending on `endingOn`, inclusive.
  ///
  /// Signature unchanged since ADR-0006. Now builds one `CalendarDay` per key
  /// from `trailingDays` and folds with `summary(of:)`, so the rolling window
  /// and the calendar windows cannot disagree about what a day is — and the
  /// walk is the package's one DST-safe day walk rather than a second loop.
  public static func recentSummary(
    dayCount: Int = 30,
    endingOn endDate: Date,
    totalsByDay: [Date: Double],
    alcoholFreeDays: Set<Date>,
    calendar: Calendar = .current
  ) -> RecentSummary {
    summary(
      of: calendarDays(
        trailingDays(count: dayCount, endingOn: endDate, calendar: calendar),
        totalsByDay: totalsByDay,
        alcoholFreeDays: alcoholFreeDays
      )
    )
  }

  /// `grid`'s cells up to and including the day containing `date`: the whole
  /// month once it has passed, "through today" while it is current, nothing
  /// if it has not started. A thin name over `summary(of: grid.days(through:))`
  /// so the calendar card and the share card call one function and can never
  /// disagree. Callers pass the clock in; nothing here reads it.
  public static func monthSummary(
    _ grid: MonthGrid,
    through date: Date,
    calendar: Calendar = .current
  ) -> RecentSummary {
    summary(of: grid.days(through: date, calendar: calendar))
  }

  /// The same clip over a year's twelve grids (`yearGrids`), January first:
  /// 365 or 366 days once the year has passed, the elapsed prefix while it is
  /// in progress, nothing for a year that has not begun.
  public static func yearSummary(
    _ grids: [MonthGrid],
    through date: Date,
    calendar: Calendar = .current
  ) -> RecentSummary {
    summary(of: grids.flatMap { $0.days(through: date, calendar: calendar) })
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
