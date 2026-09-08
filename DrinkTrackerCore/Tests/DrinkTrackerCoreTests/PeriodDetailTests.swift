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

  /// The trailing bar is drawn across its whole calendar unit, so a touch on
  /// the part of it after today must still select it; the next unit is no bar.
  @Test("A touch anywhere on the trailing week or month bar selects it, and past it selects nothing")
  func trailingBarIsSelectableAcrossItsUnit() {
    let end = date(2026, 9, 3, 12)  // a Thursday
    #expect(TrendSummary.bucketStart(containing: date(2026, 9, 20), range: .year, endingOn: end, calendar: calendar) == date(2026, 9, 1))
    #expect(TrendSummary.bucketStart(containing: date(2026, 9, 30, 23, 59), range: .year, endingOn: end, calendar: calendar) == date(2026, 9, 1))
    #expect(TrendSummary.bucketStart(containing: date(2026, 10, 1, 1), range: .year, endingOn: end, calendar: calendar) == nil)
    #expect(TrendSummary.bucketStart(containing: date(2026, 9, 5, 12), range: .quarter, endingOn: end, calendar: calendar) == date(2026, 8, 30))
    #expect(TrendSummary.bucketStart(containing: date(2026, 9, 6, 1), range: .quarter, endingOn: end, calendar: calendar) == nil)

    // The detail is still the bucket clipped to the range.
    let september = detail(date(2026, 9, 20), range: .year, endingOn: end)
    #expect(september?.start == date(2026, 9, 1))
    #expect(september?.lastDay == date(2026, 9, 3))
    #expect(september?.summary.dayCount == 3)
    #expect(september?.isPartial == true)

    // Daily charts keep clipping the touch itself: no bar is drawn past today.
    #expect(TrendSummary.bucketStart(containing: date(2026, 9, 4, 1), range: .week, endingOn: end, calendar: calendar) == nil)
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
      // A cocktail rows between wine and the untyped drink: `allCases` order,
      // which is the picker's order (ADR-0035).
      LoggedDrink(loggedAt: date(2026, 8, 20, 17), type: .cocktail, volumeOunces: 1.5, abvPercent: 40),
    ]
    let detail = detail(day, range: .week, endingOn: date(2026, 8, 26, 12), drinks: drinks)
    let shares = detail?.shares ?? []
    #expect(shares.map(\.kind) == [.type(.beer), .type(.wine), .type(.cocktail), .type(.unspecified), .importedFromHealth])
    #expect(shares.map(\.count) == [2, 1, 1, 1, 2])
    #expect(shares.map { abs($0.standardDrinks - [2.0, 1.0, 1.0, 1.0, 2.0][shares.firstIndex(of: $0)!]) < 0.0001 }.allSatisfy { $0 })
    let sum = shares.reduce(0) { $0 + $1.standardDrinks }
    #expect(abs(sum - 7.0) < 0.0001)
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
    let types = DrinkType.selectableCases
    for i in 0..<10_000 {
      let dayOffset = -(i % 400)
      let stamp = calendar.date(byAdding: .day, value: dayOffset, to: date(2026, 8, 26, 12 + (i % 11)))!
      switch i % 6 {
      case 0: drinks.append(LoggedDrink.importedFromHealth(sampleID: UUID(), count: Double(1 + i % 3), loggedAt: stamp))
      case 1: drinks.append(LoggedDrink.standardDrink(in: .unitedStates, at: stamp))
      default: drinks.append(LoggedDrink(loggedAt: stamp, type: types[i % types.count], volumeOunces: Double(4 + i % 10), abvPercent: Double(3 + i % 12)))
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

  // MARK: - The range's own figures (ADR-0028 amendment)

  @Test("The range's own figures use the same classifier as a bar's")
  func rangeSummaryClassifier() {
    let end = date(2026, 8, 30, 12)
    let drinks = [beer(date(2026, 8, 28, 19)), beer(date(2026, 8, 27, 19), abv: 0)]
    let free: Set<Date> = [date(2026, 8, 26)]
    let summary = TrendSummary.rangeSummary(
      range: .week, endingOn: end, drinks: drinks,
      alcoholFreeDays: free, region: .unitedStates, calendar: calendar
    )
    // A 0%-ABV day is a day with drinks — the calendar's rule, and the bar's.
    #expect(summary.daysWithDrinks == 2)
    #expect(summary.daysAlcoholFree == 1)
    #expect(summary.daysWithDrinks + summary.daysAlcoholFree + summary.daysUnlogged == summary.dayCount)
    #expect(summary.dayCount == 7)

    // The trap this function exists to avoid: `daysWithoutDrinks` counts
    // zero-*total* days, so its complement is one short of the header's count.
    let totals = TrendSummary.dailyTotals(
      range: .week, endingOn: end, drinks: drinks, region: .unitedStates, calendar: calendar
    )
    #expect(totals.count - TrendSummary.daysWithoutDrinks(totals) == 1)
  }

  @Test("The range total the header prints equals the bars' own sum")
  func rangeSummaryTotalAgreesWithBars() {
    let end = date(2026, 8, 30, 12)
    let drinks = [beer(date(2026, 8, 28, 19)), wine(date(2026, 8, 24, 20)), beer(date(2026, 8, 12, 18))]
    for range in TrendRange.allCases {
      for region in [Region.unitedStates, .unitedKingdom] {
        let totals = TrendSummary.dailyTotals(
          range: range, endingOn: end, drinks: drinks, region: region, calendar: calendar
        )
        let summary = TrendSummary.rangeSummary(
          range: range, endingOn: end, drinks: drinks,
          alcoholFreeDays: [], region: region, calendar: calendar
        )
        #expect(abs(summary.totalStandardDrinks - TrendSummary.sum(totals)) < 0.0001)
        #expect(summary.dayCount == totals.count)
      }
    }
  }

  @Test("A region switch moves the range's amounts and never its day counts")
  func rangeSummaryRegionLens() {
    let end = date(2026, 8, 30, 12)
    let drinks = [beer(date(2026, 8, 28, 19)), wine(date(2026, 8, 24, 20))]
    let us = TrendSummary.rangeSummary(
      range: .month, endingOn: end, drinks: drinks,
      alcoholFreeDays: [], region: .unitedStates, calendar: calendar
    )
    let uk = TrendSummary.rangeSummary(
      range: .month, endingOn: end, drinks: drinks,
      alcoholFreeDays: [], region: .unitedKingdom, calendar: calendar
    )
    #expect(us.daysWithDrinks == uk.daysWithDrinks)
    #expect(us.daysUnlogged == uk.daysUnlogged)
    #expect(us.totalStandardDrinks != uk.totalStandardDrinks)
  }

  // MARK: - The longest run with none (ADR-0033)

  private func day(_ n: Int, entries: Bool, marked: Bool) -> CalendarDay {
    CalendarDay(
      date: date(2026, 3, n), standardDrinks: entries ? 1 : 0,
      isMarkedAlcoholFree: marked, hasEntries: entries
    )
  }

  @Test("A run counts marked days only, and anything else breaks it")
  func longestRunCountsRecordsOnly() {
    // marked, marked, unlogged, marked, marked, marked, drinks
    let days = [
      day(1, entries: false, marked: true),
      day(2, entries: false, marked: true),
      day(3, entries: false, marked: false),
      day(4, entries: false, marked: true),
      day(5, entries: false, marked: true),
      day(6, entries: false, marked: true),
      day(7, entries: true, marked: false),
    ]
    #expect(TrendSummary.longestAlcoholFreeRun(of: days) == 3)

    // Evidence beats assertion: a day holding both is a day with drinks, so it
    // breaks the run rather than extending it.
    let contradicted = [
      day(1, entries: false, marked: true),
      day(2, entries: true, marked: true),
      day(3, entries: false, marked: true),
    ]
    #expect(TrendSummary.longestAlcoholFreeRun(of: contradicted) == 1)

    #expect(TrendSummary.longestAlcoholFreeRun(of: []) == 0)
    #expect(TrendSummary.longestAlcoholFreeRun(of: [day(1, entries: false, marked: false)]) == 0)
    #expect(TrendSummary.longestAlcoholFreeRun(of: [day(1, entries: true, marked: false)]) == 0)

    let allMarked = (1...5).map { day($0, entries: false, marked: true) }
    #expect(TrendSummary.longestAlcoholFreeRun(of: allMarked) == 5)
  }

  /// ADR-0033's whole safety argument, checked exhaustively rather than
  /// asserted: over every window of every three-state day up to length 9,
  /// turning any one day into "nothing recorded either way" — which is what
  /// *not logging* produces — can never raise the figure.
  ///
  /// This is the property the refused definition fails: counting zero-total
  /// days would make omission the cheapest way to lengthen a run.
  @Test("No omission can lengthen a run")
  func omissionNeverLengthensARun() {
    // 0 = nothing recorded, 1 = marked no alcohol, 2 = has drinks
    for length in 1...9 {
      var counters = [Int](repeating: 0, count: length)
      while true {
        let days = counters.enumerated().map { index, state in
          day(index + 1, entries: state == 2, marked: state == 1)
        }
        let base = TrendSummary.longestAlcoholFreeRun(of: days)

        for index in 0..<length where counters[index] != 0 {
          var omitted = days
          omitted[index] = day(index + 1, entries: false, marked: false)
          #expect(TrendSummary.longestAlcoholFreeRun(of: omitted) <= base)
        }

        var position = length - 1
        while position >= 0, counters[position] == 2 { counters[position] = 0; position -= 1 }
        if position < 0 { break }
        counters[position] += 1
      }
    }
  }

  @Test("A bar's run is clipped to the bar's own days")
  func longestRunClippedToTheBucket() {
    // A marked stretch that straddles two weeks: neither week may claim it all.
    let end = date(2026, 3, 14, 12)
    let free = Set((5...11).map { date(2026, 3, $0) })
    let first = detail(date(2026, 3, 5), range: .quarter, endingOn: end, free: free)
    let second = detail(date(2026, 3, 12), range: .quarter, endingOn: end, free: free)
    #expect(first?.longestAlcoholFreeRun == 3)   // Thu-Sat of the week starting Sunday Mar 1
    #expect(second?.longestAlcoholFreeRun == 4)  // Sun-Wed of the next
    #expect((first?.longestAlcoholFreeRun ?? 0) + (second?.longestAlcoholFreeRun ?? 0) == 7)
  }

  @Test("The run never exceeds the days with none, and a day bar is 0 or 1")
  func longestRunIsBounded() {
    let end = date(2026, 8, 30, 12)
    let drinks = [beer(date(2026, 8, 28, 19)), wine(date(2026, 8, 24, 20))]
    let free: Set<Date> = [date(2026, 8, 25), date(2026, 8, 26), date(2026, 8, 29)]
    for range in TrendRange.allCases {
      let days = TrendSummary.rangeDays(
        range: range, endingOn: end, drinks: drinks,
        alcoholFreeDays: free, region: .unitedStates, calendar: calendar
      )
      let summary = TrendSummary.summary(of: days)
      let run = TrendSummary.longestAlcoholFreeRun(of: days)
      #expect(run <= summary.daysAlcoholFree)
      #expect(run >= (summary.daysAlcoholFree > 0 ? 1 : 0))
    }
    #expect(detail(date(2026, 8, 25), range: .week, endingOn: end, drinks: drinks, free: free)?.longestAlcoholFreeRun == 1)
    #expect(detail(date(2026, 8, 27), range: .week, endingOn: end, drinks: drinks, free: free)?.longestAlcoholFreeRun == 0)
  }
}
