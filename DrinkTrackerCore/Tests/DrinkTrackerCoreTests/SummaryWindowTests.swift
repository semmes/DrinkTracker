import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0026: one fold, `TrendSummary.summary(of:)`, behind every window the
/// calendar summarises — the rolling 30 days, the month shown, the year shown.
@Suite("Summary windows")
struct SummaryWindowTests {

  /// UTC, Gregorian, Sunday-first so the expected dates don't depend on the
  /// machine (the same fixture `CalendarGridTests` uses).
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func cell(_ day: Date, drinks: Double? = nil, free: Bool = false) -> CalendarDay {
    CalendarDay(
      date: day, standardDrinks: drinks ?? 0, isMarkedAlcoholFree: free, hasEntries: drinks != nil
    )
  }

  // MARK: - The fold

  @Test("The three day counts partition any list of cells")
  func partitionHolds() {
    let days = [
      cell(date(2026, 8, 1), drinks: 2), cell(date(2026, 8, 2), drinks: 4),
      cell(date(2026, 8, 3), drinks: 1), cell(date(2026, 8, 4), drinks: 0.5),
      cell(date(2026, 8, 5), free: true), cell(date(2026, 8, 6), free: true),
      cell(date(2026, 8, 7), free: true),
      cell(date(2026, 8, 8)), cell(date(2026, 8, 9)), cell(date(2026, 8, 10))
    ]
    let summary = TrendSummary.summary(of: days)
    #expect(summary.dayCount == 10)
    #expect(summary.daysWithDrinks == 4)
    #expect(summary.daysAlcoholFree == 3)
    #expect(summary.daysUnlogged == 3)
    #expect(summary.totalStandardDrinks == 7.5)
    #expect(summary.averageOnDrinkingDays == 1.875)
    #expect(summary.daysWithDrinks + summary.daysAlcoholFree + summary.daysUnlogged == summary.dayCount)
  }

  @Test("An empty list is an empty summary, and divides nothing")
  func emptyList() {
    let summary = TrendSummary.summary(of: [])
    #expect(summary.dayCount == 0)
    #expect(summary.daysWithDrinks == 0)
    #expect(summary.daysAlcoholFree == 0)
    #expect(summary.daysUnlogged == 0)
    #expect(summary.totalStandardDrinks == 0)
    #expect(summary.averageOnDrinkingDays == 0)
  }

  /// The same rule the grid's colours follow (`DayIntensity.bucket`): entries
  /// make a day with drinks even at a total that rounds to zero, and beat a
  /// marker on the same day.
  @Test("One classification rule, shared with the grid")
  func oneClassificationRule() {
    let zeroStrength = TrendSummary.summary(of: [cell(date(2026, 8, 3), drinks: 0)])
    #expect(zeroStrength.daysWithDrinks == 1)
    #expect(zeroStrength.daysAlcoholFree == 0)
    #expect(zeroStrength.totalStandardDrinks == 0)

    let both = TrendSummary.summary(of: [
      CalendarDay(date: date(2026, 8, 3), standardDrinks: 2, isMarkedAlcoholFree: true, hasEntries: true)
    ])
    #expect(both.daysWithDrinks == 1)
    #expect(both.daysAlcoholFree == 0)
  }

