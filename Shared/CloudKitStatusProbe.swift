import CloudKit
import Foundation

/// Asks CloudKit whether sync can actually work, and records the answer.
///
/// This exists because a device run showed that `SharedModelContainer.make()`
/// cannot answer the question. Opening the container with `cloudKitDatabase:
/// .automatic` **succeeds** with no iCloud account signed in — `ModelContainer(…)`
/// returns normally, and `NSCloudKitMirroringDelegate` fails some time later with
/// `CKAccountStatusNoAccount`, on its own schedule, into the console.
///
/// So the failure never reaches the `catch` in `make()`, the no-CloudKit fallback
/// rung never fires, and `Diagnostics.storeMode` reports the configuration that was
/// *requested* rather than the one that is working. Everything looks healthy while
/// nothing syncs — the exact class of silent failure the diagnostics exist to
/// surface, hiding inside the diagnostics themselves.
///
/// `accountStatus()` is the direct question, so this asks it directly.
enum CloudKitStatusProbe {

  /// Cheap: one round trip against the local account daemon, no network fetch.
  /// Called on launch and on every foreground, since the user can sign into iCloud
  /// while the app is in the background and nothing would otherwise notice.
  static func refresh() async {
    let container = CKContainer(identifier: AppGroup.iCloudContainerIdentifier)
    do {
      let status = try await container.accountStatus()
      Diagnostics.recordCloudKitStatus(describe(status))
      Diagnostics.recordCloudKitStatusCode(code(for: status))
    } catch {
      Diagnostics.recordCloudKitStatus("could not check — \(error.localizedDescription)")
      Diagnostics.recordCloudKitStatusCode("unknown")
    }
  }

  /// Stable keys for the release-facing Settings row, so UI copy lives in the
  /// view rather than being parsed back out of a diagnostic string.
  private static func code(for status: CKAccountStatus) -> String {
    switch status {
    case .available: "available"
    case .noAccount: "noAccount"
    case .restricted: "restricted"
    case .temporarilyUnavailable: "temporarilyUnavailable"
    case .couldNotDetermine: "unknown"
    @unknown default: "unknown"
    }
  }

  /// Phrased for the person reading Settings, not for the console.
  ///
  /// Each case says what it means for *their data*, because "restricted" on its own
  /// tells a user nothing about whether their drinks are being saved.
  private static func describe(_ status: CKAccountStatus) -> String {
    switch status {
    case .available:
      "syncing"
    case .noAccount:
      "no iCloud account — this device only"
    case .restricted:
      "restricted by device policy — this device only"
    case .couldNotDetermine:
      "could not determine — this device only, for now"
    case .temporarilyUnavailable:
      "temporarily unavailable — will retry"
    @unknown default:
      "unrecognised status (\(status.rawValue))"
    }
  }
}
