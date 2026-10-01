import Foundation

// Trends on one window (ADR-0058). Every figure under the range picker whose
// denominator is a count of days reads one set of days: the range's own day
// walk, cut at the first record's day while the log is younger than the range.
//
// Until ADR-0058 two of the three published comparisons ignored the picker:
// they read ADR-0030's window, 28 days and then 364 once the record was a year
// old, through their own queries and their own clock, so at Quarter the card
// read 12.5 a week over 28 days under a chart reading 158.9 over 88. Now the
// comparisons fold the same days the chart card's header folds, so their
// figures are the header's figures and cannot drift from them.
//
// What the window changes is the denominators, never the counts. No day
// before the first record holds an entry or a marker, so the range's total,
// its days with drinks and its longest run are the same over either set; what
// a young log used to get wrong was counting the days before its first record
// as days without a drink. So while the log is younger than the range, the
// dashed line, the per-day card, the days with no drinks logged, the weekday
// rows and the three comparisons all divide by the days since the first
// record, and the screen says so ("Since Aug 12"). The bars keep the range:
// the picker's promise is the span of the x axis, and a week before the first
// record draws as it always has, with nothing in it.
//
// The comparisons add one gate of their own, the record's: they appear once
// the log holds 28 days of record, at every range, Week included. That is
// ADR-0018's floor, kept, and day-keyed for the first time (the reopen
// ADR-0030's 2026-09-07 amendment named): the first entry or no-alcohol
// record falls 27 or more days before today. It replaces ADR-0030's year of
// record and ADR-0038's four weeks of range. A gate on how much has been
// recorded says nothing about what was recorded (ADR-0038's rule).

/// The days a Trends range's day-count figures cover (ADR-0058): the range's
/// own, or, while the log is younger than the range, the range's from the
/// first record's day.
public struct TrendWindow: Hashable, Sendable {
  /// The fewest days of record before a published figure is placed beside the
  /// reader's: ADR-0018's four weeks, counted in day keys since ADR-0058, and
  /// one floor for all three comparisons at every range. Below it a weekly
  /// average is noise (ADR-0018). It is a floor on how long the record is, not
  /// on the window: at Week, above it, the figures rest on seven days and the
  /// weekend split on three, which ADR-0058's first decision accepts. The
  /// reader's own figures — the line and the cards — have no floor; they divide
  /// by the window's days however few there are.
  public static let comparisonFloor = 28

  /// The range the picker chose. The window never reaches past it.
  public let range: TrendRange
  /// Start-of-day keys the window covers, oldest first — a suffix of the
  /// range's own keys, walked by the package's one DST-safe day walk.
  public let days: [Date]
  /// Whether the window starts at the first record's day rather than the
  /// range's first day: the log is younger than the range. Wherever the
  /// window's figures are labelled, the label then says "since" that day.
  public let isClipped: Bool
  /// Whether the record holds `comparisonFloor` days: the first record's day
  /// is that many days back, counting today, or further. A fact about how
  /// much has been recorded, never about what.
  public let clearsComparisonFloor: Bool

  init(range: TrendRange, days: [Date], isClipped: Bool, clearsComparisonFloor: Bool) {
    self.range = range
    self.days = days
    self.isClipped = isClipped
    self.clearsComparisonFloor = clearsComparisonFloor
  }

  /// How many days every figure over the window divides by.
  public var dayCount: Int { days.count }

  /// The window's first day: the range's first day, or the first record's day
  /// while the window is clipped — the date a "Since" label names.
  public var firstDay: Date? { days.first }
}

extension TrendSummary {

