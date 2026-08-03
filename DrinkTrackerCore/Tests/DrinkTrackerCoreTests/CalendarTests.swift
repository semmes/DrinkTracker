import Foundation
import Testing

@testable import DrinkTrackerCore

@Suite("Day intensity")
struct DayIntensityTests {

  @Test("Nothing recorded is distinct from a day with no alcohol")
  func unloggedIsNotAlcoholFree() {
    let unlogged = DayIntensity.bucket(
      standardDrinks: 0, isMarkedAlcoholFree: false, hasEntries: false
    )
    let free = DayIntensity.bucket(
      standardDrinks: 0, isMarkedAlcoholFree: true, hasEntries: false
    )
    #expect(unlogged == .unlogged)
    #expect(free == .alcoholFree)
    #expect(unlogged.isRecorded == false)
    #expect(free.isRecorded)
  }

  @Test("Buckets line up with the labels they're shown under")
  func bucketBoundaries() {
    func bucket(_ drinks: Double) -> DayIntensity {
      DayIntensity.bucket(
        standardDrinks: drinks, isMarkedAlcoholFree: false, hasEntries: true
      )
    }
    #expect(bucket(1) == .low)
    #expect(bucket(2) == .low)
    #expect(bucket(3) == .medium)
    #expect(bucket(5) == .medium)
    #expect(bucket(6) == .high)
    #expect(bucket(12) == .high)
  }

  /// Rounding to the nearest whole drink is what makes the labels literally true:
  /// 2.5 reads as 3, so it belongs under "3–5" rather than being shown as "1–2".
  @Test("Fractional totals round before bucketing")
  func fractionalTotalsRound() {
    func bucket(_ drinks: Double) -> DayIntensity {
      DayIntensity.bucket(
        standardDrinks: drinks, isMarkedAlcoholFree: false, hasEntries: true
      )
    }
    #expect(bucket(2.4) == .low)
    #expect(bucket(2.5) == .medium)
    #expect(bucket(5.4) == .medium)
    #expect(bucket(5.5) == .high)
  }

  /// The one direction that would actually mislead: a small drink rounding to zero
  /// and being shown as a day with no alcohol.
  @Test("A logged drink that rounds to zero is still a drinking day")
  func tinyDrinkIsNotAlcoholFree() {
    let intensity = DayIntensity.bucket(
      standardDrinks: 0.3, isMarkedAlcoholFree: false, hasEntries: true
    )
    #expect(intensity == .low)
    #expect(intensity != .alcoholFree)
  }

  /// If a day somehow carries both, the entries win — they're evidence, the marker
  /// is an assertion.
  @Test("Entries override an alcohol-free marker")
  func entriesBeatTheMarker() {
    let intensity = DayIntensity.bucket(
      standardDrinks: 2, isMarkedAlcoholFree: true, hasEntries: true
    )
    #expect(intensity == .low)
  }

  @Test("Every case has a legend label and a spoken description")
  func everyCaseIsDescribed() {
    for intensity in DayIntensity.allCases {
      #expect(!intensity.legendLabel.isEmpty)
      #expect(!intensity.accessibilityDescription.isEmpty)
    }
  }
}

@Suite("Calendar grids")
struct CalendarGridTests {

