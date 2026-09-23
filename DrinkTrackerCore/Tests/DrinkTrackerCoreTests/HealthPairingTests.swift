import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0048: a drinking night is not a calendar day. The plan's vector list
/// (time zone changes, DST, a drink at 3 a.m., a night with no sleep, two
/// sleep sessions in one window, a nap, an empty log, a bucket one night short
/// of the gate), the five sessions typed into the Health app in Phase 0, and
/// the structural rules — two figures and no delta, a gate on both buckets,
/// buckets from the log alone. Every clock is injected.
@Suite("Health pairing")
struct HealthPairingTests {

  /// UTC, Gregorian, Sunday-first: the same fixture the summary tests use.
  private var utc: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func zoned(_ identifier: String) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: identifier)!
    cal.firstWeekday = 1
    return cal
  }

  private func at(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
    in calendar: Calendar
  ) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  private func beer(at date: Date) -> LoggedDrink {
    LoggedDrink(loggedAt: date, type: .beer, volumeOunces: 12, abvPercent: 5)
  }

  private func hours(_ h: Double) -> TimeInterval { h * 3600 }

  /// A `now` late enough that every 2026 night in these tests is complete.
  private var lateNow: Date { at(2027, 1, 1, in: utc) }

  private func nights(_ first: Date, _ last: Date, calendar: Calendar, now: Date? = nil) -> [DrinkingNight] {
    HealthPairing.nights(from: first, through: last, completeBy: now ?? lateNow, calendar: calendar)
  }

  // MARK: - The night and its windows

  @Test("A night is named for its evening and its three windows are the ones ADR-0048 states")
  func windowsOfANight() throws {
    let cal = utc
    let night = try #require(DrinkingNight(evening: at(2026, 9, 14, 20, in: cal), calendar: cal))
    #expect(night.evening == at(2026, 9, 14, in: cal))
    #expect(night.drinkWindow.start == at(2026, 9, 14, 6, in: cal))
    #expect(night.drinkWindow.end == at(2026, 9, 15, 6, in: cal))
    #expect(night.sleepDay.start == at(2026, 9, 14, 18, in: cal))
    #expect(night.sleepDay.end == at(2026, 9, 15, 18, in: cal))
    #expect(night.dayAfter.start == at(2026, 9, 15, in: cal))
    #expect(night.dayAfter.end == at(2026, 9, 16, in: cal))
  }

  @Test("A drink at 3 a.m. belongs to the night before it; 06:00 is the first instant of the next")
  func drinkAtThreeInTheMorning() throws {
    let cal = utc
    let small = try #require(DrinkingNight.containing(at(2026, 9, 15, 3, in: cal), calendar: cal))
    #expect(small.evening == at(2026, 9, 14, in: cal))
    let lastSecond = try #require(
      DrinkingNight.containing(at(2026, 9, 15, 5, 59, in: cal).addingTimeInterval(59), calendar: cal))
    #expect(lastSecond.evening == at(2026, 9, 14, in: cal))
    let six = try #require(DrinkingNight.containing(at(2026, 9, 15, 6, in: cal), calendar: cal))
    #expect(six.evening == at(2026, 9, 15, in: cal))
    let morning = try #require(DrinkingNight.containing(at(2026, 9, 15, 9, in: cal), calendar: cal))
    #expect(morning.evening == at(2026, 9, 15, in: cal))
  }

  @Test("Consecutive nights tile time: each window closes exactly where the next opens")
  func windowsTile() {
    // September holds Santiago's 23-hour transition day; the New York week
    // around November 1 holds a 25-hour one.
    let spans: [(Calendar, Date, Date)] = [
      (utc, at(2026, 9, 1, in: utc), at(2026, 9, 10, in: utc)),
      (zoned("America/New_York"), at(2026, 9, 1, in: zoned("America/New_York")), at(2026, 9, 10, in: zoned("America/New_York"))),
      (zoned("America/Santiago"), at(2026, 9, 1, in: zoned("America/Santiago")), at(2026, 9, 10, in: zoned("America/Santiago"))),
      (zoned("America/New_York"), at(2026, 10, 28, in: zoned("America/New_York")), at(2026, 11, 6, in: zoned("America/New_York"))),
    ]
    for (calendar, first, last) in spans {
      let list = nights(first, last, calendar: calendar)
      #expect(list.count == 10)
      for (earlier, later) in zip(list, list.dropFirst()) {
        #expect(earlier.drinkWindow.end == later.drinkWindow.start)
        #expect(earlier.sleepDay.end == later.sleepDay.start)
        #expect(earlier.dayAfter.end == later.dayAfter.start)
        #expect(earlier.evening < later.evening)
      }
    }
  }

  // MARK: - Time zones and DST

  @Test("The same instant is a different night in a different zone: the calendar handed in decides")
  func timeZoneChange() throws {
    // 07:00 UTC on Sep 15 is 08:00 in London (the night of the 15th) and
    // 03:00 in New York (still the night of the 14th).
    let instant = at(2026, 9, 15, 7, in: utc)
    let london = try #require(DrinkingNight.containing(instant, calendar: zoned("Europe/London")))
    let newYork = try #require(DrinkingNight.containing(instant, calendar: zoned("America/New_York")))
    #expect(london.evening == at(2026, 9, 15, in: zoned("Europe/London")))
    #expect(newYork.evening == at(2026, 9, 14, in: zoned("America/New_York")))
  }

  @Test("Spring forward: the night's window is 23 hours and a drink on either side of the jump stays in it")
  func springForward() throws {
    // New York, 2026-03-08: 02:00 EST becomes 03:00 EDT.
    let cal = zoned("America/New_York")
    let night = try #require(DrinkingNight(evening: at(2026, 3, 7, in: cal), calendar: cal))
    #expect(night.drinkWindow.duration == hours(23))
    let beforeJump = at(2026, 3, 8, 6, 30, in: utc)  // 01:30 EST
    let afterJump = at(2026, 3, 8, 7, 30, in: utc)   // 03:30 EDT
    let six = at(2026, 3, 8, 10, in: utc)            // 06:00 EDT
    #expect(DrinkingNight.containing(beforeJump, calendar: cal)?.evening == night.evening)
    #expect(DrinkingNight.containing(afterJump, calendar: cal)?.evening == night.evening)
    #expect(DrinkingNight.containing(six, calendar: cal)?.evening == at(2026, 3, 8, in: cal))
  }

  @Test("Fall back: the night's window is 25 hours and both 01:30s belong to it")
  func fallBack() throws {
    // New York, 2026-11-01: 02:00 EDT becomes 01:00 EST, so 01:30 happens twice.
    let cal = zoned("America/New_York")
    let night = try #require(DrinkingNight(evening: at(2026, 10, 31, in: cal), calendar: cal))
    #expect(night.drinkWindow.duration == hours(25))
    let firstOneThirty = at(2026, 11, 1, 5, 30, in: utc)   // 01:30 EDT
    let secondOneThirty = at(2026, 11, 1, 6, 30, in: utc)  // 01:30 EST
    #expect(DrinkingNight.containing(firstOneThirty, calendar: cal)?.evening == night.evening)
    #expect(DrinkingNight.containing(secondOneThirty, calendar: cal)?.evening == night.evening)
  }

  @Test("A zone that changes its clocks at midnight keys the transition day's night like any other")
  func midnightTransition() throws {
    // Santiago, 2026-09-06: the day has no 00:00, so its start is 01:00 —
    // the case that once lost the rolling summary a day. The night keyed by
    // the walk and the night a drink resolves to must agree.
    let cal = zoned("America/Santiago")
    let list = nights(at(2026, 9, 4, in: cal), at(2026, 9, 8, in: cal), calendar: cal)
    #expect(list.count == 5)
    let transitionNight = try #require(list.first { cal.component(.day, from: $0.evening) == 6 })
    let smallHours = at(2026, 9, 7, 0, 30, in: cal)
    #expect(DrinkingNight.containing(smallHours, calendar: cal)?.evening == transitionNight.evening)
    let buckets = HealthPairing.buckets(
      list, drinks: [beer(at: smallHours)], alcoholFreeDays: [], calendar: cal)
    #expect(buckets.drinks.map(\.evening) == [transitionNight.evening])
  }

  // MARK: - Which nights are complete

  @Test("A night counts once the day after it has ended: the evening two days ago is the newest")
  func provisionalNightsAreHeldBack() {
    let cal = utc
    let first = at(2026, 9, 1, in: cal)
    let tenInTheMorning = nights(first, at(2026, 9, 21, in: cal), calendar: cal, now: at(2026, 9, 21, 10, in: cal))
    #expect(tenInTheMorning.last?.evening == at(2026, 9, 19, in: cal))
    // Exactly midnight ending the day after: the night of the 20th arrives.
    let midnight = nights(first, at(2026, 9, 21, in: cal), calendar: cal, now: at(2026, 9, 22, in: cal))
    #expect(midnight.last?.evening == at(2026, 9, 20, in: cal))
    let secondBefore = nights(
      first, at(2026, 9, 21, in: cal), calendar: cal, now: at(2026, 9, 22, in: cal).addingTimeInterval(-1))
    #expect(secondBefore.last?.evening == at(2026, 9, 19, in: cal))
  }

  // MARK: - Buckets

  @Test("A logged drink in the window makes a drinks night; a marker makes a no-drinks night; silence makes neither")
  func bucketsFromTheLog() {
    let cal = utc
    let list = nights(at(2026, 9, 10, in: cal), at(2026, 9, 14, in: cal), calendar: cal)
    let buckets = HealthPairing.buckets(
      list,
      drinks: [beer(at: at(2026, 9, 10, 21, in: cal)), beer(at: at(2026, 9, 13, 2, in: cal))],
      alcoholFreeDays: [at(2026, 9, 11, 12, in: cal), at(2026, 9, 14, in: cal)],
      calendar: cal
    )
    // The 2 a.m. drink on the 13th is the night of the 12th.
    #expect(buckets.drinks.map(\.evening) == [at(2026, 9, 10, in: cal), at(2026, 9, 12, in: cal)])
    #expect(buckets.noDrinks.map(\.evening) == [at(2026, 9, 11, in: cal), at(2026, 9, 14, in: cal)])
    // The 13th: nothing logged, nothing marked, in neither column.
    #expect(!buckets.drinks.contains { $0.evening == at(2026, 9, 13, in: cal) })
    #expect(!buckets.noDrinks.contains { $0.evening == at(2026, 9, 13, in: cal) })
  }

  @Test("Nights before the first record are in neither column")
  func recordHasABeginning() {
    let cal = utc
    let list = nights(at(2026, 9, 1, in: cal), at(2026, 9, 12, in: cal), calendar: cal)
    let buckets = HealthPairing.buckets(
      list,
      drinks: [beer(at: at(2026, 9, 10, 20, in: cal))],
      alcoholFreeDays: [at(2026, 9, 11, in: cal)],
      calendar: cal
    )
    #expect(buckets.drinks.count + buckets.noDrinks.count == 2)
    #expect(buckets.drinks.first?.evening == at(2026, 9, 10, in: cal))
  }

  @Test("A drink in the window's small hours outranks the marker on the evening's day")
  func tailDrinkBeatsMarker() {
    // The 14th is marked no alcohol; a drink at 01:00 on the 15th is inside
    // the night of the 14th's window, so that night is a drinks night. The
    // night of the 15th has no marker (the app will not mark a day holding a
    // drink) and is unrecorded.
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 15, in: cal), calendar: cal)
    let buckets = HealthPairing.buckets(
      list,
      drinks: [beer(at: at(2026, 9, 15, 1, in: cal))],
      alcoholFreeDays: [at(2026, 9, 14, in: cal)],
      calendar: cal
    )
    #expect(buckets.drinks.map(\.evening) == [at(2026, 9, 14, in: cal)])
    #expect(buckets.noDrinks.isEmpty)
  }

  @Test("Any entry makes a drinks night — a Health import and a 0% drink included, as the calendar counts days")
  func anyEntryCounts() {
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 15, in: cal), calendar: cal)
    let entries = [
      LoggedDrink.importedFromHealth(sampleID: UUID(), count: 1, loggedAt: at(2026, 9, 14, 22, in: cal)),
      LoggedDrink(loggedAt: at(2026, 9, 15, 22, in: cal), type: .beer, volumeOunces: 12, abvPercent: 0),
    ]
    let buckets = HealthPairing.buckets(list, drinks: entries, alcoholFreeDays: [], calendar: cal)
    #expect(buckets.drinks.count == 2)
  }

  @Test("An empty log has no buckets and no figures, whatever Health holds")
  func emptyLog() {
    let cal = utc
    let list = nights(at(2026, 9, 1, in: cal), at(2026, 9, 30, in: cal), calendar: cal)
    #expect(list.count == 30)
    let buckets = HealthPairing.buckets(list, drinks: [], alcoholFreeDays: [], calendar: cal)
    #expect(buckets.drinks.isEmpty)
    #expect(buckets.noDrinks.isEmpty)
    #expect(!buckets.clearsGate())
    let values = list.map { NightValue(night: $0.evening, value: 60) }
    #expect(HealthPairing.figures(buckets, values: values) == nil)
  }

  // MARK: - Sleep, as the Health app files it

  /// The five sessions typed into the Health app on 2026-09-21
  /// (`docs/health-pairing-phase-0-findings.md`), in the zone they were typed
  /// in, and the totals the app showed for each day. Health names a day for
  /// its morning; a `DrinkingNight` for its evening; the table maps between.
  @Test("The five sessions from Phase 0 file and sum here exactly as the Health app showed them")
  func phaseZeroReplay() {
    let cal = zoned("America/New_York")
    let list = nights(at(2026, 9, 12, in: cal), at(2026, 9, 19, in: cal), calendar: cal)
    let samples = [
      // 1: Mon 11:40 PM to Tue 7:10 AM — Health: Tue Sep 15.
      SleepSample(start: at(2026, 9, 14, 23, 40, in: cal), end: at(2026, 9, 15, 7, 10, in: cal), stage: .asleepUnspecified),
      // 2: Fri 8 PM to 11 PM — Health: Sat Sep 19, "3 hr".
      SleepSample(start: at(2026, 9, 18, 20, in: cal), end: at(2026, 9, 18, 23, in: cal), stage: .asleepUnspecified),
      // 3: Wed 4 PM to 8 PM, straddling 6 PM — Health: whole, under Thu Sep 17.
      SleepSample(start: at(2026, 9, 16, 16, in: cal), end: at(2026, 9, 16, 20, in: cal), stage: .asleepUnspecified),
      // 4: Tue 2 PM to 3:30 PM, a nap — Health: added to Tue Sep 15, "9 hr".
      SleepSample(start: at(2026, 9, 15, 14, in: cal), end: at(2026, 9, 15, 15, 30, in: cal), stage: .asleepUnspecified),
      // 5: Sun 1 PM to 7 PM, five hours before 6 PM and one after — Health: whole, under Sun Sep 13.
      SleepSample(start: at(2026, 9, 13, 13, in: cal), end: at(2026, 9, 13, 19, in: cal), stage: .asleepUnspecified),
    ]
    let asleep = HealthPairing.timeAsleep(from: samples, for: list, calendar: cal)
    let byNight = Dictionary(uniqueKeysWithValues: asleep.map { ($0.night, $0.value) })
    #expect(byNight[at(2026, 9, 12, in: cal)] == hours(6))      // Health's Sun 13
    #expect(byNight[at(2026, 9, 14, in: cal)] == hours(9))      // Health's Tue 15: 7h30 + 1h30
    #expect(byNight[at(2026, 9, 16, in: cal)] == hours(4))      // Health's Thu 17
    #expect(byNight[at(2026, 9, 18, in: cal)] == hours(3))      // Health's Sat 19
    #expect(byNight.count == 4)
    // Health's week average after the five: 22 hours over the four days with data.
    let average = asleep.map(\.value).reduce(0, +) / Double(asleep.count)
    #expect(average == hours(5.5))
  }

  @Test("A night with no sleep recorded has no value — absent, not zero")
  func nightWithNoSleep() {
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 16, in: cal), calendar: cal)
    let samples = [
      SleepSample(start: at(2026, 9, 14, 23, in: cal), end: at(2026, 9, 15, 7, in: cal), stage: .core)
    ]
    let asleep = HealthPairing.timeAsleep(from: samples, for: list, calendar: cal)
    #expect(asleep.map(\.night) == [at(2026, 9, 14, in: cal)])
    #expect(!asleep.contains { $0.value == 0 })
  }

  @Test("Two sleep sessions in one sleep day are summed, and the waking between them is not")
  func twoSessionsInOneWindow() {
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 14, in: cal), calendar: cal)
    let samples = [
      SleepSample(start: at(2026, 9, 14, 23, in: cal), end: at(2026, 9, 15, 1, in: cal), stage: .core),
      SleepSample(start: at(2026, 9, 15, 1, in: cal), end: at(2026, 9, 15, 1, 20, in: cal), stage: .awake),
      SleepSample(start: at(2026, 9, 15, 1, 20, in: cal), end: at(2026, 9, 15, 7, in: cal), stage: .deep),
    ]
    let asleep = HealthPairing.timeAsleep(from: samples, for: list, calendar: cal)
    #expect(asleep.count == 1)
    #expect(asleep.first?.value == hours(2) + hours(5) + 2400)
  }

  @Test("A nap the next afternoon is summed into the night before it, as Health does")
  func napIsSummedIn() {
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 15, in: cal), calendar: cal)
    let samples = [
      SleepSample(start: at(2026, 9, 14, 23, in: cal), end: at(2026, 9, 15, 6, in: cal), stage: .rem),
      SleepSample(start: at(2026, 9, 15, 14, in: cal), end: at(2026, 9, 15, 15, in: cal), stage: .core),
    ]
    let asleep = HealthPairing.timeAsleep(from: samples, for: list, calendar: cal)
    #expect(asleep.map(\.night) == [at(2026, 9, 14, in: cal)])
    #expect(asleep.first?.value == hours(8))
  }

  @Test("A stretch crossing 18:00 goes whole to the night holding its middle; an awakening across 18:00 splits a session in two")
  func stretchesAcrossTheBoundary() {
    // Core sleep to 17:59 and REM from 17:59 touch, so they merge into one
    // stretch whose middle is after 18:00: all of it files under the night
    // of the 16th, where filed sample by sample the first hour would be the
    // night of the 15th. A waking that straddles 18:00 leaves two stretches,
    // one each side, so that sleep lands on two nights. Both are the rule
    // ADR-0048 states and names the cost of.
    let cal = utc
    let list = nights(at(2026, 9, 15, in: cal), at(2026, 9, 16, in: cal), calendar: cal)
    let touching = [
      SleepSample(start: at(2026, 9, 16, 17, in: cal), end: at(2026, 9, 16, 17, 59, in: cal), stage: .core),
      SleepSample(start: at(2026, 9, 16, 17, 59, in: cal), end: at(2026, 9, 16, 19, 30, in: cal), stage: .rem),
    ]
    #expect(HealthPairing.timeAsleep(from: touching, for: list, calendar: cal) == [
      NightValue(night: at(2026, 9, 16, in: cal), value: hours(2.5))
    ])
    let woken = [
      SleepSample(start: at(2026, 9, 16, 16, in: cal), end: at(2026, 9, 16, 17, 50, in: cal), stage: .core),
      SleepSample(start: at(2026, 9, 16, 17, 50, in: cal), end: at(2026, 9, 16, 18, 10, in: cal), stage: .awake),
      SleepSample(start: at(2026, 9, 16, 18, 10, in: cal), end: at(2026, 9, 16, 20, in: cal), stage: .core),
    ]
    #expect(HealthPairing.timeAsleep(from: woken, for: list, calendar: cal) == [
      NightValue(night: at(2026, 9, 15, in: cal), value: hours(1) + 3000),
      NightValue(night: at(2026, 9, 16, in: cal), value: hours(1) + 3000),
    ])
  }

  @Test("An inverted or zero-length sleep sample is dropped, and a non-finite quantity is")
  func malformedSamplesAreDropped() {
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 15, in: cal), calendar: cal)
    let sleep = [
      SleepSample(start: at(2026, 9, 15, 7, in: cal), end: at(2026, 9, 14, 23, in: cal), stage: .core),
      SleepSample(start: at(2026, 9, 15, 1, in: cal), end: at(2026, 9, 15, 1, in: cal), stage: .core),
      SleepSample(start: at(2026, 9, 15, 2, in: cal), end: at(2026, 9, 15, 3, in: cal), stage: .core),
    ]
    #expect(HealthPairing.timeAsleep(from: sleep, for: list, calendar: cal) == [
      NightValue(night: at(2026, 9, 14, in: cal), value: hours(1))
    ])
    let quantities = [
      HealthSample(start: at(2026, 9, 15, 12, in: cal), end: at(2026, 9, 15, 12, in: cal), value: .nan),
      HealthSample(start: at(2026, 9, 15, 13, in: cal), end: at(2026, 9, 15, 12, in: cal), value: 70),
      HealthSample(start: at(2026, 9, 15, 14, in: cal), end: at(2026, 9, 15, 14, in: cal), value: 60),
    ]
    #expect(HealthPairing.nightlyValues(of: quantities, for: list, attribution: .dayAfter, calendar: cal) == [
      NightValue(night: at(2026, 9, 14, in: cal), value: 60)
    ])
    // A non-finite value handed straight to the figures is a night with no
    // value, so the gate sees thirteen where fourteen were listed.
    let made = fixture(cal, drinkValues: Array(repeating: 60.0, count: 14), noneValues: Array(repeating: 55.0, count: 14))
    var poisoned = made.values
    poisoned[0] = NightValue(night: poisoned[0].night, value: .nan)
    #expect(HealthPairing.figures(made.buckets, values: poisoned) == nil)
  }

  @Test("In bed and awake are not sleep; overlapping sources count an hour once; order does not matter")
  func stagesAndOverlaps() {
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 14, in: cal), calendar: cal)
    let samples = [
      SleepSample(start: at(2026, 9, 14, 22, 30, in: cal), end: at(2026, 9, 15, 7, in: cal), stage: .inBed),
      SleepSample(start: at(2026, 9, 14, 23, in: cal), end: at(2026, 9, 15, 1, in: cal), stage: .core),
      // A second app recording the same hour as unspecified sleep.
      SleepSample(start: at(2026, 9, 14, 23, 30, in: cal), end: at(2026, 9, 15, 0, 30, in: cal), stage: .asleepUnspecified),
      SleepSample(start: at(2026, 9, 15, 1, in: cal), end: at(2026, 9, 15, 1, 10, in: cal), stage: .awake),
      SleepSample(start: at(2026, 9, 15, 1, 10, in: cal), end: at(2026, 9, 15, 7, in: cal), stage: .core),
    ]
    let expected = hours(2) + hours(5) + 3000
    #expect(HealthPairing.timeAsleep(from: samples, for: list, calendar: cal).first?.value == expected)
    #expect(HealthPairing.timeAsleep(from: samples.reversed(), for: list, calendar: cal).first?.value == expected)
    let inBedOnly = [samples[0]]
    #expect(HealthPairing.timeAsleep(from: inBedOnly, for: list, calendar: cal).isEmpty)
  }

  // MARK: - Daily figures

  @Test("A calendar-day figure pairs with the night before it, and two samples on one day average")
  func dailyFigurePairsWithTheDayAfter() {
    let cal = utc
    let list = nights(at(2026, 9, 13, in: cal), at(2026, 9, 15, in: cal), calendar: cal)
    let samples = [
      HealthSample(start: at(2026, 9, 15, 23, 59, in: cal), end: at(2026, 9, 15, 23, 59, in: cal), value: 62),
      HealthSample(start: at(2026, 9, 15, in: cal), end: at(2026, 9, 16, in: cal).addingTimeInterval(-1), value: 64),
      HealthSample(start: at(2026, 9, 14, 12, in: cal), end: at(2026, 9, 14, 12, in: cal), value: 58),
      // Outside the nights asked for: dropped, never mis-filed.
      HealthSample(start: at(2026, 9, 20, 12, in: cal), end: at(2026, 9, 20, 12, in: cal), value: 99),
    ]
    let values = HealthPairing.nightlyValues(of: samples, for: list, attribution: .dayAfter, calendar: cal)
    #expect(values == [
      NightValue(night: at(2026, 9, 13, in: cal), value: 58),
      NightValue(night: at(2026, 9, 14, in: cal), value: 63),
    ])
  }

  @Test("A spanning sample is filed by its middle, not its start or its end")
  func spanningSampleFilesByMiddle() {
    // 23:00 on the 15th to 03:00 on the 16th: start on the 15th, middle and
    // end on the 16th. Filed by the day after, that is the night of the 15th;
    // by its start it would be the 14th's. Under the sleep-day rule, two
    // samples tell start, middle and end apart: 17:00 to 20:00 on the 16th
    // (middle 18:30) is the night of the 16th where its start says the 15th,
    // and 15:00 to 20:00 (middle 17:30) is the night of the 15th where its
    // end says the 16th.
    let cal = utc
    let list = nights(at(2026, 9, 14, in: cal), at(2026, 9, 16, in: cal), calendar: cal)
    let overnight = [HealthSample(start: at(2026, 9, 15, 23, in: cal), end: at(2026, 9, 16, 3, in: cal), value: 61)]
    #expect(HealthPairing.nightlyValues(of: overnight, for: list, attribution: .dayAfter, calendar: cal) == [
      NightValue(night: at(2026, 9, 15, in: cal), value: 61)
    ])
    let evening = [HealthSample(start: at(2026, 9, 16, 17, in: cal), end: at(2026, 9, 16, 20, in: cal), value: 36.2)]
    #expect(HealthPairing.nightlyValues(of: evening, for: list, attribution: .sleepDay, calendar: cal) == [
      NightValue(night: at(2026, 9, 16, in: cal), value: 36.2)
    ])
    let lateEnd = [HealthSample(start: at(2026, 9, 16, 15, in: cal), end: at(2026, 9, 16, 20, in: cal), value: 36.4)]
    #expect(HealthPairing.nightlyValues(of: lateEnd, for: list, attribution: .sleepDay, calendar: cal) == [
      NightValue(night: at(2026, 9, 15, in: cal), value: 36.4)
    ])
  }

  @Test("A nightly figure files by the sleep day, on the 18:00 rule the sleep sessions use")
  func nightlyFigureFilesBySleepDay() {
    let cal = utc
    let list = nights(at(2026, 9, 13, in: cal), at(2026, 9, 15, in: cal), calendar: cal)
    let samples = [
      // A wrist-temperature style sample spanning the night: middle 03:00 on the 15th.
      HealthSample(start: at(2026, 9, 14, 23, in: cal), end: at(2026, 9, 15, 7, in: cal), value: 36.4),
      // 17:59 on the 15th is still the sleep day of the night of the 14th; 18:00 is the next.
      HealthSample(start: at(2026, 9, 15, 17, 59, in: cal), end: at(2026, 9, 15, 17, 59, in: cal), value: 36.6),
      HealthSample(start: at(2026, 9, 15, 18, in: cal), end: at(2026, 9, 15, 18, in: cal), value: 36.8),
    ]
    let values = HealthPairing.nightlyValues(of: samples, for: list, attribution: .sleepDay, calendar: cal)
    #expect(values == [
      NightValue(night: at(2026, 9, 14, in: cal), value: 36.5),
      NightValue(night: at(2026, 9, 15, in: cal), value: 36.8),
    ])
  }

  // MARK: - The gate and the figures

  /// Drink nights from June 1 with a value each, then marked nights from
  /// June 16 with a value each, over forty nights.
  private func fixture(
    _ cal: Calendar, drinkValues: [Double], noneValues: [Double]
  ) -> (buckets: NightBuckets, values: [NightValue]) {
    let list = nights(at(2026, 6, 1, in: cal), at(2026, 7, 10, in: cal), calendar: cal)
    var drinks: [LoggedDrink] = []
    var markers: [Date] = []
    var values: [NightValue] = []
    for (offset, value) in drinkValues.enumerated() {
      let evening = list[offset].evening
      drinks.append(beer(at: evening.addingTimeInterval(hours(21))))
      values.append(NightValue(night: evening, value: value))
    }
    for (offset, value) in noneValues.enumerated() {
      let evening = list[15 + offset].evening
      markers.append(evening)
      values.append(NightValue(night: evening, value: value))
    }
    let buckets = HealthPairing.buckets(list, drinks: drinks, alcoholFreeDays: markers, calendar: cal)
    return (buckets, values)
  }

  @Test("The gate is fourteen nights with a value in each bucket; one short on either side hides everything")
  func gateInBothBuckets() {
    let cal = utc
    let fourteen = Array(repeating: 60.0, count: 14)
    let thirteen = Array(repeating: 60.0, count: 13)
    #expect(PairedFigures.minimumNights == 14)
    let both = fixture(cal, drinkValues: fourteen, noneValues: fourteen)
    #expect(HealthPairing.figures(both.buckets, values: both.values) != nil)
    let drinksShort = fixture(cal, drinkValues: thirteen, noneValues: fourteen)
    #expect(HealthPairing.figures(drinksShort.buckets, values: drinksShort.values) == nil)
    let noneShort = fixture(cal, drinkValues: fourteen, noneValues: thirteen)
    #expect(HealthPairing.figures(noneShort.buckets, values: noneShort.values) == nil)
  }

  @Test("The gate counts nights with a value, not nights in the bucket")
  func gateCountsValues() {
    let cal = utc
    let full = fixture(cal, drinkValues: Array(repeating: 60.0, count: 14), noneValues: Array(repeating: 55.0, count: 14))
    #expect(full.buckets.clearsGate())
    // Fourteen drink nights logged, but a value for only thirteen of them.
    let missingOne = full.values.filter { $0.night != full.buckets.drinks[0].evening }
    #expect(HealthPairing.figures(full.buckets, values: missingOne) == nil)
  }

  @Test("The log-only gate needs both sides, and counts a night once however often it is listed")
  func logOnlyGateIsAConjunction() {
    let cal = utc
    let fourteen = Array(repeating: 60.0, count: 14)
    let thirteen = Array(repeating: 60.0, count: 13)
    #expect(fixture(cal, drinkValues: fourteen, noneValues: thirteen).buckets.clearsGate() == false)
    #expect(fixture(cal, drinkValues: thirteen, noneValues: fourteen).buckets.clearsGate() == false)
    #expect(fixture(cal, drinkValues: fourteen, noneValues: fourteen).buckets.clearsGate())
    // Seven nights listed twice are seven nights, on the offer's gate and the table's.
    let seven = fixture(cal, drinkValues: Array(repeating: 60.0, count: 7), noneValues: Array(repeating: 55.0, count: 7))
    let doubled = NightBuckets(
      drinks: seven.buckets.drinks + seven.buckets.drinks,
      noDrinks: seven.buckets.noDrinks + seven.buckets.noDrinks
    )
    #expect(doubled.clearsGate() == false)
    #expect(HealthPairing.figures(doubled, values: seven.values) == nil)
    #expect(HealthPairing.figures(doubled, values: seven.values, minimumNights: 7)?.drinks.nights == 7)
    // The same nights listed twice into `buckets` come out once.
    let list = nights(at(2026, 6, 1, in: cal), at(2026, 6, 3, in: cal), calendar: cal)
    let twice = HealthPairing.buckets(
      list + list, drinks: [beer(at: at(2026, 6, 1, 21, in: cal))], alcoholFreeDays: [at(2026, 6, 2, in: cal)], calendar: cal)
    #expect(twice.drinks.count == 1)
    #expect(twice.noDrinks.count == 1)
  }

  @Test("Two values for one night collapse to their mean before the night joins the average")
  func valuesForOneNightCollapse() throws {
    let cal = utc
    let made = fixture(cal, drinkValues: Array(repeating: 60.0, count: 14), noneValues: Array(repeating: 50.0, count: 14))
    // Three more readings on one drink night at 90 would pull a sample-weighted
    // mean to 65.3; per night they collapse to (60 + 90 × 3) / 4 = 82.5 for that
    // night alone, and the figure moves by (82.5 − 60) / 14.
    let extra = (0..<3).map { _ in NightValue(night: made.buckets.drinks[0].evening, value: 90) }
    let figures = try #require(HealthPairing.figures(made.buckets, values: made.values + extra))
    #expect(abs(figures.drinks.average - (60 + 22.5 / 14)) < 0.0001)
    #expect(figures.drinks.nights == 14)
  }

  @Test("Two figures, two counts, the span they cover — and each is the mean over its own nights")
  func figuresAreTwoMeans() throws {
    let cal = utc
    let drinkValues = (0..<14).map { 60.0 + Double($0) }      // 60…73, mean 66.5
    let noneValues = (0..<16).map { 50.0 + Double($0 % 2) }    // 50,51,… mean 50.5
    let made = fixture(cal, drinkValues: drinkValues, noneValues: noneValues)
    let figures = try #require(HealthPairing.figures(made.buckets, values: made.values))
    #expect(figures.drinks == PairedFigures.Figure(average: 66.5, nights: 14))
    #expect(figures.noDrinks == PairedFigures.Figure(average: 50.5, nights: 16))
    // Sixteen marked nights from June 16 run through July 1.
    #expect(figures.firstNight == at(2026, 6, 1, in: cal))
    #expect(figures.lastNight == at(2026, 7, 1, in: cal))
    #expect(figures.lastNight == made.buckets.noDrinks.last?.evening)
  }

  @Test("A larger floor can be asked for, and a floor below one is treated as one")
  func floorIsAParameter() {
    let cal = utc
    let made = fixture(cal, drinkValues: Array(repeating: 60.0, count: 14), noneValues: Array(repeating: 55.0, count: 14))
    #expect(HealthPairing.figures(made.buckets, values: made.values, minimumNights: 15) == nil)
    #expect(HealthPairing.figures(made.buckets, values: made.values, minimumNights: 0) != nil)
    // A floor of zero against an empty bucket is still nothing: never an
    // average over no nights.
    let oneSided = NightBuckets(drinks: made.buckets.drinks, noDrinks: [])
    #expect(HealthPairing.figures(oneSided, values: made.values, minimumNights: 0) == nil)
  }

  /// The floor at each range (ADR-0048's 2026-09-22 amendment): the base at
  /// Quarter and Year, two a bucket at Week and seven at Month — and, at
  /// Week, exactly what its five countable nights can hold twice. A seven-day
  /// range ending on the 22nd, read on the 22nd: the evenings of the 16th
  /// through the 20th count (the 21st's day after is the 22nd, still
  /// running), and two drink nights with two marked nights among them clear
  /// the floor, where one marked night does not and the base floor never
  /// could. The means are over those two nights each.
  @Test("The floor scales to the range: two a bucket at Week, seven at Month, fourteen at Quarter and Year")
  func floorFollowsTheRange() {
    let cal = utc
    #expect(PairedFigures.minimumNights(at: .week) == 2)
    #expect(PairedFigures.minimumNights(at: .month) == 7)
    #expect(PairedFigures.minimumNights(at: .quarter) == PairedFigures.minimumNights)
    #expect(PairedFigures.minimumNights(at: .year) == PairedFigures.minimumNights)
    #expect(PairedFigures.minimumNights(at: .week) * 2 <= 5)

    let today = at(2026, 9, 22, in: cal)
    let first = TrendRange.week.startDate(endingOn: today, calendar: cal)
    let list = HealthPairing.nights(
      from: first, through: today, completeBy: today.addingTimeInterval(hours(10)), calendar: cal)
    #expect(list.count == 5)
    #expect(list.first?.evening == at(2026, 9, 16, in: cal))
    #expect(list.last?.evening == at(2026, 9, 20, in: cal))

    // Drinks on the 18th and 19th; the 16th and 17th recorded as no alcohol.
    let drinks = [beer(at: at(2026, 9, 18, 21, in: cal)), beer(at: at(2026, 9, 19, 22, in: cal))]
    let twoMarked = [at(2026, 9, 16, in: cal), at(2026, 9, 17, in: cal)]
    let buckets = HealthPairing.buckets(list, drinks: drinks, alcoholFreeDays: twoMarked, calendar: cal)
    #expect(buckets.clearsGate(minimumNights: PairedFigures.minimumNights(at: .week)))
    #expect(buckets.clearsGate() == false)
    let values = [
      NightValue(night: at(2026, 9, 16, in: cal), value: 56),
      NightValue(night: at(2026, 9, 17, in: cal), value: 58),
      NightValue(night: at(2026, 9, 18, in: cal), value: 61),
      NightValue(night: at(2026, 9, 19, in: cal), value: 63),
    ]
    let figures = HealthPairing.figures(
      buckets, values: values, minimumNights: PairedFigures.minimumNights(at: .week))
    #expect(figures?.drinks == PairedFigures.Figure(average: 62, nights: 2))
    #expect(figures?.noDrinks == PairedFigures.Figure(average: 57, nights: 2))
    #expect(HealthPairing.figures(buckets, values: values) == nil)

    // One marked night short: nothing, at the Week floor too.
    let oneMarked = HealthPairing.buckets(
      list, drinks: drinks, alcoholFreeDays: [at(2026, 9, 16, in: cal)], calendar: cal)
    #expect(oneMarked.clearsGate(minimumNights: PairedFigures.minimumNights(at: .week)) == false)
    #expect(
      HealthPairing.figures(
        oneMarked, values: values, minimumNights: PairedFigures.minimumNights(at: .week)) == nil)
  }

  /// Heart rate variability's floor (ADR-0052): twice the base, and the row
  /// hidden one night short on either side, over a log the base floor would
  /// show — so the absence is the floor's doing, not the data's. Twenty-eight
  /// drink nights from June 1, then twenty-eight marked nights from July 1.
  @Test("Heart rate variability's floor is twice the base, and one night short on either side hides the row")
  func heartRateVariabilityFloor() {
    let cal = utc
    let floor = PairedFigures.minimumNightsForHeartRateVariability
    #expect(floor == 28)
    #expect(floor == 2 * PairedFigures.minimumNights)

    func made(drinkNights: Int, markedNights: Int) -> (buckets: NightBuckets, values: [NightValue]) {
      let list = nights(at(2026, 6, 1, in: cal), at(2026, 8, 31, in: cal), calendar: cal)
      var drinks: [LoggedDrink] = []
      var markers: [Date] = []
      var values: [NightValue] = []
      for offset in 0..<drinkNights {
        let evening = list[offset].evening
        drinks.append(beer(at: evening.addingTimeInterval(hours(21))))
        values.append(NightValue(night: evening, value: 38))
      }
      for offset in 0..<markedNights {
        let evening = list[30 + offset].evening
        markers.append(evening)
        values.append(NightValue(night: evening, value: 48))
      }
      let buckets = HealthPairing.buckets(list, drinks: drinks, alcoholFreeDays: markers, calendar: cal)
      return (buckets, values)
    }

    let both = made(drinkNights: floor, markedNights: floor)
    let figures = HealthPairing.figures(both.buckets, values: both.values, minimumNights: floor)
    #expect(figures?.drinks == PairedFigures.Figure(average: 38, nights: floor))
    #expect(figures?.noDrinks == PairedFigures.Figure(average: 48, nights: floor))

    let drinksShort = made(drinkNights: floor - 1, markedNights: floor)
    #expect(HealthPairing.figures(drinksShort.buckets, values: drinksShort.values, minimumNights: floor) == nil)
    let markedShort = made(drinkNights: floor, markedNights: floor - 1)
    #expect(HealthPairing.figures(markedShort.buckets, values: markedShort.values, minimumNights: floor) == nil)

    // The same two logs clear the base floor: what hides the row is the
    // floor asked for, which is the metric's, never the figures' shape.
    #expect(HealthPairing.figures(drinksShort.buckets, values: drinksShort.values) != nil)
    #expect(HealthPairing.figures(markedShort.buckets, values: markedShort.values) != nil)
  }

  /// Wrist temperature (ADR-0053): the watch's one reading a night, filed
  /// under the night whose sleep day holds its middle, and the row's two
  /// figures are the plain means of those readings — no baseline, no
  /// deviation, no sign. Nights with nothing logged carry readings too and
  /// enter neither figure, which is what "the reading, not a change from a
  /// median of the range" makes structural: no night outside a bucket can
  /// move a figure inside one.
  @Test("Wrist temperature is two absolute means, each night's reading filed by the sleep day it fell in")
  func wristTemperatureIsAbsoluteMeansBySleepDay() {
    let cal = utc
    let list = nights(at(2026, 6, 1, in: cal), at(2026, 7, 10, in: cal), calendar: cal)
    var drinks: [LoggedDrink] = []
    var markers: [Date] = []
    var samples: [HealthSample] = []
    for (index, night) in list.enumerated() {
      let evening = night.evening
      let reading: Double
      // Fifteen drink nights, because the second night's reading files
      // under the third (below) and leaves fourteen with a value — the gate.
      if index < 15 {
        drinks.append(beer(at: evening.addingTimeInterval(hours(21))))
        reading = 36.5
      } else if index < 29 {
        markers.append(evening)
        reading = 36.25
      } else {
        reading = 36.75  // nothing logged: in neither column
      }
      // The sample spans the sleep, 23:30 to 06:30, so its middle, 03:00, is
      // inside the sleep day that began at 18:00 on `evening`. Two are
      // shaped to tell the filing rules apart: the first night's is an
      // instant at 23:45, which the sleep-day rule files under `evening`
      // where a day-after rule would file it under the night before the
      // list; the second night's spans 17:00 to 21:00 the next afternoon,
      // so its start is inside this night's sleep day but its middle, 19:00,
      // is inside the *next* night's — the middle rule files it there, where
      // it joins that night's own reading (two of 36.5, averaged to one),
      // and this night is left without a value.
      let start: Date
      let end: Date
      switch index {
      case 0:
        start = evening.addingTimeInterval(hours(23.75))
        end = start
      case 1:
        start = evening.addingTimeInterval(hours(41))
        end = evening.addingTimeInterval(hours(45))
      default:
        start = evening.addingTimeInterval(hours(23.5))
        end = evening.addingTimeInterval(hours(30.5))
      }
      samples.append(HealthSample(start: start, end: end, value: reading))
    }
    let buckets = HealthPairing.buckets(list, drinks: drinks, alcoholFreeDays: markers, calendar: cal)
    let values = HealthPairing.nightlyValues(of: samples, for: list, attribution: .sleepDay, calendar: cal)
    // Every night but the second has a value; the second's reading went to
    // the third, which still reads 36.5.
    #expect(values.count == list.count - 1)
    #expect(values.first?.night == list[0].evening)
    #expect(values[1].night == list[2].evening)
    #expect(values[1].value == 36.5)
    #expect(!values.contains { $0.night == list[1].evening })

    let figures = HealthPairing.figures(buckets, values: values)
    #expect(figures?.drinks == PairedFigures.Figure(average: 36.5, nights: 14))
    #expect(figures?.noDrinks == PairedFigures.Figure(average: 36.25, nights: 14))
  }

  /// Plan rule 1: the value type stores exactly two figures, two counts and
  /// the span, and nothing that relates one side to the other. A stored
  /// difference, ratio or verdict changes this list and fails here. `Mirror`
  /// sees stored properties only — a computed one, or an extension in another
  /// target, is caught by review, not by this.
  @Test("The figures carry no delta: their stored properties are exactly the four named")
  func noDeltaField() {
    let figures = PairedFigures(
      drinks: .init(average: 62, nights: 18),
      noDrinks: .init(average: 58, nights: 31),
      firstNight: Date(timeIntervalSince1970: 0),
      lastNight: Date(timeIntervalSince1970: 86_400)
    )
    let labels = Mirror(reflecting: figures).children.compactMap(\.label)
    #expect(labels == ["drinks", "noDrinks", "firstNight", "lastNight"])
    let figureLabels = Mirror(reflecting: figures.drinks).children.compactMap(\.label)
    #expect(figureLabels == ["average", "nights"])
  }
}