  /// The window a Trends range's day-count figures cover, ending on the day
  /// containing `endDate` (ADR-0058).
  ///
  /// `firstRecord` is the earliest recorded fact — an entry or a no-alcohol
  /// marker, whichever is older — or nil for an empty log. The window is
  /// clipped only when that fact's day falls inside the range after its first
  /// day; a record older than the range leaves the range whole, and so does
  /// no record through today (an empty log, or one whose only rows are dated
  /// later than today): nothing was recorded inside the range, so there is no
  /// first day to cut it at, and the figures read the range as they always did.
  ///
  /// The floor is counted in day keys, not instants, and a record's day counts
  /// whole: a record made at 23:59 on 3 September clears it from 00:00 on 30
  /// September, the day 3 September becomes the 28th day back counting today —
  /// 26 days and a minute after it was made. The interval rule ADR-0030 used
  /// (28 × 24 hours) cleared the same record at 23:59 on 1 October.
  ///
  /// A no-alcohol marker's day is a start-of-day instant from the zone it was
  /// written in, read here in the current one, as every surface reads it; a
  /// marker written east of the reader dates the window, and the floor, from the
  /// day before (ADR-0058's readings, the "markers stored as instants" limit).
  public static func trendWindow(
    range: TrendRange,
    endingOn endDate: Date,
    firstRecord: Date?,
    calendar: Calendar = .current
  ) -> TrendWindow {
    let rangeKeys = days(in: range, endingOn: endDate, calendar: calendar)
    guard let firstRecord else {
      return TrendWindow(range: range, days: rangeKeys, isClipped: false, clearsComparisonFloor: false)
    }
    let recordDay = calendar.startOfDay(for: firstRecord)
    let lastDay = calendar.startOfDay(for: endDate)
    // The 28th day back, counting today: the day the record has to reach. The
    // trailing walk re-normalises every key, so on a midnight-DST day this is
    // the same 01:00 key `startOfDay` gives the record.
    let floorDay = trailingDays(count: TrendWindow.comparisonFloor, endingOn: endDate, calendar: calendar).first
    let clears = floorDay.map { recordDay <= $0 } ?? false
    guard let rangeFirst = rangeKeys.first, recordDay > rangeFirst, recordDay <= lastDay else {
      return TrendWindow(range: range, days: rangeKeys, isClipped: false, clearsComparisonFloor: clears)
    }
    return TrendWindow(
      range: range,
      days: rangeKeys.filter { $0 >= recordDay },
      isClipped: true,
      clearsComparisonFloor: clears
    )
  }

  /// The comparisons' window: `trendWindow`'s, or nil while the record is under
  /// the floor — the one gate the three published comparisons share, at every
  /// range (ADR-0058). A window, not a flag, so a comparison cannot be drawn
  /// without the days it covers.
  public static func comparisonWindow(
    range: TrendRange,
    endingOn endDate: Date,
    firstRecord: Date?,
    calendar: Calendar = .current
  ) -> TrendWindow? {
    let window = trendWindow(range: range, endingOn: endDate, firstRecord: firstRecord, calendar: calendar)
    return window.clearsComparisonFloor ? window : nil
  }

  /// A fold's total over its weeks: the total divided by (days ÷ 7) — one
  /// function behind the weekly average the comparison places beside the
  /// survey, the dashed line at Quarter, and a complete year's weekly average
  /// on the year view, so the three can never print two numbers for one week.
  /// A window of exactly seven days is its own total. Zero for an empty fold;
  /// the comparison then says nothing, as it does for a zero average.
  public static func weeklyFigure(of summary: RecentSummary) -> Double {
    guard summary.dayCount > 0 else { return 0 }
    return summary.totalStandardDrinks / (Double(summary.dayCount) / 7)
  }

  /// The window's figures, folded from the range's classified days — the days
  /// `rangeDays` returns for the same range, end and log, which hold every day
  /// of the window. Trends already classifies the range once for its header,
  /// so the window costs a filter, not another pass over the log.
  public static func windowFold(
    of rangeDays: [CalendarDay],
    in window: TrendWindow,
    calendar: Calendar = .current
  ) -> TrendWindowFold {
    let keys = Set(window.days)
    let days = rangeDays.filter { keys.contains($0.date) }
    return TrendWindowFold(
      window: window,
      days: days,
      summary: summary(of: days),
      weekdays: weekdayTotals(of: days, calendar: calendar)
    )
  }

