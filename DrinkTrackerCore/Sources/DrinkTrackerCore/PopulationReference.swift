import Foundation

/// The bundled population reference (1.2 spec, Feature C; ADR-0018).
///
/// A static JSON resource — never a network call — holding the 2020 National
/// Alcohol Survey's distribution of drinks per week, renormalized to US
/// adults who drink (the derivation is stated in the file and shown to the
/// user). Comparison happens in grams of pure ethanol, so the user's
/// regional unit setting cannot silently skew it: their average converts
/// region-units → grams, the survey's levels are US drinks × 14 g, and the
/// two meet in the middle.
///
/// This is a *descriptive statistic*, deliberately: no NIAAA thresholds, no
/// guideline lines, no recommended limits (spec constraint 5 — a statistic
/// is a fact; a threshold is a recommendation).
public struct PopulationReference: Sendable {

  public struct Row: Codable, Sendable {
    public let drinksMin: Int
    /// nil for the open-ended top row ("70+").
    public let drinksMax: Int?
    public let gramsMax: Double?
    public let percentAllAdults: Double
    public let percentDrinkers: Double

    enum CodingKeys: String, CodingKey {
      case drinksMin = "drinks_min"
      case drinksMax = "drinks_max"
      case gramsMax = "grams_max"
      case percentAllAdults = "percent_all_adults"
      case percentDrinkers = "percent_drinkers"
    }
  }

  public let source: String
  public let sourceURL: String
  public let year: Int
  public let population: String
  public let derivation: String
  public let gramsPerSurveyDrink: Double
  public let abstainersPercentAllAdults: Double
  public let rows: [Row]

  /// Hidden until at least this much history exists — below it the average
  /// is noise (spec acceptance criterion).
  public static let minimumHistory: TimeInterval = 28 * 24 * 60 * 60

  // MARK: - Loading

  /// The bundled file, decoded once. nil only if the bundle is broken, in
  /// which case the feature silently doesn't render — never a placeholder
  /// number.
  public static let bundled: PopulationReference? = {
    guard let url = Bundle.module.url(forResource: "us-population-reference", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? PopulationReference(data: data)
  }()

  public init(data: Data) throws {
    struct File: Codable {
      let source: String
      let source_url: String
      let year: Int
      let population: String
      let derivation: String
      let grams_per_survey_drink: Double
      let abstainers_percent_all_adults: Double
      let rows: [Row]
    }
    let file = try JSONDecoder().decode(File.self, from: data)
    self.source = file.source
    self.sourceURL = file.source_url
    self.year = file.year
    self.population = file.population
    self.derivation = file.derivation
    self.gramsPerSurveyDrink = file.grams_per_survey_drink
    self.abstainersPercentAllAdults = file.abstainers_percent_all_adults
    self.rows = file.rows
  }

  // MARK: - Comparison

  /// The comparison for a weekly average, or nil when there is nothing
  /// honest to say (a zero average compares against no row).
  ///
  /// `gramsPerWeek` is the user's average converted to grams — callers do
  /// `units × region.gramsPureAlcoholPerStandardDrink` (the mandatory
  /// conversion; a UK unit is 8 g, a survey drink 14 g).
  ///
  /// The bracket is chosen conservatively: the average rounds *up* to the
  /// next survey level, so "lower than roughly N%" is true at the bracket's
  /// edge rather than optimistic inside it. Near the top of the table the
  /// phrasing flips to "more than roughly N%" (floored to 5) because
  /// "lower than roughly 0%" states nothing.
  public enum Comparison: Equatable, Sendable {
    /// "That's lower than roughly N% of US adults who drink."
    case lowerThan(percent: Int)
    /// "That's more than roughly N% of US adults who drink."
    case moreThan(percent: Int)
  }

  public func comparison(gramsPerWeek: Double) -> Comparison? {
    guard gramsPerWeek > 0 else { return nil }
    let surveyDrinks = gramsPerWeek / gramsPerSurveyDrink
    // The 0.005-drink shave (0.07 g of ethanol a week) keeps an
    // exactly-N-drink average at level N: regional grams are derived values
    // (a US drink computes to 14.0001 g, 7.8 ppm high), and without the
    // shave that drift compounds with volume and the ceiling bumps exact
    // averages into the next bracket.
    let level = max(1, Int((surveyDrinks - 0.005).rounded(.up)))

    // Smallest row whose upper bound covers the level; the open-ended top
    // row covers everything above the table.
    let row = rows.first { row in
      guard let max = row.drinksMax else { return true }
      return level <= max
    }
    guard let row else { return nil }

    let percentMore = 100 - row.percentDrinkers
    let roundedToFive = Int((percentMore / 5).rounded() * 5)
    guard roundedToFive >= 5 else {
      // Almost nobody drinks more; say the true direction instead.
      let floored = Int((row.percentDrinkers / 5).rounded(.down) * 5)
      return .moreThan(percent: min(floored, 95))
    }
    return .lowerThan(percent: roundedToFive)
  }
}
