import DrinkTrackerCore
import Foundation
import SwiftData
import Testing

/// Tier 2 (docs/PRD.md §4) — the persistence layer, against an in-memory store.
///
/// These are the behaviours the domain tests can't reach: `DrinkTrackerCore` is
/// deliberately free of SwiftData, so anything about *rows* has to be tested here.
@Suite("Drink repository")
struct DrinkRepositoryTests {

  let context: ModelContext
  let repository: DrinkRepository

  /// Swift Testing builds a fresh instance per test, so each one gets its own
  /// empty store without any teardown.
  init() throws {
    // Built from the shared schema rather than a hand-listed model, so a model
    // added to the store but forgotten here fails loudly instead of quietly going
    // untested.
    let container = try ModelContainer(
      for: SharedModelContainer.schema,
      configurations: ModelConfiguration(
        schema: SharedModelContainer.schema,
        isStoredInMemoryOnly: true
      )
    )
    self.context = ModelContext(container)
    self.repository = DrinkRepository(context: context)
  }

  private func drink(
    id: UUID = UUID(),
    at date: Date = Date(),
    type: DrinkType = .beer,
    ounces: Double = 12,
    abv: Double = 5,
    region: Region = .unitedStates,
    sample: UUID? = nil
  ) -> LoggedDrink {
    LoggedDrink(
      id: id,
      loggedAt: date,
      type: type,
      volumeOunces: ounces,
      abvPercent: abv,
      region: region,
      healthKitSampleID: sample
    )
  }

  private func allEntries() throws -> [DrinkEntry] {
    try context.fetch(FetchDescriptor<DrinkEntry>())
  }

  // MARK: - Overwrite by id

  @Test("Saving a new drink inserts one entry")
  func savingInserts() throws {
    repository.save(drink())
    #expect(try allEntries().count == 1)
  }

  /// The single most load-bearing line in this type. `DrinkStore.save` routes every
  /// edit through here, so if this ever inserted instead of overwriting, correcting
  /// a drink would silently *double* its contribution to the daily total rather
  /// than replacing it.
  @Test("Saving the same id twice overwrites rather than duplicating")
  func savingSameIDOverwrites() throws {
    let id = UUID()
    repository.save(drink(id: id, ounces: 12))
    repository.save(drink(id: id, ounces: 16))

    let entries = try allEntries()
    #expect(entries.count == 1)
    #expect(entries.first?.volumeOunces == 16)
  }

  @Test("Overwriting replaces every field, not just the one that changed")
  func overwriteReplacesAllFields() throws {
    let id = UUID()
    let original = Date(timeIntervalSince1970: 1_000_000)
    let corrected = Date(timeIntervalSince1970: 2_000_000)

    repository.save(drink(id: id, at: original, type: .beer, ounces: 12, abv: 5))
    repository.save(drink(id: id, at: corrected, type: .wine, ounces: 5, abv: 12))

    let entry = try #require(try allEntries().first)
    #expect(entry.loggedAt == corrected)
    #expect(entry.typeRawValue == DrinkType.wine.rawValue)
    #expect(entry.volumeOunces == 5)
    #expect(entry.abvPercent == 12)
  }

  @Test("Different ids produce separate entries")
  func differentIDsInsertSeparately() throws {
    repository.save(drink())
    repository.save(drink())
    #expect(try allEntries().count == 2)
  }

  @Test("saveOrThrow surfaces success where save swallows it")
  func saveOrThrowSucceeds() throws {
    // The widget's intent uses the throwing form, because there a swallowed
    // failure looks exactly like a missed tap.
    try repository.saveOrThrow(drink())
    #expect(try allEntries().count == 1)
  }

  // MARK: - Deletion and undo

  @Test("Deleting by id removes only that entry")
  func deleteRemovesOne() throws {
    let keep = drink()
    let remove = drink()
    repository.save(keep)
    repository.save(remove)

    repository.delete(id: remove.id)

    let entries = try allEntries()
    #expect(entries.count == 1)
    #expect(entries.first?.entryID == keep.id)
  }