  /// The window and its figures, from the log: the window `trendWindow` cuts,
  /// folded over the range's own classified days.
  public static func windowFold(
    range: TrendRange,
    endingOn endDate: Date,
    drinks: [LoggedDrink],
    alcoholFreeDays: Set<Date>,
    firstRecord: Date?,
    region: Region,
    calendar: Calendar = .current
  ) -> TrendWindowFold {
    let window = trendWindow(range: range, endingOn: endDate, firstRecord: firstRecord, calendar: calendar)
    let days = rangeDays(
      range: range, endingOn: endDate, drinks: drinks,
      alcoholFreeDays: alcoholFreeDays, region: region, calendar: calendar
    )
    return windowFold(of: days, in: window, calendar: calendar)
  }
}

/// A Trends range's day-count figures over its window (ADR-0058): everything
/// the screen prints whose denominator is a count of days, from one
/// classification of the window's days.
public struct TrendWindowFold: Hashable, Sendable {
  public let window: TrendWindow
  /// The window's days, classified by `summary(of:)`'s one definition of a day.
  public let days: [CalendarDay]
  /// ADR-0006's figures over the window. Its total and its days with drinks
  /// equal the range's, because no day before the first record holds anything;
  /// its `dayCount` is the window's.
  public let summary: RecentSummary
  /// The window by weekday, seven rows in the calendar's order (ADR-0032).
  public let weekdays: [WeekdayTotal]

  init(window: TrendWindow, days: [CalendarDay], summary: RecentSummary, weekdays: [WeekdayTotal]) {
    self.window = window
    self.days = days
    self.summary = summary
    self.weekdays = weekdays
  }

  /// Mean per day over the window, days with nothing in them included — the
  /// per-day card, and the line at Week and Month.
  public var dailyAverage: Double {
    days.isEmpty ? 0 : summary.totalStandardDrinks / Double(days.count)
  }

  /// The window's days whose total is zero — the "Days with no drinks logged"
  /// card (ADR-0028): days with nothing logged, days recorded as no alcohol,
  /// and days whose only drinks are 0% ABV. Deliberately not the complement of
  /// `summary.daysWithDrinks`, which counts the last kind as days with drinks.
  public var daysWithoutDrinks: Int {
    days.count { $0.standardDrinks == 0 }
  }

  /// The window's total over its weeks (`TrendSummary.weeklyFigure`) — the
  /// weekly average the comparison places, and the line at Quarter.
  public var weeklyFigure: Double { TrendSummary.weeklyFigure(of: summary) }

  /// The dashed line's value, on the bars' own scale (ADR-0028, ADR-0058): per
  /// day at Week and Month; the window's weekly figure at Quarter, so the
  /// legend and the weekly-average comparison print one number, seven times the
  /// per-day average before either is rounded (the per-day card prints that
  /// average to one decimal, so seven times the printed card can differ by the
  /// rounding); and at Year the mean of the complete months inside the
  /// window, the line's rule unchanged — a month the window holds only part of
  /// (the one in progress, or, while the window is clipped, the month of the
  /// first record unless it fell on the 1st) is left out. nil at Year while no
  /// month is complete, in which case no line is drawn.
  ///
  /// Quarter has no such rule (decisions 3 and 5): a window shorter than a week
  /// still draws its weekly figure, its total times 7 over its days, so on a
  /// log's first days the line stands above every weekly bar — one day with 4
  /// drinks reads "Your weekly average · 28". Recorded in ADR-0058 and put to
  /// the owner; the one-line alternative is nil while `window.dayCount < 7`.
  public func averageLine(calendar: Calendar = .current) -> Double? {
    switch window.range {
    case .week, .month:
      return dailyAverage
    case .quarter:
      return weeklyFigure
    case .year:
      let totals = days.map { DayTotal(date: $0.date, standardDrinks: $0.standardDrinks) }
      let months = TrendSummary.bucketed(totals, by: .month, calendar: calendar)
      return TrendSummary.bucketAverage(months, unit: .month, calendar: calendar)
    }
  }
}

extension PopulationReference {
  /// The weekly average a whole window of calendar days implies — the year
  /// view's name for `TrendSummary.weeklyFigure`, kept so a complete year and a
  /// Trends range are compared by one function (ADR-0030, ADR-0058).
  public static func weeklyAverage(of summary: RecentSummary) -> Double {
    TrendSummary.weeklyFigure(of: summary)
  }
}
