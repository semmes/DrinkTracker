import Foundation

/// The current sitting, if one is active (1.2 spec, Feature B; ADR-0017).
public struct DrinkSession: Hashable, Sendable {
  /// When the first drink of the run happened.
  public let start: Date
  /// When the most recent drink happened (clamped to `now` — see
  /// `SessionPace.currentSession`).
  public let lastDrinkAt: Date
  /// Drinks in the run: each typed entry is 1; a Health import contributes
  /// its count. A Double because external counts can be fractional.
  public let count: Double

  public init(start: Date, lastDrinkAt: Date, count: Double) {
    self.start = start
    self.lastDrinkAt = lastDrinkAt
    self.count = count
  }
}

/// Pure session-pace math. Deliberately calendar-free: sessions are runs of
/// absolute timestamps, so midnight, DST transitions, and time-zone changes
/// cannot split or double them (the spec's edge cases, pinned by tests).
///
/// `now` is always injected, never read — tests drive the clock.
///
/// The measurement-tool boundary this feature lives inside (the spec's three
/// hard rules, restated as ADR-0017): nothing here runs outside an active
/// session, nothing about gaps is ever persisted, and no notification exists.
/// A session "ending" is the absence of a value, not an event.
public enum SessionPace {

  /// A run of drinks where each is within this interval of the previous one.
  public static let gapThreshold: TimeInterval = 4 * 60 * 60

  /// The rolling window behind "N in the last 2 hours".
  public static let rollingWindow: TimeInterval = 2 * 60 * 60

  /// The rolling count is displayed only at or above this. Below it, the
  /// line adds nothing the session count doesn't already say.
  public static let rollingDisplayMinimum: Double = 3

  /// The active session, or nil when the last drink is more than
  /// `gapThreshold` ago — at which point nothing is written or recorded; the
  /// card simply stops existing.
  ///
  /// Timestamps after `now` (a device clock that jumped backwards, or skew
  /// on an entry synced from another device) are clamped to `now` rather
  /// than dropped: the drink is real and belongs to the sitting, and the
  /// clamp is what keeps elapsed time from ever reading negative.
  public static func currentSession(
    in drinks: [LoggedDrink],
    now: Date,
    gapThreshold: TimeInterval = gapThreshold
  ) -> DrinkSession? {
    let times = drinks
      .map { (at: min($0.loggedAt, now), count: $0.countedDrinks ?? 1) }
      .sorted { $0.at > $1.at }
    guard let mostRecent = times.first, now.timeIntervalSince(mostRecent.at) <= gapThreshold else {
      return nil
    }

    var start = mostRecent.at
    var count: Double = 0
    for entry in times {
      guard start.timeIntervalSince(entry.at) <= gapThreshold else { break }
      start = entry.at
      count += entry.count
    }
    return DrinkSession(start: start, lastDrinkAt: mostRecent.at, count: count)
  }

  /// Drinks inside `[now - window, now]`, inclusive at both ends.
  ///
  /// This, not time-since-last, is the number that tracks pace: someone deep
  /// into a fast run sees a "since last drink" clock that keeps resetting to
  /// near zero — calmest exactly when the pace is fastest. The rolling count
  /// is the primary signal; elapsed time is context (the spec's rationale).
  public static func rollingCount(
    in drinks: [LoggedDrink],
    now: Date,
    window: TimeInterval = rollingWindow
  ) -> Double {
    drinks
      // Future timestamps clamp to now, matching currentSession.
      .filter { now.timeIntervalSince(min($0.loggedAt, now)) <= window }
      .reduce(0) { $0 + ($1.countedDrinks ?? 1) }
  }
}
