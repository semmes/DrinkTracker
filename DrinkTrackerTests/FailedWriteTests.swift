import DrinkTrackerCore
import Foundation
import SwiftData
import Testing

/// Tier 2 (docs/PRD.md §4) — what the repository's *writes* do when the store
/// fails under them (ADR-0004's third 2026-09-16 amendment): every read a write
/// depends on answers before anything changes, and a save that fails leaves
/// nothing in the context for a later save to deliver.
///
/// Two failures, both from `DamageableStore` (see `FailedReadTests`): the store
/// overwritten before the write, so its reads throw; and the store overwritten
/// from inside the write's own save (`damageOnNextSave`), so its reads answer
/// and only the save fails. Each test then restores the bytes, saves the same
/// context — which is what writes anything a failed call left pending, as the
/// next save in the app would — and reads back through a fresh context.
///
/// The tests in this suite go through calls the repository had before this
/// change, so they were run against the old repository: each failed there
/// except the control, which passes on both by design. The next suite covers
/// the reads this change added.
@Suite("Writes that fail")
struct FailedWriteTests {

  /// Noon today, so no test sits near a day boundary.
  private let day = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 60 * 60)

  // MARK: - A drink and the day's marker (ADR-0011)

  /// The regression: the marker read ran after the insert, through `try?`, so
  /// it read as no markers, and the insert outlived the failed save — the
  /// next save that worked wrote a drink beside the marker.
  @Test("A drink is not written onto a day recorded as no alcohol when the day's markers cannot be read")
  func drinkRefusesAnUnreadableMarkedDay() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    #expect(try repository.markAlcoholFreeOrThrow(day))

    try store.damage()
    #expect(throws: (any Error).self) {
      try repository.saveOrThrow(beer(at: day))
    }
    #expect(!context.hasChanges)

    try store.restore()
    try context.save()
    let fresh = DrinkRepository(context: ModelContext(store.container))
    #expect(fresh.drinks(on: day).isEmpty)
    #expect(fresh.isMarkedAlcoholFree(day))
  }

  /// The regression: an id read that failed read as "no such entry", so an
  /// edit inserted a second row carrying the same id.
  @Test("An edit whose entry cannot be read does not become a second entry with the same id")
  func editRefusesAnUnreadableEntry() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    let original = beer(at: day)
    try repository.saveOrThrow(original)

    try store.damage()
    #expect(throws: (any Error).self) {
      try repository.saveOrThrow(LoggedDrink(
        id: original.id, loggedAt: day, type: .beer, volumeOunces: 16, abvPercent: 5
      ))
    }
    #expect(!context.hasChanges)

    try store.restore()
    try context.save()
    let entries = try ModelContext(store.container).fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.count == 1)
    #expect(entries.first?.logged.id == original.id)
    #expect(entries.first?.logged.volumeOunces == 12)
  }

  // MARK: - A save that fails after its reads answered

  /// The reads succeed here, so this is the rollback alone: the insert and
  /// the marker's deletion are both in the context when the save fails, and
  /// before, both were written by the next save that worked.
  @Test("A drink whose save fails leaves nothing behind for a later save to write")
  func failedDrinkSaveLeavesNothingPending() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    #expect(try repository.markAlcoholFreeOrThrow(day))

    store.damageOnNextSave(of: context)
    #expect(throws: (any Error).self) {
      try repository.saveOrThrow(beer(at: day))
    }
    #expect(!context.hasChanges)

    try store.restore()
    try context.save()
    let fresh = DrinkRepository(context: ModelContext(store.container))
    #expect(fresh.drinks(on: day).isEmpty)
    #expect(fresh.isMarkedAlcoholFree(day))
  }

  /// The same for the no-alcohol marker, whose reads were already made to
  /// throw — but whose insert still outlived a failed save.
  @Test("A no-alcohol marker whose save fails is not written later")
  func failedMarkerSaveLeavesNothingPending() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    try repository.saveOrThrow(beer(at: day.addingTimeInterval(-2 * 24 * 60 * 60)))

    store.damageOnNextSave(of: context)
    #expect(throws: (any Error).self) {
      try repository.markAlcoholFreeOrThrow(day)
    }
    #expect(!context.hasChanges)

    try store.restore()
    try context.save()
    #expect(!DrinkRepository(context: ModelContext(store.container)).isMarkedAlcoholFree(day))
  }

  /// The control: after a failed save and a restored store, the same context
  /// writes the same drink, so what the two tests above pin is the rollback,
  /// not a context the failure broke.
  @Test("After a failed save and a restored store, the same context writes the drink")
  func contextWritesAfterRollback() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    let drink = beer(at: day)

    store.damageOnNextSave(of: context)
    #expect(throws: (any Error).self) {
      try repository.saveOrThrow(drink)
    }
    try store.restore()
    try repository.saveOrThrow(drink)

    let entries = try ModelContext(store.container).fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.map(\.logged.id) == [drink.id])
  }

  // MARK: - The Health sweep (ADR-0025)

  /// The regression: the deletion's read went through `try?`, the sweep did
  /// not know it had failed, and the anchor advanced past the deletion — so
  /// the mirror stayed for good. Throwing is what lets the sweep keep its
  /// anchor, and applying the same delta again removes it.
  @Test("A Health deletion that cannot be read throws, and removes the mirror when offered again")
  func sweepDeletionThrowsAndReplays() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    let sampleID = UUID()
    try repository.applyExternalChanges(
      added: [ExternalBeverageSample(id: sampleID, count: 2, loggedAt: day)], deletedIDs: []
    )

    try store.damage()
    #expect(throws: (any Error).self) {
      try repository.applyExternalChanges(added: [], deletedIDs: [sampleID])
    }
    #expect(!context.hasChanges)
    try store.restore()
    try context.save()
    #expect(DrinkRepository(context: ModelContext(store.container)).drinks(on: day).count == 1)

    try repository.applyExternalChanges(added: [], deletedIDs: [sampleID])
    #expect(DrinkRepository(context: ModelContext(store.container)).drinks(on: day).isEmpty)
  }

  /// A zero offered while its day could not be read was refused for good.
  /// Now it throws, and the replayed delta marks the day.
  @Test("A Health zero on a day that cannot be read throws, and marks the day when offered again")
  func sweepZeroThrowsAndReplays() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    try repository.saveOrThrow(beer(at: day.addingTimeInterval(-2 * 24 * 60 * 60)))
    let zero = ExternalBeverageSample(id: UUID(), count: 0, loggedAt: day)

    try store.damage()
    #expect(throws: (any Error).self) {
      try repository.applyExternalChanges(added: [zero], deletedIDs: [])
    }
    try store.restore()
    try context.save()
    #expect(!DrinkRepository(context: ModelContext(store.container)).isMarkedAlcoholFree(day))

    try repository.applyExternalChanges(added: [zero], deletedIDs: [])
    #expect(DrinkRepository(context: ModelContext(store.container)).isMarkedAlcoholFree(day))
  }

  /// Replaying is only safe if what already landed dedups: the first sample's
  /// save works, the second's fails, and the whole delta offered again leaves
  /// exactly one of each.
  @Test("A sweep that failed partway lands each change exactly once when replayed")
  func sweepReplayIsIdempotent() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    let first = ExternalBeverageSample(id: UUID(), count: 2, loggedAt: day)
    let second = ExternalBeverageSample(id: UUID(), count: 1, loggedAt: day.addingTimeInterval(60))
    try repository.applyExternalChanges(added: [first], deletedIDs: [])

    // `first` dedups without a save, so the damaged save is `second`'s.
    store.damageOnNextSave(of: context)
    #expect(throws: (any Error).self) {
      try repository.applyExternalChanges(added: [first, second], deletedIDs: [])
    }
    try store.restore()
    try context.save()

    try repository.applyExternalChanges(added: [first, second], deletedIDs: [])
    let entries = try ModelContext(store.container).fetch(FetchDescriptor<DrinkEntry>())
    #expect(entries.compactMap(\.healthKitSampleID).sorted { $0.uuidString < $1.uuidString }
      == [first.id, second.id].sorted { $0.uuidString < $1.uuidString })
  }

  // MARK: - Helpers

  private func beer(at date: Date) -> LoggedDrink {
    LoggedDrink(loggedAt: date, type: .beer, volumeOunces: 12, abvPercent: 5)
  }
}

