import Foundation
import SwiftData

/// The App Group that lets the app and the widget see the same drink log and the
/// same region setting.
///
/// Both targets carry this identifier in their entitlements. Everything shared
/// between them — the SwiftData store and `AppSettings` — is anchored here rather
/// than in each target's private container.
enum AppGroup {
  /// Derived from the running bundle rather than hardcoded.
  ///
  /// The entitlements declare `group.$(BUNDLE_ID_PREFIX).DrinkTracker`, which is
  /// built from the same prefix as the bundle identifiers in `Signing.xcconfig`.
  /// Computing it here keeps a literal from drifting out of step with that value
  /// — a mismatch wouldn't fail to build, it would just silently give the app and
  /// the widget two different stores.
  ///
  /// The widget's bundle id is the app's plus `.Widget`, so the extension drops
  /// that suffix to arrive at the same group as its host app.
  static let identifier: String = {
    var bundleID = Bundle.main.bundleIdentifier ?? ""
    if bundleID.hasSuffix(widgetSuffix) {
      bundleID = String(bundleID.dropLast(widgetSuffix.count))
    }
    return "group." + bundleID
  }()

  /// Must match the widget target's `PRODUCT_BUNDLE_IDENTIFIER` suffix.
  private static let widgetSuffix = ".Widget"

  /// The iCloud container, derived the same way the App Group is.
  ///
  /// The entitlement declares `iCloud.$(BUNDLE_ID_PREFIX).DrinkTracker`, which is
  /// the host app's bundle identifier with an `iCloud.` prefix — so this computes
  /// it rather than repeating the literal, for the same reason `identifier` does.
  static var iCloudContainerIdentifier: String {
    var bundleID = Bundle.main.bundleIdentifier ?? ""
    if bundleID.hasSuffix(widgetSuffix) {
      bundleID = String(bundleID.dropLast(widgetSuffix.count))
    }
    return "iCloud." + bundleID
  }

  /// Defaults visible to both targets.
  ///
  /// Falls back to `.standard` if the group is unavailable, which happens when the
  /// entitlement isn't provisioned. The app still runs in that case; the widget
  /// just won't observe a region change until signing is set up properly.
  static var defaults: UserDefaults {
    UserDefaults(suiteName: identifier) ?? .standard
  }

  /// Whether the shared container is actually reachable.
  ///
  /// Useful as a diagnostic: if this is false, the app and widget are silently
  /// reading different stores.
  static var isAvailable: Bool {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
  }
}

// MARK: - Diagnostics

/// A breadcrumb the widget extension can leave for the app to read.
///
/// The extension is a separate, short-lived process whose console output is
/// effectively unreadable from the simulator, so this is the practical way to see
/// whether a widget button actually ran. Read it with
/// `AppGroup.defaults.string(forKey: Diagnostics.lastWidgetLogKey)`.
enum Diagnostics {
  static let lastWidgetLogKey = "lastWidgetLog"

  static func record(_ step: String) {
    AppGroup.defaults.set(step, forKey: lastWidgetLogKey)
  }

  /// The last thing the widget's log intent did, if it has ever run.
  static var lastWidgetLog: String? {
    AppGroup.defaults.string(forKey: lastWidgetLogKey)
  }

  static let intentBuildKey = "lastIntentBuild"

  /// Records that a `LogDrinkIntent` was *constructed*, and by which process.
  ///
  /// Separate key from `lastWidgetLog` on purpose: construction and execution are
  /// different events, and one overwriting the other is what made the last round of
  /// this inconclusive. Together they bisect the remaining possibilities —
  ///
  /// - build absent → the widget never rendered its buttons at all
  /// - build present, `lastWidgetLog` absent → the tap never reached `perform()`,
  ///   which is dispatch or parameter resolution
  /// - both present → the intent ran, and the fault is in what it did
  ///
  /// Diagnostic scaffolding. It writes on every timeline render, which is why it
  /// records something cheap.
  static func recordIntentBuild(_ description: String) {
    AppGroup.defaults.set(description, forKey: intentBuildKey)
  }

  static var lastIntentBuild: String? {
    AppGroup.defaults.string(forKey: intentBuildKey)
  }

  static let storeModeKey = "storeMode"

  /// Which configuration the shared store was last opened with.
  ///
  /// "requested" is doing real work in that string. Opening with CloudKit enabled
  /// says nothing about whether mirroring then succeeded — see `cloudKitStatus`.
  ///
  /// Both degraded modes are invisible from the UI otherwise: losing CloudKit
  /// looks exactly like "nothing has synced yet", and losing the store entirely
  /// looks like an empty log. Recording the mode is what makes them
  /// distinguishable after the fact.
  static func recordStoreMode(_ mode: String) {
    AppGroup.defaults.set(mode, forKey: storeModeKey)
  }

