import SwiftData

/// The schema, versioned — the migration plan every store-opening site goes
/// through (PRD Iteration 3: "a `VersionedSchema` and a migration test belong
/// in Iteration 3 at the latest").
///
/// `AlcoholFreeDay` was added after stores already existed in the wild, and
/// SwiftData's lightweight migration absorbed it because the change was
/// additive. Nothing pinned that. This file is the pin: the current shape is
/// version 1.0.0, opening always passes `DrinkTrackerMigrationPlan`, and the
/// tier-2 tests in `SchemaMigrationTests` hold both facts in place — an
/// unversioned store from any shipped build must reopen intact under the
/// plan, and a model change without a version bump fails a test instead of
/// shipping as an accident.
///
/// ## Adding version 2 (the recipe, written down while it is cheap)
///
/// 1. **Additive change** (new optional property, new model): CloudKit
///    mirroring only supports lightweight migration, so the change must stay
///    additive regardless — every property with a default or optional, no
///    `.unique`, no renames (`DrinkEntry` documents the constraints). Move
///    nothing. Add `DrinkTrackerSchemaV2` listing the models, append it to
///    `schemas`, add `MigrationStage.lightweight(fromVersion:toVersion:)` to
///    `stages`, point `CurrentSchema` at V2, and update the pinned attribute
///    lists in `SchemaMigrationTests` in the same commit.
/// 2. **Shape change** (rename, retype, delete): both versions of the class
///    must exist at once, so first move today's definitions into an
///    `extension DrinkTrackerSchemaV1 { … }` namespace with top-level
///    `typealias`es keeping call sites compiling, then write the V2 classes
///    and a `.custom` stage. **Stop first**: the store mirrors to CloudKit,
///    which cannot migrate deployed record types — a non-additive change
///    likely needs a new CloudKit schema strategy and its own ADR before any
///    code.
///
/// Either way: the migration test that proves an old store survives is part
/// of the change, not a follow-up (PRD invariant discipline, §4 tier 2).
enum DrinkTrackerSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  /// The two models as they shipped in v1.0 and v1.1. Top-level classes, not
  /// namespaced copies: while exactly one version exists, the live classes
  /// *are* version 1, and namespacing would only add a rename with CloudKit
  /// production stores on the other side of it. The recipe above moves them
  /// when — and only when — a shape change forces two versions to coexist.
  static var models: [any PersistentModel.Type] {
    [DrinkEntry.self, AlcoholFreeDay.self]
  }
}

/// The version the running app targets. Bump alongside a new schema version.
typealias CurrentSchema = DrinkTrackerSchemaV1

/// One plan, no stages yet.
///
/// Empty `stages` is a statement, not a stub: every store ever shipped is
/// already at V1, so there is nothing to migrate *from*. The value of wiring
/// the plan in now is that the next schema change starts from "add a stage
/// and a test" rather than "retrofit versioning onto live stores".
enum DrinkTrackerMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [DrinkTrackerSchemaV1.self]
  }

  static var stages: [MigrationStage] { [] }
}
