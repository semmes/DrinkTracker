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
  /// The region in effect when this drink was logged.
  ///
  /// Provenance only — it is deliberately *not* used to compute totals. Volume and
  /// ABV are the physical facts; a region is just the unit those facts get
  /// expressed in, so totals are always computed in one consistent region chosen by
  /// the caller. Summing entries by their own stored regions would add UK units to
  /// US standard drinks, which is meaningless.
  public var region: Region
  /// UUID of the HealthKit sample behind this drink, if any: one the app wrote
  /// for its own entry, or — when `countedDrinks` is set — another app's sample
  /// this entry mirrors.
  public var healthKitSampleID: UUID?
  /// Non-nil for drinks imported from Apple Health that another app recorded.
  ///
  /// External samples carry only a count and a time — no volume, no ABV — so an
  /// imported drink cannot honestly join the gram math. Instead it *is* its
  /// count: `standardDrinks(in:)` returns this value in every region, because
  /// "a drink" from an unknown source is one drink under any lens, and any
  /// conversion would be invented precision (ADR-0014).
  public var countedDrinks: Double?

  /// True for entries mirrored from another app's Health data.
  public var isImportedFromHealth: Bool { countedDrinks != nil }

  public init(
    id: UUID = UUID(),
    loggedAt: Date = Date(),
    type: DrinkType,
    volumeOunces: Double,
    abvPercent: Double,
    region: Region = .unitedStates,
    healthKitSampleID: UUID? = nil,
    countedDrinks: Double? = nil
  ) {
    self.id = id
    self.loggedAt = loggedAt
    self.type = type
    self.volumeOunces = volumeOunces
    self.abvPercent = abvPercent
    self.region = region
    self.healthKitSampleID = healthKitSampleID
    self.countedDrinks = countedDrinks
  }

  /// An entry mirroring `count` beverages another app recorded in Health.
  ///
  /// Type is `.other` with zero volume and strength — the physical facts are
  /// unknown, and zero says so louder than a plausible-looking default would.
  public static func importedFromHealth(
    sampleID: UUID,
    count: Double,
    loggedAt: Date
  ) -> LoggedDrink {
    LoggedDrink(
      loggedAt: loggedAt,
      type: .other,
      volumeOunces: 0,
      abvPercent: 0,
      healthKitSampleID: sampleID,
      countedDrinks: max(0, count)
    )
  }

  /// This drink's contribution to a daily total, expressed in `region`'s units.
  ///
  /// Callers pass the user's *current* region, not `self.region`, so changing the
  /// setting re-expresses the whole history in the new unit rather than leaving a
  /// pile of mixed, unaddable numbers. Imported drinks are the one exception to
  /// re-expression: their count is the whole fact, so it is the same number under
  /// every lens.
  public func standardDrinks(in region: Region) -> Double {
    if let countedDrinks { return countedDrinks }
    return StandardDrink.count(volumeOunces: volumeOunces, abvPercent: abvPercent, region: region)
  }

  /// Grams of pure ethanol, which is what gets written to HealthKit alongside
  /// the beverage count.
  public var gramsOfAlcohol: Double {
    StandardDrink.gramsOfAlcohol(volumeOunces: volumeOunces, abvPercent: abvPercent)
  }

  /// The "last logged" line under the Today metric, e.g. "Beer, 12oz, 5% ABV".
  public var summaryLine: String {
    if let countedDrinks {
      let count = Self.format(countedDrinks)
      return countedDrinks == 1
        ? "From Apple Health, 1 drink"
        : "From Apple Health, \(count) drinks"
    }
    return "\(type.displayName), \(Self.format(volumeOunces))oz, \(Self.format(abvPercent))% ABV"
  }

  static func format(_ value: Double) -> String {
    value == value.rounded()
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
  }
}
