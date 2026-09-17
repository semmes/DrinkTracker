import DrinkTrackerCore
import Foundation
import SwiftData
import Testing

/// Tier 2 (docs/PRD.md §4) — what the repository does when a read *fails*,
/// as distinct from a read that finds nothing.
///
/// An in-memory store could not be made to fail a fetch: a model missing from
/// the schema fetches as empty, Foundation answered every extreme date tried
/// rather than refusing one, and the unsupported predicates tried crashed the
/// process. What
/// does fail, deterministically, is a real store file overwritten under an open
/// connection — the fetch then throws Cocoa error 259, "not in the correct
/// format" — and putting the bytes back lets the same container read and save
/// again. That is the shape these tests use: damage, act, restore, save, and
/// read back with a fresh context, so that anything the failed call left
/// *pending* in its context gets its chance to be written, as it would the
/// next time the app saved anything. (Probed on macOS 26 before being relied
/// on here; the 2026-09-16 amendments to ADR-0004 and ADR-0042 carry the
/// measurements.)
@Suite("Reads that fail")
struct FailedReadTests {

  /// Noon today, so no test sits near a day boundary.
  private let day = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 60 * 60)

  // MARK: - The no-alcohol marker's backstop (ADR-0011)

  /// The regression: `drinks(on:)` turns a failed fetch into an empty day, so
  /// the refusal let the marker through, and the insert outlived the failed
  /// save. Restoring the store and saving is what shows that it did — the old
  /// path ends here with a marker on a day that has a drink.
  @Test("A day whose drinks cannot be read is not recorded as no alcohol, now or once the store recovers")
  func throwingMarkerRefusesAnUnreadableDay() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    try repository.saveOrThrow(beer(at: day))

    try store.damage()
    #expect(throws: (any Error).self) {
      try repository.markAlcoholFreeOrThrow(day)
    }
    #expect(context.insertedModelsArray.isEmpty)

    try store.restore()
    try context.save()
    let fresh = DrinkRepository(context: ModelContext(store.container))
    #expect(fresh.drinks(on: day).count == 1)
    #expect(!fresh.isMarkedAlcoholFree(day))
  }

  /// `DrinkStore.markAlcoholFree` — Today's button, the calendar's action bar
  /// and bulk fill — goes through the non-throwing form, whose `false` must
  /// now also cover a read that failed, with nothing left behind.
  @Test("The non-throwing marker answers false for a day it cannot read, and writes nothing")
  func plainMarkerRefusesAnUnreadableDay() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    try repository.saveOrThrow(beer(at: day))

    try store.damage()
    #expect(repository.markAlcoholFree(day) == false)
    #expect(context.insertedModelsArray.isEmpty)

    try store.restore()
    try context.save()
    #expect(!DrinkRepository(context: ModelContext(store.container)).isMarkedAlcoholFree(day))
  }

  /// ADR-0025's copy of the same refusal, on the Health sweep's path. It
  /// throws now rather than refusing quietly, so the sweep keeps its anchor
  /// (ADR-0025's second 2026-09-16 amendment).
  @Test("A Health zero is not mirrored onto a day whose drinks cannot be read")
  func healthZeroRefusesAnUnreadableDay() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    try repository.saveOrThrow(beer(at: day))

    try store.damage()
    #expect(throws: (any Error).self) {
      try repository.markAlcoholFreeFromHealth(sampleID: UUID(), day: day)
    }
    #expect(context.insertedModelsArray.isEmpty)

    try store.restore()
    try context.save()
    #expect(!DrinkRepository(context: ModelContext(store.container)).isMarkedAlcoholFree(day))
  }

  /// The control for the three above: an empty day that could not be read
  /// while the store was damaged is recorded once it reads again, through the
  /// same context — so what they pin is the refusal, not a store or a context
  /// that never came back.
  @Test("After a failed read and a restored store, an empty day is recorded as no alcohol as before")
  func restoredStoreStillMarks() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    try repository.saveOrThrow(beer(at: day.addingTimeInterval(-2 * 24 * 60 * 60)))

    try store.damage()
    #expect(throws: (any Error).self) {
      try repository.markAlcoholFreeOrThrow(day)
    }
    try store.restore()
    #expect(try repository.markAlcoholFreeOrThrow(day))
    #expect(DrinkRepository(context: ModelContext(store.container)).isMarkedAlcoholFree(day))
  }

  // MARK: - The counter's seed (ADR-0023, ADR-0042)

  /// Before the amendment a failed history read seeded from an empty one: the
  /// day's described wine became an untyped standard drink, which as the
  /// newest entry would have turned the rest of the day's ＋ into standard
  /// drinks as well.
  @Test("＋ reports a history it cannot read instead of logging a drink nobody described")
  func seedThrowsOnAnUnreadableHistory() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    let now = day
    let wine = LoggedDrink(
      loggedAt: now.addingTimeInterval(-60), type: .wine, volumeOunces: 5, abvPercent: 12
    )
    try repository.saveOrThrow(wine)

    // Readable, the day's described drink is what ＋ repeats.
    let seeded = try repository.nextQuickDrink(seed: .standardDrink, region: .unitedStates, at: now)
    #expect(seeded.type == .wine)

    try store.damage()
    for seed in [DrinkDraft.CountSeed.standardDrink, .usualDrink] {
      #expect(throws: (any Error).self) {
        try repository.nextQuickDrink(seed: seed, region: .unitedStates, at: now)
      }
    }
    #expect(throws: (any Error).self) {
      try repository.logOneDrink(seed: .standardDrink, region: .unitedStates)
    }
    #expect(context.insertedModelsArray.isEmpty)

    try store.restore()
    try context.save()
    let entries = try ModelContext(store.container).fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.map(\.logged.id) == [wine.id])
  }

  // MARK: - Helpers

  private func beer(at date: Date) -> LoggedDrink {
    LoggedDrink(loggedAt: date, type: .beer, volumeOunces: 12, abvPercent: 5)
  }
}

