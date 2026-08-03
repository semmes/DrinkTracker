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

  // MARK: - Onboarding

  @Test("The onboarding flag round-trips and starts false")
  func onboardingRoundTrips() {
    let settings = AppSettings(defaults: defaults)
    #expect(settings.hasCompletedOnboarding == false)

    settings.hasCompletedOnboarding = true
    #expect(AppSettings(defaults: defaults).hasCompletedOnboarding)
  }
}