  @Test("Deleting an id that isn't there is a no-op")
  func deleteMissingIsNoOp() throws {
    repository.save(drink())
    repository.delete(id: UUID())
    #expect(try allEntries().count == 1)
  }

  /// The undo path. `DeletionCoordinator` re-saves the same `LoggedDrink`, and
  /// because save overwrites by id the entry comes back where it was — rather
  /// than reappearing as a new drink logged at the moment you hit undo.
  @Test("Re-saving a deleted drink restores its original id and timestamp")
  func undoRestoresInPlace() throws {
    let original = Date(timeIntervalSince1970: 1_700_000_000)
    let removed = drink(at: original, type: .wine, ounces: 5, abv: 12)

    repository.save(removed)
    repository.delete(id: removed.id)
    #expect(try allEntries().isEmpty)

    repository.save(removed)

    let entry = try #require(try allEntries().first)
    #expect(entry.entryID == removed.id)
    #expect(entry.loggedAt == original)
    #expect(entry.typeRawValue == DrinkType.wine.rawValue)
  }

  // MARK: - Day scoping

  @Test("Only the requested day's drinks come back")
  func drinksOnDayFiltersByDay() throws {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date()).addingTimeInterval(60 * 60 * 12)
    let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))

    repository.save(drink(at: today))
    repository.save(drink(at: today))
    repository.save(drink(at: yesterday))

    #expect(repository.drinks(on: today).count == 2)
    #expect(repository.drinks(on: yesterday).count == 1)
  }

  @Test("A drink at the very start of the day counts as that day")
  func startOfDayIsInclusive() throws {
    let start = Calendar.current.startOfDay(for: Date())
    repository.save(drink(at: start))
    #expect(repository.drinks(on: start).count == 1)
  }

  // MARK: - Totals

  /// Guards PRD invariant 3: region is a display lens. These entries were logged
  /// under UK units; the total still has to come back in whatever the caller asks
  /// for, or history stops being addable across a settings change.
  @Test("Totals use the caller's region, not the region stored on the entry")
  func totalIgnoresStoredRegion() throws {
    let day = Date()
    repository.save(drink(at: day, ounces: 12, abv: 5, region: .unitedKingdom))

    let asUS = repository.total(on: day, region: .unitedStates)
    let asUK = repository.total(on: day, region: .unitedKingdom)

    #expect(asUS != asUK)
    #expect(abs(asUS - StandardDrink.count(
      volumeOunces: 12, abvPercent: 5, region: .unitedStates
    )) < 0.0001)
  }

  @Test("An empty day totals zero rather than failing")
  func emptyDayTotalsZero() {
    #expect(repository.total(on: Date(), region: .unitedStates) == 0)
  }

  // MARK: - HealthKit backfill queue

  /// Backs `DrinkStore.backfillHealthKit`. The widget writes to SwiftData only, so
  /// its entries land with no sample id and get swept up on next foreground.
  @Test("Only entries without a HealthKit sample are queued, oldest first")
  func awaitingSyncReturnsUnsyncedOldestFirst() throws {
    let older = Date(timeIntervalSince1970: 1_000)
    let newer = Date(timeIntervalSince1970: 2_000)

    repository.save(drink(at: newer, sample: nil))
    repository.save(drink(at: older, sample: nil))
    repository.save(drink(at: Date(), sample: UUID()))

    let queued = repository.awaitingHealthKitSync()
    #expect(queued.count == 2)
    #expect(queued.first?.loggedAt == older)
    #expect(queued.last?.loggedAt == newer)
  }

  @Test("Nothing is queued once every entry carries a sample")
  func awaitingSyncEmptyWhenAllSynced() {
    repository.save(drink(sample: UUID()))
    #expect(repository.awaitingHealthKitSync().isEmpty)
  }

  // MARK: - Lookup

  @Test("entry(with:) finds the row and returns nil for an unknown id")
  func entryLookup() {
    let saved = drink()
    repository.save(saved)

    #expect(repository.entry(with: saved.id)?.entryID == saved.id)
    #expect(repository.entry(with: UUID()) == nil)
  }
}

