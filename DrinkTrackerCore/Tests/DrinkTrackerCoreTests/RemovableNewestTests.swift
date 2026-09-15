import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0043, pinned: the wrist's − removes today's newest entry only when the
/// watch can remove it cleanly, and never reaches past it to an older one.
@Suite("Removable newest")
struct RemovableNewestTests {

  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }()

  private let noon = Date(timeIntervalSince1970: 1_700_000_000 + 12 * 3600)

  private func drink(
    minutesAgo: Double,
    sampleID: UUID? = nil,
    countedDrinks: Double? = nil
  ) -> LoggedDrink {
    LoggedDrink(
      loggedAt: noon.addingTimeInterval(-minutesAgo * 60),
      type: .beer,
      volumeOunces: 12,
      abvPercent: 5,
      healthKitSampleID: sampleID,
      countedDrinks: countedDrinks
    )
  }

  @Test("A day with nothing has nothing to remove")
  func nothingToday() {
    #expect(LoggedDrink.removableNewest(in: [], on: noon, calendar: calendar) == nil)
    // Yesterday's drink is not today's.
    let yesterday = drink(minutesAgo: 30 * 60)
    #expect(LoggedDrink.removableNewest(in: [yesterday], on: noon, calendar: calendar) == nil)
  }

  @Test("The newest of today's own entries is removable")
  func newestOwnEntry() {
    let older = drink(minutesAgo: 90)
    let newest = drink(minutesAgo: 5)
    let found = LoggedDrink.removableNewest(in: [older, newest], on: noon, calendar: calendar)
    #expect(found?.id == newest.id)
  }

  @Test("A newest entry the phone has backfilled into Health is unavailable — and − does not skip past it")
  func newestHasSample() {
    let older = drink(minutesAgo: 90)                       // removable on its own
    let newest = drink(minutesAgo: 5, sampleID: UUID())     // Health owns it now
    #expect(LoggedDrink.removableNewest(in: [older, newest], on: noon, calendar: calendar) == nil)
  }

  @Test("A newest entry mirrored from another app's Health record is unavailable")
  func newestIsImport() {
    let older = drink(minutesAgo: 90)
    let imported = drink(minutesAgo: 5, sampleID: UUID(), countedDrinks: 1)
    #expect(LoggedDrink.removableNewest(in: [older, imported], on: noon, calendar: calendar) == nil)
  }

  @Test("A watch-logged entry behind an older phone-logged one is removable — only the newest is judged")
  func watchLoggedBehindPhoneLogged() {
    let phoneLogged = drink(minutesAgo: 120, sampleID: UUID())
    let watchLogged = drink(minutesAgo: 3)
    let found = LoggedDrink.removableNewest(in: [phoneLogged, watchLogged], on: noon, calendar: calendar)
    #expect(found?.id == watchLogged.id)
  }

  @Test("Order of the input does not matter")
  func orderIndependent() {
    let a = drink(minutesAgo: 60)
    let b = drink(minutesAgo: 10)
    #expect(LoggedDrink.removableNewest(in: [a, b], on: noon, calendar: calendar)?.id == b.id)
    #expect(LoggedDrink.removableNewest(in: [b, a], on: noon, calendar: calendar)?.id == b.id)
  }
}
