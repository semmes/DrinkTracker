import Foundation

// The population comparison's window and the two averages it takes
// (ADR-0030): the shipped trailing four weeks, and the trailing twelve months
// once the record is long enough — the survey's own measure is a yearly one,
// and a single heavy week moves a four-week average by a quarter. Both are
// instant-based windows with a fixed divisor, as the card has always
// computed (the contract's "Your average" table). The arithmetic lived in the
// view until now; here it is testable and shared with the year view.

extension PopulationReference {

  /// Which span the weekly average covers.
  public enum Window: Equatable, Sendable {
    /// 28 days ending now, divided by 4 — the 1.2 rule.
    case fourWeeks
    /// 52 whole weeks (364 days) ending now, divided by 52.
    case twelveMonths

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

    /// How many calendar days the window holds, for the frequency measure.
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
  public static func window(firstRecord: Date?, now: Date) -> Window? {
    guard let firstRecord else { return nil }
    let age = now.timeIntervalSince(firstRecord)
    if age >= Window.twelveMonths.length { return .twelveMonths }
    if age >= minimumHistory { return .fourWeeks }
    return nil
  }

  /// Average per week over `window` ending at `now`, in `region`'s units:
  /// every entry logged at or after the cutoff, summed, over the fixed
  /// divisor. Health imports count at the current region's grams (a known
  /// imprecision the contract records). Entries dated after `now` are not
  /// excluded, as they never were.
  public static func weeklyAverage(
    _ drinks: [LoggedDrink],
    window: Window,
    endingAt now: Date,
    region: Region
  ) -> Double {
    let cutoff = now.addingTimeInterval(-window.length)
    let total = drinks
      .filter { $0.loggedAt >= cutoff }
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
