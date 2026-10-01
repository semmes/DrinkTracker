import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0058: Trends on one window. Every figure under the range picker whose
/// denominator is a count of days reads the range's own days, cut at the first
/// record's day while the log is younger than the range; the bars keep the
/// range; and the three comparisons share one floor, 28 days of record.
@Suite("Trends window")
struct TrendWindowTests {

  /// UTC, Sunday-first: 30 September 2026 is a Wednesday, and the four ranges
  /// ending on it hold 7, 30, 88 (5 July on) and 365 (1 October 2025 on) days —
  /// the 88 the owner's Quarter screenshot shows.
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  private func beer(_ at: Date, abv: Double = 5) -> LoggedDrink {
    LoggedDrink(loggedAt: at, type: .beer, volumeOunces: 12, abvPercent: abv, region: .unitedStates)
  }

  private var today: Date { date(2026, 9, 30) }

  private func window(_ range: TrendRange, firstRecord: Date?, endingOn end: Date? = nil) -> TrendWindow {
    TrendSummary.trendWindow(range: range, endingOn: end ?? today, firstRecord: firstRecord, calendar: calendar)
  }

  private func fold(
    _ range: TrendRange,
    _ drinks: [LoggedDrink],
    markers: Set<Date> = [],
    firstRecord: Date?,
    endingOn end: Date? = nil
  ) -> TrendWindowFold {
    TrendSummary.windowFold(
      range: range, endingOn: end ?? today, drinks: drinks, alcoholFreeDays: markers,
      firstRecord: firstRecord, region: .unitedStates, calendar: calendar
    )
  }

  // MARK: - The floor

  @Test("The comparisons appear from 28 days of record, counted in days, at every range")
  func floorBothSides() {
    for range in TrendRange.allCases {
      // 3 September is the 28th day back, counting today.
      #expect(window(range, firstRecord: date(2026, 9, 3, 23, 59)).clearsComparisonFloor)
      #expect(window(range, firstRecord: date(2026, 9, 3, 0, 0)).clearsComparisonFloor)
      #expect(!window(range, firstRecord: date(2026, 9, 4, 0, 0)).clearsComparisonFloor)
      #expect(window(range, firstRecord: date(2019, 1, 1)).clearsComparisonFloor)
      #expect(TrendSummary.comparisonWindow(range: range, endingOn: today, firstRecord: date(2026, 9, 4, 0, 0), calendar: calendar) == nil)
      #expect(TrendSummary.comparisonWindow(range: range, endingOn: today, firstRecord: date(2026, 9, 3), calendar: calendar) != nil)
    }
  }

  @Test("No record is under the floor and clips nothing")
  func noRecord() {
    for range in TrendRange.allCases {
      let w = window(range, firstRecord: nil)
      #expect(!w.clearsComparisonFloor)
      #expect(!w.isClipped)
      #expect(w.days == TrendSummary.days(in: range, endingOn: today, calendar: calendar))
      #expect(TrendSummary.comparisonWindow(range: range, endingOn: today, firstRecord: nil, calendar: calendar) == nil)
    }
    // An empty log reads the range as it always has: seven days with no drinks of seven.
    let empty = fold(.week, [], firstRecord: nil)
    #expect(empty.daysWithoutDrinks == 7)
    #expect(empty.window.dayCount == 7)
  }

  @Test("A record dated after today is under the floor and clips nothing")
  func recordAfterToday() {
    for range in TrendRange.allCases {
      let w = window(range, firstRecord: date(2026, 10, 1))
      #expect(!w.clearsComparisonFloor)
      #expect(!w.isClipped)
      #expect(w.dayCount == TrendSummary.days(in: range, endingOn: today, calendar: calendar).count)
    }
  }

