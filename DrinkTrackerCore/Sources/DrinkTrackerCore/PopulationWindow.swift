import Foundation

// The population comparison's window and the two averages it takes
// (ADR-0030): the shipped trailing four weeks, and the trailing twelve months
// once the record is long enough — the survey's own measure is a yearly one,
// and a single heavy week moves a four-week average by a quarter. The gate
// that picks the window compares instants (how old the first record is); the
// average inside it is keyed by calendar day, on the same day keys the
// drinking-days line counts, over a fixed divisor (ADR-0030's amendment of
// 2026-09-07). The arithmetic lived in the view until now; here it is
// testable and shared with the year view.

extension PopulationReference {

  /// Which span the weekly average covers.
  public enum Window: Equatable, Sendable {
    /// The last 28 calendar days, divided by 4 — the 1.2 rule.
    case fourWeeks
    /// The last 52 whole weeks (364 calendar days), divided by 52.
    case twelveMonths

    /// The age the first recorded fact must reach for `window(firstRecord:now:)`
    /// to pick this window — an interval, because the gate compares two
    /// instants. Nothing else reads it: the average and the day count walk
    /// `days` instead.
    public var length: TimeInterval {
      switch self {
      case .fourWeeks: 28 * 24 * 60 * 60
      case .twelveMonths: 364 * 24 * 60 * 60
      }
    }

    /// The fixed divisor. It does not vary with how much of the window is
    /// logged — the shipped rule, kept (ADR-0018).
    public var weeks: Double {
      switch self {
      case .fourWeeks: 4
      case .twelveMonths: 52
      }
    }

    /// How many calendar days the window holds — the span both of the card's
    /// lines cover, walked with `TrendSummary.trailingDays`.
    public var days: Int {
      switch self {
      case .fourWeeks: 28
      case .twelveMonths: 364
      }
    }
  }

  /// The window the record supports: twelve months once the first recorded
  /// fact (an entry or a marker) is 52 weeks old, four weeks once it is 28
  /// days old, nothing before that — the gate the card has always had.
  /// Deliberately still a comparison of instants: it measures how old the
  /// record is, not what is inside the window.
  public static func window(firstRecord: Date?, now: Date) -> Window? {
    guard let firstRecord else { return nil }
    let age = now.timeIntervalSince(firstRecord)
    if age >= Window.twelveMonths.length { return .twelveMonths }
    if age >= minimumHistory { return .fourWeeks }
    return nil
  }

  /// Average per week over `window` ending on the day containing `now`, in
  /// `region`'s units: every entry logged on one of the window's calendar
  /// days — the same `days` keys `FrequencyReference.drinkingDays` counts,
  /// from `TrendSummary.trailingDays`, the package's DST-safe walk — summed,
  /// over the fixed divisor. Until 2026-09-07 the filter was an instant cutoff
  /// (`now` less `length`), so the card's two lines could cover sets of drinks
  /// that differed by a partial day: an evening drink 28 days back, read the
  /// next morning, made the average positive over "0 of the last 28 days".
  /// Health imports count at the current region's grams (a known imprecision
  /// the contract records). An entry later today is inside the window; one
  /// dated on a later day is not — the day count's rule, which narrows the old
  /// "entries after `now` are not excluded".
  public static func weeklyAverage(
    _ drinks: [LoggedDrink],
    window: Window,
    endingAt now: Date,
    region: Region,
    calendar: Calendar = .current
  ) -> Double {
    let keys = Set(TrendSummary.trailingDays(count: window.days, endingOn: now, calendar: calendar))
    let total = drinks
      .filter { keys.contains(calendar.startOfDay(for: $0.loggedAt)) }
      .reduce(0.0) { $0 + $1.standardDrinks(in: region) }
    return total / window.weeks
  }

  /// The weekly average a whole window of calendar days implies — a
  /// complete year's summary, from the same fold the year view shows: the
  /// total over the window's weeks (`dayCount / 7`). Zero for an empty
  /// window; the comparison then says nothing, as it does for a zero
  /// average.
  public static func weeklyAverage(of summary: RecentSummary) -> Double {
    guard summary.dayCount > 0 else { return 0 }
    return summary.totalStandardDrinks / (Double(summary.dayCount) / 7)
  }
}