  /// Fixed to UTC and to a Sunday-first week so the layout assertions below are
  /// about the grid logic rather than about wherever the test happens to run.
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }

  @Test("A month grid has one cell per day of that month")
  func monthGridLength() {
    let january = TrendSummary.monthGrid(
      containing: date(2026, 1, 15),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )
    #expect(january.days.count == 31)

    let february = TrendSummary.monthGrid(
      containing: date(2026, 2, 10),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )
    #expect(february.days.count == 28)
  }

  @Test("A leap February gets its 29th day")
  func leapYear() {
    let february = TrendSummary.monthGrid(
      containing: date(2028, 2, 1),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )
    #expect(february.days.count == 29)
  }

  /// 1 August 2026 is a Saturday. On a Sunday-first week that's the seventh column,
  /// so six blanks come first.
  @Test("Leading blanks put the 1st under the right weekday")
  func leadingBlanks() {
    let august = TrendSummary.monthGrid(
      containing: date(2026, 8, 1),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )
    #expect(august.leadingBlanks == 6)
  }

  /// The same month on a Monday-first calendar shifts by one. Hardcoding either
  /// convention would misplace every date for half the world.
  @Test("Leading blanks follow the locale's first weekday")
  func leadingBlanksFollowLocale() {
    var mondayFirst = calendar
    mondayFirst.firstWeekday = 2
    let august = TrendSummary.monthGrid(
      containing: date(2026, 8, 1),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: mondayFirst
    )
    #expect(august.leadingBlanks == 5)
  }

  @Test("Totals and markers land on the right days")
  func cellsCarryTheirData() {
    let third = date(2026, 8, 3)
    let fourth = date(2026, 8, 4)

    let august = TrendSummary.monthGrid(
      containing: third,
      totalsByDay: [third: 4.0],
      alcoholFreeDays: [fourth],
      calendar: calendar
    )

    let day3 = august.days.first { $0.date == third }
    let day4 = august.days.first { $0.date == fourth }
    let day5 = august.days.first { $0.date == date(2026, 8, 5) }

    #expect(day3?.intensity == .medium)
    #expect(day3?.standardDrinks == 4.0)
    #expect(day4?.intensity == .alcoholFree)
    #expect(day5?.intensity == .unlogged)
  }

  @Test("A year is twelve months, January first")
  func yearGrids() {
    let year = TrendSummary.yearGrids(
      2026, totalsByDay: [:], alcoholFreeDays: [], calendar: calendar
    )
    #expect(year.count == 12)
    #expect(year.first?.month == date(2026, 1, 1))
    #expect(year.last?.month == date(2026, 12, 1))
    #expect(year.reduce(0) { $0 + $1.days.count } == 365)
  }

  @Test("recordedDayCount counts both drinking and alcohol-free days")
  func recordedDayCount() {
    let august = TrendSummary.monthGrid(
      containing: date(2026, 8, 1),
      totalsByDay: [date(2026, 8, 2): 3.0, date(2026, 8, 9): 1.0],
      alcoholFreeDays: [date(2026, 8, 3)],
      calendar: calendar
    )
    #expect(august.recordedDayCount == 3)
  }

  @Test("Totals are bucketed by day and summed within each")
  func totalsByDay() {
    let drinks = [
      LoggedDrink(loggedAt: date(2026, 8, 3), type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(loggedAt: date(2026, 8, 3), type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(loggedAt: date(2026, 8, 4), type: .wine, volumeOunces: 5, abvPercent: 12)
    ]
    let totals = TrendSummary.totalsByDay(drinks, region: .unitedStates, calendar: calendar)
    #expect(totals.count == 2)
    #expect(abs((totals[date(2026, 8, 3)] ?? 0) - 2.0) < 0.01)
    #expect(abs((totals[date(2026, 8, 4)] ?? 0) - 1.0) < 0.01)
  }

  /// Invariant 3 reaching the calendar: the same drinking is bucketed differently
  /// under a different region, because the units it's counted in changed.
  @Test("Buckets follow the current region, not the entry's")
  func bucketsFollowRegion() {
    // Four 12oz 5% beers: 4.0 US standard drinks, but ~7.0 UK units.
    let drinks = (0..<4).map { _ in
      LoggedDrink(
        loggedAt: date(2026, 8, 3), type: .beer, volumeOunces: 12, abvPercent: 5,
        region: .unitedStates
      )
    }
    let day = date(2026, 8, 3)

    let asUS = TrendSummary.monthGrid(
      containing: day,
      totalsByDay: TrendSummary.totalsByDay(drinks, region: .unitedStates, calendar: calendar),
      alcoholFreeDays: [],
      calendar: calendar
    ).days.first { $0.date == day }

    let asUK = TrendSummary.monthGrid(
      containing: day,
      totalsByDay: TrendSummary.totalsByDay(drinks, region: .unitedKingdom, calendar: calendar),
      alcoholFreeDays: [],
      calendar: calendar
    ).days.first { $0.date == day }

    #expect(asUS?.intensity == .medium)
    #expect(asUK?.intensity == .high)
  }
}

@Suite("Recent summary")
struct RecentSummaryTests {

  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }

  @Test("The three day counts account for every day in the window")
  func countsArePartitioned() {
    let end = date(2026, 8, 30)
    let summary = TrendSummary.recentSummary(
      dayCount: 30,
      endingOn: end,
      totalsByDay: [date(2026, 8, 30): 2.0, date(2026, 8, 29): 4.0],
      alcoholFreeDays: [date(2026, 8, 28), date(2026, 8, 27)],
      calendar: calendar
    )
    #expect(summary.dayCount == 30)
    #expect(summary.daysWithDrinks == 2)
    #expect(summary.daysAlcoholFree == 2)
    #expect(summary.daysUnlogged == 26)
    #expect(
      summary.daysWithDrinks + summary.daysAlcoholFree + summary.daysUnlogged
        == summary.dayCount
    )
  }

  /// The average is over drinking days only. Averaging across the window would let
  /// a stretch of unlogged days quietly pull it down — a figure that falls because
  /// you stopped recording is worse than no figure.
  @Test("The average covers drinking days, not the whole window")
  func averageIsOverDrinkingDays() {
    let summary = TrendSummary.recentSummary(
      dayCount: 30,
      endingOn: date(2026, 8, 30),
      totalsByDay: [date(2026, 8, 30): 2.0, date(2026, 8, 29): 4.0],
      alcoholFreeDays: [],
      calendar: calendar
    )
    #expect(summary.totalStandardDrinks == 6.0)
    #expect(summary.averageOnDrinkingDays == 3.0)
  }

  @Test("An empty window doesn't divide by zero")
  func emptyWindow() {
    let summary = TrendSummary.recentSummary(
      dayCount: 30,
      endingOn: date(2026, 8, 30),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )
    #expect(summary.averageOnDrinkingDays == 0)
    #expect(summary.totalStandardDrinks == 0)
    #expect(summary.daysUnlogged == 30)
  }

  @Test("Days outside the window are ignored")
  func windowIsBounded() {
    let summary = TrendSummary.recentSummary(
      dayCount: 7,
      endingOn: date(2026, 8, 30),
      totalsByDay: [date(2026, 8, 30): 1.0, date(2026, 1, 1): 99.0],
      alcoholFreeDays: [],
      calendar: calendar
    )
    #expect(summary.daysWithDrinks == 1)
    #expect(summary.totalStandardDrinks == 1.0)
  }
}