  static var storeMode: String? {
    AppGroup.defaults.string(forKey: storeModeKey)
  }

  static let cloudKitStatusKey = "cloudKitStatus"

  /// Whether CloudKit mirroring is *actually* working, as opposed to requested.
  ///
  /// These are different questions, which a device run made obvious. Opening the
  /// container with `cloudKitDatabase: .automatic` succeeds even with no iCloud
  /// account: `ModelContainer(…)` returns normally and `NSCloudKitMirroringDelegate`
  /// fails afterwards, asynchronously, with `CKAccountStatusNoAccount`. So
  /// `storeMode` can only ever report what was asked for — it is written before
  /// the answer exists.
  ///
  /// This is the answer, and it has to be fetched separately.
  static func recordCloudKitStatus(_ status: String) {
    AppGroup.defaults.set(status, forKey: cloudKitStatusKey)
  }

  static var cloudKitStatus: String? {
    AppGroup.defaults.string(forKey: cloudKitStatusKey)
  }

  static let cloudKitStatusCodeKey = "cloudKitStatusCode"

  /// Machine-readable form of the same answer, for the release-facing Settings
  /// row — UI copy maps from this rather than parsing the diagnostic string.
  static func recordCloudKitStatusCode(_ code: String) {
    AppGroup.defaults.set(code, forKey: cloudKitStatusCodeKey)
  }

  static var cloudKitStatusCode: String? {
    AppGroup.defaults.string(forKey: cloudKitStatusCodeKey)
  }

  /// Whether the store fell back to memory — the one state where nothing at all
  /// is being saved. Surfaced in release builds, not just diagnostics.
  static var isStoreInMemory: Bool {
    storeMode?.hasPrefix("IN MEMORY") == true
  }

  /// Whether the diagnostics UI should be shown.
  ///
  /// Debug builds always. **TestFlight builds too**, which is the point: the widget
  /// dispatch question can only be answered on a real device, and a tester holding a
  /// Release build has no way to read the breadcrumb — so the only report they can
  /// make is "nothing happened", which is precisely the answer that distinguishes
  /// nothing. A build that can't be diagnosed can't be tested.
  ///
  /// App Store builds never. TestFlight is identified by its sandbox receipt, which
  /// is the standard signal and the only one that separates TestFlight from a
  /// production install — both are Release, so `#if DEBUG` cannot tell them apart.
  static var isVisible: Bool {
    #if DEBUG
    return true
    #else
    return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    #endif
  }
}

// MARK: - Shared store

enum SharedModelContainer {
  static let schema = Schema([DrinkEntry.self, AlcoholFreeDay.self])

  /// Where the store lives.
  ///
  /// Identical for every configuration below. The App Group is what makes the app
  /// and the widget one app, so it is never the thing a fallback gives up.
  private static var groupContainer: ModelConfiguration.GroupContainer {
    AppGroup.isAvailable ? .identifier(AppGroup.identifier) : .automatic
  }

  private static func configuration(
    cloudKit: ModelConfiguration.CloudKitDatabase
  ) -> ModelConfiguration {
    ModelConfiguration(schema: schema, groupContainer: groupContainer, cloudKitDatabase: cloudKit)
  }

  /// Builds the container both targets open.
  ///
  /// Deliberately takes no options. The app and the widget must open the store
  /// with *identical* configuration: a CloudKit-mirrored store opened without
  /// CloudKit will still read, but writes fail silently, which cost real debugging
  /// time when the widget's one-tap log appeared to do nothing. Keeping a single
  /// code path makes that divergence impossible to reintroduce.
  ///
  /// That is also why the CloudKit fallback lives *here* rather than at the call
  /// site. The app used to carry its own fallback that dropped the group container
  /// as well as CloudKit, while the widget had no fallback at all — so one iCloud
  /// failure sent the app to a private store and left the widget with no store,
  /// which is precisely the silent split this type exists to prevent. One ladder,
  /// both processes.
  ///
  /// Losing sync is a degradation; losing the widget is a broken feature. So the
  /// fallback keeps the App Group and gives up only the mirroring.
  ///
  /// **Unverified (Tier 4, see docs/PRD.md §4):** whether a store that *was*
  /// mirrored reopens cleanly without CloudKit. Both processes now run the same
  /// ladder, so they agree at any given moment, but two processes opening the
  /// store while iCloud availability is changing could still land on different
  /// rungs. Confirming that needs a device.
  static func make() throws -> ModelContainer {
    do {
      let container = try ModelContainer(
        for: schema,
        configurations: configuration(cloudKit: .automatic)
      )
      Diagnostics.recordStoreMode("shared, CloudKit requested")
      return container
    } catch {
      let container = try ModelContainer(
        for: schema,
        configurations: configuration(cloudKit: .none)
      )
      Diagnostics.recordStoreMode("shared, no CloudKit — \(error)")
      return container
    }
  }
}
