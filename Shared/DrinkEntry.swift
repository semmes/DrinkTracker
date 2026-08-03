import DrinkTrackerCore
import Foundation
import SwiftData

/// SwiftData persistence shell around `LoggedDrink`.
///
/// Shaped for CloudKit mirroring: every stored property has a default value and
/// nothing is marked `@Attribute(.unique)`, both of which CloudKit requires. The
/// enums are stored as their raw strings so adding a case later can't fail to
/// decode existing records.
@Model
final class DrinkEntry {
  var entryID: UUID = UUID()
  var loggedAt: Date = Date()
  var typeRawValue: String = DrinkType.beer.rawValue
  var volumeOunces: Double = 12
  var abvPercent: Double = 5
  var regionRawValue: String = Region.unitedStates.rawValue
  var healthKitSampleID: UUID?

  init(_ drink: LoggedDrink) {
    self.entryID = drink.id
    self.loggedAt = drink.loggedAt
    self.typeRawValue = drink.type.rawValue
    self.volumeOunces = drink.volumeOunces
    self.abvPercent = drink.abvPercent
    self.regionRawValue = drink.region.rawValue
    self.healthKitSampleID = drink.healthKitSampleID
  }

  /// Projects the stored row back into the domain value the app computes over.
  var logged: LoggedDrink {
    LoggedDrink(
      id: entryID,
      loggedAt: loggedAt,
      type: DrinkType(rawValue: typeRawValue) ?? .other,
      volumeOunces: volumeOunces,
      abvPercent: abvPercent,
      region: Region(rawValue: regionRawValue) ?? .unitedStates,
      healthKitSampleID: healthKitSampleID
    )
  }

  /// Overwrites this row in place, used by the edit-after path so a correction
  /// replaces the original rather than adding a second entry.
  func apply(_ drink: LoggedDrink) {
    loggedAt = drink.loggedAt
    typeRawValue = drink.type.rawValue
    volumeOunces = drink.volumeOunces
    abvPercent = drink.abvPercent
    regionRawValue = drink.region.rawValue
    healthKitSampleID = drink.healthKitSampleID
  }
}

extension Array where Element == DrinkEntry {
  /// Convenience for handing a `@Query` result to the pure domain layer.
  var loggedDrinks: [LoggedDrink] { map(\.logged) }
}

// MARK: - Alcohol-free days

/// A day the user recorded as having no alcohol.
///
/// This exists because "no entries" and "no alcohol" are different facts, and the
/// calendar has to tell them apart. Every day before the app was installed has no
/// entries; treating that as abstinence would have the year view claim a history
/// that never happened. Only an explicit marker can say "I was here, and there was
/// nothing to log."
///
/// Shaped for CloudKit like `DrinkEntry`: a default value on every stored property
/// and no `@Attribute(.unique)`. Uniqueness per day is enforced by the repository
/// instead — see `DrinkRepository.markAlcoholFree`.
@Model
final class AlcoholFreeDay {
  /// Start of the day, in the calendar in force when it was recorded.
  var day: Date = Date()
  var recordedAt: Date = Date()

  init(day: Date, recordedAt: Date = Date()) {
    self.day = day
    self.recordedAt = recordedAt
  }
}
