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
  func saveOrThrow(_ drink: LoggedDrink, calendar: Calendar = .current) throws {
    if let existing = entry(with: drink.id) {
      existing.apply(drink)
    } else {
      context.insert(DrinkEntry(drink))
    }

    // Evidence beats assertion: a drink landing on a day marked alcohol-free
    // removes the marker. Leaving it dormant would be worse than a visible
    // contradiction — it would resurrect the moment the entries were deleted,
    // claiming abstinence for a day the user just said had drinks. Sitting here
    // rather than in the UI means every write path gets it: the app, the
    // calendar backfill, and the widget's intent alike.
    if let marker = alcoholFreeDay(on: calendar.startOfDay(for: drink.loggedAt)) {
      context.delete(marker)
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

  // MARK: - Alcohol-free days

  /// Records that a day had no alcohol. Idempotent — marking twice is one marker.
  ///
  /// Refuses to mark a day that already has entries. The two would contradict each
  /// other, and silently keeping both leaves a dormant marker that reappears the
  /// moment those entries are removed — asserting abstinence for a day the user
  /// never said that about. Remove the entries first; the caller checks.
  @discardableResult
  func markAlcoholFree(_ day: Date, calendar: Calendar = .current) -> Bool {
    let startOfDay = calendar.startOfDay(for: day)
    guard drinks(on: startOfDay, calendar: calendar).isEmpty else { return false }
    guard alcoholFreeDay(on: startOfDay) == nil else { return true }
    context.insert(AlcoholFreeDay(day: startOfDay))
    try? context.save()
    return true
  }

  func unmarkAlcoholFree(_ day: Date, calendar: Calendar = .current) {
    let startOfDay = calendar.startOfDay(for: day)
    guard let existing = alcoholFreeDay(on: startOfDay) else { return }
    context.delete(existing)
    try? context.save()
  }

  func isMarkedAlcoholFree(_ day: Date, calendar: Calendar = .current) -> Bool {
    alcoholFreeDay(on: calendar.startOfDay(for: day)) != nil
  }

  func alcoholFreeDay(on startOfDay: Date) -> AlcoholFreeDay? {
    var descriptor = FetchDescriptor<AlcoholFreeDay>(
      predicate: #Predicate { $0.day == startOfDay }
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  /// Every marked day, as start-of-day dates.
  ///
  /// A `Set` because the calendar asks "is this day marked" once per cell — 365
  /// times for a year grid — and a linear scan per cell would be quadratic.
  func allAlcoholFreeDays() -> Set<Date> {
    let entries = (try? context.fetch(FetchDescriptor<AlcoholFreeDay>())) ?? []
    return Set(entries.map(\.day))
  }

  // MARK: - Imported Health entries (ADR-0013)

  /// Mirrors one external Health sample as a count-based entry, exactly once.
  ///
  /// Dedup is by the external sample's UUID (stored in `healthKitSampleID`), so
  /// re-running an import — a reset anchor, a second device — inserts nothing
  /// new. Routed through `saveOrThrow` so an imported drink clears a same-day
  /// alcohol-free marker exactly like a logged one: evidence beats assertion,
  /// whichever app recorded the evidence.
  func importExternalSample(id: UUID, count: Double, loggedAt: Date) {
    guard entryForHealthSample(id) == nil else { return }
    try? saveOrThrow(.importedFromHealth(sampleID: id, count: count, loggedAt: loggedAt))
  }

  /// Removes mirrored entries whose external samples were deleted from Health.
  ///
  /// Touches only count-based rows: a deleted sample that *this app* wrote means
  /// someone pruned the mirror in the Health app, and the log — the source of
  /// truth for the app's own entries — must not follow it.
  func removeImportedEntries(sampleIDs: [UUID]) {
    guard !sampleIDs.isEmpty else { return }
    for id in sampleIDs {
      if let entry = entryForHealthSample(id), entry.countedDrinks != nil {
        context.delete(entry)
      }
    }
    try? context.save()
  }

  private func entryForHealthSample(_ id: UUID) -> DrinkEntry? {
    var descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.healthKitSampleID == id }
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  // MARK: - HealthKit backfill

  /// Entries that never made it into Health, oldest first.
  ///
  /// Imported entries can never appear here: their `healthKitSampleID` is the
  /// external sample they mirror, so the nil-filter excludes them — which is
  /// what keeps an import from echoing back into Health as a duplicate sample.
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
