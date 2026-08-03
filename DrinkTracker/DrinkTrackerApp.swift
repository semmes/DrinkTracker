import DrinkTrackerCore
import SwiftData
import SwiftUI

@main
struct DrinkTrackerApp: App {
  @State private var settings = AppSettings()
  @State private var health = HealthKitService()

  private let container: ModelContainer

  init() {
    AppTheme.install()

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
      container = try SharedModelContainer.make()
    } catch {
      // Launch anyway, rather than crash-looping a user who then has no way to
      // reach their log. The cost is that this session's drinks don't persist,
      // so it is recorded rather than swallowed: Settings → Diagnostics shows
      // the store mode, and this is the one state where it says "in memory".
      // See docs/decisions/0004-a-failed-store-degrades-to-memory.md.
      Diagnostics.recordStoreMode("IN MEMORY — nothing will be saved — \(error)")
      container = try! ModelContainer(
        for: SharedModelContainer.schema,
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
    }
    .modelContainer(container)
  }
}

/// Routes straight from onboarding to Today. There is no account step in between.
struct RootView: View {
  @Environment(AppSettings.self) private var settings

  var body: some View {
    if settings.hasCompletedOnboarding {
      TodayView()
    } else {
      OnboardingFlow()
    }
  }
}
