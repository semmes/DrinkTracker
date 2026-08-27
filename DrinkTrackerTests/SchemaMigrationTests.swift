import DrinkTrackerCore
import Foundation
import SwiftData
import Testing

/// Pins the schema version story (see `Shared/SchemaVersions.swift`).
///
/// Two things are load-bearing here. First, every store in the wild was
/// created *without* a versioned schema, so adopting one must be
/// identity-preserving — an existing store has to reopen under the migration
/// plan with its rows intact, or the upgrade bricks real logs. Second, the
/// schema's exact shape is pinned attribute by attribute: a model change that
/// skips the versioning recipe now fails here instead of shipping as an
/// accidental lightweight migration, which is precisely the gap the PRD
/// flagged ("nothing pins that").
@Suite("Schema versioning")
struct SchemaMigrationTests {

  // MARK: - Upgrade path

  @Test("A store created before versioning reopens intact under the migration plan")
  func unversionedStoreSurvivesAdoption() throws {
    let storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("migration-test-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("store.sqlite")
    try FileManager.default.createDirectory(
      at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

    let drinkID = UUID()
    let day = Calendar.current.startOfDay(for: Date())

    // Open the way every shipped build did: a bare Schema, no version, no plan —
    // scoped so the container is released before the second open.
    do {
      let legacySchema = Schema([DrinkEntry.self, AlcoholFreeDay.self])
      let container = try ModelContainer(
        for: legacySchema,
        configurations: ModelConfiguration(schema: legacySchema, url: storeURL)
      )
      let context = ModelContext(container)
      context.insert(
        DrinkEntry(
          LoggedDrink(id: drinkID, type: .beer, volumeOunces: 12, abvPercent: 5)
        )
      )
      context.insert(AlcoholFreeDay(day: day))
      try context.save()
    }

    // Reopen the same file the way the app opens stores from now on.
    let container = try ModelContainer(
      for: SharedModelContainer.schema,
      migrationPlan: DrinkTrackerMigrationPlan.self,
      configurations: ModelConfiguration(schema: SharedModelContainer.schema, url: storeURL)
    )
    let context = ModelContext(container)

    let drinks = try context.fetch(FetchDescriptor<DrinkEntry>())
    let freeDays = try context.fetch(FetchDescriptor<AlcoholFreeDay>())
    #expect(drinks.count == 1)
    #expect(drinks.first?.entryID == drinkID)
    // The stored physical facts, byte-exact — derived math is tier 1's job.
    #expect(drinks.first?.volumeOunces == 12)
    #expect(drinks.first?.abvPercent == 5)
    #expect(drinks.first?.typeRawValue == DrinkType.beer.rawValue)
    #expect(freeDays.count == 1)
    #expect(freeDays.first?.day == day)
  }

  @Test("The in-memory last resort opens under the plan too")
  func inMemoryOpensUnderPlan() throws {
    // The app's catch-all rung (DrinkTrackerApp.init) uses exactly this shape.
    let container = try ModelContainer(
      for: SharedModelContainer.schema,
      migrationPlan: DrinkTrackerMigrationPlan.self,
      configurations: ModelConfiguration(
        schema: SharedModelContainer.schema,
        isStoredInMemoryOnly: true
      )
    )
    let context = ModelContext(container)
    context.insert(DrinkEntry(LoggedDrink(type: .wine, volumeOunces: 5, abvPercent: 12)))
    try context.save()
    #expect(try context.fetch(FetchDescriptor<DrinkEntry>()).count == 1)
  }

  // MARK: - Version pins

  @Test("The current version is 1.0.0 with no migration stages")
  func versionOneNoStages() {
    #expect(CurrentSchema.self == DrinkTrackerSchemaV1.self)
    #expect(DrinkTrackerSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    #expect(DrinkTrackerMigrationPlan.schemas.count == 1)
    #expect(DrinkTrackerMigrationPlan.schemas.first == DrinkTrackerSchemaV1.self)
    // Every shipped store is already V1; a stage appearing here must arrive
    // with a new schema version and its own upgrade-path test.
    #expect(DrinkTrackerMigrationPlan.stages.isEmpty)
  }

  @Test("The shared schema is the versioned schema, not a parallel list")
  func sharedSchemaMatchesVersioned() {
    let shared = Set(SharedModelContainer.schema.entities.map(\.name))
    let versioned = Set(Schema(versionedSchema: CurrentSchema.self).entities.map(\.name))
    #expect(shared == versioned)
  }

  /// The drift alarm. Adding, renaming, or removing a stored property lands
  /// here first: update the pin **and** follow the recipe in
  /// `SchemaVersions.swift` (new version, stage, migration test) in the same
  /// commit — never by editing this list alone.
  @Test("V1's exact shape is pinned, attribute by attribute")
  func schemaShapeIsPinned() throws {
    let entities = Dictionary(
      uniqueKeysWithValues: SharedModelContainer.schema.entities.map { ($0.name, $0) }
    )
    #expect(Set(entities.keys) == ["DrinkEntry", "AlcoholFreeDay"])

    let drinkEntry = try #require(entities["DrinkEntry"])
    #expect(
      Set(drinkEntry.attributes.map(\.name)) == [
        "entryID", "loggedAt", "typeRawValue", "volumeOunces",
        "abvPercent", "regionRawValue", "healthKitSampleID", "countedDrinks",
      ]
    )
    #expect(drinkEntry.relationships.isEmpty)

    let alcoholFreeDay = try #require(entities["AlcoholFreeDay"])
    #expect(Set(alcoholFreeDay.attributes.map(\.name)) == ["day", "recordedAt"])
    #expect(alcoholFreeDay.relationships.isEmpty)

    // CloudKit constraints, pinned as facts rather than remembered as lore:
    // no attribute may be unique, and every non-optional needs a default
    // (the @Model defaults satisfy this; uniqueness we can assert directly).
    for entity in entities.values {
      for attribute in entity.attributes {
        #expect(!attribute.isUnique, "\(entity.name).\(attribute.name) is unique — CloudKit mirroring forbids this")
      }
    }
  }
}
