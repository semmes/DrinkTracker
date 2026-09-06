import Foundation
import Testing

@testable import DrinkTrackerCore

/// Feature B's edge-case list from docs/tallyist-1.2-spec.md, pinned one test
/// per case. Everything drives an injected clock — `Date()` never appears.
@Suite("Session pace")
struct SessionPaceTests {

  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  private func minutes(_ m: Double) -> TimeInterval { m * 60 }
  private func hours(_ h: Double) -> TimeInterval { h * 3600 }

  private func beer(at offset: TimeInterval) -> LoggedDrink {
    LoggedDrink(loggedAt: now.addingTimeInterval(offset), type: .beer, volumeOunces: 12, abvPercent: 5)
  }

  @Test("A run of drinks inside the gap threshold is one session")
  func basicSession() {
    let drinks = [beer(at: -minutes(150)), beer(at: -minutes(90)), beer(at: -minutes(47))]
    let session = SessionPace.currentSession(in: drinks, now: now)
    #expect(session != nil)
    #expect(session?.count == 3)
    #expect(session?.start == now.addingTimeInterval(-minutes(150)))
    #expect(session?.lastDrinkAt == now.addingTimeInterval(-minutes(47)))
  }

  @Test("No drink within the threshold means no session — nothing is written, it just isn't there")
  func sessionEnds() {
    let drinks = [beer(at: -hours(5))]
    #expect(SessionPace.currentSession(in: drinks, now: now) == nil)
    #expect(SessionPace.currentSession(in: [], now: now) == nil)
  }

  @Test("A gap inside history splits the run: only the recent side is the session")
  func gapSplitsRun() {
    let drinks = [
      beer(at: -hours(10)), beer(at: -hours(9.5)),  // an earlier sitting
      beer(at: -hours(2)), beer(at: -hours(1)),      // the current one
    ]
    let session = SessionPace.currentSession(in: drinks, now: now)
    #expect(session?.count == 2)
    #expect(session?.start == now.addingTimeInterval(-hours(2)))
  }

  @Test("A backdated entry cannot create or resurrect a session now")
  func backdatedEntry() {
    // Added *now* from History, but dated yesterday: the timestamp is what
    // counts, so no card appears.
    let drinks = [beer(at: -hours(20))]
    #expect(SessionPace.currentSession(in: drinks, now: now) == nil)
  }

  @Test("Editing a timestamp recomputes: moving the drink out of range ends the session")
  func editedTimestamp() {
    let inRange = [beer(at: -hours(3))]
    let moved = [beer(at: -hours(6))]
    #expect(SessionPace.currentSession(in: inRange, now: now) != nil)
    #expect(SessionPace.currentSession(in: moved, now: now) == nil)
  }

  @Test("Deleting the only recent drink removes the session")
  func deletionHidesCard() {
    let before = [beer(at: -hours(6)), beer(at: -minutes(30))]
    let after = [beer(at: -hours(6))]
    #expect(SessionPace.currentSession(in: before, now: now) != nil)
    #expect(SessionPace.currentSession(in: after, now: now) == nil)
  }

  @Test("A Health import contributes its count, not one")
  func importedCountsSum() {
    let drinks = [
      beer(at: -minutes(90)),
      .importedFromHealth(sampleID: UUID(), count: 2, loggedAt: now.addingTimeInterval(-minutes(30))),
    ]
    let session = SessionPace.currentSession(in: drinks, now: now)
    #expect(session?.count == 3)
    #expect(SessionPace.rollingCount(in: drinks, now: now) == 3)
  }

  @Test("Identical timestamps both count and don't break ordering")
  func identicalTimestamps() {
    let drinks = [beer(at: -minutes(30)), beer(at: -minutes(30))]
    let session = SessionPace.currentSession(in: drinks, now: now)
    #expect(session?.count == 2)
    #expect(session?.start == now.addingTimeInterval(-minutes(30)))
  }

  @Test("A session crosses midnight untouched — absolute time, no calendar")
  func midnightIsNotABoundary() {
    // 11 PM and 1 AM in any time zone are two hours apart; nothing here
    // consults a calendar, so day boundaries and DST cannot split a run.
    let drinks = [beer(at: -hours(2)), beer(at: -minutes(10))]
    let session = SessionPace.currentSession(in: drinks, now: now)
    #expect(session?.count == 2)
  }

  @Test("A clock jump backwards clamps to now — never a negative elapsed time")
  func backwardsClockClamps() {
    // Logged, then the device clock moved back 20 minutes: the drink is real
    // and stays in the session, at an effective time of now.
    let drinks = [beer(at: minutes(20))]
    let session = SessionPace.currentSession(in: drinks, now: now)
    #expect(session != nil)
    #expect(session?.lastDrinkAt == now)
    #expect(now.timeIntervalSince(session!.lastDrinkAt) >= 0)
    #expect(SessionPace.rollingCount(in: drinks, now: now) == 1)
  }

