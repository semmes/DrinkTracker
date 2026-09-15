import DrinkTrackerCore
import Foundation
import WatchConnectivity
import WidgetKit

/// The watch's half of the settings bridge (Phase 2, ADR-0041).
///
/// Receives the phone's region and counter seed and writes them where every
/// reader on the watch already looks — the App Group defaults, under the keys
/// `AppSettings` owns — so `AppSettings.storedRegion()` and
/// `storedCounterSeed()` answer the same on the wrist as on the phone with no
/// code of their own, and the complication (Phase 6) reads the right region
/// the way the home-screen widget does.
///
/// A missing or unreadable payload means keep what you have, never reset to
/// the default: a watch that briefly read an empty context and reverted to the
/// US would be a worse failure than one that kept a stale but correct region.
/// The codec that enforces that is `WatchContext`, tier-1 tested. This channel
/// never writes a row.
extension Notification.Name {
  /// Posted on the main queue after a context from the phone has been written
  /// into the App Group — the region or the counter seed may have changed, and
  /// every figure on screen is expressed in the region (PRD invariant 3).
  static let watchContextDidChange = Notification.Name("DrinkTrackerWatch.watchContextDidChange")
}

final class WatchContextStore: NSObject, WCSessionDelegate, @unchecked Sendable {
  static let shared = WatchContextStore()

  private override init() {
    super.init()
  }

  /// Once, at launch. The most recent context the phone sent is waiting in the
  /// session whether or not this app was running when it was sent, and the
  /// activation completion applies it.
  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  /// Writes a readable context into the App Group, tells the complication and
  /// any view that is showing a figure; ignores anything else.
  func apply(_ dictionary: [String: Any]) {
    guard let context = WatchContext(dictionary: dictionary) else { return }
    AppSettings.store(region: context.region)
    AppSettings.store(counterSeed: context.counterSeed)
    Diagnostics.recordWatchContextReceived(sentAt: context.sentAt)
    // The complication's captions are in the region's unit, captured at its
    // last timeline build (Phase 6); the same reload the phone does for its
    // widget on a region change.
    WidgetCenter.shared.reloadAllTimelines()
    // The App Group defaults are not observable, so a view already on screen
    // would keep the old region until something else redrew it — the first
    // pair test showed exactly that on the debug line. Delivered on the main
    // queue, the way `.NSCalendarDayChanged` reaches `TodayView`.
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .watchContextDidChange, object: nil)
    }
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated else { return }
    apply(session.receivedApplicationContext)
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    apply(applicationContext)
  }
}
