import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0030, ADR-0031, ADR-0032: the comparison window, the complete-year
/// average, the drinking-days reference, and the weekday fold.
@Suite("Insight references")
struct InsightReferenceTests {

  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func beer(_ at: Date, ounces: Double = 12) -> LoggedDrink {
    LoggedDrink(loggedAt: at, type: .beer, volumeOunces: ounces, abvPercent: 5, region: .unitedStates)
  }

  // MARK: - The window

  // ADR-0030's window followed the age of the record — 28 days, then 364 —
  // whatever the range picker said. ADR-0058 retired it: the comparisons fold
  // the Trends range's own days, cut at the first record's day while the log is
  // younger than the range, behind one floor of 28 days of record. Each test
  // below is the one that pinned the old rule, rewritten to pin its successor;
  // `TrendWindowTests` carries the new rule's own tests.

  private func fold(
    _ range: TrendRange,
    _ drinks: [LoggedDrink],
    endingOn now: Date,
    firstRecord: Date? = nil,
    region: Region = .unitedStates,
    calendar cal: Calendar? = nil
  ) -> TrendWindowFold {
    let cal = cal ?? calendar
    // A first record two years back by default, so the window is the range's
    // own: the tests here are about which days the range holds, not about a
    // young log.
    let first = firstRecord ?? cal.date(byAdding: .year, value: -2, to: now)!
    return TrendSummary.windowFold(
      range: range, endingOn: now, drinks: drinks, alcoholFreeDays: [],
      firstRecord: first, region: region, calendar: cal
    )
  }

  /// Was "The window follows the age of the first recorded fact": the record's
  /// age now gates, and only gates — the window is the range's.
  @Test("The comparisons wait for 28 days of record, whatever the range")
  func windowGate() {
    let now = date(2026, 9, 5)
    for range in TrendRange.allCases {
      func clears(_ first: Date?) -> Bool {
        TrendSummary.comparisonWindow(range: range, endingOn: now, firstRecord: first, calendar: calendar) != nil
      }
      #expect(!clears(nil))
      #expect(!clears(date(2026, 8, 10, 0)))   // 27 days of record, counting today
      #expect(clears(date(2026, 8, 9, 23)))    // 28: the 28th day back, at its last hour
      #expect(clears(date(2020, 1, 1)))
    }
  }

  /// Was "Four weeks is the shipped rule": Month's weekly figure is its 30
  /// days' total over 30 ÷ 7, the range's first day inside and the day before
  /// it outside.
  @Test("Month's weekly figure is its 30 days' total over 30 ÷ 7")
  func monthWeeklyFigure() {
    let now = date(2026, 9, 5)
    let drinks = [
      beer(date(2026, 9, 4)),
      beer(date(2026, 8, 7, 0)),   // the 30th day back, at its first minute: inside
      beer(date(2026, 8, 6, 23))   // the 31st: outside, though only 29 days and 13 hours before `now`
    ]
    let figure = fold(.month, drinks, endingOn: now).weeklyFigure
    let expected: Double = 2.0 / (30.0 / 7.0)
    #expect(abs(figure - expected) < 1e-9)
  }

  /// Was "Twelve months is 52 whole weeks of calendar days over a fixed 52":
  /// Year's weekly figure is its range's total over its own days ÷ 7, the
  /// range being the twelve calendar months the chart draws.
  @Test("Year's weekly figure is its twelve months' total over their days ÷ 7")
  func yearWeeklyFigure() {
    let now = date(2026, 9, 5)  // Year covers 1 Oct 2025 – 5 Sep 2026: 340 days
    var drinks: [LoggedDrink] = []
    for week in 0..<48 {  // one beer a week, the last one 330 days back
      drinks.append(beer(calendar.date(byAdding: .day, value: -(week * 7 + 1), to: now)!))
    }
    drinks.append(beer(date(2025, 10, 1, 0)))    // the range's first day, at its first minute: inside
    drinks.append(beer(date(2025, 9, 30, 23)))   // the day before: outside
    let year = fold(.year, drinks, endingOn: now)
    #expect(year.window.dayCount == 340)
    let expected: Double = 49.0 / (340.0 / 7.0)
    #expect(abs(year.weeklyFigure - expected) < 1e-9)
    // The same drinks over Month are the last month's five only.
    let month = fold(.month, drinks, endingOn: now)
    let expectedMonth: Double = 5.0 / (30.0 / 7.0)
    #expect(abs(month.weeklyFigure - expectedMonth) < 1e-9)
  }

