import Foundation
import SwiftData

/// The schema, versioned — the migration plan every store-opening site goes
/// through (PRD Iteration 3: "a `VersionedSchema` and a migration test belong
/// in Iteration 3 at the latest").
///
/// `AlcoholFreeDay` was added after stores already existed in the wild, and
/// SwiftData's lightweight migration absorbed it because the change was
/// additive. Nothing pinned that. This file is the pin: every shape the app
/// has ever written is a version here, opening always passes
/// `DrinkTrackerMigrationPlan`, and the tier-2 tests in `SchemaMigrationTests`
/// hold the story in place — a store of any shipped shape must reopen intact
/// under the plan, and a model change without a version bump fails a test
/// instead of shipping as an accident.
///
/// ## The versions
///
/// - **1.0.0** — `DrinkEntry` and `AlcoholFreeDay` as v1.0 and v1.1 wrote
///   them. Frozen below as nested copies with stored properties only;
///   neither the app nor the tests instantiate them (two shapes of one
///   entity alive in one process crashed the test run — the suite comment
///   in `SchemaMigrationTests` has the story). They exist so the plan and
///   the pin tests can recognise a store of that shape.
/// - **2.0.0** — the live classes. `AlcoholFreeDay` gains the optional
///   `healthKitSampleID` (ADR-0025). Lightweight stage from 1.0.0.
///
/// ## Adding version 3 (the recipe)
///
/// 1. **Additive change** (new optional property, new model): CloudKit
///    mirroring only supports lightweight migration, so the change must stay
///    additive regardless — every property with a default or optional, no
///    `.unique`, no renames (`DrinkEntry` documents the constraints). Freeze
///    the outgoing shape: copy today's live classes into a new
///    `extension DrinkTrackerSchemaV2 { … }` namespace as stored-property-only
///    `@Model`s (the way V1 is below), make the change on the live top-level
///    classes, add `DrinkTrackerSchemaV3` listing them, append it to
///    `schemas`, add `MigrationStage.lightweight(fromVersion:toVersion:)` to
///    `stages`, point `CurrentSchema` at V3, and update the pinned attribute
///    lists and the upgrade-path tests in `SchemaMigrationTests` in the same
///    commit — with new fixture files in `DrinkTrackerTests/Fixtures/`
///    written by the *last V2 commit* through each open path (a worktree of
///    that commit, a throwaway test that writes the store, then
///    `PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE;` so the
///    file stands alone), never a store built from the frozen classes.
///    **Nesting is safe**: an entity's name is the class's simple name, so
///    `DrinkTrackerSchemaV1.AlcoholFreeDay` and the live `AlcoholFreeDay` are
///    the same entity to SwiftData and the same record type to CloudKit
///    (the pin test asserts the names).
/// 2. **Shape change** (rename, retype, delete): the same freeze, then a
///    `.custom` stage. **Stop first**: the store mirrors to CloudKit, which
///    cannot migrate deployed record types — a non-additive change likely
///    needs a new CloudKit schema strategy and its own ADR before any code.
///
/// **CloudKit needs the new field too, and that is a console step.** The
/// Development environment learns a new attribute the first time a debug
/// build writes one; Production learns nothing on its own. Before the App
/// Store build that carries a new attribute goes out, deploy the schema
/// (CloudKit Console → the app's container → Schema → *Deploy Schema
/// Changes* to Production), or that build's records with the new field fail
/// to export and sync stalls — silently, as every CloudKit failure is. The
/// owner does this; it is recorded in CLAUDE.md as a release step.
///
/// Either way: the migration test that proves an old store survives is part
/// of the change, not a follow-up (PRD invariant discipline, §4 tier 2).
enum DrinkTrackerSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [DrinkEntry.self, AlcoholFreeDay.self]
  }

  /// `DrinkEntry` exactly as v1.0 and v1.1 stored it. Stored properties only —
  /// no domain projection, because nothing but a migration test ever reads
  /// one of these.
  @Model
  final class DrinkEntry {
    var entryID: UUID = UUID()
    var loggedAt: Date = Date()
    var typeRawValue: String = "beer"
    var volumeOunces: Double = 12
    var abvPercent: Double = 5
    var regionRawValue: String = "unitedStates"
    var healthKitSampleID: UUID?
    var countedDrinks: Double?

    init(
      entryID: UUID = UUID(),
      loggedAt: Date = Date(),
      typeRawValue: String = "beer",
      volumeOunces: Double = 12,
      abvPercent: Double = 5,
      regionRawValue: String = "unitedStates",
      healthKitSampleID: UUID? = nil,
      countedDrinks: Double? = nil
    ) {
      self.entryID = entryID
      self.loggedAt = loggedAt
      self.typeRawValue = typeRawValue
      self.volumeOunces = volumeOunces
      self.abvPercent = abvPercent
      self.regionRawValue = regionRawValue
      self.healthKitSampleID = healthKitSampleID
      self.countedDrinks = countedDrinks
    }
  }

  /// `AlcoholFreeDay` before ADR-0025: a day and when it was recorded, no
  /// provenance.
  @Model
  final class AlcoholFreeDay {
    var day: Date = Date()
    var recordedAt: Date = Date()

    init(day: Date, recordedAt: Date = Date()) {
      self.day = day
      self.recordedAt = recordedAt
    }
  }
}

/// The current shape: the live top-level classes in `DrinkEntry.swift`.
///
/// One change from V1 — `AlcoholFreeDay.healthKitSampleID`, optional, so a
/// V1 store migrates lightweight (the column is added as null, which is what
/// "recorded in this app" already means).
enum DrinkTrackerSchemaV2: VersionedSchema {
  static let versionIdentifier = Schema.Version(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    [DrinkEntry.self, AlcoholFreeDay.self]
  }
}

/// The version the running app targets. Bump alongside a new schema version.
typealias CurrentSchema = DrinkTrackerSchemaV2

/// One plan, one stage.
///
/// Every store ever shipped is V1-shaped and stamped 1.0.0 — a bare `Schema`
/// stamps that too, so a v1.0/v1.1 store and one written under the V1 plan
/// carry identical model metadata. One stage takes them to V2; the
/// upgrade-path tests reopen a fixture written through each open path.
enum DrinkTrackerMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [DrinkTrackerSchemaV1.self, DrinkTrackerSchemaV2.self]
  }

  static var stages: [MigrationStage] {
    [
      .lightweight(
        fromVersion: DrinkTrackerSchemaV1.self,
        toVersion: DrinkTrackerSchemaV2.self
      )
    ]
  }
}