  /// Santiago moves its clocks at midnight on 2026-09-06, so that day starts
  /// at 01:00 (ADR-0026). A Month range ending 5 October starts on it, and the
  /// floor counted back from 3 October lands on it.
  @Test("The floor and the clip hold on a midnight daylight-saving range start")
  func santiagoRangeStart() {
    var santiago = Calendar(identifier: .gregorian)
    santiago.timeZone = TimeZone(identifier: "America/Santiago")!
    santiago.firstWeekday = 1
    func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
      santiago.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    let transitionDay = santiago.startOfDay(for: at(9, 6, 12))

    let end = at(10, 5, 12)
    let fromTransition = TrendSummary.trendWindow(range: .month, endingOn: end, firstRecord: at(9, 6, 1, 30), calendar: santiago)
    #expect(!fromTransition.isClipped)
    #expect(fromTransition.dayCount == 30)
    #expect(fromTransition.firstDay == transitionDay)

    let dayAfter = TrendSummary.trendWindow(range: .month, endingOn: end, firstRecord: at(9, 7, 0, 30), calendar: santiago)
    #expect(dayAfter.isClipped)
    #expect(dayAfter.dayCount == 29)
    #expect(dayAfter.firstDay == santiago.startOfDay(for: at(9, 7, 12)))

    // The 28th day back from 3 October, counting it, is the transition day.
    let floorEnd = at(10, 3, 12)
    #expect(TrendSummary.trendWindow(range: .week, endingOn: floorEnd, firstRecord: at(9, 6, 1, 30), calendar: santiago).clearsComparisonFloor)
    #expect(!TrendSummary.trendWindow(range: .week, endingOn: floorEnd, firstRecord: at(9, 7, 0, 30), calendar: santiago).clearsComparisonFloor)

    // And a fold over the clipped window has 29 days, none of them before the record.
    let drinks = [beer(at(9, 7, 20)), beer(at(10, 5, 9))]
    let folded = TrendSummary.windowFold(
      range: .month, endingOn: end, drinks: drinks, alcoholFreeDays: [],
      firstRecord: at(9, 7, 20), region: .unitedStates, calendar: santiago
    )
    #expect(folded.summary.dayCount == 29)
    #expect(folded.summary.daysWithDrinks == 2)
  }

  // MARK: - The clip

  @Test("A log younger than the range covers the first record's day through today, at every range")
  func clipAtEveryRange() {
    let aug12 = date(2026, 8, 12, 9)
    #expect(!window(.week, firstRecord: aug12).isClipped)
    #expect(!window(.month, firstRecord: aug12).isClipped)
    let quarter = window(.quarter, firstRecord: aug12)
    let year = window(.year, firstRecord: aug12)
    for w in [quarter, year] {
      #expect(w.isClipped)
      #expect(w.dayCount == 50)  // 12 August – 30 September
      #expect(w.firstDay == calendar.startOfDay(for: aug12))
      #expect(w.days.last == calendar.startOfDay(for: today))
    }
    // Under 13 weeks old, Quarter and Year cover the same days and fold to
    // the same figures; only their chart titles differ.
    #expect(quarter.days == year.days)
    let drinks = [beer(date(2026, 8, 12, 9)), beer(date(2026, 8, 15)), beer(date(2026, 9, 26)), beer(date(2026, 9, 26, 21))]
    let q = fold(.quarter, drinks, firstRecord: aug12)
    let y = fold(.year, drinks, firstRecord: aug12)
    #expect(q.summary == y.summary)
    #expect(q.weekdays == y.weekdays)
    #expect(q.dailyAverage == y.dailyAverage)
    #expect(q.weeklyFigure == y.weeklyFigure)

    // Three days old: clipped at every range, Week included.
    let sep28 = date(2026, 9, 28, 18)
    for range in TrendRange.allCases {
      let w = window(range, firstRecord: sep28)
      #expect(w.isClipped)
      #expect(w.dayCount == 3)
    }
  }

  /// The first day of a log, the commonest young log there is: the first record
  /// is today's, and every range, Week included, is that one day. Without this
  /// case the clip's upper bound (a record on or before today) could become
  /// "before today" and pass every other test (the 2026-10-01 review's mutation).
  @Test("Day one: a first record dated today clips every range to today")
  func dayOne() {
    let now = date(2026, 9, 30, 21)
    let morning = date(2026, 9, 30, 8)
    let drinks = [beer(date(2026, 9, 30, 20))]
    let todayKey = calendar.startOfDay(for: now)
    for range in TrendRange.allCases {
      let f = fold(range, drinks, firstRecord: morning, endingOn: now)
      #expect(f.window.isClipped, "\(range)")
      #expect(f.window.days == [todayKey], "\(range)")
      #expect(!f.window.clearsComparisonFloor, "\(range)")
      #expect(f.daysWithoutDrinks == 0, "\(range)")
      #expect(f.summary.daysWithDrinks == 1, "\(range)")
      #expect(f.weekdays.reduce(0) { $0 + $1.dayCount } == 1, "\(range)")
      #expect(abs(f.dailyAverage - f.summary.totalStandardDrinks) < 1e-9, "\(range)")
    }
    let week = fold(.week, drinks, firstRecord: morning, endingOn: now)
    #expect(week.averageLine(calendar: calendar) == week.dailyAverage)
    #expect(fold(.year, drinks, firstRecord: morning, endingOn: now).averageLine(calendar: calendar) == nil)
  }

