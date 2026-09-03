import Foundation

/// What was logged in one bar of the Trends chart, by kind (ADR-0028).
///
/// Rows come back in `DrinkType.allCases` order with Health imports last, so
/// the same log always lists the same way. `count` is entries for typed and
/// untyped rows — one entry is one drink (invariant 7) — and the summed
/// sample counts for imports, which is why it is a Double. `standardDrinks`
/// is the row's contribution to the bar in the caller's region: imports
/// contribute their count under every lens (ADR-0014); everything else
/// re-expresses (ADR-0002). A row an older build materialised with
/// `countedDrinks` stripped (ADR-0022) reads as `.type(.other)`, which is
/// what that row now is.
public struct DrinkShare: Hashable, Sendable, Identifiable {
  public enum Kind: Hashable, Sendable {
    case type(DrinkType)
    case importedFromHealth
  }

  public let kind: Kind
  public let count: Double
  public let standardDrinks: Double

  public var id: Kind { kind }

  public init(kind: Kind, count: Double, standardDrinks: Double) {
    self.kind = kind
    self.count = count
    self.standardDrinks = standardDrinks
  }
}

/// How one day stands in the log — the calendar's three-way split
/// (`DayIntensity`) without the magnitude buckets. Entries beat a marker,
/// exactly as `DayIntensity.bucket` decides it; a 0% drink is still `.drinks`.
public enum DayRecord: Hashable, Sendable {
  case drinks
  /// `fromHealth` is true when another app's zero put the marker there
  /// (ADR-0025), so the detail can say "From Apple Health" as the day sheet
  /// does.
  case alcoholFree(fromHealth: Bool)
  case unlogged
}

/// The facts behind one bar on the Trends chart: a calendar day (Week and
/// Month ranges), or a calendar week (Quarter) or month (Year) clipped to the
/// range (ADR-0028).
///
/// Every field is an independent, checkable figure in ADR-0006's sense.
/// Nothing here is expressed against the range's average, ranked against
/// other bars, or scaled to the range — the chart draws the average line;
/// this reports the bar. There is deliberately no field for a delta, and a
/// test pins that a day's detail is identical whichever range contains it.
public struct PeriodDetail: Hashable, Sendable {
  /// `.day`, `.weekOfYear`, or `.month` — `TrendRange.bucket`.
  public let unit: Calendar.Component
  /// The bar's key — equal to the `DayTotal.date` or `PeriodTotal.start` it
  /// describes, so a view matches it against the bars it drew by equality.
  public let start: Date
  /// Start of the bucket's last day inside the range. Equals `start` for a
  /// day bar.
  public let lastDay: Date
  /// Days the full calendar period holds — 1, 7, or 28–31 — counted in day
  /// ordinals, never elapsed hours (`TrendSummary.periodLength`'s reason).
  public let periodLength: Int
  /// ADR-0006's four figures plus the unlogged count, over `summary.dayCount`
  /// days — the days of the period that lie inside the range. Always
  /// `daysWithDrinks + daysAlcoholFree + daysUnlogged == dayCount`.
  public let summary: RecentSummary
  /// For a `.day` bar, which kind of day it is; nil for buckets, whose
  /// `summary` carries the counts.
  public let dayRecord: DayRecord?
  /// What was logged, by kind, in a stable order. Empty when nothing was.
  public let shares: [DrinkShare]

  /// True while the period runs past the range — the trailing bucket.
  public var isPartial: Bool { summary.dayCount < periodLength }

  /// The bar's height by another name; equal to the bar and to the sum of
  /// `shares` by test.
  public var standardDrinks: Double { summary.totalStandardDrinks }

  public init(
    unit: Calendar.Component,
    start: Date,
    lastDay: Date,
    periodLength: Int,
    summary: RecentSummary,
    dayRecord: DayRecord?,
    shares: [DrinkShare]
  ) {
    self.unit = unit
    self.start = start
    self.lastDay = lastDay
    self.periodLength = periodLength
    self.summary = summary
    self.dayRecord = dayRecord
    self.shares = shares
  }
}

extension TrendSummary {

  /// Start-of-day keys for every day of the range, oldest first — the same
  /// walk `dailyTotals` makes, so buckets and the detail see exactly the
  /// same days.
  static func days(in range: TrendRange, endingOn endDate: Date, calendar: Calendar) -> [Date] {
    dayKeys(from: range.startDate(endingOn: endDate, calendar: calendar), through: endDate, calendar: calendar)
  }

  /// The distinct bar keys of a range, oldest first: the day keys themselves
  /// on daily charts, the calendar-period starts `bucketed` keys on otherwise.
  static func bucketStarts(range: TrendRange, endingOn endDate: Date, calendar: Calendar) -> [Date] {
    let keys = days(in: range, endingOn: endDate, calendar: calendar)
    guard range.bucket != .day else { return keys }
    var order: [Date] = []
    var seen: Set<Date> = []
    for key in keys {
      guard let start = calendar.dateInterval(of: range.bucket, for: key)?.start else { continue }
      if seen.insert(start).inserted { order.append(start) }
    }
    return order
  }

