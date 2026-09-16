import CoreData
import Foundation
import WidgetKit

/// Tells the home-screen widget to redraw at the two moments the phone's store
/// gains a drink the widget has not been told about (ADR-0047).
///
/// Every reload the phone had was tied to a write this device made: the app's
/// own saves in `DrinkStore`, a region change, and the widget's own ＋. A drink
/// that arrived from the watch or another device through CloudKit reloaded
/// nothing, so the widget kept whatever it last drew. The owner's device run on
/// 2026-09-16 shows exactly that: the watch's drink landed in the phone's store
/// at 17:55:59 and the widget still read 0 through an open, a return to the
/// home screen and a reopen, until the app's own log at 17:56:31 reloaded it.
///
/// So the app now also reloads:
///
/// - **when a CloudKit import finishes**, which is the moment the store changed.
///   On the phone only the app mirrors — the widget has no iCloud container —
///   so nothing the widget does can post this event, and a reload cannot cause
///   the next one. The watch needed a floor for that loop; this does not.
/// - **when the app leaves the foreground.** An iPhone's home-screen widget
///   cannot be seen while the app is in front, so this is the reload the reader
///   actually sees, and it reads the store after everything the app did while
///   it was open, imports included.
///
/// Reloading is all it does. It redraws a widget; it never asks CloudKit for
/// anything — `CloudKitSyncMonitor`'s rule, and ADR-0004's refusal of anything
/// that retries, forces or schedules a transfer, both stand.
enum WidgetReloads {
  nonisolated(unsafe) private static var observer: NSObjectProtocol?

  /// Idempotent, so the app may call it from `init` without guarding.
  static func start() {
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil,
      queue: .main
    ) { note in
      guard
        let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
          as? NSPersistentCloudKitContainer.Event,
        event.type == .import,
        // Each event posts twice, starting and ending; only the ending half
        // says whether the rows are in the store.
        event.endDate != nil
      else { return }
      guard event.succeeded else {
        // Recorded so that "no import happened" and "an import happened and
        // failed" read differently in the timeline — the question a stale
        // widget raises first.
        Diagnostics.appendTimeline(
          "import failed — \(event.error?.localizedDescription ?? "no reason given")"
        )
        return
      }
      reload(because: "import landed")
    }
  }

  /// Recorded, not acted on: the widget cannot be seen from inside the app, and
  /// a reload here would read the store before an import that is about to land.
  static func appBecameActive() {
    Diagnostics.appendTimeline("app active")
  }

  static func appLeftForeground() {
    reload(because: "app left the foreground")
  }

  /// Every reload the app process asks for goes through here, so each one
  /// leaves its reason in the timeline. A widget build with no reason beside
  /// it is then one the app did not ask for — the system's own, or an intent's.
  static func reload(because reason: String) {
    Diagnostics.appendTimeline("reload widget — \(reason)")
    WidgetCenter.shared.reloadAllTimelines()
  }
}
