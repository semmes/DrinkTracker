import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0012's reminder, pinned: a week before a renewal, never for a recurring
/// tip that was cancelled, and none once that week has begun.
@Suite("Recurring tip renewal")
struct SupportRenewalTests {
  private let now = Date(timeIntervalSinceReferenceDate: 812_000_000)
  private let day: TimeInterval = 24 * 60 * 60
  private let week: TimeInterval = 7 * 24 * 60 * 60

  @Test func renewsAMonthOutWithAReminderAWeekBefore() throws {
    let expiration = now.addingTimeInterval(30 * day)
    let renewal = try #require(SupportRenewal(expiration: expiration, willAutoRenew: true, now: now))
    #expect(renewal.state == .renews)
    #expect(renewal.date == expiration)
    let expected: Date = expiration.addingTimeInterval(-week)
    #expect(renewal.reminderDate == expected)
  }

  @Test func aYearlyTipIsRemindedAWeekBeforeTheYearEnds() throws {
    let expiration = now.addingTimeInterval(365 * day)
    let renewal = try #require(SupportRenewal(expiration: expiration, willAutoRenew: true, now: now))
    let expected: Date = now.addingTimeInterval(358 * day)
    #expect(renewal.reminderDate == expected)
  }

  @Test func aCancelledTipEndsAndIsNotReminded() throws {
    let expiration = now.addingTimeInterval(30 * day)
    let renewal = try #require(SupportRenewal(expiration: expiration, willAutoRenew: false, now: now))
    #expect(renewal.state == .ends)
    #expect(renewal.date == expiration)
    #expect(renewal.reminderDate == nil)
  }

  @Test func unknownRenewalInfoIsReadAsRenewing() throws {
    let expiration = now.addingTimeInterval(30 * day)
    let renewal = try #require(SupportRenewal(expiration: expiration, willAutoRenew: nil, now: now))
    #expect(renewal.state == .renews)
    #expect(renewal.reminderDate != nil)
  }

  @Test func insideTheLastWeekThereIsNoReminderToSchedule() throws {
    let expiration = now.addingTimeInterval(5 * day)
    let renewal = try #require(SupportRenewal(expiration: expiration, willAutoRenew: true, now: now))
    #expect(renewal.state == .renews)
    #expect(renewal.reminderDate == nil)
  }

  @Test func aReminderDueWithinAMinuteIsNotScheduled() throws {
    let notice: TimeInterval = SupportRenewal.minimumNotice
    let onTheLine = now.addingTimeInterval(week + notice)
    let justPast = now.addingTimeInterval(week + notice + 1)
    let late = try #require(SupportRenewal(expiration: onTheLine, willAutoRenew: true, now: now))
    let inTime = try #require(SupportRenewal(expiration: justPast, willAutoRenew: true, now: now))
    #expect(late.reminderDate == nil)
    let expected: Date = now.addingTimeInterval(notice + 1)
    #expect(inTime.reminderDate == expected)
  }

  @Test func noRecurringTipSaysNothing() {
    #expect(SupportRenewal(expiration: nil, willAutoRenew: true, now: now) == nil)
    #expect(SupportRenewal(expiration: nil, willAutoRenew: nil, now: now) == nil)
  }

  @Test func aPeriodThatHasEndedSaysNothing() {
    #expect(SupportRenewal(expiration: now, willAutoRenew: true, now: now) == nil)
    #expect(SupportRenewal(expiration: now.addingTimeInterval(-day), willAutoRenew: false, now: now) == nil)
  }

  @Test func theLeadIsOneWeek() {
    let expected: TimeInterval = 604_800
    #expect(SupportRenewal.reminderLead == expected)
  }
}

