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
  /// Non-nil for entries mirrored from another app's Health data (ADR-0014).
  /// For those rows `healthKitSampleID` is the *external* sample's UUID.
  /// Optional with no default constraint change — an additive field, which is
  /// the only schema evolution CloudKit mirrors without a migration plan.
  var countedDrinks: Double?

  init(_ drink: LoggedDrink) {
    self.entryID = drink.id
    self.loggedAt = drink.loggedAt
    self.typeRawValue = drink.type.rawValue
    self.volumeOunces = drink.volumeOunces
    self.abvPercent = drink.abvPercent
    self.regionRawValue = drink.region.rawValue
    self.healthKitSampleID = drink.healthKitSampleID
    self.countedDrinks = drink.countedDrinks
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
      healthKitSampleID: healthKitSampleID,
      countedDrinks: countedDrinks
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
    countedDrinks = drink.countedDrinks
  }
}

extension Array where Element == DrinkEntry {
  /// Convenience for handing a `@Query` result to the pure domain layer.
  var loggedDrinks: [LoggedDrink] { map(\.logged) }
}

// MARK: - Alcohol-free days

/// A day recorded as having no alcohol.
///
/// This exists because "no entries" and "no alcohol" are different facts, and the
/// calendar has to tell them apart. Every day before the app was installed has no
/// entries; treating that as abstinence would have the year view claim a history
/// that never happened. Only an explicit marker can say "I was here, and there was
/// nothing to log."
///
/// The person who said it is usually the user, in this app. Since ADR-0025 it can
/// also be the user in *another* app: a `numberOfAlcoholicBeverages` sample whose
/// value is zero is that app's way of recording the same fact, and it mirrors
/// here as a marker carrying the sample's id — read-only in Tallyist, like every
/// other Health mirror, and removed again when the sample is (ADR-0014).
///
/// Shaped for CloudKit like `DrinkEntry`: a default value on every stored property
/// and no `@Attribute(.unique)`. Uniqueness per day is enforced by the repository
/// instead — see `DrinkRepository.markAlcoholFree`.
@Model
final class AlcoholFreeDay {
  /// Start of the day, in the calendar in force when it was recorded.
  var day: Date = Date()
  var recordedAt: Date = Date()
  /// Non-nil for markers mirrored from another app's zero-count Health sample
  /// (ADR-0025): the *external* sample's UUID, which is the dedup key and what
  /// deletion sync matches on. Optional and additive — schema version 2, the
  /// same kind of change `countedDrinks` was (see `SchemaVersions.swift`).
  var healthKitSampleID: UUID?

  init(day: Date, recordedAt: Date = Date(), healthKitSampleID: UUID? = nil) {
    self.day = day
    self.recordedAt = recordedAt
    self.healthKitSampleID = healthKitSampleID
  }

  /// Whether another app's Health record is what put this marker here. Such a
  /// marker is disclosed as "From Apple Health" and offers no remove control:
  /// HealthKit will not let this app delete another app's sample, so a
  /// Tallyist-side removal could never propagate (ADR-0014's rule, inherited).
  var isImportedFromHealth: Bool { healthKitSampleID != nil }
}