  @Test("An entry synced mid-session folds into the current session")
  func syncedEntryFolds() {
    // The same pure function over a bigger array — which is exactly what a
    // CloudKit merge produces.
    let local = [beer(at: -minutes(100)), beer(at: -minutes(20))]
    let merged = local + [beer(at: -minutes(60))]
    #expect(SessionPace.currentSession(in: local, now: now)?.count == 2)
    let session = SessionPace.currentSession(in: merged, now: now)
    #expect(session?.count == 3)
    #expect(session?.start == now.addingTimeInterval(-minutes(100)))
  }

  @Test("The rolling window is inclusive at its edge and blind outside it")
  func rollingWindowBoundary() {
    let drinks = [
      beer(at: -SessionPace.rollingWindow),          // exactly on the edge
      beer(at: -SessionPace.rollingWindow - 1),      // one second outside
      beer(at: -minutes(10)),
    ]
    #expect(SessionPace.rollingCount(in: drinks, now: now) == 2)
  }

  /// The chip prints a count and is shaded by an amount (ADR-0034), so the two
  /// have to share a window and nothing else. Same three drinks, same edge
  /// behaviour, different quantity.
  @Test("The rolling total shares the count's window but measures standard drinks")
  func rollingStandardDrinksSharesTheWindow() {
    let drinks = [
      beer(at: -SessionPace.rollingWindow),          // exactly on the edge
      beer(at: -SessionPace.rollingWindow - 1),      // one second outside
      beer(at: -minutes(10)),
    ]
    // Two 12oz/5% beers inside the window: 12 × 0.05 = 0.6 fl oz of alcohol
    // each, which is exactly one US standard drink apiece.
    #expect(SessionPace.rollingCount(in: drinks, now: now) == 2)
    let total = SessionPace.rollingStandardDrinks(in: drinks, now: now, region: .unitedStates)
    #expect(abs(total - 2) < 0.0001)
  }

  /// The lens reaches the chip's colour like every other total (ADR-0002): the
  /// same two beers are two US standard drinks and about 2.7 UK units, so the
  /// shade can differ between regions for identical drinking. That is the
  /// display-lens behaviour, not a bug.
  @Test("The rolling total is region-lensed")
  func rollingStandardDrinksFollowsRegion() {
    let drinks = [beer(at: -minutes(30)), beer(at: -minutes(10))]
    let us = SessionPace.rollingStandardDrinks(in: drinks, now: now, region: .unitedStates)
    let uk = SessionPace.rollingStandardDrinks(in: drinks, now: now, region: .unitedKingdom)
    #expect(abs(us - 2) < 0.0001)
    #expect(uk > us)
  }

  /// A Health import's count *is* the whole fact, so it contributes the same
  /// number to both figures and is the same number under every lens
  /// (`LoggedDrink.standardDrinks(in:)`, ADR-0014). Worth pinning here because
  /// it is the reason the chip's shade cannot be read as "how much alcohol" in
  /// general — for an imported row it is "how many drinks the other app said".
  @Test("An imported count contributes its count to both figures, unlensed")
  func importedCountsAreUnlensed() {
    let imported = LoggedDrink(
      loggedAt: now.addingTimeInterval(-minutes(20)),
      type: .other,
      volumeOunces: 0,
      abvPercent: 0,
      countedDrinks: 2
    )
    let drinks = [beer(at: -minutes(10)), imported]
    #expect(SessionPace.rollingCount(in: drinks, now: now) == 3)
    for region in Region.allCases {
      let total = SessionPace.rollingStandardDrinks(in: drinks, now: now, region: region)
      let beerAlone = SessionPace.rollingStandardDrinks(
        in: [beer(at: -minutes(10))], now: now, region: region
      )
      #expect(abs(total - (beerAlone + 2)) < 0.0001, "import re-expressed under \(region)")
    }
  }

  @Test("Chained drinks extend a session well past one threshold from now")
  func chainExtendsSession() {
    // Each drink within 4h of the previous; the run reaches back 9 hours even
    // though no single drink is within 9h of the first.
    let drinks = [beer(at: -hours(9)), beer(at: -hours(6)), beer(at: -hours(3))]
    let session = SessionPace.currentSession(in: drinks, now: now)
    #expect(session?.count == 3)
    #expect(session?.start == now.addingTimeInterval(-hours(9)))
  }
}
