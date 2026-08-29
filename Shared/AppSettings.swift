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

  /// What the counter's ＋ logs — one standard drink, or the user's usual
  /// drink (ADR-0023).
  ///
  /// **Defaults to `.standardDrink`**, which is a change of behaviour for
  /// existing installs and is meant to be. ADR-0009 seeded a count from the
  /// log's own habits on the argument that a wine drinker's "3" should weigh
  /// what their wine weighs; the first field report on it said the opposite —
  /// that a varied drinker gets a type they did not choose and ends up in the
  /// type picker anyway, which is the friction the counter exists to remove.
  /// Face value is also the reading that cannot be wrong about a drink nobody
  /// described. Anyone who wants the old rule keeps it in Settings.
  ///
  /// Stored as a raw string rather than a Bool so "never set" is `nil` and the
  /// default lives in one place, instead of relying on `bool(forKey:)`
  /// returning false.
  var counterSeed: DrinkDraft.CountSeed {
    didSet { defaults.set(counterSeed.rawValue, forKey: Keys.counterSeed) }
  }

  /// Whether Today shows the session pace card during an active sitting.
  ///
  /// Off by default — the 1.2 spec's rule for every new behavioral surface.
  /// The card itself has further conditions (a drink within the gap
  /// threshold); this is only the standing opt-in.
  var showsSessionPace: Bool {
    didSet { defaults.set(showsSessionPace, forKey: Keys.sessionPace) }
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = AppGroup.defaults) {
    self.defaults = defaults
    self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    self.region = defaults.string(forKey: Keys.region).flatMap(Region.init(rawValue:))
    self.prefersDetailedLogging = defaults.bool(forKey: Keys.detailedLogging)
    self.showsSessionPace = defaults.bool(forKey: Keys.sessionPace)
    self.counterSeed = Self.storedCounterSeed(defaults: defaults)
  }

  /// Region lookup for contexts without a live `AppSettings` — notably the widget's
  /// intent, which runs in another process and off the main actor.
  nonisolated static func storedRegion(
    defaults: UserDefaults = AppGroup.defaults
  ) -> Region {
    defaults.string(forKey: Keys.region).flatMap(Region.init(rawValue:)) ?? .unitedStates
  }

  /// Counter-seed lookup for contexts without a live `AppSettings` — the
  /// widget's ＋ runs in the extension process and logs through the same rule
  /// as Today's, so it has to read the same preference.
  nonisolated static func storedCounterSeed(
    defaults: UserDefaults = AppGroup.defaults
  ) -> DrinkDraft.CountSeed {
    defaults.string(forKey: Keys.counterSeed)
      .flatMap(DrinkDraft.CountSeed.init(rawValue:)) ?? .standardDrink
  }

  private enum Keys {
    static let onboarding = "hasCompletedOnboarding"
    static let region = "region"
    static let detailedLogging = "prefersDetailedLogging"
    static let sessionPace = "showsSessionPace"
    static let counterSeed = "counterSeed"
  }
}
