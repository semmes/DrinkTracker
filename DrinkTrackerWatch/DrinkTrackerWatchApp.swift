import CoreData
import SwiftData
import SwiftUI
import WidgetKit

/// The watch app's entry point.
///
/// Opens the shared store through `SharedModelContainer.make()` — the same
/// ladder the phone and its widget run, so every process opens the store with
/// identical configuration (PRD invariant 5) — and degrades to memory the way
/// the phone does (ADR-0004) rather than crash-looping. On the wrist the store
/// is the only data path (ADR-0041): it fills from the user's own CloudKit
/// database, and the counter writes to it.
///
/// Also activates the settings bridge (Phase 2, ADR-0041): the phone's region
/// and counter seed arrive over WatchConnectivity and land in the App Group
/// defaults, where every reader on the watch already looks.
///
/// And keeps the face honest (Phase 6, ADR-0046): a drink logged on the phone
/// reaches this store by CloudKit a few seconds later and updates the
/// counter's query, but nothing would reload the complication until midnight
/// — so a store change from outside this process reloads every timeline.
@main
struct DrinkTrackerWatchApp: App {
  private let container: ModelContainer
  /// Whether the store fell back to memory at launch. The counter reads this
  /// rather than the App Group's store-mode breadcrumb, which the
  /// complication's own `SharedModelContainer.make()` also writes.
  private let isStoreInMemory: Bool
  private let storeChanges = StoreChangeReloader()

  init() {
    do {
      container = try SharedModelContainer.make()
      isStoreInMemory = false
    } catch {
      // Launch anyway, recorded rather than swallowed: the counter shows the
      // storage-failure strip whenever the store is in memory.
      Diagnostics.recordStoreMode("IN MEMORY — nothing will be saved — \(error)")
      container = try! ModelContainer(
        for: SharedModelContainer.schema,
        migrationPlan: DrinkTrackerMigrationPlan.self,
        configurations: ModelConfiguration(
          schema: SharedModelContainer.schema,
          isStoredInMemoryOnly: true
        )
      )
      isStoreInMemory = true
    }
    WatchContextStore.shared.activate()
    storeChanges.start()
    // The wrist's only data path is CloudKit (ADR-0041), so whether it is
    // moving is the one thing worth recording about it.
    CloudKitSyncMonitor.start()
  }

  var body: some Scene {
    WindowGroup {
      CounterView(isStoreInMemory: isStoreInMemory)
    }
    .modelContainer(container)
  }
}

/// Reloads the complication's timelines when the store changes underneath
/// the app — a CloudKit import of the phone's writes, which arrives as a
/// burst of remote-change notifications and is coalesced into one reload.
/// Nothing is written, nothing is remembered; the face simply re-reads.
///
/// Covers the app while it runs, and while the system runs it in the
/// background for a CloudKit push (the `remote-notification` background
/// mode). An evening logged entirely on the phone with the watch app never
/// launched still reaches the face only at the next reload — recorded in
/// ADR-0046 as the residual.
/// Every notification is handled on the main queue, so the state below needs
/// no lock of its own; `@MainActor` rather than a lock is also what keeps the
/// reload off whatever thread Core Data posts from.
@MainActor
final class StoreChangeReloader {
  private var pending: Task<Void, Never>?
  private var lastReload: Date?
  private var observer: NSObjectProtocol?

  /// A floor between reloads. The notification fires for *any* writer to the
  /// store file, and the complication's own container — opened on every
  /// timeline build — writes CloudKit bookkeeping of its own, so a reload
  /// can post the notification that would ask for the next one. The floor
  /// breaks that loop; the face is never more than this far behind a change
  /// the app is running for, and a reload on every raise covers the rest.
  private static let minimumInterval: TimeInterval = 60

  func start() {
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.scheduleReload() }
    }
  }

  private func scheduleReload() {
    pending?.cancel()
    pending = Task { @MainActor in
      // Coalesce the burst a CloudKit import arrives as.
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      // Wait the floor out rather than dropping the change. Dropping was the
      // first shape and it was wrong: a change arriving inside the floor is
      // exactly the phone's next drink, and it would have stayed off the face
      // until something else asked. The cost of deferring instead is that a
      // reload which provokes its own notification settles into one reload a
      // minute while the app is open — the cadence the counter's own
      // `TimelineView` already runs at.
      if let lastReload {
        let since = Date().timeIntervalSince(lastReload)
        if since < Self.minimumInterval {
          try? await Task.sleep(for: .seconds(Self.minimumInterval - since))
          guard !Task.isCancelled else { return }
        }
      }
      lastReload = Date()
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
