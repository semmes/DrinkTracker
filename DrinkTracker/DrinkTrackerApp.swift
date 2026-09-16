import DrinkTrackerCore
import SwiftData
import SwiftUI

@main
struct DrinkTrackerApp: App {
  @State private var settings: AppSettings
  @State private var health = HealthKitService()
  @Environment(\.scenePhase) private var scenePhase

  /// Standard defaults on purpose — the widget is excluded (see
  /// `AppearancePreference`). Applied once at the root; sheets and covers
  /// presented inside this hierarchy inherit it.
  @AppStorage(AppearancePreference.storageKey)
  private var appearanceRaw = AppearancePreference.system.rawValue

  private let container: ModelContainer

  init() {
    AppTheme.install()
    // A CSV staged for a share sheet last session has no reason to still exist.
    LogExportFile.removeStaleExports()

    // The settings bridge to a paired watch (watch Phase 2, ADR-0041): the
    // region and counter seed cross to the wrist whenever either changes, and
    // the publisher re-sends the current pair on activation and on every
    // foregrounding, below. Only these two values cross, and never a row.
    let settings = AppSettings()
    settings.watchBridge = { region, counterSeed in
      WatchContextPublisher.shared.publish(
        WatchContext(region: region, counterSeed: counterSeed, sentAt: .now)
      )
    }
    _settings = State(initialValue: settings)
    WatchContextPublisher.shared.activate()

    // What mirroring actually does, as opposed to what it was asked for or
    // whether an account exists. Settings reads it rather than promising a
    // sync it has not seen (the owner's cellular evening, 2026-09-15).
    CloudKitSyncMonitor.start()

    // A drink that reaches this store from the watch redraws the home-screen
    // widget when its import lands and when the app is left (ADR-0047). Started
    // here, not on a view, because the import this exists for is the one that
    // arrives while no view is on screen.
    WidgetReloads.start()

    #if DEBUG
    // A missing App Group doesn't fail the build — the app and widget just end up
    // with separate stores and the widget quietly shows a stale zero. Say so.
    if !AppGroup.isAvailable {
      print("""
        ⚠️ App Group "\(AppGroup.identifier)" is not available.
        The widget will read a different store than the app.
        Check the App Groups capability on both targets and BUNDLE_ID_PREFIX \
        in Config/Signing.xcconfig.
        """)
    }
    #endif

    // Lives in the App Group so the widget reads and writes the same store.
    // CloudKit-backed so the log follows the user's existing iCloud account —
    // there is no sign-in.
    //
    // The iCloud-unavailable fallback is inside make(), so the widget takes the
    // same path this does. Reaching the catch below means the store could not be
    // opened *at all*, with or without mirroring — which no configuration fixes.
    do {
      // This launch, and only this launch, records how the store opened: the
      // key is what Settings' "IN MEMORY" warning reads, so nothing that opens
      // the store later — an extension, or an intent in this same process — may
      // write over it (ADR-0047).
      let opened = try SharedModelContainer.open()
      container = opened.container
      Diagnostics.recordStoreMode(opened.mode)
    } catch {
      // Launch anyway, rather than crash-looping a user who then has no way to
      // reach their log. The cost is that this session's drinks don't persist,
      // so it is recorded rather than swallowed: Settings → Diagnostics shows
      // the store mode, and this is the one state where it says "in memory".
      // See docs/decisions/0004-a-failed-store-degrades-to-memory.md.
      Diagnostics.recordStoreMode("IN MEMORY — nothing will be saved — \(error)")
      container = try! ModelContainer(
        for: SharedModelContainer.schema,
        migrationPlan: DrinkTrackerMigrationPlan.self,
        configurations: ModelConfiguration(
          schema: SharedModelContainer.schema,
          isStoredInMemoryOnly: true
        )
      )
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(settings)
        .environment(health)
        .preferredColorScheme(
          AppearancePreference(rawValue: appearanceRaw)?.colorScheme
        )
    }
    .modelContainer(container)
    .onChange(of: scenePhase) { previous, phase in
      switch phase {
      case .active:
        // Settings can change while the watch is out of reach; an application
        // context is latest-value-wins, so re-sending the current pair on every
        // foreground costs nothing and covers a watch paired since last time.
        WatchContextPublisher.shared.publishCurrent()
        WidgetReloads.appBecameActive()
      case .inactive where previous == .active, .background where previous == .active:
        // Once per leave, at its first step. Going home is `.active` →
        // `.inactive` → `.background`, and the request made at `.inactive` is
        // made while the app is still in the foreground, which WidgetKit does
        // not charge to the widget's daily reload budget; one made at
        // `.background` is charged, and nothing can have changed between the
        // two. `.inactive` also covers leaving by the app switcher, which can
        // end the process without reaching `.background`; the second case
        // covers a jump straight from `.active` to `.background`.
        WidgetReloads.appLeftForeground()
      default:
        break
      }
    }
  }
}

/// Routes straight from onboarding to the tab bar, which opens on Today. There
/// is no account step in between.
struct RootView: View {
  @Environment(AppSettings.self) private var settings

  var body: some View {
    if settings.hasCompletedOnboarding {
      AppTabs()
    } else {
      OnboardingFlow()
    }
  }
}