  /// Was "The divisor never shrinks with a sparse window": it still never
  /// shrinks with how much of the window is logged. What sets it is the
  /// window's days — the range's, or the days since the first record.
  @Test("The divisor is the window's days, never the days logged")
  func divisorIsTheWindow() {
    let now = date(2026, 9, 5)
    let drinks = [beer(date(2026, 9, 5, 11))]
    // An old record: one drink over a sparse range still divides by all of it.
    let year = fold(.year, drinks, endingOn: now)
    let yearExpected: Double = 1.0 / (340.0 / 7.0)
    #expect(abs(year.weeklyFigure - yearExpected) < 1e-9)
    let month = fold(.month, drinks, endingOn: now)
    let monthExpected: Double = 1.0 / (30.0 / 7.0)
    #expect(abs(month.weeklyFigure - monthExpected) < 1e-9)
    // A log that began 14 days ago divides by those 14 days, at every range
    // longer than they are.
    let young = date(2026, 8, 23, 9)
    for range in [TrendRange.month, .quarter, .year] {
      let clipped = fold(range, drinks, endingOn: now, firstRecord: young)
      #expect(clipped.window.dayCount == 14)
      let expected: Double = 1.0 / (14.0 / 7.0)
      #expect(abs(clipped.weeklyFigure - expected) < 1e-9)
    }
  }

  /// The probe from the 1.3 review: an evening drink just outside the window,
  /// read the next morning, sits inside an instant cutoff and outside the
  /// window's days, and printed an average above zero over "0 of the last 28
  /// days". Both edges of the window are still calendar days: the far one, the
  /// range's first day, and the near one, where an entry later today counts
  /// and an entry dated tomorrow does not.
  @Test("Both edges of the window are calendar days, not instants")
  func edgesAreCalendarDays() {
    let morning = date(2026, 9, 5, 8)  // Month covers 7 August – 5 September
    func month(_ drinks: [LoggedDrink]) -> TrendWindowFold { fold(.month, drinks, endingOn: morning) }
    let oneDrinkWeekly: Double = 1.0 / (30.0 / 7.0)

    let probe = month([beer(date(2026, 8, 6, 21))])
    #expect(probe.weeklyFigure == 0)
    #expect(probe.summary.daysWithDrinks == 0)

    let firstMinute = month([beer(date(2026, 8, 7, 0))])
    #expect(abs(firstMinute.weeklyFigure - oneDrinkWeekly) < 1e-9)
    #expect(firstMinute.summary.daysWithDrinks == 1)

    let laterToday = month([beer(date(2026, 9, 5, 23))])
    #expect(abs(laterToday.weeklyFigure - oneDrinkWeekly) < 1e-9)
    #expect(laterToday.summary.daysWithDrinks == 1)
    let tomorrow = month([beer(date(2026, 9, 6, 0))])
    #expect(tomorrow.weeklyFigure == 0)
    #expect(tomorrow.summary.daysWithDrinks == 0)

    // The same at Year, whose first day is the 1st of a month eleven back.
    #expect(fold(.year, [beer(date(2025, 10, 1, 0))], endingOn: morning).weeklyFigure > 0)
    #expect(fold(.year, [beer(date(2025, 9, 30, 23))], endingOn: morning).weeklyFigure == 0)
  }

  /// One set of days, two lines: whatever the drinking-days count counts, the
  /// weekly figure sums, and nothing else. Checked drink by drink at every
  /// range and three reading times, so a drink one line includes and the other
  /// drops — or the reverse — names itself.
  @Test("The weekly figure and the drinking-days count cover one set of days")
  func averageAndDayCountAgree() {
    let readings = [date(2026, 9, 5, 0), date(2026, 9, 5, 8), date(2026, 9, 5, 23)]
    let candidates = [
      date(2026, 8, 5, 23), date(2026, 8, 6, 0), date(2026, 8, 6, 21), date(2026, 8, 6, 23),
      date(2026, 8, 7, 0), date(2026, 8, 7, 7), date(2026, 8, 7, 23),
      date(2026, 8, 29, 23), date(2026, 8, 30, 0),
      date(2026, 9, 5, 0), date(2026, 9, 5, 12), date(2026, 9, 5, 23),
      date(2026, 9, 6, 0), date(2026, 9, 6, 9),
      date(2026, 7, 4, 23), date(2026, 7, 5, 0), date(2026, 7, 5, 12),
      date(2025, 9, 30, 23), date(2025, 10, 1, 0), date(2025, 10, 1, 12)
    ]
    for now in readings {
      for range in TrendRange.allCases {
        for at in candidates {
          let one = fold(range, [beer(at)], endingOn: now)
          let counted = one.summary.daysWithDrinks == 1
          let summed = one.weeklyFigure > 0
          #expect(counted == summed, "\(at) read at \(now) over \(range): counted \(counted), summed \(summed)")
        }
      }
    }
    // And all at once: six of the candidates fall on Month's 30 days ending
    // September 5 — three on August 7, three on the 5th — and two more on
    // August 29 and 30, so four days and eight drinks.
    let all = fold(.month, candidates.map { beer($0) }, endingOn: readings[1])
    #expect(all.summary.daysWithDrinks == 4)
    let expected: Double = 8.0 / (30.0 / 7.0)
    #expect(abs(all.weeklyFigure - expected) < 1e-9)
  }