/// Tier 2 — the reads this change added for writes that had none of their
/// own: removal, the Health sample a row points at, bulk fill, and the day
/// sheet's timestamp.
@Suite("Writes that fail — the reads they now make")
struct FailedWriteReadTests {

  private let day = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 60 * 60)
  private var pastDay: Date { day.addingTimeInterval(-3 * 24 * 60 * 60) }

  // MARK: - Removal

  @Test("A removal that cannot read its entry, or cannot save, removes nothing")
  func removalRefusesAFailingStore() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    let drink = beer(at: day)
    try repository.saveOrThrow(drink)

    try store.damage()
    #expect(throws: (any Error).self) { try repository.deleteOrThrow(id: drink.id) }
    try store.restore()

    store.damageOnNextSave(of: context)
    #expect(throws: (any Error).self) { try repository.deleteOrThrow(id: drink.id) }
    #expect(!context.hasChanges)
    try store.restore()
    try context.save()

    #expect(DrinkRepository(context: ModelContext(store.container)).drinks(on: day).map(\.id) == [drink.id])
  }

  @Test("A removal returns the entry as stored, sample id included")
  func removalReturnsTheStoredEntry() throws {
    let store = try DamageableStore()
    let repository = DrinkRepository(context: ModelContext(store.container))
    let sampleID = UUID()
    let stored = LoggedDrink(loggedAt: day, type: .wine, volumeOunces: 5, abvPercent: 12, healthKitSampleID: sampleID)
    try repository.saveOrThrow(stored)

    // A screen's copy that predates the sample id: the removal still answers
    // with the id the row held, which is the sample to retire.
    let snapshot = LoggedDrink(id: stored.id, loggedAt: day, type: .wine, volumeOunces: 5, abvPercent: 12)
    #expect(try repository.deleteOrThrow(id: snapshot.id)?.healthKitSampleID == sampleID)
    #expect(try repository.deleteOrThrow(id: snapshot.id) == nil)
  }

  // MARK: - The Health sample a row points at

  /// Two writers stamp sample ids across an await; the second must not
  /// overwrite the first.
  @Test("A sample id is recorded only over the id the caller expected")
  func sampleIDIsComparedBeforeItIsSet() throws {
    let store = try DamageableStore()
    let repository = DrinkRepository(context: ModelContext(store.container))
    let drink = beer(at: day)
    try repository.saveOrThrow(drink)
    let first = UUID()
    let second = UUID()

    #expect(try repository.recordHealthSample(first, for: drink, replacing: nil))
    #expect(try !repository.recordHealthSample(second, for: drink, replacing: nil))
    #expect(try !repository.recordHealthSample(second, for: beer(at: day), replacing: nil))
    #expect(try repository.recordHealthSample(nil, for: drink, replacing: first))

    let fresh = DrinkRepository(context: ModelContext(store.container))
    #expect(fresh.entry(with: drink.id)?.healthKitSampleID == nil)
  }

  /// A sample written from a drink the reader then edited mirrors a drink the
  /// log no longer holds, so it is not recorded — the stale copy backfill once
  /// held across its whole sweep.
  @Test("A sample id is not recorded on a row whose facts changed after the sample was written")
  func sampleIDIsNotRecordedOverAnEdit() throws {
    let store = try DamageableStore()
    let repository = DrinkRepository(context: ModelContext(store.container))
    let written = beer(at: day)
    try repository.saveOrThrow(written)
    try repository.saveOrThrow(LoggedDrink(
      id: written.id, loggedAt: day, type: .beer, volumeOunces: 16, abvPercent: 5
    ))

    #expect(try !repository.recordHealthSample(UUID(), for: written, replacing: nil))
    #expect(DrinkRepository(context: ModelContext(store.container)).entry(with: written.id)?.healthKitSampleID == nil)
  }

  @Test("A sample id whose save fails is not written later")
  func failedSampleIDSaveLeavesNothingPending() throws {
    let store = try DamageableStore()
    let context = ModelContext(store.container)
    let repository = DrinkRepository(context: context)
    let drink = beer(at: day)
    try repository.saveOrThrow(drink)

    store.damageOnNextSave(of: context)
    #expect(throws: (any Error).self) {
      try repository.recordHealthSample(UUID(), for: drink, replacing: nil)
    }
    #expect(!context.hasChanges)
    try store.restore()
    try context.save()

    #expect(DrinkRepository(context: ModelContext(store.container)).entry(with: drink.id)?.healthKitSampleID == nil)
  }

  // MARK: - Bulk fill (ADR-0011)

  /// The bug on the calendar: an empty query offered recorded days and seeded
  /// from no history. The write-time reads throw instead.
  @Test("Bulk fill throws for a history or a day it cannot read")
  func bulkFillRefusesAFailingStore() throws {
    let store = try DamageableStore()
    let repository = DrinkRepository(context: ModelContext(store.container))
    try repository.saveOrThrow(beer(at: pastDay))

    try store.damage()
    #expect(throws: (any Error).self) { try repository.historyOrThrow() }
    #expect(throws: (any Error).self) {
      try repository.bulkFillDrinks(2, on: pastDay, from: [], seed: .usualDrink, region: .unitedStates)
    }
    try store.restore()
  }

  @Test("Bulk fill writes nothing to a day with drinks or a marker, and the seeded drink to a blank one")
  func bulkFillSkipsRecordedDaysAtWriteTime() throws {
    let store = try DamageableStore()
    let repository = DrinkRepository(context: ModelContext(store.container))
    let wine = LoggedDrink(loggedAt: pastDay, type: .wine, volumeOunces: 5, abvPercent: 12)
    try repository.saveOrThrow(wine)
    let marked = pastDay.addingTimeInterval(-24 * 60 * 60)
    #expect(try repository.markAlcoholFreeOrThrow(marked))
    let blank = pastDay.addingTimeInterval(-2 * 24 * 60 * 60)
    let history = try repository.historyOrThrow()

    #expect(try repository.bulkFillDrinks(2, on: pastDay, from: history, seed: .usualDrink, region: .unitedStates).isEmpty)
    #expect(try repository.bulkFillDrinks(2, on: marked, from: history, seed: .usualDrink, region: .unitedStates).isEmpty)

    let filled = try repository.bulkFillDrinks(2, on: blank, from: history, seed: .usualDrink, region: .unitedStates)
    #expect(filled.count == 2)
    // The history's type, not beer at beer's defaults.
    #expect(filled.allSatisfy { $0.type == .wine })
    #expect(filled.allSatisfy { Calendar.current.isDate($0.loggedAt, inSameDayAs: blank) })
  }

  // MARK: - The day sheet's timestamp

  /// A past day read as empty is stamped at noon — before drinks it already
  /// had, so − then removed one of those instead.
  @Test("The day sheet's timestamp throws for a day it cannot read, and follows the day's latest drink otherwise")
  func backfillTimestampReadsTheDay() throws {
    let store = try DamageableStore()
    let repository = DrinkRepository(context: ModelContext(store.container))
    let evening = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: pastDay)!
    try repository.saveOrThrow(beer(at: evening))

    #expect(try repository.backfillTimestampOrThrow(on: pastDay) == evening.addingTimeInterval(1))

    try store.damage()
    #expect(throws: (any Error).self) { try repository.backfillTimestampOrThrow(on: pastDay) }
    try store.restore()
  }

  // MARK: - Helpers

  private func beer(at date: Date) -> LoggedDrink {
    LoggedDrink(loggedAt: date, type: .beer, volumeOunces: 12, abvPercent: 5)
  }
}
