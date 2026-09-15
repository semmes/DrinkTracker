import Foundation

extension LoggedDrink {
  /// The entry the wrist's − may remove: today's newest, when it is one the
  /// watch can remove cleanly (ADR-0043).
  ///
  /// `nil` when the day has nothing, when the newest entry is a mirror of
  /// another app's Health record (read-only everywhere — ADR-0014), or when
  /// the newest carries a Health sample the phone wrote. The watch has no
  /// HealthKit and cannot retire that sample, and deleting the row would leave
  /// Health holding a drink that no longer exists, permanently and silently —
  /// so the control is unavailable rather than wrong.
  ///
  /// Never skips to an older entry. Skipping would silently remove a drink the
  /// user did not point at, and on a screen this size there is no room to say
  /// which one went. In practice the newest entry is removable for as long as
  /// it is likely to matter: the entries the watch logs carry no sample until
  /// the phone next backfills them, so a mis-tap corrected in the next minute
  /// always has the control, and a drink from two hours ago, once the phone
  /// has been opened, does not.
  ///
  /// Pure over the day's rows so the rule is pinned at tier 1 rather than
  /// living in a view; the caller fetches at execution time, never from a
  /// captured snapshot, the way `TodayView`'s counter does.
  public static func removableNewest(
    in drinks: [LoggedDrink],
    on day: Date,
    calendar: Calendar = .current
  ) -> LoggedDrink? {
    let todays = drinks.filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
    guard let newest = todays.max(by: { $0.loggedAt < $1.loggedAt }) else { return nil }
    guard !newest.isImportedFromHealth, newest.healthKitSampleID == nil else { return nil }
    return newest
  }
}
