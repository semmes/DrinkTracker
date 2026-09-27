import Foundation

/// What the tip jar says about an active recurring tip, and when its reminder
/// fires (ADR-0012 and its amendment of 2026-09-26).
///
/// The jar promises a local notification a week before each renewal, so that
/// cancelling before a charge is always realistic. Until 1.4 two things broke
/// that promise. The reminder was re-derived only while the tip jar screen was
/// open, so from the second renewal on it waited for someone to open that
/// screen. And a recurring tip that had been cancelled still read "Renews" and
/// still got a reminder that it renews. The app now re-derives this at launch
/// and on every foreground, from the latest entitlement and its renewal info,
/// through this one initialiser.
///
/// Date arithmetic only, and here rather than in the app so it is pinned at
/// tier 1: no test tier reaches StoreKit or the tip jar screen.
public struct SupportRenewal: Equatable, Sendable {
  public enum State: Equatable, Sendable {
    /// It renews on `date`, as far as this device knows.
    case renews
    /// It was cancelled and ends on `date`. Nothing renews, so nothing is
    /// reminded.
    case ends
  }

  public let state: State

  /// The end of the current period: the next renewal, or the last day.
  public let date: Date

  /// When the reminder fires, or nil when none is due: the tip ends, or the
  /// week before the renewal has already begun.
  public let reminderDate: Date?

  /// A week before the renewal.
  public static let reminderLead: TimeInterval = 7 * 24 * 60 * 60

  /// A reminder due within this much of now is not scheduled. It would fire
  /// at once, while the reader may still be on the screen that set it.
  public static let minimumNotice: TimeInterval = 60

  /// How many renewals ahead the reminders are scheduled: a year's worth for
  /// either tip, counted from the app's last launch or foreground. A reminder
  /// is a local notification, so it exists only once the app has run to
  /// schedule it; scheduling one a period ahead would leave a subscriber who
  /// stops opening the app with no reminder for the renewal after next, the
  /// person the reminder is most for. Their text holds either way ("Unless
  /// it's been cancelled…"), and every refresh replaces them.
  public static let monthlyReminderCount = 12
  public static let yearlyReminderCount = 2

  /// The reminder for this renewal and each of the next `count - 1`, one per
  /// period after `date`, each a week before its renewal, in order. An entry
  /// is nil when that reminder is not due: the first once its week has begun,
  /// and every one when the tip ends. Each later renewal is counted from `date`
  /// in the Gregorian calendar, in `timeZone`, because the App Store's periods
  /// are Gregorian whatever calendar the device shows; counted in a Hebrew or
  /// Islamic calendar they drift by up to weeks. The App Store's own dates for
  /// those renewals are not known in advance and may still differ by a day or
  /// so, which the reminder's wording allows for ("in about a week").
  public func reminderDates(
    every period: Calendar.Component,
    count: Int,
    timeZone: TimeZone,
    now: Date
  ) -> [Date?] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return (0..<max(count, 0)).map { n in
      guard state == .renews,
            let renewal = calendar.date(byAdding: period, value: n, to: date)
      else { return nil }
      let fireDate = renewal.addingTimeInterval(-Self.reminderLead)
      return fireDate > now.addingTimeInterval(Self.minimumNotice) ? fireDate : nil
    }
  }

  /// - Parameters:
  ///   - expiration: the latest recurring entitlement's expiration date, or
  ///     nil when there is no active recurring tip.
  ///   - willAutoRenew: the entitlement's renewal info, or nil when it could
  ///     not be read (offline, or unverified). Unknown is read as renewing: a
  ///     reminder that proves unneeded costs less than a charge nobody was
  ///     warned of.
  ///   - now: the moment of the refresh.
  /// - Returns: nil when there is nothing to say: no recurring tip, or one
  ///   whose period has already ended.
  public init?(expiration: Date?, willAutoRenew: Bool?, now: Date) {
    guard let expiration, expiration > now else { return nil }
    date = expiration
    if willAutoRenew == false {
      state = .ends
      reminderDate = nil
    } else {
      state = .renews
      let fireDate = expiration.addingTimeInterval(-Self.reminderLead)
      reminderDate = fireDate > now.addingTimeInterval(Self.minimumNotice) ? fireDate : nil
    }
  }
}