  /// Start of the bar containing `date` on a chart of `range` ending on
  /// `endDate`, or nil when `date` falls outside the range's days.
  ///
  /// Selection hands back a continuous x value, so a touch past the last bar
  /// (the chart pads its domain) or before the first resolves to nothing —
  /// never a clamp to the nearest bar. Day keys are re-normalised through
  /// `startOfDay`; week and month starts come from `dateInterval(of:for:)`,
  /// which is what `bucketed` keys on, so on a midnight-DST day both agree
  /// on 01:00.
  public static func bucketStart(
    containing date: Date,
    range: TrendRange,
    endingOn endDate: Date,
    calendar: Calendar = .current
  ) -> Date? {
    let day = calendar.startOfDay(for: date)
    let firstDay = calendar.startOfDay(for: range.startDate(endingOn: endDate, calendar: calendar))
    let lastDay = calendar.startOfDay(for: endDate)
    guard day >= firstDay, day <= lastDay else { return nil }
    guard range.bucket != .day else { return day }
    return calendar.dateInterval(of: range.bucket, for: day)?.start
  }

  /// The bar after (`direction > 0`) or before (`direction < 0`) the bar at
  /// `start`, for VoiceOver's adjustable stepping; nil at either end of the
  /// range, and nil if `start` is not a bar.
  public static func adjacentBucketStart(
    from start: Date,
    direction: Int,
    range: TrendRange,
    endingOn endDate: Date,
    calendar: Calendar = .current
  ) -> Date? {
    let starts = bucketStarts(range: range, endingOn: endDate, calendar: calendar)
    guard let index = starts.firstIndex(of: start) else { return nil }
    let next = index + (direction > 0 ? 1 : -1)
    return starts.indices.contains(next) ? starts[next] : nil
  }

  /// The facts behind the bar containing `date`, or nil when `date` is
  /// outside the range.
  ///
  /// `healthMarkedDays` is the subset of `alcoholFreeDays` another app's
  /// zero put there (ADR-0025); the view passes both sets, as `CalendarView`
  /// does. The period's days are the range's own walk (`days(in:)`) filtered
  /// to the bucket, so a Santiago week that begins at 01:00 still yields
  /// seven keys matching `alcoholFreeDays` and the per-day sums. One pass
  /// over `drinks` plus the bucket's days — nothing quadratic — so a scrub
  /// across a month re-runs it per frame without a cache.
  public static func periodDetail(
    containing date: Date,
    range: TrendRange,
    endingOn endDate: Date,
    drinks: [LoggedDrink],
    alcoholFreeDays: Set<Date>,
    healthMarkedDays: Set<Date> = [],
    region: Region,
    calendar: Calendar = .current
  ) -> PeriodDetail? {
    guard let start = bucketStart(containing: date, range: range, endingOn: endDate, calendar: calendar)
    else { return nil }
    let unit = range.bucket

    let bucketDays = days(in: range, endingOn: endDate, calendar: calendar).filter { key in
      unit == .day ? key == start : calendar.dateInterval(of: unit, for: key)?.start == start
    }
    guard let lastDay = bucketDays.last else { return nil }

    let periodLength = unit == .day
      ? 1
      : (periodLength(of: unit, containing: start, calendar: calendar) ?? bucketDays.count)

    let bucketSet = Set(bucketDays)
    let inBucket = drinks.filter { bucketSet.contains(calendar.startOfDay(for: $0.loggedAt)) }
    let totalsByDay = totalsByDay(inBucket, region: region, calendar: calendar)
    let summary = summary(
      of: calendarDays(bucketDays, totalsByDay: totalsByDay, alcoholFreeDays: alcoholFreeDays)
    )

    var dayRecord: DayRecord?
    if unit == .day {
      if totalsByDay[start] != nil {
        dayRecord = .drinks
      } else if alcoholFreeDays.contains(start) {
        dayRecord = .alcoholFree(fromHealth: healthMarkedDays.contains(start))
      } else {
        dayRecord = .unlogged
      }
    }

    return PeriodDetail(
      unit: unit,
      start: start,
      lastDay: lastDay,
      periodLength: periodLength,
      summary: summary,
      dayRecord: dayRecord,
      shares: shares(of: inBucket, region: region)
    )
  }

  /// What was logged among `drinks`, by kind, in a stable order (see
  /// `DrinkShare`). `region` is the caller's current region, never the
  /// entry's (invariant 3).
  public static func shares(of drinks: [LoggedDrink], region: Region) -> [DrinkShare] {
    var sums: [DrinkShare.Kind: (count: Double, drinks: Double)] = [:]
    for drink in drinks {
      let kind: DrinkShare.Kind = drink.isImportedFromHealth ? .importedFromHealth : .type(drink.type)
      var entry = sums[kind, default: (0, 0)]
      entry.count += drink.isImportedFromHealth ? (drink.countedDrinks ?? 0) : 1
      entry.drinks += drink.standardDrinks(in: region)
      sums[kind] = entry
    }
    let order: [DrinkShare.Kind] = DrinkType.allCases.map { .type($0) } + [.importedFromHealth]
    return order.compactMap { kind in
      sums[kind].map { DrinkShare(kind: kind, count: $0.count, standardDrinks: $0.drinks) }
    }
  }
}
