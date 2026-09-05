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

  @Test("The window follows the age of the first recorded fact")
  func windowGate() {
    let now = date(2026, 9, 5)
    #expect(PopulationReference.window(firstRecord: nil, now: now) == nil)
    #expect(PopulationReference.window(firstRecord: now.addingTimeInterval(-27 * 86400), now: now) == nil)
    #expect(PopulationReference.window(firstRecord: now.addingTimeInterval(-28 * 86400), now: now) == .fourWeeks)
    #expect(PopulationReference.window(firstRecord: now.addingTimeInterval(-363 * 86400), now: now) == .fourWeeks)
    #expect(PopulationReference.window(firstRecord: now.addingTimeInterval(-364 * 86400), now: now) == .twelveMonths)
    #expect(PopulationReference.window(firstRecord: date(2020, 1, 1), now: now) == .twelveMonths)
  }

  @Test("Four weeks is the shipped rule: the trailing 28 days over a fixed 4")
  func fourWeekAverage() {
    let now = date(2026, 9, 5)
    let drinks = [
      beer(now.addingTimeInterval(-1 * 86400)),
      beer(now.addingTimeInterval(-27 * 86400)),
      beer(now.addingTimeInterval(-29 * 86400))  // outside
    ]
    let average = PopulationReference.weeklyAverage(drinks, window: .fourWeeks, endingAt: now, region: .unitedStates)
    #expect(abs(average - 2.0 / 4) < 1e-9)
  }

  @Test("Twelve months is 52 whole weeks over a fixed 52")
  func twelveMonthAverage() {
    let now = date(2026, 9, 5)
    var drinks: [LoggedDrink] = []
    for week in 0..<52 {  // one beer a week, the last one 357 days back
      drinks.append(beer(now.addingTimeInterval(-Double(week * 7 + 1) * 86400)))
    }
    drinks.append(beer(now.addingTimeInterval(-365 * 86400)))  // outside
    let average = PopulationReference.weeklyAverage(drinks, window: .twelveMonths, endingAt: now, region: .unitedStates)
    #expect(abs(average - 1.0) < 1e-9)
    // The same year's drinks over four weeks are the last four only.
    let recent = PopulationReference.weeklyAverage(drinks, window: .fourWeeks, endingAt: now, region: .unitedStates)
    #expect(abs(recent - 1.0) < 1e-9)
  }

  @Test("The divisor never shrinks with a sparse window")
  func fixedDivisor() {
    let now = date(2026, 9, 5)
    let drinks = [beer(now.addingTimeInterval(-3600))]
    #expect(abs(PopulationReference.weeklyAverage(drinks, window: .twelveMonths, endingAt: now, region: .unitedStates) - 1.0 / 52) < 1e-9)
  }

  @Test("The window's average re-expresses under the current region only")
  func windowFollowsTheLens() {
    let now = date(2026, 9, 5)
    let drinks = [beer(now.addingTimeInterval(-86400))]
    let us = PopulationReference.weeklyAverage(drinks, window: .fourWeeks, endingAt: now, region: .unitedStates)
    let uk = PopulationReference.weeklyAverage(drinks, window: .fourWeeks, endingAt: now, region: .unitedKingdom)
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

  @Test("Drinking days are distinct calendar days with an entry, inside the window")
  func drinkingDays() {
    let end = date(2026, 9, 5)
    let drinks = [
      beer(date(2026, 9, 5, 20)), beer(date(2026, 9, 5, 21)),   // one day, two drinks
      beer(date(2026, 9, 1, 9)),
      beer(date(2026, 8, 9, 23)),                                // the 28th day back: inside
      beer(date(2026, 8, 8, 23)),                                // outside
      LoggedDrink(loggedAt: date(2026, 8, 20), type: .beer, volumeOunces: 12, abvPercent: 0, region: .unitedStates)  // 0%: still an entry
    ]
    #expect(FrequencyReference.drinkingDays(in: drinks, last: 28, endingOn: end, calendar: calendar) == 4)
    #expect(FrequencyReference.drinkingDays(in: drinks, last: 364, endingOn: end, calendar: calendar) == 5)
    #expect(FrequencyReference.drinkingDays(in: [], last: 28, endingOn: end, calendar: calendar) == 0)
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
