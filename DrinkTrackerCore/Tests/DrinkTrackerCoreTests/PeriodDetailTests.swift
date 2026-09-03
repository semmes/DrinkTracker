import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0028: the facts behind one Trends bar, and the lookup from a touched
/// x value to the bar it lands in.
@Suite("Period detail")
struct PeriodDetailTests {

  /// UTC, Gregorian, Sunday-first so the expected dates don't depend on the
  /// machine.
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: min))!
  }

  private func beer(_ at: Date, abv: Double = 5, region: Region = .unitedStates) -> LoggedDrink {
    LoggedDrink(loggedAt: at, type: .beer, volumeOunces: 12, abvPercent: abv, region: region)
  }

  private func wine(_ at: Date) -> LoggedDrink {
    LoggedDrink(loggedAt: at, type: .wine, volumeOunces: 5, abvPercent: 12)
  }

  private func detail(
    _ touch: Date, range: TrendRange, endingOn end: Date, drinks: [LoggedDrink] = [],
    free: Set<Date> = [], health: Set<Date> = [], region: Region = .unitedStates,
    calendar: Calendar? = nil
  ) -> PeriodDetail? {
    TrendSummary.periodDetail(
      containing: touch, range: range, endingOn: end, drinks: drinks,
      alcoholFreeDays: free, healthMarkedDays: health, region: region,
      calendar: calendar ?? self.calendar
    )
  }

  // MARK: - Finding the bar

  @Test("A touch resolves to the day bar it lands in, and to nothing outside the range")
  func dayBarLookup() {
    let end = date(2026, 8, 26, 12)
    #expect(TrendSummary.bucketStart(containing: date(2026, 8, 25, 23, 59), range: .week, endingOn: end, calendar: calendar) == date(2026, 8, 25))
    #expect(TrendSummary.bucketStart(containing: date(2026, 8, 20), range: .week, endingOn: end, calendar: calendar) == date(2026, 8, 20))
    #expect(TrendSummary.bucketStart(containing: date(2026, 8, 19, 23, 59), range: .week, endingOn: end, calendar: calendar) == nil)
    #expect(TrendSummary.bucketStart(containing: date(2026, 8, 27, 0, 30), range: .week, endingOn: end, calendar: calendar) == nil)

    let day = detail(date(2026, 8, 25, 23, 59), range: .week, endingOn: end)
    #expect(day?.unit == .day)
    #expect(day?.summary.dayCount == 1)
    #expect(day?.periodLength == 1)
    #expect(day?.isPartial == false)
    #expect(day?.start == day?.lastDay)
  }

  @Test("A touch on a Wednesday resolves to that calendar week's start under either first weekday")
  func weekBarLookupFollowsFirstWeekday() {
    let end = date(2026, 8, 26, 12)
    let touch = date(2026, 8, 12, 15)
    var mondayFirst = calendar
    mondayFirst.firstWeekday = 2

    let sunday = TrendSummary.bucketStart(containing: touch, range: .quarter, endingOn: end, calendar: calendar)
    let monday = TrendSummary.bucketStart(containing: touch, range: .quarter, endingOn: end, calendar: mondayFirst)
    #expect(sunday == date(2026, 8, 9))
    #expect(monday == date(2026, 8, 10))

    for cal in [calendar, mondayFirst] {
      let bars = TrendSummary.bucketed(
        TrendSummary.dailyTotals(range: .quarter, endingOn: end, drinks: [], region: .unitedStates, calendar: cal),
        by: .weekOfYear, calendar: cal
      )
      let start = TrendSummary.bucketStart(containing: touch, range: .quarter, endingOn: end, calendar: cal)
      #expect(bars.contains { $0.start == start })
    }
  }

  @Test("A month bar's detail is the month clipped to the range, and says so")
  func monthBarClips() {
    let end = date(2026, 8, 26, 12)
    let august = detail(date(2026, 8, 10), range: .year, endingOn: end)
    #expect(august?.start == date(2026, 8, 1))
    #expect(august?.lastDay == date(2026, 8, 26))
    #expect(august?.periodLength == 31)
    #expect(august?.summary.dayCount == 26)
    #expect(august?.isPartial == true)

    let march = detail(date(2026, 3, 15), range: .year, endingOn: end)
    #expect(march?.summary.dayCount == 31)
    #expect(march?.isPartial == false)

    let first = detail(date(2025, 9, 15), range: .year, endingOn: end)
    #expect(first?.start == date(2025, 9, 1))
    #expect(first?.summary.dayCount == 30)
    #expect(first?.isPartial == false)

    #expect(detail(date(2025, 8, 31), range: .year, endingOn: end) == nil)
  }

  @Test("A partial week counts only days inside the range")
  func partialWeek() {
    let end = date(2026, 8, 26, 12)  // a Wednesday
    let drinks = [beer(date(2026, 8, 24, 20)), beer(date(2026, 8, 29, 20))]
    let week = detail(end, range: .quarter, endingOn: end, drinks: drinks, free: [date(2026, 8, 28)])
    #expect(week?.start == date(2026, 8, 23))
    #expect(week?.lastDay == date(2026, 8, 26))
    #expect(week?.periodLength == 7)
    #expect(week?.summary.dayCount == 4)
    #expect(week?.isPartial == true)
    #expect(week?.summary.daysWithDrinks == 1)
    #expect(week?.summary.daysAlcoholFree == 0)
    #expect(week?.summary.daysUnlogged == 3)
    #expect(week?.shares.count == 1)
  }

  // MARK: - The figures

  @Test("A week's figures partition its seven days and match the bar")
  func weekFiguresMatchTheBar() {
    let end = date(2026, 8, 26, 12)
    let drinks = [beer(date(2026, 8, 10, 19)), beer(date(2026, 8, 10, 21)), wine(date(2026, 8, 13, 20))]
    let free: Set<Date> = [date(2026, 8, 11), date(2026, 8, 12)]
    let week = detail(date(2026, 8, 12, 9), range: .quarter, endingOn: end, drinks: drinks, free: free, health: [date(2026, 8, 12)])

    #expect(week?.start == date(2026, 8, 9))
    #expect(week?.summary.daysWithDrinks == 2)
    #expect(week?.summary.daysAlcoholFree == 2)
    #expect(week?.summary.daysUnlogged == 3)
    #expect(week?.summary.dayCount == 7)
    #expect(week.map { abs($0.summary.totalStandardDrinks - 3.0) < 0.0001 } == true)
    #expect(week.map { abs($0.summary.averageOnDrinkingDays - 1.5) < 0.0001 } == true)
    #expect(week?.dayRecord == nil)

    let totals = TrendSummary.dailyTotals(range: .quarter, endingOn: end, drinks: drinks, region: .unitedStates, calendar: calendar)
    let bar = TrendSummary.bucketed(totals, by: .weekOfYear, calendar: calendar).first { $0.start == date(2026, 8, 9) }
    #expect(bar.map { abs($0.standardDrinks - (week?.standardDrinks ?? -1)) < 1e-9 } == true)

    // A different fact, asserted beside it: the Trends card counts every
    // zero-total day, markers included.
    let sevenDays = totals.filter { $0.date >= date(2026, 8, 9) && $0.date <= date(2026, 8, 15) }
    #expect(TrendSummary.daysWithoutDrinks(sevenDays) == 5)
  }

  @Test("Shares sum to the bar and list in a stable order")
  func sharesSumAndOrder() {
    let day = date(2026, 8, 20)
    let drinks: [LoggedDrink] = [
      LoggedDrink.importedFromHealth(sampleID: UUID(), count: 2, loggedAt: date(2026, 8, 20, 22)),
      LoggedDrink.standardDrink(in: .unitedStates, at: date(2026, 8, 20, 21)),
      wine(date(2026, 8, 20, 20)),
      beer(date(2026, 8, 20, 19)),
      beer(date(2026, 8, 20, 18)),
    ]
    let detail = detail(day, range: .week, endingOn: date(2026, 8, 26, 12), drinks: drinks)
    let shares = detail?.shares ?? []
    #expect(shares.map(\.kind) == [.type(.beer), .type(.wine), .type(.unspecified), .importedFromHealth])
    #expect(shares.map(\.count) == [2, 1, 1, 2])
    #expect(shares.map { abs($0.standardDrinks - [2.0, 1.0, 1.0, 2.0][shares.firstIndex(of: $0)!]) < 0.0001 }.allSatisfy { $0 })
    let sum = shares.reduce(0) { $0 + $1.standardDrinks }
    #expect(abs(sum - 6.0) < 0.0001)
    #expect(abs(sum - (detail?.standardDrinks ?? -1)) < 1e-9)

    let onlyWine = TrendSummary.shares(of: [wine(day), wine(day)], region: .unitedStates)
    #expect(onlyWine.map(\.kind) == [.type(.wine)])
    #expect(onlyWine.first?.count == 2)
  }

  @Test("Shares follow the region lens; imports do not")
  func sharesFollowTheLens() {
    let drinks: [LoggedDrink] = [
      beer(date(2026, 8, 20, 18)), beer(date(2026, 8, 20, 19)), wine(date(2026, 8, 20, 20)),
      LoggedDrink.standardDrink(in: .unitedStates, at: date(2026, 8, 20, 21)),
      LoggedDrink.importedFromHealth(sampleID: UUID(), count: 2, loggedAt: date(2026, 8, 20, 22)),
    ]
    let ukUnit = LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5).standardDrinks(in: .unitedKingdom)
    for region in Region.allCases {
      let d = detail(date(2026, 8, 20), range: .week, endingOn: date(2026, 8, 26, 12), drinks: drinks, region: region)
      let shares = d?.shares ?? []
      #expect(shares.map(\.count) == [2, 1, 1, 2])
      let sum = shares.reduce(0) { $0 + $1.standardDrinks }
      #expect(abs(sum - (d?.standardDrinks ?? -1)) < 1e-9)
      #expect(shares.last?.standardDrinks == 2.0)
      if region == .unitedKingdom {
        #expect(abs((shares[0].standardDrinks) - 2 * ukUnit) < 0.0001)
      }
    }
  }

  @Test("A fractional import stays fractional, and an older build's stripped import reads as the log stands")
  func importShapes() {
    let half = TrendSummary.shares(
      of: [LoggedDrink.importedFromHealth(sampleID: UUID(), count: 1.5, loggedAt: date(2026, 8, 20, 12))],
      region: .unitedKingdom
    )
    #expect(half.map(\.kind) == [.importedFromHealth])
    #expect(half.first?.count == 1.5)
    #expect(half.first?.standardDrinks == 1.5)

    let stripped = LoggedDrink(loggedAt: date(2026, 8, 20, 12), type: .other, volumeOunces: 0, abvPercent: 0)
    let shares = TrendSummary.shares(of: [stripped], region: .unitedStates)
    #expect(shares.map(\.kind) == [.type(.other)])
    #expect(shares.first?.count == 1)
    #expect(shares.first?.standardDrinks == 0)
  }

  @Test("A day names which zero it is")
  func dayRecordKinds() {
    let end = date(2026, 8, 26, 12)
    let day = date(2026, 8, 24)
    #expect(detail(day, range: .week, endingOn: end, free: [day], health: [day])?.dayRecord == .alcoholFree(fromHealth: true))
    #expect(detail(day, range: .week, endingOn: end, free: [day])?.dayRecord == .alcoholFree(fromHealth: false))
    let blank = detail(day, range: .week, endingOn: end)
    #expect(blank?.dayRecord == .unlogged)
    #expect(blank?.summary.daysUnlogged == 1)

    let zeroStrength = detail(day, range: .week, endingOn: end, drinks: [beer(date(2026, 8, 24, 20), abv: 0)])
    #expect(zeroStrength?.dayRecord == .drinks)
    #expect(zeroStrength?.standardDrinks == 0)
    #expect(zeroStrength?.shares.map(\.kind) == [.type(.beer)])

    let both = detail(day, range: .week, endingOn: end, drinks: [beer(date(2026, 8, 24, 20))], free: [day])
    #expect(both?.dayRecord == .drinks)
    #expect(both?.summary.daysAlcoholFree == 0)
  }

  @Test("The midnight daylight-saving day is found and keeps its total")
  func santiagoTransitionWeek() {
    var santiago = Calendar(identifier: .gregorian)
    santiago.timeZone = TimeZone(identifier: "America/Santiago")!
    santiago.firstWeekday = 1
    func noon(_ month: Int, _ day: Int) -> Date {
      santiago.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }
    func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
      santiago.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    let drinks = [noon(9, 6), noon(9, 7), noon(9, 16)].map {
      LoggedDrink(loggedAt: $0, type: .beer, volumeOunces: 12, abvPercent: 5)
    }
    let marker = santiago.startOfDay(for: noon(9, 8))
    let transitionDay = santiago.startOfDay(for: noon(9, 6))

    let day = detail(at(9, 6, 1, 30), range: .month, endingOn: noon(9, 26), drinks: drinks, calendar: santiago)
    #expect(day?.start == transitionDay)
    #expect(day.map { abs($0.standardDrinks - 1.0) < 0.0001 } == true)

    let week = detail(noon(9, 8), range: .quarter, endingOn: noon(10, 16), drinks: drinks, free: [marker], calendar: santiago)
    #expect(week?.start == transitionDay)
    #expect(week?.periodLength == 7)
    #expect(week?.summary.dayCount == 7)
    #expect(week?.isPartial == false)
    #expect(week?.summary.daysWithDrinks == 2)
    #expect(week?.summary.daysAlcoholFree == 1)
    #expect(week?.summary.daysUnlogged == 4)
    #expect(week?.lastDay == santiago.startOfDay(for: noon(9, 12)))
  }

  @Test("bucketStart matches bucketed's placement for every bar")
  func bucketStartMatchesEveryBar() {
    var santiago = Calendar(identifier: .gregorian)
    santiago.timeZone = TimeZone(identifier: "America/Santiago")!
    santiago.firstWeekday = 1
    let santiagoEnd = santiago.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12))!

    let cases: [(TrendRange, Date, Calendar)] =
      TrendRange.allCases.map { ($0, date(2026, 8, 26, 12), calendar) } + [(.quarter, santiagoEnd, santiago)]
    for (range, end, cal) in cases {
      let totals = TrendSummary.dailyTotals(range: range, endingOn: end, drinks: [], region: .unitedStates, calendar: cal)
      let starts = range.bucket == .day
        ? totals.map(\.date)
        : TrendSummary.bucketed(totals, by: range.bucket, calendar: cal).map(\.start)
      for start in starts {
        let found = TrendSummary.bucketStart(containing: start.addingTimeInterval(3600), range: range, endingOn: end, calendar: cal)
        #expect(found == start, "\(range) \(start)")
      }
      #expect(TrendSummary.bucketStarts(range: range, endingOn: end, calendar: cal) == starts)
    }
  }

  @Test("Detail totals agree with the bars for every bucket at scale")
  func detailAgreesWithBarsAtScale() {
    let end = date(2026, 8, 26, 12)
    var drinks: [LoggedDrink] = []
    let types: [DrinkType] = [.beer, .wine, .spirit, .other]
    for i in 0..<10_000 {
      let dayOffset = -(i % 400)
      let stamp = calendar.date(byAdding: .day, value: dayOffset, to: date(2026, 8, 26, 12 + (i % 11)))!
      switch i % 6 {
      case 0: drinks.append(LoggedDrink.importedFromHealth(sampleID: UUID(), count: Double(1 + i % 3), loggedAt: stamp))
      case 1: drinks.append(LoggedDrink.standardDrink(in: .unitedStates, at: stamp))
      default: drinks.append(LoggedDrink(loggedAt: stamp, type: types[i % 4], volumeOunces: Double(4 + i % 10), abvPercent: Double(3 + i % 12)))
      }
    }
    for range in [TrendRange.quarter, .year] {
      let totals = TrendSummary.dailyTotals(range: range, endingOn: end, drinks: drinks, region: .unitedStates, calendar: calendar)
      for bar in TrendSummary.bucketed(totals, by: range.bucket, calendar: calendar) {
        let d = detail(bar.start, range: range, endingOn: end, drinks: drinks)
        #expect(d.map { abs($0.standardDrinks - bar.standardDrinks) < 1e-9 } == true)
        #expect(d?.summary.dayCount == bar.dayCount)
      }
    }
    let month = TrendSummary.dailyTotals(range: .month, endingOn: end, drinks: drinks, region: .unitedStates, calendar: calendar)
    for bar in month {
      let d = detail(bar.date, range: .month, endingOn: end, drinks: drinks)
      #expect(d.map { abs($0.standardDrinks - bar.standardDrinks) < 1e-9 } == true)
    }
  }

  /// The structural pin that nothing range-relative — an average delta, a
  /// rank, a percentage — has crept into the type.
  @Test("A bar's facts do not depend on the range that contains it")
  func rangeIndependence() {
    let end = date(2026, 8, 26, 12)
    let drinks = [beer(date(2026, 8, 25, 19)), wine(date(2026, 8, 25, 21)), beer(date(2026, 8, 20, 19))]
    let week = detail(date(2026, 8, 25, 12), range: .week, endingOn: end, drinks: drinks)
    let month = detail(date(2026, 8, 25, 12), range: .month, endingOn: end, drinks: drinks)
    #expect(week != nil)
    #expect(week == month)
  }

  @Test("Stepping moves one bar at a time and stops at the ends")
  func stepping() {
    let end = date(2026, 8, 26, 12)
    #expect(TrendSummary.adjacentBucketStart(from: date(2026, 8, 26), direction: 1, range: .week, endingOn: end, calendar: calendar) == nil)
    #expect(TrendSummary.adjacentBucketStart(from: date(2026, 8, 20), direction: -1, range: .week, endingOn: end, calendar: calendar) == nil)
    #expect(TrendSummary.adjacentBucketStart(from: date(2026, 8, 22), direction: 1, range: .week, endingOn: end, calendar: calendar) == date(2026, 8, 23))
    #expect(TrendSummary.adjacentBucketStart(from: date(2026, 8, 23), direction: -1, range: .quarter, endingOn: end, calendar: calendar) == date(2026, 8, 16))
    #expect(TrendSummary.adjacentBucketStart(from: date(2026, 8, 1), direction: 1, range: .year, endingOn: end, calendar: calendar) == nil)
    #expect(TrendSummary.adjacentBucketStart(from: date(2026, 8, 1), direction: -1, range: .year, endingOn: end, calendar: calendar) == date(2026, 7, 1))
    #expect(TrendSummary.adjacentBucketStart(from: date(2026, 8, 2), direction: -1, range: .year, endingOn: end, calendar: calendar) == nil)
  }

  @Test("A detail for a date after the range's end is nothing, and a new drink shows up in place")
  func afterRangeAndLiveData() {
    #expect(detail(date(2026, 8, 26), range: .week, endingOn: date(2026, 8, 1, 12)) == nil)

    let end = date(2026, 8, 26, 12)
    let before = detail(date(2026, 8, 25), range: .week, endingOn: end, drinks: [beer(date(2026, 8, 25, 19))])
    let after = detail(date(2026, 8, 25), range: .week, endingOn: end, drinks: [beer(date(2026, 8, 25, 19)), beer(date(2026, 8, 25, 20))])
    #expect(before?.shares.first?.count == 1)
    #expect(after?.shares.first?.count == 2)
    #expect(after.map { abs($0.standardDrinks - 2.0) < 0.0001 } == true)
  }
}