/// Tier 2 — mirroring other apps' Health data into the log (ADR-0014).
@Suite("Health import")
struct HealthImportTests {

  let context: ModelContext
  let repository: DrinkRepository

  init() throws {
    let container = try ModelContainer(
      for: SharedModelContainer.schema,
      configurations: ModelConfiguration(
        schema: SharedModelContainer.schema,
        isStoredInMemoryOnly: true
      )
    )
    self.context = ModelContext(container)
    self.repository = DrinkRepository(context: context)
  }

  private func allEntries() -> [DrinkEntry] {
    (try? context.fetch(FetchDescriptor<DrinkEntry>())) ?? []
  }

  @Test("An external sample imports once, however often it is offered")
  func importIsIdempotent() {
    let sampleID = UUID()
    repository.importExternalSample(id: sampleID, count: 2, loggedAt: Date())
    repository.importExternalSample(id: sampleID, count: 2, loggedAt: Date())
    repository.importExternalSample(id: sampleID, count: 2, loggedAt: Date())

    let entries = allEntries()
    #expect(entries.count == 1)
    #expect(entries.first?.countedDrinks == 2)
    #expect(entries.first?.healthKitSampleID == sampleID)
  }

  @Test("Imported entries never enter the HealthKit backfill queue")
  func importedNeverBackfills() {
    repository.importExternalSample(id: UUID(), count: 1, loggedAt: Date())
    // A widget-logged drink (no sample yet) still queues; the import doesn't.
    repository.save(LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5))

    let queued = repository.awaitingHealthKitSync()
    #expect(queued.count == 1)
    #expect(queued.first?.countedDrinks == nil)
  }

  @Test("Importing onto a day marked alcohol-free removes the marker")
  func importClearsMarker() {
    let day = Date()
    #expect(repository.markAlcoholFree(day))
    repository.importExternalSample(id: UUID(), count: 1, loggedAt: day)
    #expect(!repository.isMarkedAlcoholFree(day))
  }

  @Test("Source deletions remove only the mirrored entry")
  func deletionRemovesOnlyMirrors() {
    let externalID = UUID()
    let ownSampleID = UUID()
    repository.importExternalSample(id: externalID, count: 1, loggedAt: Date())
    let own = LoggedDrink(
      loggedAt: Date(),
      type: .beer,
      volumeOunces: 12,
      abvPercent: 5,
      healthKitSampleID: ownSampleID
    )
    repository.save(own)

    // The delta reports both UUIDs deleted — as Health does when the user
    // prunes samples in the Health app. Only the mirror may follow.
    repository.removeImportedEntries(sampleIDs: [externalID, ownSampleID])

    let remaining = allEntries()
    #expect(remaining.count == 1)
    #expect(remaining.first?.entryID == own.id)
  }

  @Test("An imported entry round-trips its count through the store")
  func importedRoundTrips() {
    repository.importExternalSample(id: UUID(), count: 4, loggedAt: Date())
    let logged = allEntries().first?.logged
    #expect(logged?.isImportedFromHealth == true)
    #expect(logged?.standardDrinks(in: .unitedKingdom) == 4)
    #expect(logged?.standardDrinks(in: .unitedStates) == 4)
  }
}

/// Tier 2 (docs/PRD.md §4) — adoption's persistence guarantees (ADR-0016).
///
/// The pure transformation is tier 1's job; what belongs here is what the
/// *rows* do afterwards: the overwrite lands in place, a re-import can't
/// resurrect the count, deletion sync no longer treats the entry as a mirror,
/// and the backfill never queues it for a second Health sample.
@Suite("Import adoption rows")
struct ImportAdoptionRepositoryTests {

  let context: ModelContext
  let repository: DrinkRepository

  init() throws {
    let container = try ModelContainer(
      for: SharedModelContainer.schema,
      configurations: ModelConfiguration(
        schema: SharedModelContainer.schema,
        isStoredInMemoryOnly: true
      )
    )
    self.context = ModelContext(container)
    self.repository = DrinkRepository(context: context)
  }

