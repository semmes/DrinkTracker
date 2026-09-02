import DrinkTrackerCore
import Foundation
import SwiftData
import Testing

/// Pins the schema version story (see `Shared/SchemaVersions.swift`).
///
/// Two things are load-bearing here. First, every store in the wild is
/// V1-shaped — created either without a versioned schema at all (v1.0, v1.1)
/// or stamped 1.0.0 by an early 1.2 build — so the upgrade to V2 must be
/// identity-preserving: each kind of store has to reopen under the migration
/// plan with its rows intact, or the upgrade bricks real logs. Second, the
/// schema's exact shape is pinned attribute by attribute: a model change that
/// skips the versioning recipe now fails here instead of shipping as an
/// accidental lightweight migration, which is precisely the gap the PRD
/// flagged ("nothing pins that").
///
/// ## The fixtures
///
/// `Fixtures/v1-unversioned.sqlite` and `Fixtures/v1-stamped.sqlite` are real
/// store files, written by the code on `main` at f7b6581 (the last V1 commit)
/// through the same two open paths shipped builds used — a bare `Schema` with
/// no plan, and the V1 plan. A bare `Schema` stamps a store 1.0.0 as well,
/// so their model metadata is byte-identical and the second test is
/// belt-and-braces over the two writer paths, not a second store shape. Each
/// holds one beer, one imported drink, and one alcohol-free day, with fixed
/// ids and UTC dates. They are files rather than
/// stores the test builds from the frozen V1 classes because SwiftData keeps
/// one process-wide notion of what "AlcoholFreeDay" is: two containers with
/// different shapes of the same entity alive at once — which is what
/// building a V1 store while other suites run V2 in-memory stores amounts to
/// — crashed the run with `setValue:forUndefinedKey:`. Nothing in the app
/// ever does that (the plan uses V1 inside one container's opening, alone),
/// so the tests must not either.
///
/// When version 3 arrives, write its fixtures the same way from the last V2
/// commit; do not regenerate these.
@Suite("Schema versioning")
struct SchemaMigrationTests {

  private final class BundleAnchor {}

  /// Fixed facts the fixtures were written with.
  private enum Fixture {
    static let drinkID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let importedSampleID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static var utc: Calendar {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(identifier: "UTC")!
      return calendar
    }
    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
      utc.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
    static let markedDay = date(2026, 8, 23)
  }

  /// A private, writable copy of a fixture — migration happens to a file, and
  /// the bundle's copy must stay exactly what a shipped build wrote.
  private func copyOfFixture(_ name: String) throws -> URL {
    let source = try #require(
      Bundle(for: BundleAnchor.self).url(forResource: name, withExtension: "sqlite"),
      "fixture \(name).sqlite is not in the test bundle"
    )
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("migration-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = directory.appendingPathComponent("store.sqlite")
    try FileManager.default.copyItem(at: source, to: destination)
    return destination
  }

  /// Opens the copied store the way the app opens stores from now on, and
  /// checks the V1 rows came through the lightweight stage intact.
  private func assertUpgraded(_ storeURL: URL) throws {
    defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
    let container = try ModelContainer(
      for: SharedModelContainer.schema,
      migrationPlan: DrinkTrackerMigrationPlan.self,
      configurations: ModelConfiguration(schema: SharedModelContainer.schema, url: storeURL)
    )
    let context = ModelContext(container)

    let drinks = try context.fetch(FetchDescriptor<DrinkEntry>())
    #expect(drinks.count == 2)
    let beer = try #require(drinks.first { $0.entryID == Fixture.drinkID })
    // The stored physical facts, byte-exact — derived math is tier 1's job.
    #expect(beer.loggedAt == Fixture.date(2026, 8, 24, 20))
    #expect(beer.typeRawValue == DrinkType.beer.rawValue)
    #expect(beer.volumeOunces == 12)
    #expect(beer.abvPercent == 5)
    #expect(beer.countedDrinks == nil)
    let imported = try #require(drinks.first { $0.healthKitSampleID == Fixture.importedSampleID })
    #expect(imported.countedDrinks == 2)
    #expect(imported.loggedAt == Fixture.date(2026, 8, 25, 21))

    let markers = try context.fetch(FetchDescriptor<AlcoholFreeDay>())
    #expect(markers.count == 1)
    #expect(markers.first?.day == Fixture.markedDay)
    #expect(markers.first?.recordedAt == Fixture.date(2026, 8, 23, 22))
    // The added column arrives empty, which is what "recorded here" means.
    #expect(markers.first?.healthKitSampleID == nil)
    #expect(markers.first?.isImportedFromHealth == false)

    // And the migrated store takes the new shape: a marker with provenance
    // writes and reads back through the same file.
    let sampleID = UUID()
    context.insert(AlcoholFreeDay(day: Fixture.date(2026, 8, 26), healthKitSampleID: sampleID))
    try context.save()
    let mirrored = try context.fetch(FetchDescriptor<AlcoholFreeDay>())
      .first { $0.healthKitSampleID != nil }
    #expect(mirrored?.healthKitSampleID == sampleID)
    #expect(mirrored?.day == Fixture.date(2026, 8, 26))
  }

