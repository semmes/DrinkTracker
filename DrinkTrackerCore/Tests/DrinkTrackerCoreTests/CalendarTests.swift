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
    #expect(bucket(9) == .high)
    #expect(bucket(10) == .veryHigh)
    #expect(bucket(12) == .veryHigh)
  }

  /// Every legend label is a literal claim about the bucket it sits under, and
  /// the ramp is only honest if the two cannot drift. This walks the whole
  /// range a day can reach and asserts the bucket's own label actually
  /// contains the number — so renaming a label without moving its boundary, or
  /// moving a boundary without renaming, fails here rather than on a device.
  @Test("Every whole total lands under a label that describes it")
  func labelsDescribeTheirRange() {
    for drinks in 1...40 {
      let intensity = DayIntensity.bucket(
        standardDrinks: Double(drinks), isMarkedAlcoholFree: false, hasEntries: true
      )
      let expected: DayIntensity =
        switch drinks {
        case 1...2: .low
        case 3...5: .medium
        case 6...9: .high
        default: .veryHigh
        }
      #expect(intensity == expected, "\(drinks) standard drinks bucketed as \(intensity)")
    }
  }

  /// The ramp's order is what carries magnitude, so it is pinned rather than
  /// left to declaration order surviving an edit. `allCases` is legend order:
  /// the two non-quantities first, then the four drinking bands least to most.
  @Test("The ramp is four drinking bands, least to most")
  func rampOrder() {
    #expect(DayIntensity.allCases == [.unlogged, .alcoholFree, .low, .medium, .high, .veryHigh])
    #expect(DayIntensity.allCases.filter(\.isRecorded).count == 5)
  }

  /// The band follows the digits the reader sees. `StandardDrink.formatted`
  /// prints a total to one decimal, and the band is decided on that same value,
  /// so the edges are the half-steps between the labels: 2.5 prints as "2.5"
  /// and belongs under "3–5" rather than "1–2". Rounding to a whole drink first
  /// (the rule until 2026-09-07) put a 9.4583-drink day in "6–9" and a 9.5-drink
  /// day in "10+" while both printed "≈ 9.5 standard drinks" — two colours for
  /// one figure, and the same pair at 5.5 and at 2.5 (ADR-0034's amendment).
  /// Those probe pairs are pinned here by value.
  @Test("Fractional totals band on the digits they print")
  func fractionalTotalsBandOnThePrintedDigits() {
    func bucket(_ drinks: Double) -> DayIntensity {
      DayIntensity.bucket(
        standardDrinks: drinks, isMarkedAlcoholFree: false, hasEntries: true
      )
    }
    #expect(bucket(2.4) == .low)
    #expect(bucket(2.5) == .medium)
    #expect(bucket(5.4) == .medium)
    #expect(bucket(5.5) == .high)
    #expect(bucket(9.4) == .high)
    #expect(bucket(9.5) == .veryHigh)

    // The probe pairs: each prints one figure, so each draws one colour.
    #expect(StandardDrink.formatted(9.4583) == "9.5")
    #expect(bucket(9.4583) == .veryHigh)
    #expect(bucket(9.4583) == bucket(9.5))
    #expect(StandardDrink.formatted(5.4583) == "5.5")
    #expect(bucket(5.4583) == .high)
    #expect(bucket(5.4583) == bucket(5.5))
    #expect(StandardDrink.formatted(2.4583) == "2.5")
    #expect(bucket(2.4583) == .medium)
    #expect(bucket(2.4583) == bucket(2.5))
    // A figure that prints below an edge stays below it.
    #expect(StandardDrink.formatted(9.4499) == "9.4")
    #expect(bucket(9.4499) == .high)
  }

  /// The band is a function of the printed figure and nothing else: over every
  /// total a day can plausibly reach, two totals that `StandardDrink.formatted`
  /// prints the same must bucket the same. A finer rounding in either place —
  /// the formatter to two decimals, the band back to a whole drink — fails
  /// here. The sweep also pins that the band never falls as the total rises.
  @Test("Two totals that print the same figure draw the same colour")
  func bandIsAFunctionOfThePrintedDigits() {
    func rank(_ band: DayIntensity) -> Int { DayIntensity.allCases.firstIndex(of: band)! }
    var bandByFigure: [String: DayIntensity] = [:]
    var previous = DayIntensity.low
    for thousandths in 0...15_000 {
      let total = Double(thousandths) / 1000
      let band = DayIntensity.bucket(standardDrinks: total, isMarkedAlcoholFree: false, hasEntries: true)
      let figure = StandardDrink.formatted(total)
      if let seen = bandByFigure[figure] {
        #expect(seen == band, "\(total) prints \(figure) and bucketed as \(band), not \(seen)")
      } else {
        bandByFigure[figure] = band
      }
      #expect(rank(band) >= rank(previous), "\(total) fell to \(band) from \(previous)")
      previous = band
    }
    #expect(bandByFigure["0"] == .low)
    #expect(bandByFigure["2.4"] == .low)
    #expect(bandByFigure["2.5"] == .medium)
    #expect(bandByFigure["5.4"] == .medium)
    #expect(bandByFigure["5.5"] == .high)
    #expect(bandByFigure["9.4"] == .high)
    #expect(bandByFigure["9.5"] == .veryHigh)
    #expect(bandByFigure["15"] == .veryHigh)
  }

  /// A total that is not a number cannot trap the calendar. NaN fails every
  /// comparison and lands on the floor a logged day always has, −∞ likewise,
  /// and +∞ is the top — what the whole-drink rule did, kept when the edges
  /// moved to the printed digits.
  @Test("A non-finite total takes the floor or the top, never a trap")
  func nonFiniteTotalsDoNotTrap() {
    func bucket(_ drinks: Double) -> DayIntensity {
      DayIntensity.bucket(
        standardDrinks: drinks, isMarkedAlcoholFree: false, hasEntries: true
      )
    }
    #expect(bucket(.nan) == .low)
    #expect(bucket(-.infinity) == .low)
    #expect(bucket(.infinity) == .veryHigh)
    #expect(DayIntensity.bucket(standardDrinks: .nan, isMarkedAlcoholFree: true, hasEntries: false) == .alcoholFree)
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

  /// August 2026, Sunday-first: six leading blanks, so row 0 holds only the 1st in
  /// its last column, and every later row starts on a Sunday.
  @Test("Grid positions map to day indices, and blanks map to nothing")
  func dayIndexFromPosition() {
    let august = TrendSummary.monthGrid(
      containing: date(2026, 8, 1),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )

    // The 1st sits at row 0, column 6 (Saturday).
    #expect(august.dayIndex(row: 0, column: 6) == 0)
    // The blanks before it are not days.
    #expect(august.dayIndex(row: 0, column: 0) == nil)
    #expect(august.dayIndex(row: 0, column: 5) == nil)
    // Row 1 starts on Sunday the 2nd.
    #expect(august.dayIndex(row: 1, column: 0) == 1)
    #expect(august.dayIndex(row: 1, column: 6) == 7)
    // The 31st is a Monday: row 5, column 1.
    #expect(august.dayIndex(row: 5, column: 1) == 30)
    // Past the month's end, and off the grid entirely.
    #expect(august.dayIndex(row: 5, column: 2) == nil)
    #expect(august.dayIndex(row: 6, column: 0) == nil)
    #expect(august.dayIndex(row: -1, column: 0) == nil)
    #expect(august.dayIndex(row: 0, column: 7) == nil)
  }

  @Test("A selection run is the same days whichever way the drag went")
  func selectionRunIsOrderInsensitive() {
    let august = TrendSummary.monthGrid(
      containing: date(2026, 8, 1),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )

    let forward = august.days(between: 7, and: 11)
    let backward = august.days(between: 11, and: 7)
    #expect(forward == backward)
    #expect(forward.count == 5)
    #expect(forward.first?.date == date(2026, 8, 8))
    #expect(forward.last?.date == date(2026, 8, 12))
  }

  @Test("A selection run clamps to the month instead of failing")
  func selectionRunClamps() {
    let august = TrendSummary.monthGrid(
      containing: date(2026, 8, 1),
      totalsByDay: [:],
      alcoholFreeDays: [],
      calendar: calendar
    )

    // An anchor inside the month dragged past its end keeps the valid extent.
    let clamped = august.days(between: 28, and: 40)
    #expect(clamped.count == 3)
    #expect(clamped.last?.date == date(2026, 8, 31))

    // A run that starts before the grid clamps at the 1st.
    let fromBefore = august.days(between: -3, and: 2)
    #expect(fromBefore.count == 3)
    #expect(fromBefore.first?.date == date(2026, 8, 1))

    // A single-cell "run" is that one day.
    #expect(august.days(between: 4, and: 4).count == 1)
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

  /// The day sheet's minus removes the day's most recent entry — the top row of
  /// its own newest-first list, never a drink from another day.
  @Test("The day's most recent entry is what minus removes")
  func mostRecentOnDay() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let noon = calendar.date(
      from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 8, day: 20, hour: 12)
    )!
    let evening = calendar.date(byAdding: .hour, value: 8, to: noon)!
    let nextDay = calendar.date(byAdding: .day, value: 1, to: noon)!

    let lunch = LoggedDrink(loggedAt: noon, type: .beer, volumeOunces: 12, abvPercent: 5)
    let dinner = LoggedDrink(loggedAt: evening, type: .wine, volumeOunces: 5, abvPercent: 12)
    let tomorrow = LoggedDrink(loggedAt: nextDay, type: .spirit, volumeOunces: 1.5, abvPercent: 40)

    let found = TrendSummary.mostRecentDrink(
      on: noon, in: [lunch, dinner, tomorrow], calendar: calendar
    )
    #expect(found?.id == dinner.id)
    #expect(TrendSummary.mostRecentDrink(on: nextDay, in: [lunch, dinner], calendar: calendar) == nil)
  }
}

