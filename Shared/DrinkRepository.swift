import DrinkTrackerCore
import Foundation
import SwiftData

/// Why a day could not be read — distinct from a day with nothing in it.
enum DayReadError: Error {
  /// The calendar could not produce the end of the day asked for.
  case unrepresentableDay
}

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
  /// missed tap and there is no UI to notice the missing entry — and by every
  /// other write that must be able to say it did not happen.
  ///
  /// **Both reads answer before anything changes, and a save that fails
  /// leaves nothing behind** (ADR-0004's third 2026-09-16 amendment). The
  /// reads used to run after the insert and through `try?`: on a store that
  /// could not be read the day's markers read as none, so nothing was
  /// deleted, the save failed, and the insert stayed pending in the context —
  /// where the next save that worked wrote a drink onto a day still marked
  /// no alcohol, the contradiction ADR-0011 forbids. An edit whose id read
  /// failed inserted a second row with the same id the same way.
  func saveOrThrow(_ drink: LoggedDrink, calendar: Calendar = .current) throws {
    let existing = try entryOrThrow(with: drink.id)
    // Evidence beats assertion: a drink landing on a day marked alcohol-free
    // removes the marker. Leaving it dormant would be worse than a visible
    // contradiction — it would resurrect the moment the entries were deleted,
    // claiming abstinence for a day the user just said had drinks. Sitting here
    // rather than in the UI means every write path gets it: the app, the
    // calendar backfill, and the widget's intent alike.
    // Every marker on the day, not the first: two can land on one day when
    // two devices act before CloudKit merges, and each contradicts the drink.
    let markers = try alcoholFreeDaysOrThrow(on: calendar.startOfDay(for: drink.loggedAt))

    if let existing {
      existing.apply(drink)
    } else {
      context.insert(DrinkEntry(drink))
    }
    for marker in markers {
      context.delete(marker)
    }
    try commit()
  }

  /// Saves, or puts the context back as it was and throws.
  ///
  /// Every write in this type ends here. A failed `ModelContext.save()` keeps
  /// its changes pending, and the context writes them on the next save that
  /// works — a drink the reader was never told had landed, arriving later
  /// beside the retry they made meanwhile. Rolling back makes a thrown error
  /// mean what it says: nothing changed. It discards every pending change in
  /// the context, not only this write's, which is safe because no write here
  /// leaves a change unsaved — the rule `DrinkStore.backfillHealthKit` keeps
  /// too, by recording each sample id as its own save.
  private func commit() throws {
    do {
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  // MARK: - The counter's ＋

  /// The drink the counter's ＋ logs next: one, by whichever seed the user
  /// chose (ADR-0023 and its day-memory revision) — under the default, a day
  /// starts at one standard drink and the count follows the most recent drink
  /// described *that day*; under the usual-drink seed, the type they log
  /// most. The history is fetched here, at execution time, so a tap that
  /// lands behind a just-described drink repeats it.
  ///
  /// The one implementation of the rule (ADR-0042): Today's ＋, the widget's
  /// `LogOneDrinkIntent` and the watch's ＋ all call this, and none of them
  /// builds the drink itself — a second copy is how the rule drifts, which is
  /// the bug the day sheet's `countSeedPreview` exists to prevent.
  ///
  /// **Throws when the history cannot be read, rather than seeding from an
  /// empty one** (ADR-0042's 2026-09-16 amendment). An empty history is a
  /// real answer — a day with nothing described starts at a standard drink —
  /// so a failed read passed off as one logs a drink the user did not
  /// describe: an untyped standard drink after they described a beer, which
  /// then becomes the day's newest entry and turns every later ＋ that day
  /// into standard drinks too; or, under the usual-drink seed, a beer at
  /// beer's defaults. The tap is reported as not saved instead.
  func nextQuickDrink(
    seed: DrinkDraft.CountSeed,
    region: Region,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) throws -> LoggedDrink {
    DrinkDraft
      .quickCount(1, from: try historyOrThrow(), seed: seed, region: region, at: date, calendar: calendar)
      .makeLoggedDrink(region: region)
  }

  /// The whole log, for a seed — never an empty one standing in for a read
  /// that failed.
  func historyOrThrow() throws -> [LoggedDrink] {
    try context.fetch(FetchDescriptor<DrinkEntry>()).loggedDrinks
  }

  /// When the day sheet's ＋ dates a drink on `day`: now for today, else
  /// noon or one second after the day's latest drink
  /// (`TrendSummary.backfillTimestamp`), so the new drink is the day's newest
  /// and ＋ then − gives back exactly what was there.
  ///
  /// Throws rather than reading the day as empty: an empty day is noon, so a
  /// failed read stamped a past day's drink *before* drinks it already had,
  /// and − then removed one of those instead of the drink just logged.
  func backfillTimestampOrThrow(on day: Date, calendar: Calendar = .current) throws -> Date {
    TrendSummary.backfillTimestamp(
      on: day,
      existing: try drinksOrThrow(on: day, calendar: calendar),
      calendar: calendar
    )
  }

  // MARK: - Bulk fill (ADR-0011)

  /// The drinks bulk fill writes on one day: `count` of the drink `history`
  /// seeds, at noon — or none, when the day already has a record.
  ///
  /// The sheet filters recorded days out before offering them, but it filters
  /// the calendar's query, and a query that failed its first fetch hands back
  /// no rows: every day in the run looked blank and every one was offered.
  /// So the rule ADR-0011 states — a day with any record is skipped, always —
  /// is also kept here, at write time, through reads that throw. `history`
  /// is read once by the caller before its loop (`historyOrThrow`), so every
  /// day gets the same drink rather than a seed that drifts as the loop's own
  /// writes change what is most recent.
  func bulkFillDrinks(
    _ count: Int,
    on day: Date,
    from history: [LoggedDrink],
    seed: DrinkDraft.CountSeed,
    region: Region,
    calendar: Calendar = .current
  ) throws -> [LoggedDrink] {
    guard count > 0 else { return [] }
    guard try drinksOrThrow(on: day, calendar: calendar).isEmpty,
          try !isMarkedAlcoholFreeOrThrow(day, calendar: calendar) else { return [] }
    let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    return DrinkDraft
      .quickCount(count, from: history, seed: seed, region: region, at: noon, calendar: calendar)
      .makeLoggedDrinks(region: region, calendar: calendar)
  }

  /// `nextQuickDrink`, saved — for the surfaces with no HealthKit of their
  /// own, the widget's intent and the watch. The phone's Today goes through
  /// `DrinkStore.save` instead, which also writes the Health sample; an entry
  /// saved here lands with no sample id and the app mirrors it on its next
  /// foreground (`DrinkStore.backfillHealthKit`).
  @discardableResult
  func logOneDrink(seed: DrinkDraft.CountSeed, region: Region) throws -> LoggedDrink {
    let drink = try nextQuickDrink(seed: seed, region: region)
    try saveOrThrow(drink)
    return drink
  }

  func delete(id: UUID) {
    _ = try? deleteOrThrow(id: id)
  }

  /// Removes the entry with this id and returns it as it was stored, or nil
  /// when there is no such entry. Throws when the entry cannot be read or the
  /// removal cannot be saved, having changed nothing.
  ///
  /// The stored value is what the caller retires from Health: the row's own
  /// sample id, not whatever a screen's snapshot of the drink carried.
  @discardableResult
  func deleteOrThrow(id: UUID) throws -> LoggedDrink? {
    guard let existing = try entryOrThrow(with: id) else { return nil }
    let removed = existing.logged
    context.delete(existing)
    try commit()
    return removed
  }

  func entry(with id: UUID) -> DrinkEntry? {
    try? entryOrThrow(with: id)
  }

  /// `entry(with:)`, for a write that must not read "could not look" as "no
  /// such entry" — which is an insert of a second row with the same id.
  func entryOrThrow(with id: UUID) throws -> DrinkEntry? {
    var descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.entryID == id }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  // MARK: - The Health sample a row points at

  /// Points the entry at the Health sample that now mirrors it — only if the
  /// entry still points where the caller last saw it, and still holds the
  /// facts the sample was written from.
  ///
  /// Two writers stamp sample ids, `DrinkStore.save` and
  /// `DrinkStore.backfillHealthKit`, and each writes its sample to Health
  /// *before* it stamps, across an await. A row written by the one can be
  /// picked up by the other in that window; unguarded, the second stamp
  /// overwrote the first and left its sample in Health mirroring nothing — a
  /// doubled drink there that nothing in the app can see, since Tallyist
  /// never imports its own samples. And a row edited in that window has new
  /// facts, so a sample written from the old ones would mirror a drink the
  /// log no longer holds. The comparison and the save run with no suspension
  /// between them, so on the main actor they cannot interleave.
  ///
  /// - Parameter drink: the drink as it was when its sample was written. Only
  ///   its facts and id are read; its own sample id is ignored.
  /// - Returns: `false` when the entry is gone, no longer points at
  ///   `expected`, or no longer holds `drink`'s facts. The caller's sample
  ///   then mirrors nothing, and retracting it is the caller's job.
  @discardableResult
  func recordHealthSample(_ sampleID: UUID?, for drink: LoggedDrink, replacing expected: UUID?) throws -> Bool {
    guard let entry = try entryOrThrow(with: drink.id),
          entry.healthKitSampleID == expected,
          Self.sameFacts(entry.logged, drink) else {
      return false
    }
    guard sampleID != expected else { return true }
    entry.healthKitSampleID = sampleID
    try commit()
    return true
  }

  /// Whether two values describe the same drink, whichever sample mirrors it.
  private static func sameFacts(_ lhs: LoggedDrink, _ rhs: LoggedDrink) -> Bool {
    var lhs = lhs
    var rhs = rhs
    lhs.healthKitSampleID = nil
    rhs.healthKitSampleID = nil
    return lhs == rhs
  }

  /// Everything logged on the given calendar day.
  func drinks(on day: Date, calendar: Calendar = .current) -> [LoggedDrink] {
    (try? drinksOrThrow(on: day, calendar: calendar)) ?? []
  }

  /// `drinks(on:)`, for a caller that must tell *nothing logged* from *could
  /// not read* — a surface that would otherwise draw a confident zero from a
  /// failed fetch. ADR-0004 names exactly that as the real defect: losing the
  /// store looks like an empty log. The home-screen widget and the watch
  /// complication read through this (ADR-0047), and so does every refusal
  /// that asks "does this day have drinks?" — the no-alcohol marker's, in
  /// both its user and its Health forms — because there a failed read passed
  /// off as an empty day *is* the answer that lets the write through.
  func drinksOrThrow(on day: Date, calendar: Calendar = .current) throws -> [LoggedDrink] {
    let start = calendar.startOfDay(for: day)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
      throw DayReadError.unrepresentableDay
    }
    let descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.loggedAt >= start && $0.loggedAt < end },
      sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
    return try context.fetch(descriptor).map(\.logged)
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
  ///
  /// **A day that cannot be read throws; it is never read as empty.** The
  /// refusal above is ADR-0011's backstop — the one check that holds whatever
  /// the view asked — and it used to read the day through `drinks(on:)`,
  /// which turns a failed fetch into no drinks. So a failed read let a day
  /// *with* drinks be marked; and when the save then failed too, the marker
  /// stayed inserted in the context, where the next save that worked wrote it
  /// (measured: a store damaged under an open connection, then restored).
  /// Nothing is inserted until both reads have answered.
  @discardableResult
  func markAlcoholFreeOrThrow(_ day: Date, calendar: Calendar = .current) throws -> Bool {
    let startOfDay = calendar.startOfDay(for: day)
    guard try drinksOrThrow(on: startOfDay, calendar: calendar).isEmpty else { return false }
    guard try !isMarkedAlcoholFreeOrThrow(startOfDay, calendar: calendar) else { return true }
    context.insert(AlcoholFreeDay(day: startOfDay))
    try commit()
    return true
  }

  /// Removes the user's own marker. A marker mirrored from another app's
  /// Health zero (ADR-0025) is left alone: HealthKit will not let this app
  /// delete that sample, so removing the mirror here would leave the two
  /// stores disagreeing for good — the same reason imported drinks are
  /// read-only (ADR-0014). Logging a drink on the day still clears it, via
  /// `saveOrThrow`: evidence beats assertion, whoever asserted.
  func unmarkAlcoholFree(_ day: Date, calendar: Calendar = .current) {
    try? unmarkAlcoholFreeOrThrow(day, calendar: calendar)
  }

  /// `unmarkAlcoholFree`, throwing when the day's markers cannot be read or
  /// their removal cannot be saved — having removed nothing.
  func unmarkAlcoholFreeOrThrow(_ day: Date, calendar: Calendar = .current) throws {
    let startOfDay = calendar.startOfDay(for: day)
    let own = try alcoholFreeDaysOrThrow(on: startOfDay).filter { !$0.isImportedFromHealth }
    guard !own.isEmpty else { return }
    for marker in own {
      context.delete(marker)
    }
    try commit()
  }

  func isMarkedAlcoholFree(_ day: Date, calendar: Calendar = .current) -> Bool {
    alcoholFreeDay(on: calendar.startOfDay(for: day)) != nil
  }

  /// `isMarkedAlcoholFree(_:)`, throwing where that answers `false` — so a
  /// face cannot draw a count and a band on a day recorded as no alcohol
  /// because the marker read failed.
  func isMarkedAlcoholFreeOrThrow(_ day: Date, calendar: Calendar = .current) throws -> Bool {
    let startOfDay = calendar.startOfDay(for: day)
    var descriptor = FetchDescriptor<AlcoholFreeDay>(
      predicate: #Predicate { $0.day == startOfDay }
    )
    descriptor.fetchLimit = 1
    return try !context.fetch(descriptor).isEmpty
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
    (try? alcoholFreeDaysOrThrow(on: startOfDay)) ?? []
  }

  /// `alcoholFreeDays(on:)`, for a write that clears a day: read as none, a
  /// failed fetch clears nothing and the drink lands beside the marker.
  func alcoholFreeDaysOrThrow(on startOfDay: Date) throws -> [AlcoholFreeDay] {
    let descriptor = FetchDescriptor<AlcoholFreeDay>(
      predicate: #Predicate { $0.day == startOfDay }
    )
    return try context.fetch(descriptor)
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
  ///
  /// **Throws at the first read or save that fails, and the caller then
  /// withholds the anchor** (ADR-0025's second 2026-09-16 amendment). The
  /// anchor used to advance whatever happened here, and every read here went
  /// through `try?` — so a deletion made in the other app while this store
  /// could not be read left its mirror, a drink or a marker Tallyist offers
  /// no way to remove, behind for good. Withheld, the next sweep offers the
  /// whole delta again, and applying it twice is harmless in all but one
  /// case: what already landed dedups by sample id, and a deletion finds
  /// nothing left to delete. The exception is a zero whose marker landed and
  /// was then cleared by a drink the reader logged and removed before the
  /// replay — nothing carries that sample's id any more, so the replay marks
  /// the day again, where a committed anchor would have left it blank
  /// (recorded in ADR-0025's second 2026-09-16 amendment).
  func applyExternalChanges(
    added: [ExternalBeverageSample],
    deletedIDs: [UUID],
    calendar: Calendar = .current
  ) throws {
    try removeImportedEntries(sampleIDs: deletedIDs)
    try removeImportedMarkers(sampleIDs: deletedIDs)
    for sample in added {
      try importExternalSample(id: sample.id, count: sample.count, loggedAt: sample.loggedAt, calendar: calendar)
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
  ///
  /// Throws when a read or the save fails, rather than dropping the sample: a
  /// sample dropped here is one the sweep's anchor would pass for good.
  func importExternalSample(id: UUID, count: Double, loggedAt: Date, calendar: Calendar = .current) throws {
    guard count.isFinite else { return }
    if count == 0 {
      try markAlcoholFreeFromHealth(sampleID: id, day: loggedAt, calendar: calendar)
      return
    }
    guard count > 0 else { return }
    guard try entryForHealthSample(id) == nil else { return }
    try saveOrThrow(
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
  ///
  /// A day whose drinks cannot be read is not marked — the same backstop as
  /// `markAlcoholFreeOrThrow`, where a failed read passed off as empty let
  /// the marker through. It throws rather than refusing, so the sweep
  /// withholds its anchor and the zero is offered again once the day can be
  /// read. (It used to be refused for good: the anchor advanced regardless,
  /// and the day stayed blank.)
  func markAlcoholFreeFromHealth(sampleID: UUID, day: Date, calendar: Calendar = .current) throws {
    guard try alcoholFreeDay(forHealthSample: sampleID) == nil else { return }
    let startOfDay = calendar.startOfDay(for: day)
    guard try drinksOrThrow(on: startOfDay, calendar: calendar).isEmpty else { return }
    guard try !isMarkedAlcoholFreeOrThrow(startOfDay, calendar: calendar) else { return }
    context.insert(AlcoholFreeDay(day: startOfDay, recordedAt: day, healthKitSampleID: sampleID))
    try commit()
  }

  /// Removes mirrored entries whose external samples were deleted from Health.
  ///
  /// Touches only count-based rows: a deleted sample that *this app* wrote means
  /// someone pruned the mirror in the Health app, and the log — the source of
  /// truth for the app's own entries — must not follow it.
  ///
  /// Every id is read before anything is deleted, so a read that fails partway
  /// leaves no deletion pending. And every match, as for markers: two devices
  /// can each mirror the same sample before CloudKit merges, and this removed
  /// only the first, leaving a read-only drink nothing could remove.
  func removeImportedEntries(sampleIDs: [UUID]) throws {
    guard !sampleIDs.isEmpty else { return }
    let mirrors = try sampleIDs
      .flatMap { id in
        try context.fetch(FetchDescriptor<DrinkEntry>(
          predicate: #Predicate { $0.healthKitSampleID == id }
        ))
      }
      .filter { $0.countedDrinks != nil }
    guard !mirrors.isEmpty else { return }
    for entry in mirrors {
      context.delete(entry)
    }
    try commit()
  }

  /// Removes no-alcohol markers whose zero-count samples were deleted from
  /// Health (ADR-0025). The user's own markers carry no sample id and can
  /// never match; deletions are reported for every source, and only the
  /// mirror follows.
  func removeImportedMarkers(sampleIDs: [UUID]) throws {
    guard !sampleIDs.isEmpty else { return }
    // Every match: two devices can each mirror the same zero before CloudKit
    // merges, and a survivor would be a Health marker nothing can remove.
    let mirrors = try sampleIDs.flatMap { id in
      try context.fetch(FetchDescriptor<AlcoholFreeDay>(
        predicate: #Predicate { $0.healthKitSampleID == id }
      ))
    }
    guard !mirrors.isEmpty else { return }
    for marker in mirrors {
      context.delete(marker)
    }
    try commit()
  }

  func alcoholFreeDay(forHealthSample id: UUID) throws -> AlcoholFreeDay? {
    var descriptor = FetchDescriptor<AlcoholFreeDay>(
      predicate: #Predicate { $0.healthKitSampleID == id }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  private func entryForHealthSample(_ id: UUID) throws -> DrinkEntry? {
    var descriptor = FetchDescriptor<DrinkEntry>(
      predicate: #Predicate { $0.healthKitSampleID == id }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
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