@Suite("Calendar quick-log seeding")
struct QuickLogSeedTests {

  @Test("The most frequently logged type is what the calendar offers")
  func mostLoggedType() {
    let drinks = [
      LoggedDrink(type: .wine, volumeOunces: 5, abvPercent: 12),
      LoggedDrink(type: .wine, volumeOunces: 5, abvPercent: 12),
      LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5)
    ]
    #expect(TrendSummary.mostLoggedType(in: drinks) == .wine)
  }

  @Test("An empty log offers nothing, so the caller picks its own default")
  func noDrinksNoType() {
    #expect(TrendSummary.mostLoggedType(in: []) == nil)
  }

  /// A tie has to resolve the same way every time. Dictionary iteration order does
  /// not, so it breaks on declaration order instead.
  @Test("Ties resolve deterministically")
  func tiesAreStable() {
    let drinks = [
      LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(type: .wine, volumeOunces: 5, abvPercent: 12)
    ]
    let picks = (0..<20).map { _ in TrendSummary.mostLoggedType(in: drinks) }
    #expect(Set(picks).count == 1)
    #expect(picks.first == .beer)
  }

  @Test("The most recent drink of a type carries its size and strength forward")
  func mostRecentOfType() {
    let older = LoggedDrink(
      loggedAt: Date(timeIntervalSince1970: 1_000),
      type: .beer, volumeOunces: 12, abvPercent: 5
    )
    let newer = LoggedDrink(
      loggedAt: Date(timeIntervalSince1970: 2_000),
      type: .beer, volumeOunces: 16, abvPercent: 6
    )
    let wine = LoggedDrink(type: .wine, volumeOunces: 5, abvPercent: 12)

    let found = TrendSummary.mostRecentDrink(ofType: .beer, in: [older, newer, wine])
    #expect(found?.volumeOunces == 16)
    #expect(TrendSummary.mostRecentDrink(ofType: .spirit, in: [older, wine]) == nil)
  }
}
