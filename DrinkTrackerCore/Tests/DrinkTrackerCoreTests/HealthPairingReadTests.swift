import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0049: the read layer's pure half. What a read asks for is decided
/// here and never includes the current day; what a read leaves behind is
/// one line whose three arguments cannot carry a value.
@Suite("Health pairing reads")
struct HealthPairingReadTests {

  private var utc: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  private func zoned(_ identifier: String) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: identifier)!
    return cal
  }

  private func at(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
    in calendar: Calendar
  ) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  // MARK: - The window

  @Test("The window runs from the range's first day to the start of today, and never holds today")
  func windowExcludesToday() throws {
    let cal = utc
    let range = DateInterval(start: at(2026, 9, 1, 9, in: cal), end: at(2026, 9, 21, 14, in: cal))
    let window = try #require(
      HealthPairing.readWindow(for: range, endingBefore: at(2026, 9, 21, 14, 30, in: cal), calendar: cal))
    #expect(window.start == at(2026, 9, 1, in: cal))
    #expect(window.end == at(2026, 9, 21, in: cal))
    #expect(!window.contains(at(2026, 9, 21, 0, 1, in: cal)))
    #expect(HealthPairing.days(in: window, calendar: cal) == 20)
  }

  @Test("A range that ends before today is read in full; one that starts today is nothing")
  func windowClipsToTheRange() {
    let cal = utc
    let now = at(2026, 9, 21, 8, in: cal)
    let past = DateInterval(start: at(2026, 6, 1, in: cal), end: at(2026, 6, 30, 23, in: cal))
    let window = HealthPairing.readWindow(for: past, endingBefore: now, calendar: cal)
    #expect(window?.start == at(2026, 6, 1, in: cal))
    #expect(window?.end == at(2026, 6, 30, in: cal))
    let today = DateInterval(start: at(2026, 9, 21, in: cal), end: at(2026, 9, 21, 23, in: cal))
    #expect(HealthPairing.readWindow(for: today, endingBefore: now, calendar: cal) == nil)
    let future = DateInterval(start: at(2026, 9, 22, in: cal), end: at(2026, 9, 25, in: cal))
    #expect(HealthPairing.readWindow(for: future, endingBefore: now, calendar: cal) == nil)
  }

  @Test("A quarter's window ending on a spring-forward day counts calendar days, not 24-hour spans")
  func windowCountsCalendarDays() throws {
    // New York, 2026-03-08 is 23 hours long; the window's day count is
    // still the calendar's, and today is still excluded.
    let cal = zoned("America/New_York")
    let range = DateInterval(start: at(2026, 3, 1, in: cal), end: at(2026, 3, 9, in: cal))
    let window = try #require(
      HealthPairing.readWindow(for: range, endingBefore: at(2026, 3, 9, 10, in: cal), calendar: cal))
    #expect(window.end == at(2026, 3, 9, in: cal))
    #expect(HealthPairing.days(in: window, calendar: cal) == 8)
    #expect(window.duration == 8 * 24 * 3600 - 3600)
  }

  @Test("A zone that changes its clocks at midnight still starts the window at the day's start")
  func windowOnAMidnightTransition() throws {
    let cal = zoned("America/Santiago")
    let range = DateInterval(start: at(2026, 9, 6, 12, in: cal), end: at(2026, 9, 10, in: cal))
    let window = try #require(
      HealthPairing.readWindow(for: range, endingBefore: at(2026, 9, 10, 9, in: cal), calendar: cal))
    #expect(window.start == cal.startOfDay(for: at(2026, 9, 6, 12, in: cal)))
    #expect(HealthPairing.days(in: window, calendar: cal) == 4)
  }

  // MARK: - The breadcrumb

  @Test("The read breadcrumb is the metric, the day count and the seconds, and nothing else")
  func breadcrumbShape() {
    #expect(Breadcrumb.healthRead("resting heart rate", days: 364, seconds: 0.4137) == "resting heart rate · 364 days · 0.41 s")
    #expect(Breadcrumb.healthRead("resting heart rate", days: 0, seconds: 0) == "resting heart rate · 0 days · 0.00 s")
    // Nothing negative or non-finite reaches the line.
    #expect(Breadcrumb.healthRead("x", days: -3, seconds: -1) == "x · 0 days · 0.00 s")
    #expect(Breadcrumb.healthRead("x", days: 1, seconds: .nan) == "x · 1 days · 0.00 s")
  }

  /// The line is written into the App Group. Every number in it must be one
  /// of the two arguments, so a future caller cannot slip a value through
  /// by interpolation: the only digits present are the day count and the
  /// duration.
  @Test("The breadcrumb's digits are exactly the day count and the duration")
  func breadcrumbCarriesOnlyItsArguments() {
    let line = Breadcrumb.healthRead("resting heart rate", days: 91, seconds: 1.5)
    let numbers = line.split(separator: " ").compactMap { Double($0) }
    #expect(numbers == [91, 1.5])
    let stamped = Breadcrumb.stamped(line, process: "app", at: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!)
    #expect(stamped == "resting heart rate · 91 days · 1.50 s · app · 01-01 00:00:00")
  }
}