/// A store on disk, in a directory of its own, that can be overwritten under
/// its open container and then put back byte for byte.
///
/// Every file the store has — the database, its write-ahead log and the shared
/// memory index — is snapshotted just before the damage, so anything saved
/// before `damage()` is what `restore()` brings back.
final class DamageableStore {
  let container: ModelContainer
  private let directory: URL
  private var snapshot: [String: Data] = [:]

  init() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FailedReadTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    container = try ModelContainer(
      for: SharedModelContainer.schema,
      configurations: ModelConfiguration(
        schema: SharedModelContainer.schema,
        url: directory.appendingPathComponent("damageable.store"),
        cloudKitDatabase: .none
      )
    )
  }

  deinit {
    try? FileManager.default.removeItem(at: directory)
  }

  func damage() throws {
    snapshot = [:]
    for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) {
      let url = directory.appendingPathComponent(name)
      snapshot[name] = try Data(contentsOf: url)
      // The same file, not a replacement: the open connection keeps its
      // descriptor, so only writing through the existing inode reaches it.
      let handle = try FileHandle(forWritingTo: url)
      try handle.write(contentsOf: Data(repeating: 0xAB, count: 64 * 1024))
      try handle.close()
    }
  }

  func restore() throws {
    for (name, bytes) in snapshot {
      let handle = try FileHandle(forWritingTo: directory.appendingPathComponent(name))
      try handle.truncate(atOffset: 0)
      try handle.write(contentsOf: bytes)
      try handle.close()
    }
  }

  /// Damages the store from inside the next save of `context`: after every
  /// read the write made, before the write itself.
  ///
  /// That is the one failure `damage()` cannot produce on its own — reads
  /// that answered and a save that does not — and it is the case in which a
  /// write's changes are already in the context when the save fails.
  /// SwiftData posts `ModelContext.willSave` synchronously, on the saving
  /// thread, before any SQL runs; a store overwritten there fails the save
  /// with SQLite's "not a database" (probed on macOS 26 before being relied
  /// on, and the pending insert was measured still in the context after).
  /// Fires once.
  func damageOnNextSave(of context: ModelContext) {
    var observer: NSObjectProtocol?
    observer = NotificationCenter.default.addObserver(
      forName: ModelContext.willSave, object: context, queue: nil
    ) { [weak self] _ in
      if let observer { NotificationCenter.default.removeObserver(observer) }
      try? self?.damage()
    }
  }
}
