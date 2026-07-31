import DrinkTrackerCore
import Foundation
import Observation

/// Small, local-only preferences. Deliberately not CloudKit-backed — the region
/// setting is about the device's owner, and syncing it would be more surprising
/// than helpful on a shared iCloud account.
@Observable
@MainActor
final class AppSettings {

  var hasCompletedOnboarding: Bool {
    didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
  }

  /// `nil` means the user skipped the region step; the app falls back to the
  /// US definition until they set one in Settings.
  var region: Region? {
    didSet { defaults.set(region?.rawValue, forKey: Keys.region) }
  }

  /// The definition all standard-drink math measures against.
  var effectiveRegion: Region { region ?? .unitedStates }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    self.region = (defaults.string(forKey: Keys.region)).flatMap(Region.init(rawValue:))
  }

  private enum Keys {
    static let onboarding = "hasCompletedOnboarding"
    static let region = "region"
  }
}
