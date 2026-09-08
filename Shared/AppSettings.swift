import DrinkTrackerCore
import Foundation
import Observation
import WidgetKit

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
      // The medium widget's ≈ caption is in the region's unit, captured at
      // its last timeline build; without this it kept the old unit until the
      // next log or midnight (invariant 3 reaches the widget too).
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  /// The definition all standard-drink math measures against.
  var effectiveRegion: Region { region ?? .unitedStates }

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

  /// Which span the calendar's summary card covers (ADR-0026).
  ///
  /// Defaults to the rolling 30 days — the shipped behaviour, the window
  /// ADR-0006 was decided on, never clipped (nobody's first sight of the card
  /// is a two-day month), and the spec's rule that a new surface ships
  /// neutral. Stored as a raw string so "never set" is `nil` and the default
  /// lives here alone (the `counterSeed` pattern). App-only, like
  /// `showsSessionPace`: the widget has no summary card, so this `didSet`
  /// does not reload widget timelines. Not iCloud-synced, like every setting
  /// here — which window a device shows is about that device's reader.
  var calendarSummaryWindow: CalendarSummaryWindow {
    didSet { defaults.set(calendarSummaryWindow.rawValue, forKey: Keys.calendarSummaryWindow) }
  }

  /// Which of the published comparisons appear (ADR-0038): the weekly
  /// average against the survey's distribution (Trends and the year view),
  /// the drinking-days mean, and the weekend rate beside the weekday split.
  /// All three default to shown — they are the neutral surfaces the app
  /// already showed, and the 1.2 spec's "optional and off" rule is for
  /// behavioural surfaces, which a published figure beside the reader's own
  /// is not. Off removes the published figure and the reader's own line
  /// beside it; the range's own totals stay where they are. A stored value
  /// wins; "never set" reads as shown, so the default lives here and not in
  /// `bool(forKey:)`'s false.
  var showsWeeklyAverageComparison: Bool {
    didSet { defaults.set(showsWeeklyAverageComparison, forKey: Keys.weeklyAverageComparison) }
  }

  var showsDrinkingDaysComparison: Bool {
    didSet { defaults.set(showsDrinkingDaysComparison, forKey: Keys.drinkingDaysComparison) }
  }

  var showsWeekendComparison: Bool {
    didSet { defaults.set(showsWeekendComparison, forKey: Keys.weekendComparison) }
  }

  /// Which of the survey's columns the weekly-average comparison reads
  /// (ADR-0039): the total by default, or the men's or women's column the
  /// source prints beside it. A choice of reference kept on this device, not
  /// a fact recorded about the reader — which is why the type is `Column` and
  /// there is no case the table does not publish. Stored as the raw name so
  /// "never set" is `nil` and the default lives here (the `counterSeed`
  /// pattern); an unrecognised name falls back rather than crashing.
  var comparisonColumn: PopulationReference.Column {
    didSet { defaults.set(comparisonColumn.rawValue, forKey: Keys.comparisonColumn) }
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = AppGroup.defaults) {
    self.defaults = defaults
    self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    self.region = defaults.string(forKey: Keys.region).flatMap(Region.init(rawValue:))
    self.showsSessionPace = defaults.bool(forKey: Keys.sessionPace)
    self.counterSeed = Self.storedCounterSeed(defaults: defaults)
    self.calendarSummaryWindow = defaults.string(forKey: Keys.calendarSummaryWindow)
      .flatMap(CalendarSummaryWindow.init(rawValue:)) ?? .lastThirtyDays
    self.showsWeeklyAverageComparison = Self.storedFlag(Keys.weeklyAverageComparison, defaults: defaults, fallback: true)
    self.showsDrinkingDaysComparison = Self.storedFlag(Keys.drinkingDaysComparison, defaults: defaults, fallback: true)
    self.showsWeekendComparison = Self.storedFlag(Keys.weekendComparison, defaults: defaults, fallback: true)
    self.comparisonColumn = defaults.string(forKey: Keys.comparisonColumn)
      .flatMap(PopulationReference.Column.init(rawValue:)) ?? .allAdults
  }

  /// A Bool whose default is not false: the stored value if a Bool was ever
  /// written under `key`, `fallback` otherwise. `bool(forKey:)` cannot tell
  /// "never set" from "set to false", and a setting that starts on needs the
  /// difference; anything stored that is not a Bool reads as the fallback.
  nonisolated private static func storedFlag(_ key: String, defaults: UserDefaults, fallback: Bool) -> Bool {
    (defaults.object(forKey: key) as? Bool) ?? fallback
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
    static let sessionPace = "showsSessionPace"
    static let counterSeed = "counterSeed"
    static let calendarSummaryWindow = "calendarSummaryWindow"
    static let weeklyAverageComparison = "showsWeeklyAverageComparison"
    static let drinkingDaysComparison = "showsDrinkingDaysComparison"
    static let weekendComparison = "showsWeekendComparison"
    static let comparisonColumn = "comparisonColumn"
  }
}