  /// Decisions 3 and 5 read literally: at Quarter the line is the window's
  /// weekly figure, and a window shorter than a week projects its days to a
  /// week, so on a log's first days the line stands above every weekly bar.
  /// Main drew no line here (its completed-weeks mean was zero). Pinned as
  /// built and recorded in ADR-0058; the owner may prefer no line under seven
  /// days, which would change the first two expectations to nil.
  @Test("Quarter's line on a log under a week old is its days projected to a week")
  func quarterLineUnderAWeek() {
    let now = date(2026, 9, 30, 21)
    let four = (0..<4).map { beer(date(2026, 9, 30, 18 + $0)) }
    let oneDay = fold(.quarter, four, firstRecord: date(2026, 9, 30, 18), endingOn: now)
    let projected: Double = oneDay.summary.totalStandardDrinks * 7
    #expect(abs((oneDay.averageLine(calendar: calendar) ?? 0) - projected) < 1e-9)
    let fourDays = fold(.quarter, four, firstRecord: date(2026, 9, 27, 9), endingOn: now)
    let overFour: Double = fourDays.summary.totalStandardDrinks * 7 / 4
    #expect(abs((fourDays.averageLine(calendar: calendar) ?? 0) - overFour) < 1e-9)
    // From a whole week on, the line is no larger than the window's total.
    let aWeek = fold(.quarter, four, firstRecord: date(2026, 9, 24, 9), endingOn: now)
    #expect(aWeek.window.dayCount == 7)
    #expect(abs((aWeek.averageLine(calendar: calendar) ?? 0) - aWeek.summary.totalStandardDrinks) < 1e-9)
  }

  @Test("A log old enough covers the range exactly")
  func oldEnoughIsTheRange() {
    for range in TrendRange.allCases {
      let w = window(range, firstRecord: date(2024, 2, 29))
      #expect(!w.isClipped)
      #expect(w.days == TrendSummary.days(in: range, endingOn: today, calendar: calendar))
    }
    // A record on the range's own first day reaches it: nothing to clip.
    let quarterStart = date(2026, 7, 5, 20)
    #expect(!window(.quarter, firstRecord: quarterStart).isClipped)
    #expect(window(.quarter, firstRecord: quarterStart).dayCount == 88)
    #expect(window(.year, firstRecord: quarterStart).isClipped)
    #expect(window(.year, firstRecord: quarterStart).dayCount == 88)
  }

