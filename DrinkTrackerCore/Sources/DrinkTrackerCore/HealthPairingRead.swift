import Foundation

// The pure half of the health pairing's read layer (ADR-0049): which days a
// read covers, and the one breadcrumb a read leaves behind. `HealthKitService`
// owns the query itself and cannot be reached by any test tier, so everything
// here that decides what is asked for and what is recorded is a value the
// domain tests can pin.

extension HealthPairing {

  /// The calendar days a metric read covers for `range`: from the start of
  /// the range's first day up to, and never including, the day that holds
  /// `now`. Nil when nothing remains.
  ///
  /// Excluding the current day is what makes "retrospective only" a shape
  /// rather than a promise (plan, stop conditions): no read the pairing makes
  /// can return a figure from the day it is made on, so nothing built on it
  /// can become a live readout. Nothing is lost by the clip — a night counts
  /// only once the day after it has ended (ADR-0048, decision 4), so the
  /// newest day any night needs is yesterday's.
  ///
  /// The window starts on the range's own first day rather than the day
  /// after it; a per-day figure on that first day belongs to the night
  /// before the range, which the domain drops. Reading one spare day keeps
  /// the window a plain function of the range.
  public static func readWindow(
    for range: DateInterval,
    endingBefore now: Date,
    calendar: Calendar
  ) -> DateInterval? {
    let start = calendar.startOfDay(for: range.start)
    let today = calendar.startOfDay(for: now)
    let end = min(today, calendar.startOfDay(for: range.end))
    guard start < end else { return nil }
    return DateInterval(start: start, end: end)
  }

  /// How many calendar days `window` spans, for the breadcrumb: a property
  /// of the request, never of what came back. Counted as day keys rather
  /// than as elapsed days, because a window that starts on a day whose
  /// clocks changed at midnight starts at 01:00, and elapsed time truncated
  /// to whole days would count one short. Exact for the day-aligned windows
  /// `readWindow` makes; a window inside one day counts as one.
  public static func days(in window: DateInterval, calendar: Calendar) -> Int {
    guard window.end > window.start else { return 0 }
    return TrendSummary.dayKeys(
      from: window.start, through: window.end.addingTimeInterval(-1), calendar: calendar
    ).count
  }
}

extension Breadcrumb {

  /// `"<metric> · <days> days · <seconds> s"` — the whole of what a Health
  /// read leaves behind. Its three arguments are the only things this line
  /// can carry: what was asked for, how much of the calendar, and how long
  /// the store took. No value, no sample count, no count of days with data —
  /// each of those is a fact derived from Health, and this line is written
  /// into the App Group, which is exactly where nothing read from Health may
  /// go (ADR-0049; the owner's decision on the Phase 0 findings, 2026-09-21).
  public static func healthRead(_ metric: String, days: Int, seconds: Double) -> String {
    let duration = seconds.isFinite && seconds >= 0 ? seconds : 0
    return "\(metric) · \(max(0, days)) days · \(String(format: "%.2f", duration)) s"
  }
}
