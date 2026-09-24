import Foundation
import Testing

@testable import DrinkTrackerCore

/// The arithmetic behind the Comparisons card's bars (ADR-0038's 2026-09-23
/// amendment). Each bar is its printed figure's share of its own days, drawn
/// from the figure as printed, never longer than its track.
///
/// Every expected value is a typed constant, never literal arithmetic inside
/// `#expect`: Swift 6.3's type checker, which CI's domain job runs, gave up on
/// `#expect(shares == [7.0 / 12, 0.31, 10.0 / 18, 0.24])` ("unable to
/// type-check this expression in reasonable time") where 6.4 compiled it.
@Suite("Comparison figures")
struct ComparisonFiguresTests {

  // MARK: - A bar is its figure's share of its own days

  @Test("A bar is the printed figure's share of its days: 16 of 28 is sixteen twenty-eighths")
  func barsAreShares() {
    let sixteenOf28: Double = 16.0 / 28
    let sevenOf28: Double = 7.0 / 28
    #expect(ComparisonBars.share(16, of: 28) == sixteenOf28)
    #expect(ComparisonBars.share(7, of: 28) == sevenOf28)
    #expect(ComparisonBars.share(31, of: 100) == 0.31)
    #expect(ComparisonBars.share(28, of: 28) == 1)
  }

  @Test("Two figures over the same days keep their proportion; a figure over more days draws shorter")
  func sharesAreOneScale() {
    // The drinking-days pair shares a window, so the bars stand in the ratio
    // of the counts; the weekend pair does not share a denominator, so each
    // bar is read against its own — "7 of 12" is longer than "31 of every 100".
    let ratio: Double = ComparisonBars.share(16, of: 28) / ComparisonBars.share(7, of: 28)
    let countRatio: Double = 16.0 / 7
    let drift: Double = abs(ratio - countRatio)
    #expect(drift < 1e-12)
    #expect(ComparisonBars.share(7, of: 12) > ComparisonBars.share(31, of: 100))
    #expect(ComparisonBars.share(7, of: 364) < ComparisonBars.share(7, of: 28))
  }

  @Test("No days, no count, or a count past its days draws no bar longer than its track")
  func unusableFiguresDrawNothing() {
    #expect(ComparisonBars.share(0, of: 28) == 0)
    #expect(ComparisonBars.share(5, of: 0) == 0)
    #expect(ComparisonBars.share(-3, of: 28) == 0)
    #expect(ComparisonBars.share(40, of: 28) == 1)
  }

  // MARK: - The printed figures the bars are drawn from

  @Test("The drinking-days mean is drawn from the whole number the sentence prints")
  func drinkingDaysAreTheDisplayedFigure() throws {
    let frequency = try #require(FrequencyReference.bundled)
    // 87.9 a year: 6.74 in 28, 87.66 in 364.
    #expect(frequency.displayedDrinkingDays(per: 28) == 7)
    #expect(frequency.displayedDrinkingDays(per: 364) == 88)
    #expect(frequency.displayedDrinkingDays(per: 0) == 0)
  }

  @Test("The weekend rates are drawn from the whole numbers the table prints")
  func weekendRatesAreTheDisplayedFigures() throws {
    let weekend = try #require(WeekendReference.bundled)
    // 30.5 and 24.4 per hundred person-days.
    #expect(weekend.displayedWeekendPer100Days == 31)
    #expect(weekend.displayedOtherPer100Days == 24)
  }

  @Test("The weekend segment's four shares, in the order they are drawn")
  func weekendShares() throws {
    let weekend = try #require(WeekendReference.bundled)
    let split = WeekendSplit(weekendDaysWithDrinks: 7, weekendDays: 12, otherDaysWithDrinks: 10, otherDays: 18)
    let shares = split.sharesOfDays(beside: weekend)
    let sevenOf12: Double = 7.0 / 12
    let tenOf18: Double = 10.0 / 18
    let expected: [Double] = [sevenOf12, 0.31, tenOf18, 0.24]
    #expect(shares == expected)

    let empty = WeekendSplit(weekendDaysWithDrinks: 0, weekendDays: 0, otherDaysWithDrinks: 0, otherDays: 0)
    let emptyShares = empty.sharesOfDays(beside: weekend)
    let expectedEmpty: [Double] = [0, 0.31, 0, 0.24]
    #expect(emptyShares == expectedEmpty)
  }
}