  /// Santiago moves its clocks at midnight on 2026-09-06: that day has no
  /// 00:00 and `startOfDay` is 01:00, the case the package's day walk exists
  /// for (ADR-0026). The window that ends on the transition day must hold the
  /// day itself and the 29 before it, and the two lines must agree across it.
  @Test("The weekly figure survives a midnight daylight-saving day, in step with the count")
  func averageOnTransitionDay() {
    var santiago = Calendar(identifier: .gregorian)
    santiago.timeZone = TimeZone(identifier: "America/Santiago")!
    santiago.firstWeekday = 1
    func at(_ month: Int, _ day: Int, _ hour: Int) -> Date {
      santiago.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
    let now = at(9, 6, 12)
    let drinks = [
      beer(at(9, 6, 1)),   // the transition day's first hour
      beer(at(9, 6, 11)),
      beer(at(9, 5, 23)),  // the last hour before the clocks moved
      beer(at(8, 8, 0)),   // the 30th day back: inside
      beer(at(8, 7, 23))   // the 31st: outside
    ]
    let month = fold(.month, drinks, endingOn: now, calendar: santiago)
    #expect(month.window.dayCount == 30)
    let expected: Double = 4.0 / (30.0 / 7.0)
    #expect(abs(month.weeklyFigure - expected) < 1e-9)
    #expect(month.summary.daysWithDrinks == 3)
    for drink in drinks {
      let one = fold(.month, [drink], endingOn: now, calendar: santiago)
      let counted = one.summary.daysWithDrinks == 1
      let summed = one.weeklyFigure > 0
      #expect(counted == summed, "\(drink.loggedAt): counted \(counted), summed \(summed)")
    }
  }

  @Test("The weekly figure re-expresses under the current region only")
  func windowFollowsTheLens() {
    let now = date(2026, 9, 5)
    let drinks = [beer(now.addingTimeInterval(-86400))]
    let us = fold(.month, drinks, endingOn: now, region: .unitedStates).weeklyFigure
    let uk = fold(.month, drinks, endingOn: now, region: .unitedKingdom).weeklyFigure
    #expect(uk > us)
    // And the comparison agrees in grams whichever lens produced it.
    let ref = try! #require(PopulationReference.bundled)
    #expect(ref.comparison(gramsPerWeek: us * Region.unitedStates.gramsPureAlcoholPerStandardDrink)
      == ref.comparison(gramsPerWeek: uk * Region.unitedKingdom.gramsPureAlcoholPerStandardDrink))
  }

  // MARK: - A complete year

  @Test("A year's weekly average is its total over its weeks")
  func yearWeeklyAverage() {
    let summary = RecentSummary(dayCount: 365, daysWithDrinks: 100, daysAlcoholFree: 0, daysUnlogged: 265,
                                totalStandardDrinks: 104.2857142857, averageOnDrinkingDays: 1.04)
    #expect(abs(PopulationReference.weeklyAverage(of: summary) - 2.0) < 1e-6)
    let leap = RecentSummary(dayCount: 366, daysWithDrinks: 1, daysAlcoholFree: 0, daysUnlogged: 365,
                             totalStandardDrinks: 52.2857142857, averageOnDrinkingDays: 52.29)
    #expect(abs(PopulationReference.weeklyAverage(of: leap) - 1.0) < 1e-6)
    let empty = RecentSummary(dayCount: 0, daysWithDrinks: 0, daysAlcoholFree: 0, daysUnlogged: 0, totalStandardDrinks: 0, averageOnDrinkingDays: 0)
    #expect(PopulationReference.weeklyAverage(of: empty) == 0)
    // One function behind the year view and Trends (ADR-0058).
    #expect(PopulationReference.weeklyAverage(of: summary) == TrendSummary.weeklyFigure(of: summary))
  }

