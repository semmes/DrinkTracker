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
  /// Whether the store fell back to memory at launch. The counter reads this,
  /// the app's own knowledge of this launch, rather than reading the App
  /// Group's store-mode breadcrumb back. Until 2026-09-16 the complication's
  /// own container overwrote that key on every timeline build; only the two
  /// apps' launches write it now (ADR-0047), but a value this process holds
  /// still cannot be written over by anything else.
  private let isStoreInMemory: Bool
  private let storeChanges = StoreChangeReloader()

  init() {
    do {
      let opened = try SharedModelContainer.open()
      container = opened.container
      Diagnostics.recordStoreMode(opened.mode)
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
///
/// The notification is also how this app learns of a drink the complication's
/// ＋ wrote. The complication does not mirror (ADR-0055), so that drink reaches
/// CloudKit only through this app's own mirroring, which TN3163 says schedules
/// an export on a context save or on a remote change it observes while it
/// runs. Whether a launch or a push wake exports a drink the complication wrote
/// while this app was not running is not documented and not yet observed on a
/// device; ADR-0055 names that as the check before 1.4 ships.
/// Every notification is handled on the main queue, so the state below needs
/// no lock of its own; `@MainActor` rather than a lock is also what keeps the
/// reload off whatever thread Core Data posts from.
@MainActor
final class StoreChangeReloader {
  private var pending: Task<Void, Never>?
  private var lastReload: Date?
  private var observer: NSObjectProtocol?

  /// A floor between reloads. The notification fires for *any* writer to the
  /// store file. It was written for a loop: the complication's own container,
  /// opened on every timeline build, mirrored and wrote CloudKit bookkeeping of
  /// its own, so a reload could post the notification that asked for the next
  /// one. From 1.4 the complication does not mirror (ADR-0055), so a timeline
  /// build only reads and that writer is gone; no remaining one has been
  /// measured. The floor stays until it is: it still rate-limits reloads during
  /// this app's own import and export bursts, and shortening it is the face's
  /// own latency, a decision of its own. The face is never more than this far
  /// behind a change the app is running for, and a reload on every raise
  /// covers the rest.
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
