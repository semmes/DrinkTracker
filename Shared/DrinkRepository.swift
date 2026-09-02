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
    // Every marker on the day, not the first: two can land on one day when
    // two devices act before CloudKit merges, and each contradicts the drink.
    for marker in alcoholFreeDays(on: calendar.startOfDay(for: drink.loggedAt)) {
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
    (try? markAlcoholFreeOrThrow(day, calendar: calendar)) ?? false
  }

  /// Same as `markAlcoholFree`, but surfaces the failure.
  ///
  /// The returned Bool answers "was it refused?", never "did it persist" —
  /// so a swallowed save error would let a caller claim a day was recorded
  /// when nothing was written. In the app that self-corrects (the calendar
  /// and Today both re-read the marker from a live query, so the button
  /// simply stays unmarked). Out of the app it does not: an intent speaks a
  /// claim about the record and then leaves, which is the same reason
  /// `saveOrThrow` exists for drinks.
  @discardableResult
  func markAlcoholFreeOrThrow(_ day: Date, calendar: Calendar = .current) throws -> Bool {
    let startOfDay = calendar.startOfDay(for: day)
    guard drinks(on: startOfDay, calendar: calendar).isEmpty else { return false }
    guard alcoholFreeDay(on: startOfDay) == nil else { return true }
    context.insert(AlcoholFreeDay(day: startOfDay))
    try context.save()
    return true
  }

  /// Removes the user's own marker. A marker mirrored from another app's
  /// Health zero (ADR-0025) is left alone: HealthKit will not let this app
  /// delete that sample, so removing the mirror here would leave the two
  /// stores disagreeing for good — the same reason imported drinks are
  /// read-only (ADR-0014). Logging a drink on the day still clears it, via
  /// `saveOrThrow`: evidence beats assertion, whoever asserted.
  func unmarkAlcoholFree(_ day: Date, calendar: Calendar = .current) {
    let startOfDay = calendar.startOfDay(for: day)
    let own = alcoholFreeDays(on: startOfDay).filter { !$0.isImportedFromHealth }
    guard !own.isEmpty else { return }
    for marker in own {
      context.delete(marker)
    }
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

  /// Every marker on the day. One is the rule; the repository enforces it on
  /// a single device, but two devices writing before CloudKit merges can
  /// leave two, and anything that clears a day must clear them all.
  func alcoholFreeDays(on startOfDay: Date) -> [AlcoholFreeDay] {
    let descriptor = FetchDescriptor<AlcoholFreeDay>(
      predicate: #Predicate { $0.day == startOfDay }
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  /// Every marked day, as start-of-day dates.
  ///
  /// A `Set` because the calendar asks "is this day marked" once per cell — 365
  /// times for a year grid — and a linear scan per cell would be quadratic.
  func allAlcoholFreeDays() -> Set<Date> {
    let entries = (try? context.fetch(FetchDescriptor<AlcoholFreeDay>())) ?? []
    return Set(entries.map(\.day))
  }

  // MARK: - Imported Health entries (ADR-0014)

  /// Applies one sweep's worth of changes from Health, in the only order
  /// that is right for all of them: **deletions first, then additions.**
  ///
  /// A HealthKit sample cannot be edited, so any correction in another app —
  /// re-saving a zero, changing a day from one drink to none — is a delete
  /// plus a save, and both land in the same anchored delta whenever they
  /// happened between two sweeps, which is the ordinary case. Markers are
  /// one per day, so with additions first the new zero would find the stale
  /// marker (or the stale drink) still there, be refused, and then watch the
  /// stale record go — leaving the day blank for good, since the anchor has
  /// passed the new sample. Deletions first is correct for every transition
  /// (drink→drink, drink→zero, zero→drink, zero→zero) and costs nothing: a
  /// sample added and deleted between sweeps is never offered as an addition.
  func applyExternalChanges(
    added: [ExternalBeverageSample],
    deletedIDs: [UUID],
    calendar: Calendar = .current
  ) {
    removeImportedEntries(sampleIDs: deletedIDs)
    removeImportedMarkers(sampleIDs: deletedIDs)
    for sample in added {
      importExternalSample(id: sample.id, count: sample.count, loggedAt: sample.loggedAt, calendar: calendar)
    }
  }

  /// Mirrors one external Health sample, exactly once.
  ///
  /// The sample's value decides what it is. **A positive count is drinks**: a
  /// count-based entry (ADR-0014). **Zero is a recorded no-alcohol day**
  /// (ADR-0025): the other app's user said "I was here and there was nothing
  /// to log", which is the claim `AlcoholFreeDay` exists to hold. Anything
  /// else — negative, non-finite — is nothing Health can actually store and
  /// is dropped. The rule lives here rather than in `HealthKitService` so a
  /// tier-2 test can hold it, and so no caller can turn a zero into a
  /// zero-count row (which an older build would read as an empty "Other" —
  /// the ADR-0022 bug's exact shape).
  ///
  /// Dedup is by the external sample's UUID (stored in `healthKitSampleID`), so
  /// re-running an import — a reset anchor, a second device — inserts nothing
  /// new. Drinks route through `saveOrThrow` so an imported drink clears a
  /// same-day marker exactly like a logged one: evidence beats assertion,
  /// whichever app recorded the evidence.
  func importExternalSample(id: UUID, count: Double, loggedAt: Date, calendar: Calendar = .current) {
    guard count.isFinite else { return }
    if count == 0 {
      markAlcoholFreeFromHealth(sampleID: id, day: loggedAt, calendar: calendar)
      return
    }
    guard count > 0 else { return }
    guard entryForHealthSample(id) == nil else { return }
    try? saveOrThrow(
      .importedFromHealth(sampleID: id, count: count, loggedAt: loggedAt),
      calendar: calendar
    )
  }

  /// Records a day another app marked as zero drinks in Health as a no-alcohol
  /// day here, carrying the sample's id (ADR-0025).
  ///
  /// The standing rule holds unchanged: a day with entries refuses the marker.
  /// Once the sweep is over, the refusal is final for that sample — the
  /// anchor has passed it — which is the same deletion-over-dormancy trade
  /// `saveOrThrow` makes: a marker that came back the moment the entries were
  /// removed would assert abstinence for a day whose record was just "drinks,
  /// then none". Within a sweep, deletions go first (`applyExternalChanges`),
  /// so a correction made in the other app lands.
  ///
  /// A day already marked is left as it is, whoever marked it. The user's own
  /// marker stays theirs (no sample id, so a later deletion of the sample
  /// does not touch it), and a second zero sample on the same day — two apps,
  /// or one app twice — attaches to nothing.
  func markAlcoholFreeFromHealth(sampleID: UUID, day: Date, calendar: Calendar = .current) {
    guard alcoholFreeDay(forHealthSample: sampleID) == nil else { return }
    let startOfDay = calendar.startOfDay(for: day)
    guard drinks(on: startOfDay, calendar: calendar).isEmpty else { return }
    guard alcoholFreeDay(on: startOfDay) == nil else { return }
    context.insert(AlcoholFreeDay(day: startOfDay, recordedAt: day, healthKitSampleID: sampleID))
    try? context.save()
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

  /// Removes no-alcohol markers whose zero-count samples were deleted from
  /// Health (ADR-0025). The user's own markers carry no sample id and can
  /// never match; deletions are reported for every source, and only the
  /// mirror follows.
  func removeImportedMarkers(sampleIDs: [UUID]) {
    guard !sampleIDs.isEmpty else { return }
    for id in sampleIDs {
      // Every match: two devices can each mirror the same zero before CloudKit
      // merges, and a survivor would be a Health marker nothing can remove.
      let descriptor = FetchDescriptor<AlcoholFreeDay>(
        predicate: #Predicate { $0.healthKitSampleID == id }
      )
      for marker in (try? context.fetch(descriptor)) ?? [] {
        context.delete(marker)
      }
    }
    try? context.save()
  }

  func alcoholFreeDay(forHealthSample id: UUID) -> AlcoholFreeDay? {
    var descriptor = FetchDescriptor<AlcoholFreeDay>(
      predicate: #Predicate { $0.healthKitSampleID == id }
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
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

// MARK: - External samples

/// One external Health sample, reduced to the facts Health actually has.
///
/// Lives here rather than in `HealthKitService` because the repository — and
/// so the widget and the tests — must be able to take a sweep's worth of
/// them without importing HealthKit.
struct ExternalBeverageSample: Sendable, Equatable {
  let id: UUID
  let count: Double
  let loggedAt: Date

  init(id: UUID, count: Double, loggedAt: Date) {
    self.id = id
    self.count = count
    self.loggedAt = loggedAt
  }
}
