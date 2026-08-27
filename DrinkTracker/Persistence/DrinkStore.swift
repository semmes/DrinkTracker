import DrinkTrackerCore
import Foundation
import SwiftData
import WidgetKit

/// All writes to the drink log from inside the app.
///
/// Persistence itself lives in the shared `DrinkRepository`; this adds the parts
/// only the app can do — mirroring to HealthKit, and retiring the old Health sample
/// when an entry is edited.
@MainActor
struct DrinkStore {
  let repository: DrinkRepository
  let health: HealthKitService

  init(context: ModelContext, health: HealthKitService) {
    self.repository = DrinkRepository(context: context)
    self.health = health
  }

  /// Saves a drink, replacing the existing entry when the draft came from Edit.
  ///
  /// Returns the persisted value so callers can show the "last logged" line.
  @discardableResult
  func save(_ drink: LoggedDrink) async -> LoggedDrink {
    var drink = drink

    // Retire the old sample before writing the replacement, so an edit never
    // leaves two beverages behind in Health.
    if let existing = repository.entry(with: drink.id),
       let oldSampleID = existing.healthKitSampleID {
      await health.deleteSample(id: oldSampleID)
    }

    drink.healthKitSampleID = await health.save(drink)
    repository.save(drink)
    WidgetCenter.shared.reloadAllTimelines()
    return drink
  }

  /// Saves several drinks in one go, returning the last for the "just logged" line.
  ///
  /// Each is written individually so every one gets its own HealthKit sample and
  /// stays separately editable.
  @discardableResult
  func save(_ drinks: [LoggedDrink]) async -> LoggedDrink? {
    var saved: LoggedDrink?
    for drink in drinks {
      saved = await save(drink)
    }
    return saved
  }

  /// Persists an adopted import — deliberately NOT `save(_:)` (ADR-0016).
  ///
  /// `save` retires the entry's old Health sample and writes a fresh one, and
  /// both halves are wrong here: the old sample belongs to *another app* (we
  /// couldn't delete it, and mustn't want to — it is the Health record), and
  /// writing our own would double-count the drink in Health. Adoption changes
  /// what the *log* knows, and Health already knows everything it should.
  @discardableResult
  func adopt(_ adopted: LoggedDrink) -> LoggedDrink {
    repository.save(adopted)
    WidgetCenter.shared.reloadAllTimelines()
    return adopted
  }

  /// Records that a day had no alcohol.
  ///
  /// Returns Void rather than the repository's Bool: the calendar only offers this
  /// on a day with no entries, so the refusal case can't be reached from there, and
  /// a discarded Bool at every call site would suggest otherwise.
  ///
  /// No widget reload — the widget shows today's total, and a day with no alcohol
  /// totals what an unlogged day totals.
  func markAlcoholFree(_ day: Date) {
    repository.markAlcoholFree(day)
  }

  func unmarkAlcoholFree(_ day: Date) {
    repository.unmarkAlcoholFree(day)
  }

  func delete(_ drink: LoggedDrink) async {
    if let sampleID = drink.healthKitSampleID {
      await health.deleteSample(id: sampleID)
    }
    repository.delete(id: drink.id)
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// Mirrors anything logged outside the app — currently the widget — into Health.
  ///
  /// The widget writes to SwiftData only, because writing to Health from a
  /// short-lived extension process is unreliable. Those entries land with no sample
  /// id, and this sweeps them up the next time the app is foregrounded.
  ///
  /// Cheap to call repeatedly: with Health denied nothing is ever written, the ids
  /// stay nil, and each pass is one fetch that changes nothing.
  func backfillHealthKit() async {
    guard health.authorization == .authorized else { return }
    for entry in repository.awaitingHealthKitSync() {
      if let sampleID = await health.save(entry.logged) {
        entry.healthKitSampleID = sampleID
      }
    }
    try? repository.context.save()
  }

  /// The other direction: mirrors alcohol data other apps put in Health into the
  /// log as count-based entries, and removes mirrors whose samples were deleted
  /// at the source (ADR-0014).
  ///
  /// Incremental and idempotent — the anchored query returns only changes, and
  /// the repository dedups by sample UUID — so it rides the same foreground
  /// sweep as `backfillHealthKit`. The two never touch the same rows: backfill
  /// writes entries with no sample id, imports arrive with one.
  func syncFromHealth() async {
    guard let delta = await health.fetchExternalChanges() else { return }
    for sample in delta.added {
      repository.importExternalSample(id: sample.id, count: sample.count, loggedAt: sample.loggedAt)
    }
    repository.removeImportedEntries(sampleIDs: delta.deletedIDs)
    if !delta.added.isEmpty || !delta.deletedIDs.isEmpty {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
