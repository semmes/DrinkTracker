import Foundation

/// The bundled frequency reference (ADR-0031): how many days a year US
/// adults who drink have a drink on, from NESARC-III — a published mean, so
/// the 1.2 spec's second shape: the sentence states the two numbers and
/// never a percentile. A static JSON resource, never a network call; the
/// derivation is in the file and shown to the user.
///
/// A descriptive statistic, deliberately: it is a count of days, not a
/// threshold, and the user's own figure beside it is the calendar's "days
/// with drinks" over the same window (spec constraint 5).
public struct FrequencyReference: Sendable {
  public let source: String
  public let sourceURL: String
  public let year: Int
  public let population: String
  public let derivation: String
  /// Mean days with any alcohol in a year, among adults who drank in the year.
  public let drinkingDaysPerYear: Double

  public static let bundled: FrequencyReference? = {
    guard let url = Bundle.module.url(forResource: "us-frequency-reference", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? FrequencyReference(data: data)
  }()

  public init(data: Data) throws {
    struct File: Codable {
      let source: String
      let source_url: String
      let year: Int
      let population: String
      let derivation: String
      let drinking_days_per_year: Double
    }
    let file = try JSONDecoder().decode(File.self, from: data)
    self.source = file.source
    self.sourceURL = file.source_url
    self.year = file.year
    self.population = file.population
    self.derivation = file.derivation
    self.drinkingDaysPerYear = file.drinking_days_per_year
  }

  /// The mean scaled to a window of `days`: 87.9 a year is about 1.7 in 7
  /// days, 7.2 in 30 and 21.2 in 88. Callers round for display. The reader's
  /// own figure beside it is the Trends header's days with drinks over the same
  /// window (`TrendWindowFold.summary`, ADR-0058).
  public func drinkingDays(per days: Int) -> Double {
    drinkingDaysPerYear * Double(days) / 365
  }
}
