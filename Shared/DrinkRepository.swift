import DrinkTrackerCore
import Foundation
import SwiftData

/// SwiftData writes, with no HealthKit involvement.
///
/// Shared by the app and the widget. The widget deliberately stops here: writing to
/// Health from a short-lived extension process is unreliable, so anything it logs
/// lands with `healthKitSampleID == nil` and the app mirrors it to Health on next
/// launch (see `DrinkStore.backfillHealthKit`).
struct DrinkRepository {
  let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  /// Inserts, or overwrites in place when an entry with this id already exists.
  ///
  /// The overwrite is what makes edit-after replace the original's contribution to
  /// the daily total rather than adding a duplicate.
  func save(_ drink: LoggedDrink) {
    try? saveOrThrow(drink)
  }

  /// Same as `save`, but surfaces the failure.
  ///
  /// Used by the widget's intent, where a swallowed error looks exactly like a
  /// missed tap and there is no UI to notice the missing entry.
  func saveOrThrow(_ drink: LoggedDrink) throws {
    if let existing = entry(with: drink.id) {
      existing.apply(drink)
    } else {
      context.insert(DrinkEntry(drink))
    }
    try context.save()
  }

  func delete(id: UUID) {
    guard let existing = entry(with: id) else { return }
    context.delete(existing)
    try? context.save()
  }

  func entry(with id: UUID) -> DrinkEntry? {
    var descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.entryID == id }
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  /// Everything logged on the given calendar day.
  func drinks(on day: Date, calendar: Calendar = .current) -> [LoggedDrink] {
    let start = calendar.startOfDay(for: day)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
    let descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.loggedAt >= start && $0.loggedAt < end },
      sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
    return ((try? context.fetch(descriptor)) ?? []).map(\.logged)
  }

  /// Total for the given day, expressed in `region`'s units.
  func total(on day: Date, region: Region, calendar: Calendar = .current) -> Double {
    drinks(on: day, calendar: calendar).reduce(0) { $0 + $1.standardDrinks(in: region) }
  }

  /// Entries that never made it into Health, oldest first.
  func awaitingHealthKitSync() -> [DrinkEntry] {
    let descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.healthKitSampleID == nil },
      sortBy: [SortDescriptor(\.loggedAt, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
  }
}

// MARK: - Query helpers

extension FetchDescriptor where T == DrinkEntry {
  /// Everything logged on or after `startDate`, newest first. Used by `@Query` in
  /// the views, which drive their own updates rather than going through the
  /// repository.
  static func since(_ startDate: Date) -> FetchDescriptor<DrinkEntry> {
    FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.loggedAt >= startDate },
      sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
  }
}