  /// Decision 5: every figure whose denominator is a count of days divides by
  /// the window's days; the counts do not move; the bars keep the range.
  @Test("Over a young log every day-count figure divides by the window's days, and the bars keep the range")
  func youngLogDenominators() {
    let firstMarker = calendar.startOfDay(for: date(2026, 9, 19))
    let markers: Set<Date> = [firstMarker, calendar.startOfDay(for: date(2026, 9, 22))]
    let drinks = [
      beer(date(2026, 9, 20, 19)), beer(date(2026, 9, 20, 21)),
      beer(date(2026, 9, 25), abv: 0),   // a 0% drink: a day with drinks whose total is zero
      beer(date(2026, 9, 27))
    ]
    let month = fold(.month, drinks, markers: markers, firstRecord: firstMarker)
    #expect(month.window.isClipped)
    #expect(month.window.dayCount == 12)  // 19 – 30 September

    let total = month.summary.totalStandardDrinks
    let perDay: Double = total / 12
    #expect(abs(month.dailyAverage - perDay) < 1e-12)
    #expect(month.averageLine(calendar: calendar) == month.dailyAverage)
    #expect(month.daysWithoutDrinks == 10)  // the 20th and the 27th are the only days with a total
    #expect(month.weekdays.reduce(0) { $0 + $1.dayCount } == 12)
    #expect(month.summary.daysWithDrinks == 3)
    #expect(month.summary.daysAlcoholFree == 2)
    #expect(month.summary.daysUnlogged == 7)

    // The counts are the range's: no day before the first record holds anything.
    let header = TrendSummary.rangeSummary(
      range: .month, endingOn: today, drinks: drinks, alcoholFreeDays: markers, region: .unitedStates, calendar: calendar
    )
    #expect(header.dayCount == 30)
    #expect(header.daysWithDrinks == month.summary.daysWithDrinks)
    #expect(abs(header.totalStandardDrinks - total) < 1e-12)

    // The bars still number the range's buckets.
    let monthBars = TrendSummary.dailyTotals(range: .month, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar)
    #expect(monthBars.count == 30)
    let quarterBars = TrendSummary.bucketed(
      TrendSummary.dailyTotals(range: .quarter, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar),
      by: .weekOfYear, calendar: calendar
    )
    #expect(quarterBars.count == 13)
    let yearBars = TrendSummary.bucketed(
      TrendSummary.dailyTotals(range: .year, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar),
      by: .month, calendar: calendar
    )
    #expect(yearBars.count == 12)

    // The line at Quarter is the window's weekly figure; at Year no month of
    // the window is complete, so there is none.
    let quarter = fold(.quarter, drinks, markers: markers, firstRecord: firstMarker)
    let weekly: Double = total / (12.0 / 7.0)
    #expect(abs(quarter.weeklyFigure - weekly) < 1e-12)
    #expect(quarter.averageLine(calendar: calendar) == quarter.weeklyFigure)
    #expect(fold(.year, drinks, markers: markers, firstRecord: firstMarker).averageLine(calendar: calendar) == nil)
  }

  @Test("Year's line is the mean of the complete months inside the window")
  func yearLineOverCompleteMonths() {
    let drinks = [
      beer(date(2026, 8, 1, 20)), beer(date(2026, 8, 12, 20)), beer(date(2026, 8, 31, 20)),
      beer(date(2026, 9, 4, 20)), beer(date(2026, 9, 30, 20))
    ]
    // From the 1st: August and September are both whole in the window.
    let fromFirst = fold(.year, drinks, firstRecord: date(2026, 8, 1, 20))
    let twoMonths: Double = (3.0 + 2.0) / 2.0
    #expect(abs((fromFirst.averageLine(calendar: calendar) ?? -1) - twoMonths) < 1e-9)
    // From the 12th: August is part of a month, so September alone.
    let fromTwelfth = fold(.year, Array(drinks.dropFirst()), firstRecord: date(2026, 8, 12, 20))
    let september: Double = 2.0
    #expect(abs((fromTwelfth.averageLine(calendar: calendar) ?? -1) - september) < 1e-9)
    // On the 29th, September is not over: no complete month, no line.
    let early = fold(.year, Array(drinks.dropFirst().dropLast()), firstRecord: date(2026, 8, 12, 20), endingOn: date(2026, 9, 29))
    #expect(early.averageLine(calendar: calendar) == nil)
    // A log older than the range keeps the line's rule as it always was.
    let old = fold(.year, drinks, firstRecord: date(2024, 1, 1))
    let all = TrendSummary.bucketAverage(
      TrendSummary.bucketed(
        TrendSummary.dailyTotals(range: .year, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar),
        by: .month, calendar: calendar
      ),
      unit: .month, calendar: calendar
    )
    #expect(old.averageLine(calendar: calendar) == all)
  }