/// The reminders scheduled ahead, so a subscriber who stops opening the app is
/// still reminded before the renewals after the next one.
@Suite("Recurring tip reminders ahead")
struct SupportRenewalAheadTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
  }
  private let week: TimeInterval = 7 * 24 * 60 * 60

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 21, minute: 30))!
  }

  @Test func aMonthlyTipIsRemindedBeforeEachOfTheNextTwelveRenewals() throws {
    let now = date(2026, 9, 26)
    let renewal = try #require(SupportRenewal(expiration: date(2026, 10, 26), willAutoRenew: true, now: now))
    let dates = renewal.reminderDates(
      every: .month, count: SupportRenewal.monthlyReminderCount, timeZone: calendar.timeZone, now: now)
    #expect(dates.count == 12)
    let first: Date = date(2026, 10, 26).addingTimeInterval(-week)
    let twelfth: Date = date(2027, 9, 26).addingTimeInterval(-week)
    #expect(dates.first == first)
    #expect(dates.last == twelfth)
    #expect(dates.allSatisfy { $0 != nil })
  }

  @Test func theFirstMayBeDueWhileTheLaterOnesAreStillScheduled() throws {
    let now = date(2026, 9, 26)
    let renewal = try #require(SupportRenewal(expiration: date(2026, 9, 30), willAutoRenew: true, now: now))
    let dates = renewal.reminderDates(every: .month, count: 3, timeZone: calendar.timeZone, now: now)
    let second: Date = date(2026, 10, 30).addingTimeInterval(-week)
    #expect(dates[0] == nil)
    #expect(dates[1] == second)
    #expect(dates.count == 3)
  }

  @Test func aTipOnThe31stKeepsItsDayWhereTheMonthHasOne() throws {
    let now = date(2027, 1, 1)
    let renewal = try #require(SupportRenewal(expiration: date(2027, 1, 31), willAutoRenew: true, now: now))
    let dates = renewal.reminderDates(every: .month, count: 3, timeZone: calendar.timeZone, now: now)
    let february: Date = date(2027, 2, 28).addingTimeInterval(-week)
    let march: Date = date(2027, 3, 31).addingTimeInterval(-week)
    #expect(dates[1] == february)
    #expect(dates[2] == march)
  }

  @Test func aYearlyTipIsRemindedBeforeTheNextTwoRenewals() throws {
    let now = date(2026, 9, 26)
    let renewal = try #require(SupportRenewal(expiration: date(2027, 9, 26), willAutoRenew: true, now: now))
    let dates = renewal.reminderDates(
      every: .year, count: SupportRenewal.yearlyReminderCount, timeZone: calendar.timeZone, now: now)
    let second: Date = date(2028, 9, 26).addingTimeInterval(-week)
    #expect(dates.count == 2)
    #expect(dates[1] == second)
  }

  @Test func aTipThatEndsHasNoRemindersAhead() throws {
    let now = date(2026, 9, 26)
    let renewal = try #require(SupportRenewal(expiration: date(2026, 10, 26), willAutoRenew: false, now: now))
    let dates = renewal.reminderDates(every: .month, count: 12, timeZone: calendar.timeZone, now: now)
    #expect(dates.count == 12)
    #expect(dates.allSatisfy { $0 == nil })
  }

  @Test func theFirstMatchesTheSingleReminderDate() throws {
    let now = date(2026, 9, 26)
    let renewal = try #require(SupportRenewal(expiration: date(2026, 11, 2), willAutoRenew: nil, now: now))
    let dates = renewal.reminderDates(every: .month, count: 1, timeZone: calendar.timeZone, now: now)
    #expect(dates == [renewal.reminderDate])
  }

  @Test func laterRenewalsAreCountedInTheGregorianCalendar() throws {
    // A Hebrew-calendar year from this date lands weeks away from the
    // Gregorian one, which is the App Store's; the reminders follow the
    // App Store's.
    let now = date(2026, 9, 26)
    let expiration = date(2026, 10, 26)
    let renewal = try #require(SupportRenewal(expiration: expiration, willAutoRenew: true, now: now))
    let dates = renewal.reminderDates(every: .year, count: 2, timeZone: calendar.timeZone, now: now)
    let gregorian: Date = date(2027, 10, 26).addingTimeInterval(-week)
    var hebrew = Calendar(identifier: .hebrew)
    hebrew.timeZone = calendar.timeZone
    let hebrewYear = try #require(hebrew.date(byAdding: .year, value: 1, to: expiration))
    #expect(dates[1] == gregorian)
    #expect(abs(hebrewYear.timeIntervalSince(date(2027, 10, 26))) > week)
  }
}
