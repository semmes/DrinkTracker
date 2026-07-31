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
}
