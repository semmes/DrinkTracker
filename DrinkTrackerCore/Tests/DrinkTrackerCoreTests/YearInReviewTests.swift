import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0029: a complete year's review is its twelve month cards' totals as
/// bars, under the year card's own four figures, with the Trends Year line's
/// average — and nothing relative to any other year.
@Suite("Year in review")
struct YearInReviewTests {

  /// UTC, Gregorian, Sunday-first so the expected dates don't depend on the
  /// machine (the fixture `SummaryWindowTests` uses).
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func grids(_ year: Int, totals: [Date: Double], free: Set<Date> = []) -> [MonthGrid] {
    TrendSummary.yearGrids(year, totalsByDay: totals, alcoholFreeDays: free, calendar: calendar)
  }

  /// A whole past year, seen from well after it ended.
  private let later = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15

  // MARK: - The bars

  @Test("Each bar is that month's own total, and the bars sum to the year")
  func barsAreTheMonthCardsTotals() {
    let totals = [
      date(2025, 1, 10): 2.0, date(2025, 1, 20): 1.5,
      date(2025, 4, 5): 1.0,
      date(2025, 8, 20): 3.0, date(2025, 8, 21): 0.4,
      date(2025, 12, 31): 1.0
    ]
    let grids = grids(2025, totals: totals)
    let review = TrendSummary.yearInReview(grids, through: later, calendar: calendar)

    #expect(review.monthlyTotals.count == 12)
    #expect(abs(review.monthlyTotals[0] - 3.5) < 1e-9)
    #expect(review.monthlyTotals[1] == 0)
    #expect(abs(review.monthlyTotals[3] - 1.0) < 1e-9)
    #expect(abs(review.monthlyTotals[7] - 3.4) < 1e-9)
    #expect(abs(review.monthlyTotals[11] - 1.0) < 1e-9)

    // The month card's figure, month by month — the same function.
    for (grid, bar) in zip(grids, review.monthlyTotals) {
      let card = TrendSummary.monthSummary(grid, through: later, calendar: calendar)
      #expect(card.totalStandardDrinks == bar)
    }
    #expect(abs(review.monthlyTotals.reduce(0, +) - review.summary.totalStandardDrinks) < 1e-9)
  }

  @Test("The figures are the year card's own, whole")
  func figuresAreTheYearCards() {
    let totals = [date(2024, 2, 29): 2.0, date(2024, 7, 4): 4.0]
    let free: Set<Date> = [date(2024, 1, 1), date(2024, 12, 25)]
    let grids = grids(2024, totals: totals, free: free)
    let review = TrendSummary.yearInReview(grids, through: later, calendar: calendar)
    let card = TrendSummary.yearSummary(grids, through: later, calendar: calendar)

    #expect(review.summary == card)
    #expect(review.summary.dayCount == 366)
    #expect(review.summary.daysWithDrinks == 2)
    #expect(review.summary.daysAlcoholFree == 2)
    #expect(review.summary.daysUnlogged == 362)
  }

  // MARK: - The line

  @Test("The average is the total over twelve months, an unlogged month counting as zero")
  func averageIsTheTrendsMonthlyRule() {
    let totals = [date(2025, 3, 1): 6.0, date(2025, 9, 1): 6.0]
    let grids = grids(2025, totals: totals)
    let review = TrendSummary.yearInReview(grids, through: later, calendar: calendar)

    // 12 drinks over 12 months, ten of them with nothing logged: 1.0 — not
    // 6.0 over the two months with drinks. This is the Trends Year line's
    // rule (mean per complete month), and the card names it as such.
    #expect(abs(review.monthlyAverage - 1.0) < 1e-9)

    let periods = grids.map { grid in
      let month = TrendSummary.monthSummary(grid, through: later, calendar: calendar)
      return PeriodTotal(start: grid.month, standardDrinks: month.totalStandardDrinks, dayCount: month.dayCount)
    }
    #expect(TrendSummary.bucketAverage(periods, unit: .month, calendar: calendar) == review.monthlyAverage)
  }

  @Test("A year with nothing in it averages zero and still has an axis")
  func emptyYear() {
    let review = TrendSummary.yearInReview(grids(2025, totals: [:]), through: later, calendar: calendar)
    #expect(review.monthlyTotals == Array(repeating: 0, count: 12))
    #expect(review.monthlyAverage == 0)
    #expect(review.axisMaximum == 1)
    #expect(review.isOnRecord == false)
  }

