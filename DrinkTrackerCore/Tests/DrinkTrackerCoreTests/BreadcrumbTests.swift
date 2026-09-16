import Foundation
import Testing

@testable import DrinkTrackerCore

/// The shape of the diagnostic breadcrumbs. A breadcrumb that cannot say when
/// or where it was written cannot tell a tap that never ran from one that ran
/// earlier — which is exactly what the 2026-09-16 device run could not tell.
@Suite("Breadcrumb")
struct BreadcrumbTests {

  private let utc = TimeZone(identifier: "UTC")!

  /// 2026-09-16 22:57:41 UTC.
  private let instant = Date(timeIntervalSince1970: 1_789_599_461)

  @Test("A breadcrumb names its step, its process, its date and its time")
  func stamped() {
    #expect(
      Breadcrumb.stamped("saved (one-drink)", process: "Widget", at: instant, timeZone: utc)
        == "saved (one-drink) · Widget · 09-16 22:57:41"
    )
  }

  @Test("The timestamp is 24-hour, zero-padded, and rolls the date at midnight")
  func timestampIsTwentyFourHour() {
    let justAfterMidnight = Date(timeIntervalSince1970: 1_789_603_205)  // 2026-09-17 00:00:05 UTC
    #expect(Breadcrumb.timestamp(justAfterMidnight, timeZone: utc) == "09-17 00:00:05")
    #expect(Breadcrumb.timestamp(instant, timeZone: utc) == "09-16 22:57:41")
  }

  /// Two readings at the same time of day on different days must not read
  /// alike — the case a time-only stamp could not tell apart.
  @Test("The same time on two days reads differently")
  func sameTimeDifferentDay() {
    let nextEvening = instant.addingTimeInterval(24 * 60 * 60)
    #expect(Breadcrumb.timestamp(instant, timeZone: utc) != Breadcrumb.timestamp(nextEvening, timeZone: utc))
  }

  @Test("The timestamp follows the time zone it is given, date included")
  func timestampFollowsTimeZone() {
    let newYork = TimeZone(identifier: "America/New_York")!
    #expect(Breadcrumb.timestamp(instant, timeZone: newYork) == "09-16 18:57:41")
    // 00:00:05 UTC on the 17th is still the 16th in New York.
    let justAfterMidnight = Date(timeIntervalSince1970: 1_789_603_205)
    #expect(Breadcrumb.timestamp(justAfterMidnight, timeZone: newYork) == "09-16 20:00:05")
  }

  @Test("A timeline keeps the newest lines, oldest first")
  func timelineKeepsNewest() {
    var lines: [String] = []
    for n in 1...8 { lines = Breadcrumb.appending("line \(n)", to: lines, limit: 6) }
    #expect(lines == ["line 3", "line 4", "line 5", "line 6", "line 7", "line 8"])
  }

  @Test("A timeline under its limit keeps everything")
  func timelineUnderLimit() {
    #expect(Breadcrumb.appending("c", to: ["a", "b"], limit: 6) == ["a", "b", "c"])
  }

  @Test("A non-positive limit keeps nothing rather than trapping")
  func nonPositiveLimit() {
    #expect(Breadcrumb.appending("c", to: ["a", "b"], limit: 0).isEmpty)
    #expect(Breadcrumb.appending("c", to: ["a", "b"], limit: -3).isEmpty)
  }
}
