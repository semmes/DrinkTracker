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
/// The table prints three columns — Men, Women and Total — and all three are
/// bundled (ADR-0039). Which one a comparison reads is the caller's
/// `Column`; the total is the default, and nothing here asks who the reader
/// is.
///
/// This is a *descriptive statistic*, deliberately: no NIAAA thresholds, no
/// guideline lines, no recommended limits (spec constraint 5 — a statistic
/// is a fact; a threshold is a recommendation).
public struct PopulationReference: Sendable {

  /// One of the survey's published columns. A choice of reference, never a
  /// fact about the reader: `allAdults` is the table's Total column and the
  /// default; `men` and `women` are the two others the source prints. The
  /// survey publishes no further column, so no further case exists — a case
  /// that read the total under another name would be a question asked to no
  /// effect (ADR-0039).
  public enum Column: String, CaseIterable, Identifiable, Sendable {
    case allAdults
    case men
    case women

    public var id: String { rawValue }
  }

  public struct Row: Codable, Sendable {
    public let drinksMin: Int
    /// nil for the open-ended top row ("70+").
    public let drinksMax: Int?
    public let gramsMax: Double?
    public let percentAllAdults: Double
    public let percentDrinkers: Double
    public let percentMen: Double
    public let percentMenDrinkers: Double
    public let percentWomen: Double
    public let percentWomenDrinkers: Double

    enum CodingKeys: String, CodingKey {
      case drinksMin = "drinks_min"
      case drinksMax = "drinks_max"
      case gramsMax = "grams_max"
      case percentAllAdults = "percent_all_adults"
      case percentDrinkers = "percent_drinkers"
      case percentMen = "percent_men"
      case percentMenDrinkers = "percent_men_drinkers"
      case percentWomen = "percent_women"
      case percentWomenDrinkers = "percent_women_drinkers"
    }

    /// The published cumulative share of the column's whole population at or
    /// below this row's level, abstainers included — the number on the page.
    public func percentPublished(in column: Column) -> Double {
      switch column {
      case .allAdults: percentAllAdults
      case .men: percentMen
      case .women: percentWomen
      }
    }

    /// The same share renormalized to the column's drinkers — the app-side
    /// derivation, stated in the file and pinned row by row in tests.
    public func percentDrinkers(in column: Column) -> Double {
      switch column {
      case .allAdults: percentDrinkers
      case .men: percentMenDrinkers
      case .women: percentWomenDrinkers
      }
    }
  }

  public let source: String
  public let sourceURL: String
  public let year: Int
  public let population: String
  public let derivation: String
  public let gramsPerSurveyDrink: Double
  public let abstainersPercentAllAdults: Double
  public let abstainersPercentMen: Double
  public let abstainersPercentWomen: Double
  public let rows: [Row]

  /// The published abstainer share of a column — what its renormalization
  /// divides out.
  public func abstainersPercent(in column: Column) -> Double {
    switch column {
    case .allAdults: abstainersPercentAllAdults
    case .men: abstainersPercentMen
    case .women: abstainersPercentWomen
    }
  }

  /// The share of the column who reported drinking — the note's "72%" for
  /// the total, 75 for men, 69 for women. Whole numbers on the page, so a
  /// caller may print them as they are.
  public func drinkersPercent(in column: Column) -> Double {
    100 - abstainersPercent(in: column)
  }

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
      let abstainers_percent_men: Double
      let abstainers_percent_women: Double
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
    self.abstainersPercentMen = file.abstainers_percent_men
    self.abstainersPercentWomen = file.abstainers_percent_women
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

  /// The comparison against the table's Total column — every reader's
  /// default, and what every caller read before the columns were bundled.
  public func comparison(gramsPerWeek: Double) -> Comparison? {
    comparison(gramsPerWeek: gramsPerWeek, in: .allAdults)
  }

  /// The comparison against one of the survey's columns, by the same bracket
  /// rule whichever column it is: the level is found once, and only the
  /// percentage read from the row changes.
  public func comparison(gramsPerWeek: Double, in column: Column) -> Comparison? {
    // Non-finite input has no bracket, and it must not get any further: a
    // size field or a Shortcuts variable can deliver infinity, and this
    // function used to convert it to an Int, which traps — on every open of
    // Trends, until the row was deleted.
    guard gramsPerWeek.isFinite, gramsPerWeek > 0 else { return nil }
    let surveyDrinks = gramsPerWeek / gramsPerSurveyDrink
    // The 0.005-drink shave (0.07 g of ethanol a week) keeps an
    // exactly-N-drink average at level N: regional grams are derived values
    // (a US drink computes to 14.0001 g, 7.8 ppm high), and without the
    // shave that drift compounds with volume and the ceiling bumps exact
    // averages into the next bracket.
    //
    // Kept as a Double until a row is chosen: an absurd but finite volume
    // exceeds Int.max long before it exceeds the table, and the open-ended
    // top row already covers everything above the last bound.
    let level = max(1, (surveyDrinks - 0.005).rounded(.up))

    // Smallest row whose upper bound covers the level; the open-ended top
    // row covers everything above the table.
    let row = rows.first { row in
      guard let max = row.drinksMax else { return true }
      return level <= Double(max)
    }
    guard let row else { return nil }

    let percentAtOrBelow = row.percentDrinkers(in: column)
    let percentMore = 100 - percentAtOrBelow
    let roundedToFive = Int((percentMore / 5).rounded() * 5)
    guard roundedToFive >= 5 else {
      // Almost nobody drinks more; say the true direction instead.
      let floored = Int((percentAtOrBelow / 5).rounded(.down) * 5)
      return .moreThan(percent: min(floored, 95))
    }
    return .lowerThan(percent: roundedToFive)
  }
}
