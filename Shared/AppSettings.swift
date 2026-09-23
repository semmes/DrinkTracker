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
      Diagnostics.appendTimeline("reload widget — region changed")
      WidgetCenter.shared.reloadAllTimelines()
      // And the watch computes with it (invariant 3 reaches the wrist too).
      watchBridge?(effectiveRegion, counterSeed)
    }
  }

  /// Where a change to a value the watch mirrors is announced — the settings
  /// bridge of watch Phase 2 (ADR-0041). The phone app installs
  /// `WatchContextPublisher` here at launch; nothing else ever sets it, so on
  /// the widgets and on the watch itself a change goes nowhere, which is
  /// right: the phone is the source of these two values and the watch only
  /// receives them (through `store(region:)` and `store(counterSeed:)` below).
  /// Called with the *effective* region — the US fallback when none was
  /// chosen — because the watch mirrors the phone's arithmetic, not its
  /// settings screen.
  var watchBridge: (@MainActor (Region, DrinkDraft.CountSeed) -> Void)?

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
    didSet {
      defaults.set(counterSeed.rawValue, forKey: Keys.counterSeed)
      // The watch's ＋ runs the same seed rule (invariant 1 reaches the wrist).
      watchBridge?(effectiveRegion, counterSeed)
    }
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

  /// Which Apple Health figures appear beside the log on Trends (ADR-0050):
  /// one switch per metric, and only the metrics the shipped build shows —
  /// resting heart rate and sleep, as of Phase 4. Off by default, unlike the three
  /// comparisons above: those put a published figure beside the reader's own,
  /// while this is the first figure the app derives from data it does not
  /// own, and the reader turns it on. A preference, not Health data, so it
  /// lives here with the other flags; `bool(forKey:)`'s false is the default
  /// wanted, so no `storedFlag`.
  var showsRestingHeartRatePairing: Bool {
    didSet { defaults.set(showsRestingHeartRatePairing, forKey: Keys.restingHeartRatePairing) }
  }

  /// Sleep — time asleep — beside the log on Trends, Phase 4's row. Off by
  /// default like the switch above, with one difference at its first
  /// appearance: a metric that ships later arrives switched on for anyone
  /// who has an earlier pairing switch on, and off for everyone else (the
  /// design's decision 1; ADR-0051). That is decided once, the first time
  /// this key is missing, and written, so from then on the switches are
  /// independent. The earlier switch is resting heart rate, the only one that
  /// shipped before this; heart rate variability, below, inherits from the
  /// two before it, or-ed.
  var showsSleepPairing: Bool {
    didSet { defaults.set(showsSleepPairing, forKey: Keys.sleepPairing) }
  }

  /// Heart rate variability beside the log on Trends, Phase 5's row
  /// (ADR-0052): shown at Quarter and Year only, behind a floor twice the
  /// others', and the switch's caption says where. It arrives the way sleep
  /// did — on for anyone with either earlier switch on, the first time this
  /// key is missing, written then and independent after.
  var showsHeartRateVariabilityPairing: Bool {
    didSet { defaults.set(showsHeartRateVariabilityPairing, forKey: Keys.heartRateVariabilityPairing) }
  }

  /// Wrist temperature beside the log on Trends, Phase 6's row (ADR-0053):
  /// the watch's overnight reading as it is, in the unit the reader's Health
  /// app shows. It arrives the way the two before it did — on for anyone
  /// with any earlier switch on, the first time this key is missing, written
  /// then and independent after.
  var showsWristTemperaturePairing: Bool {
    didSet { defaults.set(showsWristTemperaturePairing, forKey: Keys.wristTemperaturePairing) }
  }

  /// Whether any pairing switch is on — what the one-time offer's "no
  /// pairing switch is on" condition reads, and what a later metric
  /// inherits.
  var isAnyHealthPairingOn: Bool {
    showsRestingHeartRatePairing || showsSleepPairing || showsHeartRateVariabilityPairing
      || showsWristTemperaturePairing
  }

  /// Whether the one-time offer on Trends has been answered, either way
  /// (ADR-0050). Once true, nothing in the app asks again; the switch above
  /// is the way back. Per device, as every flag here is — which matches the
  /// permission the offer asks for, since HealthKit's answer is per device
  /// too. Which way it was answered is not stored: a later metric arrives
  /// on for anyone with a pairing switch on, and off for everyone else, and
  /// the switches already say which.
  var hasAnsweredHealthPairingOffer: Bool {
    didSet { defaults.set(hasAnsweredHealthPairingOffer, forKey: Keys.healthPairingOffer) }
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
    let restingHeartRatePairing = defaults.bool(forKey: Keys.restingHeartRatePairing)
    self.showsRestingHeartRatePairing = restingHeartRatePairing
    let sleepPairing = Self.inheritedPairingFlag(
      Keys.sleepPairing, defaults: defaults, from: restingHeartRatePairing)
    self.showsSleepPairing = sleepPairing
    // Phase 5's switch inherits from the two before it, or-ed — each as it
    // stands after its own inheritance, so a device that only ever turned
    // sleep on gets heart rate variability on too (ADR-0051, ADR-0052).
    let heartRateVariabilityPairing = Self.inheritedPairingFlag(
      Keys.heartRateVariabilityPairing, defaults: defaults,
      from: restingHeartRatePairing || sleepPairing)
    self.showsHeartRateVariabilityPairing = heartRateVariabilityPairing
    // Phase 6's switch inherits from the three before it, or-ed, each as it
    // stands after its own inheritance (ADR-0051, ADR-0053).
    self.showsWristTemperaturePairing = Self.inheritedPairingFlag(
      Keys.wristTemperaturePairing, defaults: defaults,
      from: restingHeartRatePairing || sleepPairing || heartRateVariabilityPairing)
    self.hasAnsweredHealthPairingOffer = defaults.bool(forKey: Keys.healthPairingOffer)
  }

  /// A Bool whose default is not false: the stored value if a Bool was ever
  /// written under `key`, `fallback` otherwise. `bool(forKey:)` cannot tell
  /// "never set" from "set to false", and a setting that starts on needs the
  /// difference; anything stored that is not a Bool reads as the fallback.
  nonisolated private static func storedFlag(_ key: String, defaults: UserDefaults, fallback: Bool) -> Bool {
    (defaults.object(forKey: key) as? Bool) ?? fallback
  }

  /// A pairing switch's stored value — or, the first time the app runs with
  /// the switch existing, whether an earlier pairing switch is on, written
  /// then and there so the inheritance happens once (ADR-0051). `storedFlag`
  /// alone would keep following the older switch for as long as this one was
  /// never touched, which is not "arrives switched on"; it is a second copy.
  nonisolated private static func inheritedPairingFlag(
    _ key: String, defaults: UserDefaults, from earlierSwitchIsOn: Bool
  ) -> Bool {
    if let stored = defaults.object(forKey: key) as? Bool { return stored }
    defaults.set(earlierSwitchIsOn, forKey: key)
    return earlierSwitchIsOn
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

  /// The watch's half of the settings bridge (watch Phase 2, ADR-0041): the
  /// region the phone sent, written under the same key `region` reads, so
  /// `storedRegion()` — and the complication, which reads through it the way
  /// the home-screen widget does — answers the same on the wrist as on the
  /// phone with no code of its own. `Keys` stays private; these two writers
  /// are the one door in, beside the two readers that exist for the same
  /// off-main-actor situation.
  nonisolated static func store(
    region: Region,
    defaults: UserDefaults = AppGroup.defaults
  ) {
    defaults.set(region.rawValue, forKey: Keys.region)
  }

  /// The counter seed the phone sent — what the watch's ＋ logs (invariant 1).
  nonisolated static func store(
    counterSeed: DrinkDraft.CountSeed,
    defaults: UserDefaults = AppGroup.defaults
  ) {
    defaults.set(counterSeed.rawValue, forKey: Keys.counterSeed)
  }

  /// The watch's own "Show session pace" (watch Phase 5, ADR-0044): the key
  /// the phone's `showsSessionPace` uses, read from the watch's own App
  /// Group, so the setting is per device the way the phone's is (the plan's
  /// divergence 2) and never crosses the settings bridge. Off until set — the
  /// 1.2 spec's rule for every new behavioural surface.
  nonisolated static func storedShowsSessionPace(
    defaults: UserDefaults = AppGroup.defaults
  ) -> Bool {
    storedFlag(Keys.sessionPace, defaults: defaults, fallback: false)
  }

  nonisolated static func store(
    showsSessionPace: Bool,
    defaults: UserDefaults = AppGroup.defaults
  ) {
    defaults.set(showsSessionPace, forKey: Keys.sessionPace)
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
    static let restingHeartRatePairing = "showsRestingHeartRatePairing"
    static let sleepPairing = "showsSleepPairing"
    static let heartRateVariabilityPairing = "showsHeartRateVariabilityPairing"
    static let wristTemperaturePairing = "showsWristTemperaturePairing"
    static let healthPairingOffer = "hasAnsweredHealthPairingOffer"
  }
}
