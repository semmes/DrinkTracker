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

  /// How long an undo stays available.
  ///
  /// Long enough to notice the bar, read it, and reach for it. Six seconds was
  /// noticeably too short in testing.
  private let window: Duration = .seconds(10)

  @ObservationIgnored private var expiry: Task<Void, Never>?

  func delete(_ drink: LoggedDrink, using store: DrinkStore) async {
    await store.delete(drink)
    recentlyDeleted = drink
    startExpiry()
  }

  func undo(using store: DrinkStore) async {
    guard let drink = recentlyDeleted else { return }
    clear()
    // Re-saving also writes a fresh HealthKit sample, replacing the one the
    // delete retired.
    await store.save(drink)
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
