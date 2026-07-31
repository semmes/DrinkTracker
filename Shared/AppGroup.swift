import Foundation
import SwiftData

/// The App Group that lets the app and the widget see the same drink log and the
/// same region setting.
///
/// Both targets carry this identifier in their entitlements. Everything shared
/// between them — the SwiftData store and `AppSettings` — is anchored here rather
/// than in each target's private container.
enum AppGroup {
  static let identifier = "group.com.example.DrinkTracker"

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
