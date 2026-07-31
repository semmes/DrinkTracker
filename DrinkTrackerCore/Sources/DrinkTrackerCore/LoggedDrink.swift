import Foundation

/// A single logged drink, as a plain value.
///
/// This is the type the domain layer computes over. Persistence lives in the app
/// target as a SwiftData `@Model` class that maps to and from this struct, which
/// keeps the standard-drink math and trend aggregation free of any store and
/// directly unit-testable.
public struct LoggedDrink: Identifiable, Hashable, Sendable {
  public var id: UUID
  public var loggedAt: Date
  public var type: DrinkType
  public var volumeOunces: Double
  public var abvPercent: Double
  /// The region definition in effect when this drink was logged, so historical
  /// totals don't shift if the user later changes the setting.
  public var region: Region
  /// UUID of the HealthKit sample written for this drink, if any.
  public var healthKitSampleID: UUID?

  public init(
    id: UUID = UUID(),
    loggedAt: Date = Date(),
    type: DrinkType,
    volumeOunces: Double,
    abvPercent: Double,
    region: Region = .unitedStates,
    healthKitSampleID: UUID? = nil
  ) {
    self.id = id
    self.loggedAt = loggedAt
    self.type = type
    self.volumeOunces = volumeOunces
    self.abvPercent = abvPercent
    self.region = region
    self.healthKitSampleID = healthKitSampleID
  }

  /// This drink's contribution to the daily total.
  public var standardDrinks: Double {
    StandardDrink.count(volumeOunces: volumeOunces, abvPercent: abvPercent, region: region)
  }

  /// Grams of pure ethanol, which is what gets written to HealthKit alongside
  /// the beverage count.
  public var gramsOfAlcohol: Double {
    StandardDrink.gramsOfAlcohol(volumeOunces: volumeOunces, abvPercent: abvPercent)
  }

  /// The "last logged" line under the Today metric, e.g. "Beer, 12oz, 5% ABV".
  public var summaryLine: String {
    "\(type.displayName), \(Self.format(volumeOunces))oz, \(Self.format(abvPercent))% ABV"
  }

  static func format(_ value: Double) -> String {
    value == value.rounded()
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
  }
}