  // MARK: - The axis

  @Test("The axis tops out at the tallest month rounded up to a whole drink")
  func axisRoundsUp() {
    func axis(_ tallest: Double) -> Double {
      TrendSummary.yearInReview(grids(2025, totals: [date(2025, 6, 1): tallest]), through: later, calendar: calendar)
        .axisMaximum
    }
    #expect(axis(12.0) == 12)
    #expect(axis(12.3) == 13)
    #expect(axis(0.2) == 1)
    #expect(axis(5.999) == 6)
  }

  @Test("A sum of tenths that lands a hair above a whole number does not grow the axis")
  func axisShavesFloatingNoise() {
    // 1.1 + 1.3 + 0.6, summed in date order, is 3.0000000000000004 in binary.
    let totals = [date(2025, 6, 1): 1.1, date(2025, 6, 2): 1.3, date(2025, 6, 3): 0.6]
    let review = TrendSummary.yearInReview(grids(2025, totals: totals), through: later, calendar: calendar)
    #expect(review.monthlyTotals[5] > 3.0)  // the noise is real
    #expect(review.axisMaximum == 3)         // and the axis ignores it
  }

  // MARK: - The gate

  @Test("A year is complete only once the calendar has moved past it")
  func completeness() {
    #expect(TrendSummary.isComplete(year: 2025, today: date(2026, 1, 1), calendar: calendar))
    #expect(TrendSummary.isComplete(year: 2025, today: date(2026, 9, 5, 12), calendar: calendar))
    #expect(!TrendSummary.isComplete(year: 2026, today: date(2026, 12, 31, 23), calendar: calendar))
    #expect(!TrendSummary.isComplete(year: 2027, today: date(2026, 9, 5), calendar: calendar))
  }

  @Test("A year is on record with one marker or one entry, and not otherwise")
  func onRecord() {
    let blank = TrendSummary.yearInReview(grids(2025, totals: [:]), through: later, calendar: calendar)
    #expect(!blank.isOnRecord)

    let marked = TrendSummary.yearInReview(
      grids(2025, totals: [:], free: [date(2025, 5, 5)]), through: later, calendar: calendar
    )
    #expect(marked.isOnRecord)

    // An entry at a total of 0.0 (a 0% drink) is still a record.
    let zeroDrink = TrendSummary.yearInReview(
      grids(2025, totals: [date(2025, 5, 5): 0]), through: later, calendar: calendar
    )
    #expect(zeroDrink.isOnRecord)
  }

  // MARK: - The clip

  @Test("Handed the year in progress, the bars stop at today and the average covers completed months only")
  func clipsLikeEveryOtherWindow() {
    let totals = [date(2026, 1, 15): 4.0, date(2026, 9, 3): 2.0, date(2026, 9, 20): 5.0]
    let review = TrendSummary.yearInReview(grids(2026, totals: totals), through: date(2026, 9, 5), calendar: calendar)

    #expect(review.summary.dayCount == 248)
    #expect(review.monthlyTotals[0] == 4.0)
    #expect(review.monthlyTotals[8] == 2.0)   // the 20th is not in the window
    #expect(review.monthlyAverage == 0.5)     // 4.0 over January–August, eight complete months
  }

  // MARK: - The lens

  @Test("Bars re-express under the current region; day counts do not move")
  func barsFollowTheRegionLens() {
    let beers = [
      LoggedDrink(loggedAt: date(2025, 3, 1, 12), type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedKingdom),
      LoggedDrink(loggedAt: date(2025, 6, 1, 12), type: .beer, volumeOunces: 12, abvPercent: 5, region: .australia)
    ]
    func review(in region: Region) -> YearInReview {
      TrendSummary.yearInReview(
        grids(2025, totals: TrendSummary.totalsByDay(beers, region: region, calendar: calendar)),
        through: later, calendar: calendar
      )
    }
    let us = review(in: .unitedStates)
    let uk = review(in: .unitedKingdom)
    #expect(abs(us.monthlyTotals[2] - 1.0) < 0.001)
    #expect(uk.monthlyTotals[2] > us.monthlyTotals[2])
    #expect(us.summary.daysWithDrinks == uk.summary.daysWithDrinks)
    #expect(us.axisMaximum == 1)
    #expect(uk.axisMaximum == 2)
  }
}
