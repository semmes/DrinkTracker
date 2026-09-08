import DrinkTrackerCore
import Foundation
import Testing

/// Tier 2 (docs/PRD.md §4) — the preferences the app and the widget share.
///
/// Each test gets its own `UserDefaults` suite rather than the App Group's, so
/// they neither read the developer's real settings nor leak into each other.
@Suite("App settings")
@MainActor
struct AppSettingsTests {

  let defaults: UserDefaults
  private let suiteName: String

  init() throws {
    suiteName = "AppSettingsTests.\(UUID().uuidString)"
    defaults = try #require(UserDefaults(suiteName: suiteName))
  }

  // MARK: - Region

  @Test("A chosen region round-trips through defaults")
  func regionRoundTrips() {
    let settings = AppSettings(defaults: defaults)
    settings.region = .australia

    let reloaded = AppSettings(defaults: defaults)
    #expect(reloaded.region == .australia)
  }

  /// Skipping the onboarding step is a distinct state from explicitly choosing the
  /// US, and Settings relies on the difference to say the value is only a default.
  @Test("Never choosing a region is distinct from choosing the US")
  func unsetRegionIsNotUS() {
    let skipped = AppSettings(defaults: defaults)
    #expect(skipped.region == nil)
    #expect(skipped.isUsingFallbackRegion)
    #expect(skipped.effectiveRegion == .unitedStates)

    skipped.region = .unitedStates
    #expect(skipped.isUsingFallbackRegion == false)
    #expect(skipped.effectiveRegion == .unitedStates)
  }

  @Test("Clearing the region returns to the fallback state")
  func clearingRegionRestoresFallback() {
    let settings = AppSettings(defaults: defaults)
    settings.region = .unitedKingdom
    settings.region = nil

    let reloaded = AppSettings(defaults: defaults)
    #expect(reloaded.region == nil)
    #expect(reloaded.isUsingFallbackRegion)
  }

  /// `storedRegion` is how the widget's intent reads the region: another process,
  /// off the main actor, with no live `AppSettings`. If these two ever disagreed,
  /// a widget tap would log in different units than the app displays.
  @Test("storedRegion reads back what AppSettings wrote")
  func storedRegionMatchesAppSettings() {
    let settings = AppSettings(defaults: defaults)
    settings.region = .unitedKingdom

    #expect(AppSettings.storedRegion(defaults: defaults) == .unitedKingdom)
  }

  @Test("storedRegion falls back to the US when nothing was ever chosen")
  func storedRegionFallsBack() {
    #expect(AppSettings.storedRegion(defaults: defaults) == .unitedStates)
  }

  @Test("An unrecognised stored region falls back rather than crashing")
  func unknownStoredRegionFallsBack() {
    defaults.set("atlantis", forKey: "region")

    #expect(AppSettings(defaults: defaults).region == nil)
    #expect(AppSettings.storedRegion(defaults: defaults) == .unitedStates)
  }

  // MARK: - Retired keys

  /// `prefersDetailedLogging` was Today's typed-disclosure preference and is
  /// gone (ADR-0034); the typed path is now the always-present "Add specific"
  /// link, so there is nothing left to remember.
  ///
  /// The key stays in every existing install's App Group defaults, and the
  /// only failure this removal can produce is an initialiser that trips over
  /// it. Nothing reads it, so this asserts the one thing that matters: a
  /// defaults dictionary carrying the retired key still yields a settings
  /// object with its real values intact.
  @Test("A defaults store still holding the retired key initialises cleanly")
  func retiredDetailedLoggingKeyIsHarmless() {
    defaults.set(true, forKey: "prefersDetailedLogging")
    defaults.set(Region.unitedKingdom.rawValue, forKey: "region")

    let settings = AppSettings(defaults: defaults)

    #expect(settings.region == .unitedKingdom)
    #expect(settings.counterSeed == .standardDrink)
    #expect(settings.showsSessionPace == false)
  }

  // MARK: - Calendar summary window

  /// The card's window (ADR-0026) starts on the rolling 30 days every install
  /// already shows, and survives a relaunch once chosen.
  @Test("The calendar summary window defaults to the last 30 days and round-trips")
  func calendarSummaryWindowRoundTrips() {
    let settings = AppSettings(defaults: defaults)
    #expect(settings.calendarSummaryWindow == .lastThirtyDays)

    settings.calendarSummaryWindow = .monthShown
    #expect(AppSettings(defaults: defaults).calendarSummaryWindow == .monthShown)
  }

  /// The raw strings are the stored contract; anything else falls back rather
  /// than crashing, the same rule `region` follows.
  @Test("An unrecognised stored window falls back to the last 30 days")
  func unknownStoredWindowFallsBack() {
    defaults.set("fortnight", forKey: "calendarSummaryWindow")

    #expect(AppSettings(defaults: defaults).calendarSummaryWindow == .lastThirtyDays)
  }

  // MARK: - Comparisons

  /// The three published comparisons start shown (ADR-0038) — a stored false
  /// is the only thing that hides one — and each survives a relaunch alone.
  @Test("The comparisons default to shown and each round-trips off on its own")
  func comparisonsDefaultToShown() {
    let settings = AppSettings(defaults: defaults)
    #expect(settings.showsWeeklyAverageComparison)
    #expect(settings.showsDrinkingDaysComparison)
    #expect(settings.showsWeekendComparison)

    settings.showsWeeklyAverageComparison = false
    settings.showsWeekendComparison = false
    let reloaded = AppSettings(defaults: defaults)
    #expect(reloaded.showsWeeklyAverageComparison == false)
    #expect(reloaded.showsDrinkingDaysComparison)
    #expect(reloaded.showsWeekendComparison == false)
  }

  /// `bool(forKey:)` reads an absent key as false, which would turn "never
  /// set" into "off". The default lives in the initialiser instead, so only a
  /// stored Bool is read as one — anything else falls back to shown.
  @Test("Only a stored Bool hides a comparison; anything else reads as shown")
  func comparisonFlagReadsOnlyBools() {
    defaults.set("no", forKey: "showsDrinkingDaysComparison")
    #expect(AppSettings(defaults: defaults).showsDrinkingDaysComparison)

    defaults.set(false, forKey: "showsDrinkingDaysComparison")
    #expect(AppSettings(defaults: defaults).showsDrinkingDaysComparison == false)
  }

  /// The column the weekly average reads (ADR-0039) starts on the survey's
  /// total and survives a relaunch once chosen — a choice of reference,
  /// stored as the column's raw name.
  @Test("The comparison column defaults to all adults and round-trips")
  func comparisonColumnRoundTrips() {
    let settings = AppSettings(defaults: defaults)
    #expect(settings.comparisonColumn == .allAdults)

    settings.comparisonColumn = .women
    #expect(AppSettings(defaults: defaults).comparisonColumn == .women)
  }

  @Test("An unrecognised stored column falls back to all adults")
  func unknownStoredColumnFallsBack() {
    defaults.set("everyone", forKey: "comparisonColumn")

    #expect(AppSettings(defaults: defaults).comparisonColumn == .allAdults)
  }

  // MARK: - Onboarding

  @Test("The onboarding flag round-trips and starts false")
  func onboardingRoundTrips() {
    let settings = AppSettings(defaults: defaults)
    #expect(settings.hasCompletedOnboarding == false)

    settings.hasCompletedOnboarding = true
    #expect(AppSettings(defaults: defaults).hasCompletedOnboarding)
  }
}
