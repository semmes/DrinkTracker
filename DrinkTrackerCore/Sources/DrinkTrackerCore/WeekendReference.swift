import Foundation

/// The bundled weekend reference (ADR-0032): how often US adults' days
/// include a drink on the weekend against the rest of the week, from a
/// national dietary survey — Liang and Chikritzhs, 2015, on NHANES 2005 to
/// 2010. A published rate per 100 person-days over all adults, stated beside
/// the user's own weekend and weekday counts; the paper defines the weekend
/// as Friday, Saturday and Sunday, and this file carries that definition so
/// the two figures describe the same days.
///
/// A descriptive statistic: a drinking episode is any day with 10 grams of
/// alcohol or more, the authors' own analytic cutoff, not a guideline. The
/// paper's heavy-episode rate is deliberately not bundled.
public struct WeekendReference: Sendable {
  public let source: String
  public let sourceURL: String
  public let year: Int
  public let population: String
  public let derivation: String
  /// Days with a drink per 100 person-days, weekend and the rest of the week.
  public let weekendEpisodesPer100Days: Double
  public let otherEpisodesPer100Days: Double
  /// `Calendar.component(.weekday)` values the paper counts as the weekend:
  /// Friday (6), Saturday (7), Sunday (1).
  public let weekendWeekdays: Set<Int>

  public static let bundled: WeekendReference? = {
    guard let url = Bundle.module.url(forResource: "us-weekend-reference", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? WeekendReference(data: data)
  }()

  public init(data: Data) throws {
    struct File: Codable {
      let source: String
      let source_url: String
      let year: Int
      let population: String
      let derivation: String
      let weekend_episodes_per_100_person_days: Double
      let other_episodes_per_100_person_days: Double
      let weekend_weekdays: [Int]
    }
    let file = try JSONDecoder().decode(File.self, from: data)
    self.source = file.source
    self.sourceURL = file.source_url
    self.year = file.year
    self.population = file.population
    self.derivation = file.derivation
    self.weekendEpisodesPer100Days = file.weekend_episodes_per_100_person_days
    self.otherEpisodesPer100Days = file.other_episodes_per_100_person_days
    self.weekendWeekdays = Set(file.weekend_weekdays)
  }
}

/// The user's own split on the paper's definition: how many of the range's
/// weekend days had a drink, and how many of the others.
public struct WeekendSplit: Hashable, Sendable {
  public let weekendDaysWithDrinks: Int
  public let weekendDays: Int
  public let otherDaysWithDrinks: Int
  public let otherDays: Int

  public init(weekendDaysWithDrinks: Int, weekendDays: Int, otherDaysWithDrinks: Int, otherDays: Int) {
    self.weekendDaysWithDrinks = weekendDaysWithDrinks
    self.weekendDays = weekendDays
    self.otherDaysWithDrinks = otherDaysWithDrinks
    self.otherDays = otherDays
  }
}

extension TrendSummary {
  /// Folds the seven weekday totals into the paper's two groups.
  public static func weekendSplit(_ totals: [WeekdayTotal], weekend: Set<Int>) -> WeekendSplit {
    var split = (ww: 0, wd: 0, ow: 0, od: 0)
    for total in totals {
      if weekend.contains(total.weekday) {
        split.ww += total.daysWithDrinks; split.wd += total.dayCount
      } else {
        split.ow += total.daysWithDrinks; split.od += total.dayCount
      }
    }
    return WeekendSplit(weekendDaysWithDrinks: split.ww, weekendDays: split.wd, otherDaysWithDrinks: split.ow, otherDays: split.od)
  }
}
