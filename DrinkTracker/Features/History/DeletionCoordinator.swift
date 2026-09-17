import DrinkTrackerCore
import Foundation
import Observation

/// Deletes a drink and keeps it recoverable for a few seconds.
///
/// Shared by Today and History so the two behave identically. Restoring re-saves
/// the same `LoggedDrink`, and because `DrinkRepository.save` overwrites by id, an
/// undo puts the entry back exactly where it was rather than appending a copy.
@Observable
@MainActor
final class DeletionCoordinator {

  /// The drink still recoverable, if any. Drives the undo bar.
  private(set) var recentlyDeleted: LoggedDrink?

  /// Counts removals that wrote nothing, for a list to take as its identity.
  ///
  /// A destructive swipe action animates its row out before the removal has
  /// run, and when the removal then fails the data never changes, so nothing
  /// tells the list to put the row back: rendered on the iPhone 17 Pro
  /// simulator, History drew one of a day's two drinks under a header still
  /// counting two, and a later render hid the other one instead. A list
  /// keyed on this is rebuilt from its data when that happens.
  private(set) var failedRemovals = 0

  /// How long an undo stays available.
  ///
  /// Long enough to notice the bar, read it, and reach for it. Six seconds was
  /// noticeably too short in testing.
  private let window: Duration = .seconds(10)

  @ObservationIgnored private var expiry: Task<Void, Never>?

  /// Removes the drink and offers it back — unless the removal failed, in
  /// which case nothing was removed and there is nothing to offer (the store
  /// records why on the Diagnostics timeline).
  func delete(_ drink: LoggedDrink, using store: DrinkStore) async {
    guard let removed = try? await store.delete(drink) else {
      failedRemovals += 1
      return
    }
    // The stored value, not the caller's snapshot: its sample id is the one
    // the removal retired.
    recentlyDeleted = removed
    startExpiry()
  }

  func undo(using store: DrinkStore) async {
    guard let drink = recentlyDeleted else { return }
    clear()
    // Re-saving also writes a fresh HealthKit sample, replacing the one the
    // delete retired — when it did retire one. The value still carries its
    // sample id, and `DrinkStore.save` retires from that when the row is
    // gone, so an undone adopted import keeps the other app's sample and its
    // foreign id rather than getting a Tallyist sample beside it (ADR-0016).
    do {
      try await store.save(drink)
    } catch {
      // Nothing was written, so the drink is still only here. Offer it again
      // for a fresh window rather than dropping the one thing the reader
      // asked to have back.
      recentlyDeleted = drink
      startExpiry()
    }
  }

  func clear() {
    expiry?.cancel()
    expiry = nil
    recentlyDeleted = nil
  }

  private func startExpiry() {
    expiry?.cancel()
    expiry = Task { [window] in
      try? await Task.sleep(for: window)
      guard !Task.isCancelled else { return }
      recentlyDeleted = nil
    }
  }
}
