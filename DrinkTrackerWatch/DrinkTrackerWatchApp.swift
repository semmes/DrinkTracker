import SwiftData
import SwiftUI

/// The watch app's entry point.
///
/// Opens the shared store through `SharedModelContainer.make()` — the same
/// ladder the phone and its widget run, so every process opens the store with
/// identical configuration (PRD invariant 5) — and degrades to memory the way
/// the phone does (ADR-0004) rather than crash-looping. On the wrist the store
/// is the only data path (the watch plan, "Architecture"): it fills from the
/// user's own CloudKit database, and Phase 3's counter writes to it.
@main
struct DrinkTrackerWatchApp: App {
  private let container: ModelContainer

  init() {
    do {
      container = try SharedModelContainer.make()
    } catch {
      // Launch anyway, recorded rather than swallowed: Phase 3's counter shows
      // the storage-failure line whenever the store mode says "IN MEMORY".
      Diagnostics.recordStoreMode("IN MEMORY — nothing will be saved — \(error)")
      container = try! ModelContainer(
        for: SharedModelContainer.schema,
        migrationPlan: DrinkTrackerMigrationPlan.self,
        configurations: ModelConfiguration(
          schema: SharedModelContainer.schema,
          isStoredInMemoryOnly: true
        )
      )
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(container)
  }
}
