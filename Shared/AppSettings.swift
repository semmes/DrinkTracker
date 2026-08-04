import DrinkTrackerCore
import Foundation
import Observation

/// Preferences shared between the app and the widget.
///
/// Backed by the App Group's defaults rather than `.standard` so the widget reads
/// the same region the user picked in the app. Deliberately not CloudKit-backed —
/// the region setting is about the device's owner, and syncing it would be more
/// surprising than helpful on a shared iCloud account.
@Observable
@MainActor
final class AppSettings {

  var hasCompletedOnboarding: Bool {
    didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
  }

  /// The region the user picked. `nil` means they skipped the onboarding step and
  /// have never set one, which is distinct from having explicitly chosen the US.
  ///
  /// Whatever is set at onboarding persists until it is changed in Settings.
  var region: Region? {
    didSet {
      if let region {
        defaults.set(region.rawValue, forKey: Keys.region)
      } else {
        defaults.removeObject(forKey: Keys.region)
      }
    }
  }

  /// The definition all standard-drink math measures against.
  var effectiveRegion: Region { region ?? .unitedStates }

  /// Whether Today shows the by-type quick-add row and repeat control.
  ///
  /// Off by default: the primary surface is the count-first counter, and the
  /// typed path (beer/wine/spirit/other with size and strength) is a disclosure
  /// for people who want that granularity. Persisted so an advanced user opens
  /// it once and it stays open — a preference, not a mode they re-enter daily.
  var prefersDetailedLogging: Bool {
    didSet { defaults.set(prefersDetailedLogging, forKey: Keys.detailedLogging) }
  }

  /// True when the app is falling back to the US default rather than honouring an
  /// explicit choice. Settings uses this to show the value is only a default.
  var isUsingFallbackRegion: Bool { region == nil }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = AppGroup.defaults) {
    self.defaults = defaults
    self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    self.region = defaults.string(forKey: Keys.region).flatMap(Region.init(rawValue:))
    self.prefersDetailedLogging = defaults.bool(forKey: Keys.detailedLogging)
  }

  /// Region lookup for contexts without a live `AppSettings` — notably the widget's
  /// intent, which runs in another process and off the main actor.
  nonisolated static func storedRegion(
    defaults: UserDefaults = AppGroup.defaults
  ) -> Region {
    defaults.string(forKey: Keys.region).flatMap(Region.init(rawValue:)) ?? .unitedStates
  }

  private enum Keys {
    static let onboarding = "hasCompletedOnboarding"
    static let region = "region"
    static let detailedLogging = "prefersDetailedLogging"
  }
}