  private func importAndAdopt() -> (sampleID: UUID, adopted: LoggedDrink) {
    let sampleID = UUID()
    let loggedAt = Date(timeIntervalSince1970: 1_700_000_000)
    repository.importExternalSample(id: sampleID, count: 1, loggedAt: loggedAt)
    let imported = repository.entry(with: repositoryImportedID(sampleID))!.logged
    let adopted = imported.adopting(
      type: .wine, volumeOunces: 5, abvPercent: 12, region: .unitedStates
    )
    repository.save(adopted)
    return (sampleID, adopted)
  }

  private func repositoryImportedID(_ sampleID: UUID) -> UUID {
    let all = (try? context.fetch(FetchDescriptor<DrinkEntry>())) ?? []
    return all.first { $0.healthKitSampleID == sampleID }!.entryID
  }

  @Test("Adoption overwrites the mirror in place — one entry, typed facts")
  func adoptionOverwritesInPlace() throws {
    let (sampleID, adopted) = importAndAdopt()

    let entries = try context.fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.count == 1)
    let row = try #require(entries.first)
    #expect(row.entryID == adopted.id)
    #expect(row.countedDrinks == nil)
    #expect(row.typeRawValue == DrinkType.wine.rawValue)
    #expect(row.volumeOunces == 5)
    #expect(row.abvPercent == 12)
    #expect(row.healthKitSampleID == sampleID)
  }

  @Test("A re-import of the same sample cannot resurrect the count")
  func reimportStaysDeduped() throws {
    let (sampleID, adopted) = importAndAdopt()

    // The anchored query re-delivering the sample — a reset anchor, a second
    // device — must find the adopted entry by sample id and insert nothing.
    repository.importExternalSample(
      id: sampleID, count: 1, loggedAt: adopted.loggedAt
    )

    let entries = try context.fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.count == 1)
    #expect(entries.first?.countedDrinks == nil)
    #expect(entries.first?.typeRawValue == DrinkType.wine.rawValue)
  }

  @Test("Deleting the source sample no longer deletes the adopted entry")
  func deletionSyncSparesAdopted() throws {
    let (sampleID, _) = importAndAdopt()

    // The user typed these facts in; the entry is now Tallyist's own record,
    // and the mirror direction never inverts (ADR-0014's rule, inherited).
    repository.removeImportedEntries(sampleIDs: [sampleID])

    let entries = try context.fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.count == 1)
  }

  @Test("An edited adoption that keeps its foreign sample id stays deduplicated")
  func editedAdoptionKeepsDedup() throws {
    let (sampleID, adopted) = importAndAdopt()

    // The edit path re-saves the row. `DrinkStore.save` keeps the foreign id
    // when Health will not retire the sample; this pins what that preserves:
    // the same key, so a re-delivered sample still finds the row.
    var edited = adopted
    edited.loggedAt = adopted.loggedAt.addingTimeInterval(600)
    repository.save(edited)
    repository.importExternalSample(id: sampleID, count: 1, loggedAt: adopted.loggedAt)

    let entries = try context.fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.count == 1)
    #expect(entries.first?.healthKitSampleID == sampleID)
    #expect(entries.first?.loggedAt == edited.loggedAt)
    #expect(repository.awaitingHealthKitSync().isEmpty)
  }

  @Test("Adopted entries never enter the HealthKit backfill queue")
  func adoptedNeverBackfills() {
    _ = importAndAdopt()
    // The external sample id fills the slot the backfill keys on, so no
    // second sample can ever be written for this drink.
    #expect(repository.awaitingHealthKitSync().isEmpty)
  }

  @Test("An unadopted multi-count mirror still follows source deletion")
  func multiCountMirrorStillFollows() throws {
    let sampleID = UUID()
    repository.importExternalSample(id: sampleID, count: 3, loggedAt: Date())
    repository.removeImportedEntries(sampleIDs: [sampleID])
    let entries = try context.fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.isEmpty)
  }
}
