import DrinkTrackerCore
import Foundation
import SwiftData

/// All writes to the drink log from inside the app.
///
/// Persistence itself lives in the shared `DrinkRepository`; this adds the parts
/// only the app can do — mirroring to HealthKit, and retiring the old Health sample
/// when an entry is edited.
///
/// **The log is written first, and Health follows it** (ADR-0004's third
/// 2026-09-16 amendment). A row waiting for its sample is a state the app
/// already finishes on its own — it is how every drink the widget and the
/// watch log arrives, and `backfillHealthKit` mirrors it. A sample for a drink
/// the log does not hold is not: Tallyist never imports its own samples, so
/// nothing in the app can see it, and Health's count is simply wrong for good.
/// The save used to write Health first and then swallow a store save that
/// failed, which is how the second state was reached.
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
  /// Throws, having written nothing to the log or to Health, when the entry
  /// cannot be read or the save fails; the failure is on the Diagnostics
  /// timeline.
  @discardableResult
  func save(_ drink: LoggedDrink) async throws -> LoggedDrink {
    var drink = drink

    // Retire the old sample before writing the replacement, so an edit never
    // leaves two beverages behind in Health.
    //
    // Unless the old sample is not ours to retire. An adopted import
    // (ADR-0016) keeps the other app's sample id as its dedup key and its
    // backfill guard; overwriting that id let a re-delivered sample insert a
    // duplicate row, and writing our own sample doubled the drink in Health.
    // The same holds while Health is not authorized: the old sample is still
    // there, so the row keeps pointing at it rather than entering the
    // backfill queue and being mirrored a second time when access returns.
    // Either way nothing new is written, and the next authorized edit of a
    // Tallyist-owned row retires its sample as before.
    //
    // Which sample that is comes from the stored row — or, when the row is
    // already gone, from the value itself. Remove → Undo re-saves the deleted
    // `LoggedDrink` after the hard delete, so reading only the row sent every
    // undo down the fresh-sample path: an undone adopted import got a
    // Tallyist sample beside the other app's and lost its foreign id. The
    // decision is `HealthSampleRetirement` (tier 1); a draft's
    // `makeLoggedDrink` never carries a sample id, so only a value read back
    // from the store can supply one here.
    //
    // A throwing read: an entry that could not be read is not a new drink.
    let retirement: HealthSampleRetirement
    do {
      retirement = HealthSampleRetirement(
        existingSampleID: try repository.entryOrThrow(with: drink.id)?.healthKitSampleID,
        incomingSampleID: drink.healthKitSampleID
      )
    } catch {
      Diagnostics.appendTimeline("app save not written — entry unreadable: \(error)")
      throw error
    }

    // The log first. Until Health answers, the row keeps pointing at the
    // sample it already mirrors — none, for a new drink, which is the state a
    // widget-logged drink waits in for backfill.
    drink.healthKitSampleID = retirement.sampleToRetire
    do {
      try repository.saveOrThrow(drink)
    } catch {
      Diagnostics.appendTimeline("app save not written: \(error)")
      throw error
    }
    WidgetReloads.reload(because: "app saved a drink")

    // Then Health.
    let written = drink.healthKitSampleID
    if let oldSampleID = retirement.sampleToRetire {
      switch retirement.resolution(after: await health.deleteSample(id: oldSampleID)) {
      case .writeFresh:
        drink.healthKitSampleID = await health.save(drink)
      case .keep:
        return drink
      }
    } else {
      drink.healthKitSampleID = await health.save(drink)
    }
    guard drink.healthKitSampleID != written else { return drink }

    // Then the row learns which sample mirrors it — unless something else
    // mirrored, edited or removed it while Health answered, in which case this
    // sample mirrors nothing and goes (`recordHealthSample`). A save that
    // fails here does not undo the drink: it is in the log, which is the
    // record. The sample goes instead, so Health never holds one the row does
    // not name; for a new drink the row is still unsampled and backfill
    // mirrors it later, and for an edit Health lacks the drink until its next
    // edit.
    let recorded: Bool
    do {
      recorded = try repository.recordHealthSample(
        drink.healthKitSampleID, for: drink, replacing: written
      )
    } catch {
      Diagnostics.appendTimeline("Health sample not recorded on the row: \(error)")
      recorded = false
    }
    if !recorded {
      if let orphan = drink.healthKitSampleID {
        await health.deleteSample(id: orphan)
      }
      drink.healthKitSampleID = written
    }
    return drink
  }

  /// Saves several drinks in one go, returning the last for the "just logged" line.
  ///
  /// Each is written individually so every one gets its own HealthKit sample and
  /// stays separately editable.
  ///
  /// Throws only when nothing was saved. A failure partway leaves the earlier
  /// drinks written, and saying the whole thing failed would invite the retry
  /// that writes them twice — the rule `LogDrinkIntent.write` states for Siri.
  @discardableResult
  func save(_ drinks: [LoggedDrink]) async throws -> LoggedDrink? {
    var saved: LoggedDrink?
    for drink in drinks {
      do {
        saved = try await save(drink)
      } catch {
        guard saved != nil else { throw error }
        return saved
      }
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
  func adopt(_ adopted: LoggedDrink) throws -> LoggedDrink {
    do {
      try repository.saveOrThrow(adopted)
    } catch {
      Diagnostics.appendTimeline("adoption not written: \(error)")
      throw error
    }
    WidgetReloads.reload(because: "app adopted a Health drink")
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

  /// Removes a drink from the log, then retires its Health sample — in that
  /// order, for the reason the type's comment gives.
  ///
  /// Returns the drink as it was stored, whose sample id is the one retired,
  /// so an undo re-saves exactly that. Throws, having removed nothing from
  /// either, when the entry cannot be read or the removal cannot be saved. It
  /// used to retire the sample first and then swallow a failed removal, which
  /// left a row pointing at a sample Health no longer had — a drink backfill
  /// never mirrors again, because its id is not nil.
  @discardableResult
  func delete(_ drink: LoggedDrink) async throws -> LoggedDrink {
    let removed: LoggedDrink
    do {
      removed = try repository.deleteOrThrow(id: drink.id) ?? drink
    } catch {
      Diagnostics.appendTimeline("app removal not written: \(error)")
      throw error
    }
    if let sampleID = removed.healthKitSampleID {
      await health.deleteSample(id: sampleID)
    }
    WidgetReloads.reload(because: "app removed a drink")
    return removed
  }

  /// Mirrors anything logged outside the app — currently the widget — into Health.
  ///
  /// The widget writes to SwiftData only, because writing to Health from a
  /// short-lived extension process is unreliable. Those entries land with no sample
  /// id, and this sweeps them up the next time the app is foregrounded.
  ///
  /// Cheap to call repeatedly: with Health denied nothing is ever written, the ids
  /// stay nil, and each pass is one fetch that changes nothing.
  ///
  /// Each sample id is saved as soon as Health answers, never held unsaved
  /// across the next await: a store write that fails meanwhile rolls the
  /// context back (`DrinkRepository`'s `commit`), and an id discarded that way
  /// would be mirrored a second time on the next sweep. The ids are read as
  /// values, not models, so a row removed while Health answers is a missed
  /// compare rather than a write to a deleted model.
  func backfillHealthKit() async {
    guard health.authorization == .authorized else { return }
    for id in repository.awaitingHealthKitSync().map(\.entryID) {
      // Read again at its turn, never from the list above: an earlier turn's
      // Health write suspends, and meanwhile a save may have mirrored this
      // row, or an edit changed what it says.
      guard let row = try? repository.entryOrThrow(with: id),
            row.healthKitSampleID == nil else { continue }
      let drink = row.logged
      guard let sampleID = await health.save(drink) else { continue }
      do {
        // Only if the row still has no sample and still says what the sample
        // was written from: `save` may have mirrored it, or the reader edited
        // or removed it, while Health answered.
        guard try repository.recordHealthSample(sampleID, for: drink, replacing: nil) else {
          await health.deleteSample(id: sampleID)
          continue
        }
      } catch {
        await health.deleteSample(id: sampleID)
        Diagnostics.appendTimeline("Health backfill stopped: \(error)")
        return
      }
    }
  }

  /// The other direction: mirrors alcohol data other apps put in Health into the
  /// log — a positive count as a count-based entry (ADR-0014), a zero as a
  /// no-alcohol marker (ADR-0025) — and removes either kind of mirror when its
  /// sample is deleted at the source.
  ///
  /// Incremental and idempotent — the anchored query returns only changes, and
  /// the repository dedups by sample UUID — so it rides the same foreground
  /// sweep as `backfillHealthKit`. The two never touch the same rows: backfill
  /// writes entries with no sample id, imports arrive with one.
  func syncFromHealth() async {
    guard let delta = await health.fetchExternalChanges() else { return }
    // The repository owns the order (deletions first — see
    // `applyExternalChanges`); the anchor advances only once it has applied
    // everything, so a sweep cut short replays rather than skips — and so
    // does a sweep whose reads or saves failed, which is why a throw here
    // withholds the commit (ADR-0025's second 2026-09-16 amendment).
    do {
      try repository.applyExternalChanges(added: delta.added, deletedIDs: delta.deletedIDs)
      health.commit(delta)
    } catch {
      Diagnostics.appendTimeline("Health changes not applied, anchor kept: \(error)")
    }
    // Either way: a sweep that stopped partway may still have changed the log.
    WidgetReloads.reload(because: "Health changes applied")
  }
}