/// The day sheet's plus must create the day's newest entry, so that a minus right
/// after removes the drink the plus created — never a real one (ADR-0013).
@Suite("Backfill timestamps")
struct BackfillTimestampTests {

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private func date(_ day: Int, hour: Int, minute: Int = 0) -> Date {
    calendar.date(
      from: DateComponents(
        timeZone: TimeZone(identifier: "UTC")!,
        year: 2026, month: 8, day: day, hour: hour, minute: minute
      )
    )!
  }

  @Test("Today logs at now, same as Today's counter")
  func todayLogsAtNow() {
    let now = date(20, hour: 9, minute: 30)
    let stamp = TrendSummary.backfillTimestamp(
      on: date(20, hour: 0), existing: [], calendar: calendar, now: now
    )
    #expect(stamp == now)
  }

  @Test("An empty past day anchors at noon")
  func emptyPastDayIsNoon() {
    let stamp = TrendSummary.backfillTimestamp(
      on: date(10, hour: 0), existing: [], calendar: calendar, now: date(20, hour: 9)
    )
    #expect(stamp == date(10, hour: 12))
  }

  @Test("A day with evening entries lands one second after the latest")
  func landsAfterExistingEntries() {
    let evening = LoggedDrink(loggedAt: date(10, hour: 23), type: .wine, volumeOunces: 5, abvPercent: 12)
    let stamp = TrendSummary.backfillTimestamp(
      on: date(10, hour: 0), existing: [evening], calendar: calendar, now: date(20, hour: 9)
    )
    #expect(stamp == date(10, hour: 23).addingTimeInterval(1))
  }

  @Test("Morning-only entries still anchor at noon, not before")
  func morningEntriesKeepNoon() {
    let morning = LoggedDrink(loggedAt: date(10, hour: 8), type: .beer, volumeOunces: 12, abvPercent: 5)
    let stamp = TrendSummary.backfillTimestamp(
      on: date(10, hour: 0), existing: [morning], calendar: calendar, now: date(20, hour: 9)
    )
    #expect(stamp == date(10, hour: 12))
  }

  @Test("The stamp never spills into the next day")
  func clampedToTheDay() {
    let lastSecond = date(11, hour: 0).addingTimeInterval(-1)
    let late = LoggedDrink(loggedAt: lastSecond, type: .beer, volumeOunces: 12, abvPercent: 5)
    let stamp = TrendSummary.backfillTimestamp(
      on: date(10, hour: 0), existing: [late], calendar: calendar, now: date(20, hour: 9)
    )
    #expect(stamp == lastSecond)
    #expect(calendar.isDate(stamp, inSameDayAs: date(10, hour: 0)))
  }
}