  @Test("A complete year compares by the same bracket rule as the card")
  func yearComparison() throws {
    let ref = try #require(PopulationReference.bundled)
    // 208.57 drinks over 365 days = 4.0 a week → "lower than roughly 35%".
    let summary = RecentSummary(dayCount: 365, daysWithDrinks: 200, daysAlcoholFree: 0, daysUnlogged: 165,
                                totalStandardDrinks: 4.0 * 365 / 7, averageOnDrinkingDays: 1)
    let grams = PopulationReference.weeklyAverage(of: summary) * Region.unitedStates.gramsPureAlcoholPerStandardDrink
    #expect(ref.comparison(gramsPerWeek: grams) == .lowerThan(percent: 35))
  }

  // MARK: - Drinking days

  @Test("The frequency file loads, names its source, and scales by days")
  func frequencyFile() throws {
    let ref = try #require(FrequencyReference.bundled)
    #expect(ref.year == 2013)
    #expect(ref.source.contains("NESARC"))
    #expect(ref.population.contains("drank in the past year"))
    #expect(ref.drinkingDaysPerYear == 87.9)
    #expect(abs(ref.drinkingDays(per: 28) - 6.7430) < 0.001)
    #expect(abs(ref.drinkingDays(per: 364) - 87.659) < 0.001)
    #expect(abs(ref.drinkingDays(per: 365) - 87.9) < 1e-9)
  }

  /// Was a test of `FrequencyReference.drinkingDays(in:last:endingOn:calendar:)`,
  /// retired by ADR-0058: the reader's count is the window fold's days with
  /// drinks, the header's own figure, so the two cannot be counted twice.
  @Test("Drinking days are distinct calendar days with an entry, inside the window")
  func drinkingDays() {
    let end = date(2026, 9, 5)
    let drinks = [
      beer(date(2026, 9, 5, 20)), beer(date(2026, 9, 5, 21)),   // one day, two drinks
      beer(date(2026, 9, 1, 9)),
      beer(date(2026, 8, 7, 23)),                                // Month's first day: inside
      beer(date(2026, 8, 6, 23)),                                // outside Month, inside Year
      LoggedDrink(loggedAt: date(2026, 8, 20), type: .beer, volumeOunces: 12, abvPercent: 0, region: .unitedStates)  // 0%: still an entry
    ]
    #expect(fold(.month, drinks, endingOn: end).summary.daysWithDrinks == 4)
    #expect(fold(.year, drinks, endingOn: end).summary.daysWithDrinks == 5)
    #expect(fold(.month, [], endingOn: end).summary.daysWithDrinks == 0)
    // The published mean beside it scales to the same window's days.
    let ref = try! #require(FrequencyReference.bundled)
    #expect(ref.displayedDrinkingDays(per: fold(.week, [], endingOn: end).window.dayCount) == 2)
    #expect(ref.displayedDrinkingDays(per: fold(.month, [], endingOn: end).window.dayCount) == 7)
  }

  // MARK: - Weekdays

  @Test("Seven weekdays, first weekday first, summing to the range")
  func weekdayFold() {
    let end = date(2026, 9, 5)  // a Saturday
    let drinks = [
      beer(date(2026, 9, 5, 20)), beer(date(2026, 9, 5, 21)),  // Sat: 2
      beer(date(2026, 8, 29, 20)),                              // Sat: 1
      beer(date(2026, 9, 4, 20)),                               // Fri: 1
      beer(date(2026, 8, 6, 20))                                // Thu, 30 days back: outside a 30-day range ending Sep 5 (Aug 7–Sep 5)
    ]
    let totals = TrendSummary.weekdayTotals(range: .month, endingOn: end, drinks: drinks, region: .unitedStates, calendar: calendar)
    #expect(totals.map(\.weekday) == [1, 2, 3, 4, 5, 6, 7])
    #expect(totals.reduce(0) { $0 + $1.dayCount } == 30)
    #expect(abs(totals.reduce(0) { $0 + $1.standardDrinks } - 4.0) < 1e-9)
    let saturday = totals[6]
    #expect(abs(saturday.standardDrinks - 3.0) < 1e-9)
    #expect(saturday.daysWithDrinks == 2)
    #expect(saturday.dayCount == 5)  // Aug 8, 15, 22, 29, Sep 5
    #expect(totals[5].daysWithDrinks == 1)  // Friday
    #expect(totals[4].standardDrinks == 0)  // Thursday: the Aug 6 drink is outside

    var mondayFirst = calendar
    mondayFirst.firstWeekday = 2
    let rotated = TrendSummary.weekdayTotals(range: .month, endingOn: end, drinks: drinks, region: .unitedStates, calendar: mondayFirst)
    #expect(rotated.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
    #expect(rotated[5] == saturday)
  }