  @Test("The line follows the chart's grain: per day, the weekly figure, or the complete-months mean")
  func lineFollowsTheGrain() {
    var drinks: [LoggedDrink] = []
    for i in 0..<200 where i % 3 != 0 {
      drinks.append(beer(calendar.date(byAdding: .day, value: -i, to: date(2026, 9, 30, 20))!, abv: Double(4 + i % 5)))
    }
    for range in TrendRange.allCases {
      for record in [date(2024, 1, 1), date(2026, 8, 12)] {
        let f = fold(range, drinks, firstRecord: record)
        #expect(f.averageLine(grain: .day, calendar: calendar) == f.dailyAverage, "\(range)")
        #expect(f.averageLine(grain: .week, calendar: calendar) == f.weeklyFigure, "\(range)")
        #expect(f.averageLine(calendar: calendar) == f.averageLine(grain: range.defaultGrain, calendar: calendar), "\(range)")
      }
    }
    // Monthly at Year is the line as it always was.
    let year = fold(.year, drinks, firstRecord: date(2024, 1, 1))
    let months = TrendSummary.bucketAverage(
      TrendSummary.bucketed(
        TrendSummary.dailyTotals(range: .year, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar),
        by: .month, calendar: calendar
      ),
      unit: .month, calendar: calendar
    )
    #expect(year.averageLine(grain: .month, calendar: calendar) == months)
    // A daily line over a whole year divides by its 365 days.
    let daily: Double = year.summary.totalStandardDrinks / 365.0
    #expect(abs((year.averageLine(grain: .day, calendar: calendar) ?? -1) - daily) < 1e-12)
    #expect(year.window.dayCount == 365)
  }

  // MARK: - One set of days

  /// A log with a shape: a weekend drinker since `start`, a 0% drink every
  /// other Sunday, and a no-alcohol marker most Mondays — the first record is
  /// the first Friday's drink or the first Monday's marker, whichever is first.
  private func seededLog(from start: Date, through end: Date) -> (drinks: [LoggedDrink], markers: Set<Date>, first: Date?) {
    var drinks: [LoggedDrink] = []
    var markers: Set<Date> = []
    var day = calendar.startOfDay(for: start)
    var index = 0
    while day <= end {
      let weekday = calendar.component(.weekday, from: day)
      let at = { (hour: Int) in self.calendar.date(byAdding: .hour, value: hour, to: day)! }
      switch weekday {
      case 6: drinks.append(beer(at(19))); drinks.append(beer(at(21)))
      case 7:
        drinks.append(beer(at(18))); drinks.append(beer(at(20)))
        drinks.append(LoggedDrink(loggedAt: at(22), type: .wine, volumeOunces: 5, abvPercent: 12, region: .unitedStates))
      case 1 where index % 2 == 0: drinks.append(beer(at(13), abv: 0))
      case 2 where index % 3 != 0: markers.insert(day)
      default: break
      }
      index += 1
      day = calendar.date(byAdding: .day, value: 1, to: day)!
    }
    let first = [drinks.map(\.loggedAt).min(), markers.min()].compactMap { $0 }.min()
    return (drinks, markers, first)
  }

  @Test("Every figure agrees with the header and every denominator is the window's, at every range")
  func agreementOverASeededLog() throws {
    let weekend = try #require(WeekendReference.bundled).weekendWeekdays
    let ends = [date(2026, 9, 30, 8), date(2026, 9, 26, 23), date(2026, 3, 1), date(2026, 7, 15)]
    for end in ends {
      for start in [date(2025, 6, 1), date(2026, 1, 10), calendar.date(byAdding: .day, value: -40, to: end)!,
                    calendar.date(byAdding: .day, value: -20, to: end)!, calendar.date(byAdding: .day, value: -3, to: end)!] {
        let log = seededLog(from: start, through: end)
        for range in TrendRange.allCases {
          let folded = fold(range, log.drinks, markers: log.markers, firstRecord: log.first, endingOn: end)
          let header = TrendSummary.rangeSummary(
            range: range, endingOn: end, drinks: log.drinks, alcoholFreeDays: log.markers,
            region: .unitedStates, calendar: calendar
          )
          let label = "\(range) ending \(end), log from \(start)"
          let days = folded.window.dayCount
          // The weekly figure × days ÷ 7 is the header's total.
          let restored: Double = folded.weeklyFigure * Double(days) / 7
          #expect(abs(restored - header.totalStandardDrinks) < 1e-9, "\(label)")
          // Drinking days are the header's days with drinks, which are the
          // weekday rows' sum and the weekend split's.
          let split = TrendSummary.weekendSplit(folded.weekdays, weekend: weekend)
          #expect(folded.summary.daysWithDrinks == header.daysWithDrinks, "\(label)")
          #expect(folded.weekdays.reduce(0) { $0 + $1.daysWithDrinks } == header.daysWithDrinks, "\(label)")
          #expect(split.weekendDaysWithDrinks + split.otherDaysWithDrinks == header.daysWithDrinks, "\(label)")
          // Every denominator is the window's day count.
          #expect(folded.summary.dayCount == days, "\(label)")
          #expect(folded.days.count == days, "\(label)")
          #expect(folded.weekdays.reduce(0) { $0 + $1.dayCount } == days, "\(label)")
          #expect(split.dayCount == days, "\(label)")
          // The per-day average and the weekly figure are one total over one count.
          let weekly: Double = folded.dailyAverage * 7
          #expect(abs(weekly - folded.weeklyFigure) < 1e-9, "\(label)")
          // The view's route — the header's classified days, cut — is the same fold.
          let rangeDays = TrendSummary.rangeDays(
            range: range, endingOn: end, drinks: log.drinks, alcoholFreeDays: log.markers,
            region: .unitedStates, calendar: calendar
          )
          #expect(TrendSummary.windowFold(of: rangeDays, in: folded.window, calendar: calendar) == folded, "\(label)")
          // The window is the range's once the log reaches its first day.
          let rangeKeys = TrendSummary.days(in: range, endingOn: end, calendar: calendar)
          if let first = log.first, calendar.startOfDay(for: first) > rangeKeys[0] {
            #expect(folded.window.isClipped, "\(label)")
            #expect(folded.window.firstDay == calendar.startOfDay(for: first), "\(label)")
          } else {
            // Older than the range, or nothing recorded at all.
            #expect(folded.window.days == rangeKeys, "\(label)")
            #expect(!folded.window.isClipped, "\(label)")
          }
        }
      }
    }
  }

