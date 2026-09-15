import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0044, pinned: the session row draws whole dots up to a cap of eight,
/// rounds a fraction to the nearest dot with a half up, and never marks a
/// truncation — the count line carries the truth past the cap.
@Suite("Session dot row")
struct DotRowTests {

  @Test("The cap is eight")
  func cap() {
    #expect(SessionPace.dotMaximum == 8)
  }

  @Test("Nothing to draw for zero, a negative, or nothing at all")
  func nothing() {
    #expect(SessionPace.dotRow(forCount: 0) == .init(dots: 0, isTruncated: false))
    #expect(SessionPace.dotRow(forCount: -1) == .init(dots: 0, isTruncated: false))
    #expect(SessionPace.dotRow(forCount: .nan) == .init(dots: 0, isTruncated: false))
    #expect(SessionPace.dotRow(forCount: -.infinity) == .init(dots: 0, isTruncated: false))
  }

  @Test("Whole counts up to the cap draw exactly that many")
  func wholeCounts() {
    for count in 1...8 {
      #expect(SessionPace.dotRow(forCount: Double(count)) == .init(dots: count, isTruncated: false))
    }
  }

  @Test("Past the cap the row draws the cap and says so")
  func pastTheCap() {
    #expect(SessionPace.dotRow(forCount: 9) == .init(dots: 8, isTruncated: true))
    #expect(SessionPace.dotRow(forCount: 100) == .init(dots: 8, isTruncated: true))
    #expect(SessionPace.dotRow(forCount: .infinity) == .init(dots: 8, isTruncated: true))
  }

  @Test("A fraction rounds to the nearest dot, a half up")
  func fractions() {
    #expect(SessionPace.dotRow(forCount: 2.4).dots == 2)
    #expect(SessionPace.dotRow(forCount: 2.5).dots == 3)
    #expect(SessionPace.dotRow(forCount: 0.4) == .init(dots: 0, isTruncated: false))
    #expect(SessionPace.dotRow(forCount: 0.5).dots == 1)
    // 8.4 rounds down onto the cap; 8.5 rounds past it.
    #expect(SessionPace.dotRow(forCount: 8.4) == .init(dots: 8, isTruncated: false))
    #expect(SessionPace.dotRow(forCount: 8.5) == .init(dots: 8, isTruncated: true))
  }

  @Test("The dots are decided on the displayed figure, so they agree with the printed one")
  func displayedFigure() {
    // 2.45 prints "2.5" (StandardDrink.displayed), and 2.5 rounds to three
    // dots — so 2.45 must too, where the raw value would round to two.
    #expect(StandardDrink.displayed(2.45) == 2.5)
    #expect(SessionPace.dotRow(forCount: 2.45).dots == 3)
    #expect(SessionPace.dotRow(forCount: 2.44).dots == 2)
    // "0.5" prints over one dot, never a figure over no dots.
    #expect(SessionPace.dotRow(forCount: 0.45).dots == 1)
    // 8.45 prints "8.5", which is past the cap.
    #expect(SessionPace.dotRow(forCount: 8.45) == .init(dots: 8, isTruncated: true))
  }

  @Test("A smaller cap is honoured, and a zero cap draws nothing")
  func customCap() {
    #expect(SessionPace.dotRow(forCount: 5, maximum: 5) == .init(dots: 5, isTruncated: false))
    #expect(SessionPace.dotRow(forCount: 6, maximum: 5) == .init(dots: 5, isTruncated: true))
    #expect(SessionPace.dotRow(forCount: 3, maximum: 0) == .init(dots: 0, isTruncated: true))
  }
}
