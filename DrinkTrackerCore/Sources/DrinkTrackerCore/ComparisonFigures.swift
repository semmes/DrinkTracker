import Foundation

// The arithmetic behind the bars in Trends' Comparisons card (ADR-0038's
// 2026-09-23 amendment): the three published comparisons became one card, and
// the drinking days and the weekend split are drawn as bars. Every length those
// bars take is decided here, where it is tested, rather than in a view no test
// reaches.
//
// Two rules hold every bar to the figure printed above it:
//
// - **A bar never says more than its figure.** The drinking-days mean is
//   rounded to whole days where it is printed, so its bar is drawn from the
//   rounded figure; the weekend rate is printed per hundred to the whole
//   number, so its bar is too.
// - **A bar is its figure's share of its own days, over a track that is all of
//   them.** "7 of 12" fills seven-twelfths of its track, "31 of every 100"
//   thirty-one hundredths, so every bar in a segment is on one scale and the
//   track shows where that scale ends. The track is the owner's ruling
//   (2026-09-23, "so users can see where the bar chart ends and how much of it
//   they have or haven't filled"), taken with the 1.4.3 copy review's second
//   finding in front of them — a bar that fills a drawn container has a full
//   state, and the review called a full state a target. What keeps these bars
//   from being a progress bar's goal is that no segment draws one alone: each
//   puts at least two figures on the same track, the reader's and a published
//   one, so the full state is a scale two facts share rather than a finish
//   line for one. (Measuring each bar against the larger of the two was built
//   first and rendered "7 of 12" the column's full width, which states a fact
//   the figure does not.)

/// Bar lengths for a comparison drawn as bars: a figure's share of its own
/// days, 0 to 1 of the track. A window with no days, or a count outside it,
/// draws no bar longer than the track.
public enum ComparisonBars {
  public static func share(_ count: Int, of days: Int) -> Double {
    guard days > 0, count > 0 else { return 0 }
    return min(1, Double(count) / Double(days))
  }
}

extension FrequencyReference {
  /// The published mean scaled to a window and rounded to whole days — the
  /// number the drinking-days sentence prints ("about 7 in 28"), and so the
  /// number its bar is drawn from. A mean over a population is not a figure a
  /// tenth of a day can be checked against (ADR-0031).
  public func displayedDrinkingDays(per days: Int) -> Int {
    let scaled = drinkingDays(per: days)
    guard scaled.isFinite else { return 0 }
    return Int(scaled.rounded())
  }
}

extension WeekendReference {
  /// The weekend rate as printed: whole days with a drink per hundred.
  public var displayedWeekendPer100Days: Int { Int(weekendEpisodesPer100Days.rounded()) }

  /// The Monday-to-Thursday rate as printed.
  public var displayedOtherPer100Days: Int { Int(otherEpisodesPer100Days.rounded()) }
}

extension WeekendSplit {
  /// The four figures the weekend segment draws, as shares of their own days,
  /// in the order it draws them: the reader's Friday to Sunday, the published
  /// Friday to Sunday, the reader's Monday to Thursday, the published Monday
  /// to Thursday. The published rates are the printed whole numbers over a
  /// hundred, so a bar never disagrees with the figure written above it. A
  /// group with no days in it contributes a share of zero.
  public func sharesOfDays(beside reference: WeekendReference) -> [Double] {
    [
      ComparisonBars.share(weekendDaysWithDrinks, of: weekendDays),
      ComparisonBars.share(reference.displayedWeekendPer100Days, of: 100),
      ComparisonBars.share(otherDaysWithDrinks, of: otherDays),
      ComparisonBars.share(reference.displayedOtherPer100Days, of: 100),
    ]
  }
}
