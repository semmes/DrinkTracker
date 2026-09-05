import Foundation

/// The facts behind a year-in-review card (ADR-0029): ADR-0006's four figures
/// over one complete calendar year, and that year's twelve monthly totals as
/// the card's bars.
///
/// Every bar is the month card's own total — `monthSummary` over the month's
/// grid, the fold behind the calendar's card (ADR-0026) — so a reader can
/// check any bar against the month view that shows it. The average is the
/// rule the Trends Year chart already draws as "Your monthly average"
/// (`bucketAverage`), applied to a year whose every month is complete: the
/// sum over twelve months, with a month that has nothing logged counting as
/// zero. Nothing here is relative to another year, ranked, or scaled to
/// anything but the year's own tallest month; there is deliberately no field
/// for a delta, a trend, or a rate in a guideline's unit.
public struct YearInReview: Hashable, Sendable {
  /// The whole year's figures — `yearSummary`'s, 365 or 366 days.
  public let summary: RecentSummary

  /// One total per month, January first, in the caller's region (invariant
  /// 3: the same drinking re-expresses under another lens). Twelve for the
  /// twelve grids `yearGrids` builds.
  public let monthlyTotals: [Double]

  /// Mean total per complete month — the Trends Year line's rule. Zero when
  /// no month is complete, which the card's gate never lets happen.
  public let monthlyAverage: Double

  /// Top of the chart's axis: the tallest month rounded up to a whole
  /// drink, never below 1 so a year of zeros still has an axis to read.
  /// Bars scale against it and the middle tick is half of it.
  public let axisMaximum: Double

  /// Whether anything at all was recorded in the year — an entry or a
  /// no-alcohol marker on any day. A year with no record at all is not "on
  /// record" and gets no review card: twelve empty bars and "365 days have
  /// nothing logged either way" would be a picture of the app's install
  /// date, not of a year.
  public var isOnRecord: Bool {
    Self.isOnRecord(summary)
  }

  /// The same predicate over any window's summary, so a view that already
  /// holds the year's summary can gate on it without building the review.
  public static func isOnRecord(_ summary: RecentSummary) -> Bool {
    summary.daysUnlogged < summary.dayCount
  }

  public init(
    summary: RecentSummary,
    monthlyTotals: [Double],
    monthlyAverage: Double,
    axisMaximum: Double
  ) {
    self.summary = summary
    self.monthlyTotals = monthlyTotals
    self.monthlyAverage = monthlyAverage
    self.axisMaximum = axisMaximum
  }
}

extension TrendSummary {

  /// Whether every day of `year` lies before the day containing `today` —
  /// the year-in-review's gate. A year in progress is never reviewed: its
  /// bars would be partial and its average would sag with the trailing
  /// month, the sag `bucketAverage` exists to keep off the Trends chart.
  public static func isComplete(
    year: Int,
    today: Date,
    calendar: Calendar = .current
  ) -> Bool {
    year < calendar.component(.year, from: today)
  }

  /// The review of a year's twelve grids (`yearGrids`), clipped at the day
  /// containing `date` like every other window (ADR-0026).
  ///
  /// The clip is belt and braces: the card is offered only for a complete
  /// year, where `date` clips nothing. If a caller ever hands in the year in
  /// progress, the bars stop at today, the average covers the completed
  /// months only, and the summary's day count says how much of the year is
  /// in the picture — the same honesty the year card has.
  public static func yearInReview(
    _ grids: [MonthGrid],
    through date: Date,
    calendar: Calendar = .current
  ) -> YearInReview {
    let months = grids.map { monthSummary($0, through: date, calendar: calendar) }
    let totals = months.map(\.totalStandardDrinks)

    // The Trends Year line's own function, fed the same shape it gets from
    // `bucketed`: a month is complete when the clipped window holds every
    // day of it.
    let periods = zip(grids, months).map { grid, month in
      PeriodTotal(start: grid.month, standardDrinks: month.totalStandardDrinks, dayCount: month.dayCount)
    }
    let average = bucketAverage(periods, unit: .month, calendar: calendar) ?? 0

    // Rounded up from a hair below the value: a sum of tenths can land a
    // billionth above a whole number, and without the shave an exactly-12
    // month would draw a 13 axis. Over finite months only — a size field or
    // a Shortcuts variable can deliver an infinite volume (the 1.2 review's
    // population-reference trap), and an infinite axis would flatten every
    // real month to nothing; the corrupt month draws at full height instead.
    let tallest = totals.filter(\.isFinite).max() ?? 0
    let axisMaximum = max(1, (tallest - 1e-9).rounded(.up))

    return YearInReview(
      summary: yearSummary(grids, through: date, calendar: calendar),
      monthlyTotals: totals,
      monthlyAverage: average,
      axisMaximum: axisMaximum
    )
  }
}
