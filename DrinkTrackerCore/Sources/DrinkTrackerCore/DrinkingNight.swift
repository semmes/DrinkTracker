import Foundation

/// One night of the log, named for its evening, and the three windows that
/// decide what belongs to it (ADR-0048).
///
/// The app's day is the calendar day (`Calendar.startOfDay`), and `SessionPace`
/// works on absolute instants so midnight cannot split a sitting. Neither
/// answers the question the health pairing asks — *the drinks on the evening
/// of the 14th, and the sleep that followed them* — because that sleep mostly
/// happens on the 15th. So a night is its own unit, keyed by the calendar day
/// its evening falls on, with a window for each thing that can belong to it:
///
/// - `drinkWindow`, 06:00 on the evening's day to 06:00 the next day. A drink
///   at 3 a.m. belongs to the night before it; a drink at 9 a.m. to the night
///   that follows it. Six is the hour the Health app's own sleep chart ticks
///   at, and it is the point where "the sleep that follows this drink" flips
///   from last night's to tonight's.
/// - `sleepDay`, 18:00 on the evening's day to 18:00 the next day — the Health
///   app's sleep day, read off the app itself in Phase 0 (Apple publishes no
///   rule): a session is filed, whole, under the sleep day that holds its
///   middle, naps are summed in, and Health names the day for the morning
///   inside it. This type names the same day for its evening, so Health's
///   "Sep 15" is this night's Sep 14. No surface prints a night's date, so the
///   two names never meet; what has to agree is which samples are counted,
///   and that is what the window pins.
/// - `dayAfter`, the calendar day after the evening, for a figure Health keeps
///   per calendar day (resting heart rate is one): the day the night wakes
///   into, whose figure the night's sleep is inside.
///
/// Under every attribution, then, a night's health value comes from "the day
/// after, in that type's own sense of a day". Everything is computed in the
/// calendar handed in — the device's current zone, as the rest of the app keys
/// its days — and re-normalised through `startOfDay` at each step, the lesson
/// `TrendSummary.dayKeys` learned from zones that change their clocks at
/// midnight.
public struct DrinkingNight: Hashable, Sendable {
  /// The start of the calendar day this night is named for: its evening.
  public let evening: Date
  /// Drinks logged in here belong to this night. Half-open at its end.
  public let drinkWindow: DateInterval
  /// Health's day for the sleep that follows the evening. Half-open at its end.
  public let sleepDay: DateInterval
  /// The calendar day after the evening. Half-open at its end.
  public let dayAfter: DateInterval

  /// The hour a night's drinks begin to count, and the hour they stop.
  public static let drinkWindowOpensAtHour = 6
  /// The hour Health's sleep day turns over. Unpublished; measured, not read
  /// from a document — `docs/health-pairing-phase-0-findings.md`.
  public static let sleepDayBoundaryHour = 18

  /// The night named for the calendar day containing `evening`, or nil if
  /// the calendar cannot place its boundaries.
  public init?(evening: Date, calendar: Calendar) {
    let day = calendar.startOfDay(for: evening)
    guard
      let next = calendar.date(byAdding: .day, value: 1, to: day),
      let after = calendar.date(byAdding: .day, value: 2, to: day)
    else { return nil }
    let nextDay = calendar.startOfDay(for: next)
    let dayAfterEnd = calendar.startOfDay(for: after)
    guard
      let opens = Self.boundary(hour: Self.drinkWindowOpensAtHour, on: day, calendar: calendar),
      let closes = Self.boundary(hour: Self.drinkWindowOpensAtHour, on: nextDay, calendar: calendar),
      let sleepStart = Self.boundary(hour: Self.sleepDayBoundaryHour, on: day, calendar: calendar),
      let sleepEnd = Self.boundary(hour: Self.sleepDayBoundaryHour, on: nextDay, calendar: calendar),
      opens < closes, sleepStart < sleepEnd, nextDay < dayAfterEnd
    else { return nil }
    self.evening = day
    self.drinkWindow = DateInterval(start: opens, end: closes)
    self.sleepDay = DateInterval(start: sleepStart, end: sleepEnd)
    self.dayAfter = DateInterval(start: nextDay, end: dayAfterEnd)
  }

  /// The night whose drink window holds `instant`: the instant's own day if
  /// it is 06:00 or later, otherwise the day before.
  public static func containing(_ instant: Date, calendar: Calendar) -> DrinkingNight? {
    let day = calendar.startOfDay(for: instant)
    guard let opens = boundary(hour: drinkWindowOpensAtHour, on: day, calendar: calendar) else {
      return nil
    }
    if instant >= opens { return DrinkingNight(evening: day, calendar: calendar) }
    guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return nil }
    return DrinkingNight(evening: previous, calendar: calendar)
  }

  /// `hour`:00 on the calendar day that starts at `day`. On a day whose clocks
  /// skip that hour the calendar answers with the next instant that exists.
  static func boundary(hour: Int, on day: Date, calendar: Calendar) -> Date? {
    calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
  }
}

extension DateInterval {
  /// Half-open membership. `contains(_:)` is inclusive at both ends, which
  /// would file an instant on a boundary under two nights at once.
  func holds(_ instant: Date) -> Bool {
    start <= instant && instant < end
  }
}