  @Test("At Quarter the line is the comparison's weekly figure")
  func quarterLineIsTheWeeklyFigure() {
    let log = seededLog(from: date(2025, 6, 1), through: today)
    let quarter = fold(.quarter, log.drinks, markers: log.markers, firstRecord: log.first)
    #expect(quarter.averageLine(calendar: calendar) == quarter.weeklyFigure)
    #expect(quarter.window.dayCount == 88)
    // The old line, the mean of the twelve completed weeks, is not what is drawn.
    let young = seededLog(from: date(2026, 8, 12), through: today)
    let clipped = fold(.quarter, young.drinks, markers: young.markers, firstRecord: young.first)
    #expect(clipped.window.isClipped)
    #expect(clipped.averageLine(calendar: calendar) == clipped.weeklyFigure)
  }

  /// A drink on the window's first day counts in every figure, one the day
  /// before counts in none, and while the window is clipped no day before the
  /// first record is counted at all — not as a day with drinks, not as a day
  /// without, not as a day of the window.
  @Test("A drink at the window's far edge counts in every figure or in none")
  func farEdge() throws {
    let weekend = try #require(WeekendReference.bundled).weekendWeekdays
    for range in TrendRange.allCases {
      let rangeKeys = TrendSummary.days(in: range, endingOn: today, calendar: calendar)
      let first = rangeKeys[0]
      let candidates = [
        calendar.date(byAdding: .minute, value: -1, to: first)!,
        first,
        calendar.date(byAdding: .minute, value: 23 * 60 + 59, to: first)!
      ]
      for at in candidates {
        let one = fold(range, [beer(at)], firstRecord: date(2019, 1, 1))
        let split = TrendSummary.weekendSplit(one.weekdays, weekend: weekend)
        let counts = [
          one.summary.daysWithDrinks == 1,
          one.weeklyFigure > 0,
          one.dailyAverage > 0,
          one.weekdays.reduce(0) { $0 + $1.daysWithDrinks } == 1,
          split.weekendDaysWithDrinks + split.otherDaysWithDrinks == 1,
          one.daysWithoutDrinks == one.window.dayCount - 1
        ]
        #expect(Set(counts).count == 1, "\(range), drink at \(at): \(counts)")
        #expect(counts[0] == (at >= first), "\(range), drink at \(at)")
      }
    }

    // Clipped: the first record is a marker on the 20th; the window starts on
    // it, and the nineteen days of September before it are in no denominator.
    let marker = calendar.startOfDay(for: date(2026, 9, 20))
    let month = fold(.month, [beer(date(2026, 9, 20, 22))], markers: [marker], firstRecord: marker)
    #expect(month.window.firstDay == marker)
    #expect(month.window.days.allSatisfy { $0 >= marker })
    #expect(month.window.dayCount == 11)
    #expect(month.summary.daysUnlogged == 10)
    #expect(month.daysWithoutDrinks == 10)
  }
}