  /// `RecentSummary` keeps ADR-0006's shape: six stored figures and nothing
  /// that could carry a delta, a window descriptor, or a grade.
  @Test("RecentSummary carries exactly ADR-0006's six figures")
  func summaryShape() {
    let summary = RecentSummary(
      dayCount: 1, daysWithDrinks: 1, daysAlcoholFree: 0, daysUnlogged: 0,
      totalStandardDrinks: 1, averageOnDrinkingDays: 1
    )
    let stored = Mirror(reflecting: summary).children.compactMap(\.label)
    #expect(stored == [
      "dayCount", "daysWithDrinks", "daysAlcoholFree", "daysUnlogged",
      "totalStandardDrinks", "averageOnDrinkingDays"
    ])
  }

  // MARK: - The rolling window

  @Test("The rolling window is the same figures by another route")
  func rollingWindowUnchanged() {
    let totals = [date(2026, 8, 30): 2.0, date(2026, 8, 29): 4.0]
    let free: Set<Date> = [date(2026, 8, 28), date(2026, 8, 27)]
    let rolling = TrendSummary.recentSummary(
      dayCount: 30, endingOn: date(2026, 8, 30), totalsByDay: totals,
      alcoholFreeDays: free, calendar: calendar
    )
    let keys = TrendSummary.trailingDays(count: 30, endingOn: date(2026, 8, 30), calendar: calendar)
    let folded = TrendSummary.summary(
      of: TrendSummary.calendarDays(keys, totalsByDay: totals, alcoholFreeDays: free)
    )
    #expect(rolling == folded)
    #expect(rolling.daysWithDrinks == 2)
    #expect(rolling.daysAlcoholFree == 2)
    #expect(rolling.daysUnlogged == 26)
  }

  @Test("The trailing window is exactly count days, oldest first, every key normalised")
  func trailingDays() {
    let keys = TrendSummary.trailingDays(count: 30, endingOn: date(2026, 8, 30, 12), calendar: calendar)
    #expect(keys.count == 30)
    #expect(keys.first == date(2026, 8, 1))
    #expect(keys.last == date(2026, 8, 30))
    #expect(keys.allSatisfy { $0 == calendar.startOfDay(for: $0) })
    #expect(keys == keys.sorted())

    #expect(TrendSummary.trailingDays(count: 0, endingOn: date(2026, 8, 30), calendar: calendar).isEmpty)
    #expect(TrendSummary.trailingDays(count: -3, endingOn: date(2026, 8, 30), calendar: calendar).isEmpty)
    let none = TrendSummary.recentSummary(
      dayCount: 0, endingOn: date(2026, 8, 30), totalsByDay: [date(2026, 8, 30): 1],
      alcoholFreeDays: [], calendar: calendar
    )
    #expect(none.dayCount == 0)
    #expect(none.totalStandardDrinks == 0)
  }

  /// Chile moves its clocks at 00:00 on 2026-09-06, so that day starts at
  /// 01:00. The shipped window chained `date(byAdding: .day, value: -k)` from
  /// that stamp and landed on 01:00 of every earlier day — keys that matched
  /// nothing — so on that one day 29 of 30 days read unlogged. The walk is now
  /// `dayKeys`, re-normalised per step, and this pins it.
  @Test("The rolling window survives a midnight daylight-saving day")
  func rollingWindowOnTransitionDay() {
    var santiago = Calendar(identifier: .gregorian)
    santiago.timeZone = TimeZone(identifier: "America/Santiago")!
    santiago.firstWeekday = 1
    func noon(_ day: Int) -> Date {
      santiago.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
    }
    let drinks = (1...6).map { LoggedDrink(loggedAt: noon($0), type: .beer, volumeOunces: 12, abvPercent: 5) }
    let totals = TrendSummary.totalsByDay(drinks, region: .unitedStates, calendar: santiago)

    let summary = TrendSummary.recentSummary(
      dayCount: 7, endingOn: noon(6), totalsByDay: totals, alcoholFreeDays: [], calendar: santiago
    )
    #expect(summary.dayCount == 7)
    #expect(summary.daysWithDrinks == 6)
    #expect(summary.daysUnlogged == 1)
    #expect(abs(summary.totalStandardDrinks - 6.0) < 0.0001)
  }

  /// Cuba's autumn change repeats the 00:00–01:00 hour on 2026-11-01. The
  /// shipped arithmetic keyed that day at the pre-change offset while
  /// `totalsByDay` keyed it at `startOfDay`'s, so the day read as unlogged in
  /// every rolling window that contained it — the whole month after, not one
  /// day. Same walk, same fix; a second pin for the other direction.
  @Test("The rolling window survives a repeated midnight hour")
  func rollingWindowOnRepeatedMidnight() {
    var havana = Calendar(identifier: .gregorian)
    havana.timeZone = TimeZone(identifier: "America/Havana")!
    havana.firstWeekday = 1
    func noon(_ month: Int, _ day: Int) -> Date {
      havana.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }
    let days = [noon(10, 30), noon(10, 31), noon(11, 1), noon(11, 2), noon(11, 3), noon(11, 4), noon(11, 5)]
    let drinks = days.map { LoggedDrink(loggedAt: $0, type: .beer, volumeOunces: 12, abvPercent: 5) }
    let totals = TrendSummary.totalsByDay(drinks, region: .unitedStates, calendar: havana)

    let summary = TrendSummary.recentSummary(
      dayCount: 7, endingOn: noon(11, 5), totalsByDay: totals, alcoholFreeDays: [], calendar: havana
    )
    #expect(summary.dayCount == 7)
    #expect(summary.daysWithDrinks == 7)
    #expect(summary.daysUnlogged == 0)

    // Four weeks later the transition day is still inside the window (which
    // now starts on October 31, so the October 30 beer has left it) and is
    // still counted.
    let later = TrendSummary.recentSummary(
      dayCount: 30, endingOn: noon(11, 29), totalsByDay: totals, alcoholFreeDays: [], calendar: havana
    )
    #expect(later.dayCount == 30)
    #expect(later.daysWithDrinks == 6)
    #expect(later.daysUnlogged == 24)
  }

  // MARK: - The month shown

  @Test("A past month is whole")
  func pastMonthIsWhole() {
    let grid = TrendSummary.monthGrid(
      containing: date(2026, 8, 1),
      totalsByDay: [date(2026, 8, 1): 2.0, date(2026, 8, 31): 4.0],
      alcoholFreeDays: [date(2026, 8, 2)],
      calendar: calendar
    )
    #expect(grid.days(through: date(2026, 9, 2), calendar: calendar).count == 31)
    let summary = TrendSummary.monthSummary(grid, through: date(2026, 9, 2), calendar: calendar)
    #expect(summary.dayCount == 31)
    #expect(summary.daysWithDrinks == 2)
    #expect(summary.daysAlcoholFree == 1)
    #expect(summary.daysUnlogged == 28)
    #expect(summary.totalStandardDrinks == 6.0)
    #expect(summary.averageOnDrinkingDays == 3.0)
  }

  /// A future day is not "nothing logged either way" — it has not happened.
  @Test("The month in progress clips at today, and a row past today is ignored")
  func currentMonthClips() {
    let grid = TrendSummary.monthGrid(
      containing: date(2026, 9, 1),
      totalsByDay: [date(2026, 9, 1): 1.0, date(2026, 9, 3): 5.0],
      alcoholFreeDays: [],
      calendar: calendar
    )
    let summary = TrendSummary.monthSummary(grid, through: date(2026, 9, 2), calendar: calendar)
    #expect(summary.dayCount == 2)
    #expect(summary.daysWithDrinks == 1)
    #expect(summary.daysUnlogged == 1)
    #expect(summary.totalStandardDrinks == 1.0)

    // Compared at start of day, so the last second of today still counts today.
    let lastSecond = date(2026, 9, 2, 23).addingTimeInterval(59 * 60 + 59)
    #expect(grid.days(through: lastSecond, calendar: calendar).count == 2)
    #expect(grid.days(through: date(2026, 9, 1), calendar: calendar).count == 1)
    #expect(grid.days(through: date(2026, 9, 30), calendar: calendar).count == 30)
    #expect(grid.days(through: date(2026, 10, 15), calendar: calendar).count == 30)
  }

  @Test("A month that has not begun is empty")
  func futureMonthIsEmpty() {
    let grid = TrendSummary.monthGrid(
      containing: date(2026, 10, 1), totalsByDay: [:], alcoholFreeDays: [], calendar: calendar
    )
    #expect(grid.days(through: date(2026, 9, 2), calendar: calendar).isEmpty)
    let summary = TrendSummary.monthSummary(grid, through: date(2026, 9, 2), calendar: calendar)
    #expect(summary.dayCount == 0)
    #expect(summary.daysUnlogged == 0)
  }

  /// When the two windows cover the same days they must agree exactly — the
  /// rolling card and the month card are one function.
  @Test("The rolling window and a whole month agree when they coincide")
  func windowsAgreeWhenTheyCoincide() {
    let totals = [date(2026, 9, 1): 2.0, date(2026, 9, 2): 4.0, date(2026, 9, 30): 1.0]
    let free: Set<Date> = [date(2026, 9, 3)]
    let grid = TrendSummary.monthGrid(
      containing: date(2026, 9, 1), totalsByDay: totals, alcoholFreeDays: free, calendar: calendar
    )
    let month = TrendSummary.monthSummary(grid, through: date(2026, 9, 30), calendar: calendar)
    let rolling = TrendSummary.recentSummary(
      dayCount: 30, endingOn: date(2026, 9, 30), totalsByDay: totals,
      alcoholFreeDays: free, calendar: calendar
    )
    #expect(month == rolling)
    #expect(month.dayCount == 30)
    #expect(month.daysWithDrinks == 3)
    #expect(month.daysAlcoholFree == 1)
    #expect(month.daysUnlogged == 26)
  }

  @Test("The month clip keeps every day across a midnight daylight-saving change")
  func monthClipOnTransitionMonth() {
    var santiago = Calendar(identifier: .gregorian)
    santiago.timeZone = TimeZone(identifier: "America/Santiago")!
    santiago.firstWeekday = 1
    func noon(_ day: Int) -> Date {
      santiago.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
    }
    let drinks = [noon(5), noon(6), noon(7)].map {
      LoggedDrink(loggedAt: $0, type: .beer, volumeOunces: 12, abvPercent: 5)
    }
    let grid = TrendSummary.monthGrid(
      containing: noon(1),
      totalsByDay: TrendSummary.totalsByDay(drinks, region: .unitedStates, calendar: santiago),
      alcoholFreeDays: [],
      calendar: santiago
    )
    let cells = grid.days(through: noon(26), calendar: santiago)
    #expect(cells.count == 26)
    #expect(cells.first { santiago.isDate($0.date, inSameDayAs: noon(6)) }?.date == santiago.startOfDay(for: noon(6)))

    let summary = TrendSummary.monthSummary(grid, through: noon(26), calendar: santiago)
    #expect(summary.daysWithDrinks == 3)
    #expect(abs(summary.totalStandardDrinks - 3.0) < 0.0001)
    #expect(summary.daysUnlogged == 23)
  }

  // MARK: - The year shown

  @Test("The year clips at today and is whole once past")
  func yearClips() {
    func count(_ year: Int, through: Date) -> Int {
      TrendSummary.yearSummary(
        TrendSummary.yearGrids(year, totalsByDay: [:], alcoholFreeDays: [], calendar: calendar),
        through: through, calendar: calendar
      ).dayCount
    }
    #expect(count(2026, through: date(2026, 9, 2)) == 245)
    #expect(count(2026, through: date(2026, 1, 1)) == 1)
    #expect(count(2026, through: date(2026, 12, 31)) == 365)
    #expect(count(2025, through: date(2026, 9, 2)) == 365)
    #expect(count(2024, through: date(2026, 9, 2)) == 366)
    #expect(count(2027, through: date(2026, 9, 2)) == 0)
  }

  @Test("A year's figures are its months' figures, summed")
  func yearIsItsMonthsSummed() {
    let totals = [
      date(2026, 1, 10): 2.0, date(2026, 4, 5): 1.0, date(2026, 8, 20): 3.0, date(2026, 9, 1): 1.0
    ]
    let free: Set<Date> = [date(2026, 2, 14), date(2026, 9, 2)]
    let grids = TrendSummary.yearGrids(2026, totalsByDay: totals, alcoholFreeDays: free, calendar: calendar)
    let today = date(2026, 9, 2)
    let year = TrendSummary.yearSummary(grids, through: today, calendar: calendar)

    #expect(year.dayCount == 245)
    #expect(year.daysWithDrinks == 4)
    #expect(year.daysAlcoholFree == 2)
    #expect(year.daysUnlogged == 239)
    #expect(year.totalStandardDrinks == 7.0)
    #expect(year.averageOnDrinkingDays == 1.75)

    let months = grids.map { TrendSummary.monthSummary($0, through: today, calendar: calendar) }
    #expect(months.reduce(0) { $0 + $1.dayCount } == year.dayCount)
    #expect(months.reduce(0) { $0 + $1.daysWithDrinks } == year.daysWithDrinks)
    #expect(months.reduce(0) { $0 + $1.daysAlcoholFree } == year.daysAlcoholFree)
    #expect(months.reduce(0) { $0 + $1.daysUnlogged } == year.daysUnlogged)
    #expect(months.reduce(0) { $0 + $1.totalStandardDrinks } == year.totalStandardDrinks)
  }

  /// Invariant 3 reaching the year card: the same drinking totals differently
  /// under a different region, and the day counts do not move at all.
  @Test("A year re-expresses under the current region only")
  func yearFollowsTheRegionLens() {
    let beers = [
      LoggedDrink(loggedAt: date(2025, 3, 1, 12), type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedKingdom),
      LoggedDrink(loggedAt: date(2025, 6, 1, 12), type: .beer, volumeOunces: 12, abvPercent: 5, region: .australia),
      LoggedDrink(loggedAt: date(2025, 9, 1, 12), type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedStates)
    ]
    func year(in region: Region) -> RecentSummary {
      TrendSummary.yearSummary(
        TrendSummary.yearGrids(
          2025,
          totalsByDay: TrendSummary.totalsByDay(beers, region: region, calendar: calendar),
          alcoholFreeDays: [],
          calendar: calendar
        ),
        through: date(2026, 9, 2), calendar: calendar
      )
    }
    let us = year(in: .unitedStates)
    let uk = year(in: .unitedKingdom)
    #expect(abs(us.totalStandardDrinks - 3.0) < 0.001)
    let ukUnits = 3 * LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5).standardDrinks(in: .unitedKingdom)
    #expect(abs(uk.totalStandardDrinks - ukUnits) < 0.001)
    #expect(us.daysWithDrinks == 3 && uk.daysWithDrinks == 3)
    #expect(us.daysUnlogged == 362 && uk.daysUnlogged == 362)
  }

  // MARK: - The stored preference

  @Test("The window's raw values are the stored contract")
  func windowRawValues() {
    #expect(CalendarSummaryWindow.lastThirtyDays.rawValue == "lastThirtyDays")
    #expect(CalendarSummaryWindow.monthShown.rawValue == "monthShown")
    #expect(CalendarSummaryWindow.allCases == [.lastThirtyDays, .monthShown])
    #expect(CalendarSummaryWindow(rawValue: "month") == nil)
  }
}
