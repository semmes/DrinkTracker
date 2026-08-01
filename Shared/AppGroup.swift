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
}

// MARK: - Shared store

enum SharedModelContainer {
  static let schema = Schema([DrinkEntry.self])

  /// Builds the container both targets open.
  ///
  /// Deliberately takes no options. The app and the widget must open the store
  /// with *identical* configuration: a CloudKit-mirrored store opened without
  /// CloudKit will still read, but writes fail silently, which cost real debugging
  /// time when the widget's one-tap log appeared to do nothing. Keeping a single
  /// code path makes that divergence impossible to reintroduce.
  static func make() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: schema,
      groupContainer: AppGroup.isAvailable ? .identifier(AppGroup.identifier) : .automatic,
      cloudKitDatabase: .automatic
    )
    return try ModelContainer(for: schema, configurations: configuration)
  }
}
