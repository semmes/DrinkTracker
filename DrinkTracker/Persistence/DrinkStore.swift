import DrinkTrackerCore
import Foundation
import SwiftData

/// All writes to the drink log, in one place.
///
/// Reads stay in the views via `@Query` so SwiftData drives updates directly;
/// this type exists so the log/edit/delete paths — each of which has to keep
/// HealthKit in step — aren't scattered across view bodies.
@MainActor
struct DrinkStore {
  let context: ModelContext
  let health: HealthKitService

  /// Saves a drink, replacing the existing entry when the draft came from Edit.
  ///
  /// Returns the persisted value so callers can show the "last logged" line.
  @discardableResult
  func save(_ drink: LoggedDrink) async -> LoggedDrink {
    var drink = drink
    let targetID = drink.id
    let descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.entryID == targetID }
    )
    let existing = (try? context.fetch(descriptor))?.first

    // Retire the old HealthKit sample before writing the replacement, so an
    // edit never leaves two beverages behind in Health.
    if let existing, let oldSampleID = existing.healthKitSampleID {
      await health.deleteSample(id: oldSampleID)
    }

    drink.healthKitSampleID = await health.save(drink)

    if let existing {
      existing.apply(drink)
    } else {
      context.insert(DrinkEntry(drink))
    }
    try? context.save()
    return drink
  }

  func delete(_ drink: LoggedDrink) async {
    if let sampleID = drink.healthKitSampleID {
      await health.deleteSample(id: sampleID)
    }
    let targetID = drink.id
    let descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.entryID == targetID }
    )
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
      try? context.save()
    }
  }
}

// MARK: - Query helpers

extension FetchDescriptor where T == DrinkEntry {
  /// Everything logged on or after `startDate`, newest first.
  static func since(_ startDate: Date) -> FetchDescriptor<DrinkEntry> {
    FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.loggedAt >= startDate },
      sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
  }
}
