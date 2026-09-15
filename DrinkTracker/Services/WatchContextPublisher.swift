import DrinkTrackerCore
import Foundation
import WatchConnectivity

/// The phone's half of the settings bridge (watch Phase 2, ADR-0041).
///
/// Region and counter seed live in the App Group defaults, which are per device
/// by construction and deliberately not CloudKit-backed (`AppSettings`' own
/// reasoning: two people can share an iCloud account). A paired watch is the
/// same person on the same wrist, so for it the two values cross here — as an
/// application context, which is latest-value-wins and delivered when the
/// watch is next reachable, exactly the semantics a settings mirror wants.
/// Nothing else crosses: the log travels through the user's CloudKit database,
/// and this channel never carries a row.
///
/// It publishes at three moments: when the session activates, when the app
/// comes to the foreground, and when either value changes in `AppSettings`
/// (through `watchBridge`, installed at launch). The first two read the App
/// Group defaults through the same nonisolated readers the widget's intent
/// uses, so they can run on WatchConnectivity's own queue with no hop to the
/// main actor; the third is handed the values by the setter.
final class WatchContextPublisher: NSObject, WCSessionDelegate, @unchecked Sendable {
  static let shared = WatchContextPublisher()

  private override init() {
    super.init()
  }

  /// Once, at launch. Activation completes asynchronously and publishes then;
  /// `WCSession` is unsupported on iPad, where this is a no-op.
  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  /// The phone's current values as the watch should see them: the effective
  /// region (the US fallback when none was chosen, which is what the phone
  /// itself computes with) and the counter seed.
  func publishCurrent(now: Date = .now) {
    publish(WatchContext(
      region: AppSettings.storedRegion(),
      counterSeed: AppSettings.storedCounterSeed(),
      sentAt: now
    ))
  }

  func publish(_ context: WatchContext) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    // Before activation completes there is nothing to send on; the completion
    // publishes the current values itself.
    guard session.activationState == .activated else { return }
    do {
      try session.updateApplicationContext(context.dictionary)
      Diagnostics.recordWatchContextSent(
        "\(context.sentAt.formatted(.iso8601)) · \(context.region.rawValue) · \(context.counterSeed.rawValue)"
      )
    } catch {
      // The two facts that explain almost every failure: no watch paired, or a
      // watch whose companion install of this app has not happened yet.
      Diagnostics.recordWatchContextSent(
        "failed — \(error.localizedDescription) (paired: \(session.isPaired), "
          + "watch app installed: \(session.isWatchAppInstalled))"
      )
    }
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated else { return }
    publishCurrent()
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  /// The paired watch changed. Activating again is what iOS asks for, and the
  /// completion then publishes to the new one.
  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