  // MARK: - Upgrade paths

  @Test("A store v1.0 and v1.1 wrote — bare Schema, no plan, stamped 1.0.0 all the same — reopens intact under the plan")
  func unversionedStoreMigrates() throws {
    try assertUpgraded(try copyOfFixture("v1-unversioned"))
  }

  @Test("A store stamped 1.0.0 migrates to 2.0.0 through the lightweight stage")
  func versionOneStoreMigrates() throws {
    try assertUpgraded(try copyOfFixture("v1-stamped"))
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

  @Test("The current version is 2.0.0, reached from 1.0.0 by one lightweight stage")
  func versionTwoOneStage() {
    #expect(CurrentSchema.self == DrinkTrackerSchemaV2.self)
    #expect(DrinkTrackerSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    #expect(DrinkTrackerSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
    #expect(DrinkTrackerMigrationPlan.schemas.count == 2)
    #expect(DrinkTrackerMigrationPlan.schemas.first == DrinkTrackerSchemaV1.self)
    #expect(DrinkTrackerMigrationPlan.schemas.last == DrinkTrackerSchemaV2.self)
    // One stage per step. A third version arrives with its own stage and
    // its own upgrade-path fixtures, never by editing this count.
    #expect(DrinkTrackerMigrationPlan.stages.count == 1)
  }

  @Test("The shared schema is the versioned schema, not a parallel list")
  func sharedSchemaMatchesVersioned() {
    let shared = Set(SharedModelContainer.schema.entities.map(\.name))
    let versioned = Set(Schema(versionedSchema: CurrentSchema.self).entities.map(\.name))
    #expect(shared == versioned)
  }

  /// The nesting-is-safe proof the recipe relies on: an entity is named by
  /// its class's simple name, so the frozen V1 copies and the live classes
  /// are the same two entities — and the same two CloudKit record types.
  @Test("The frozen V1 models are the same entities as the live ones")
  func frozenModelsShareEntityNames() {
    let v1 = Set(Schema(versionedSchema: DrinkTrackerSchemaV1.self).entities.map(\.name))
    #expect(v1 == ["DrinkEntry", "AlcoholFreeDay"])
  }

  /// The drift alarm. Adding, renaming, or removing a stored property lands
  /// here first: update the pin **and** follow the recipe in
  /// `SchemaVersions.swift` (new version, stage, fixtures) in the same
  /// commit — never by editing this list alone.
  @Test("V2's exact shape is pinned, attribute by attribute")
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
    #expect(
      Set(alcoholFreeDay.attributes.map(\.name)) == ["day", "recordedAt", "healthKitSampleID"]
    )
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

  /// V1 is history and must stay exactly what shipped: the plan recognises a
  /// store by this shape, and a "tidy-up" of the frozen copy would make every
  /// real store unrecognisable. Schema only — the classes are never
  /// instantiated here (see the suite comment).
  @Test("V1's frozen shape is pinned too")
  func frozenShapeIsPinned() throws {
    let entities = Dictionary(
      uniqueKeysWithValues: Schema(versionedSchema: DrinkTrackerSchemaV1.self).entities
        .map { ($0.name, $0) }
    )
    let drinkEntry = try #require(entities["DrinkEntry"])
    #expect(
      Set(drinkEntry.attributes.map(\.name)) == [
        "entryID", "loggedAt", "typeRawValue", "volumeOunces",
        "abvPercent", "regionRawValue", "healthKitSampleID", "countedDrinks",
      ]
    )
    let alcoholFreeDay = try #require(entities["AlcoholFreeDay"])
    #expect(Set(alcoholFreeDay.attributes.map(\.name)) == ["day", "recordedAt"])
  }
}