  @Test("The weekend file loads with the paper's own definition, and the split follows it")
  func weekendReference() throws {
    let ref = try #require(WeekendReference.bundled)
    #expect(ref.year == 2010)
    #expect(ref.source.contains("Liang"))
    #expect(ref.weekendWeekdays == [6, 7, 1])
    #expect(ref.weekendEpisodesPer100Days == 30.5)
    #expect(ref.otherEpisodesPer100Days == 24.4)

    let end = date(2026, 9, 5)  // Saturday; the 30 days are Aug 7 (Fri) … Sep 5
    let drinks = [beer(date(2026, 9, 5)), beer(date(2026, 9, 4)), beer(date(2026, 9, 2))]  // Sat, Fri, Wed
    let totals = TrendSummary.weekdayTotals(range: .month, endingOn: end, drinks: drinks, region: .unitedStates, calendar: calendar)
    let split = TrendSummary.weekendSplit(totals, weekend: ref.weekendWeekdays)
    #expect(split.weekendDays + split.otherDays == 30)
    #expect(split.weekendDays == 14)  // Aug 7 – Sep 5: five Fridays, five Saturdays, four Sundays
    #expect(split.weekendDaysWithDrinks == 2)
    #expect(split.otherDaysWithDrinks == 1)
  }

  @Test("A week range gives each weekday exactly one day")
  func weekRangeIsOneOfEach() {
    let end = date(2026, 9, 5)
    let totals = TrendSummary.weekdayTotals(range: .week, endingOn: end, drinks: [], region: .unitedStates, calendar: calendar)
    #expect(totals.allSatisfy { $0.dayCount == 1 })
    #expect(totals.allSatisfy { $0.daysWithDrinks == 0 && $0.standardDrinks == 0 })
  }

  /// Was ADR-0038's "waits for four weeks of range": the published rate now
  /// waits for the record instead, the floor all three comparisons share
  /// (ADR-0058), so Week's three weekend days and four others sit beside it
  /// once the log is four weeks old. The rows and the split never wait.
  @Test("The weekend comparison waits for 28 days of record, not of range")
  func weekendComparisonGate() throws {
    let ref = try #require(WeekendReference.bundled)
    let end = date(2026, 9, 5)
    for range in TrendRange.allCases {
      let shown = TrendSummary.comparisonWindow(range: range, endingOn: end, firstRecord: date(2026, 8, 9), calendar: calendar)
      #expect(shown != nil)
      let hidden = TrendSummary.comparisonWindow(range: range, endingOn: end, firstRecord: date(2026, 8, 10), calendar: calendar)
      #expect(hidden == nil)
    }
    // Week, with a record old enough: one of each weekday, three of them the
    // paper's weekend, and the split covers the window's seven days.
    let week = fold(.week, [beer(date(2026, 9, 4))], endingOn: end, firstRecord: date(2026, 8, 9))
    let split = TrendSummary.weekendSplit(week.weekdays, weekend: ref.weekendWeekdays)
    #expect(split.weekendDays == 3)
    #expect(split.otherDays == 4)
    #expect(split.dayCount == week.window.dayCount)
    #expect(split.weekendDaysWithDrinks == 1)
  }

  @Test("A 0% drink makes a day with drinks; the weekday keeps the entry")
  func zeroABVCounts() {
    let end = date(2026, 9, 5)
    let drinks = [LoggedDrink(loggedAt: date(2026, 9, 3), type: .beer, volumeOunces: 12, abvPercent: 0, region: .unitedStates)]
    let totals = TrendSummary.weekdayTotals(range: .week, endingOn: end, drinks: drinks, region: .unitedStates, calendar: calendar)
    let thursday = totals.first { $0.weekday == 5 }!
    #expect(thursday.daysWithDrinks == 1)
    #expect(thursday.standardDrinks == 0)
  }
}
