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

    // Lives in the App Group so the widget reads and writes the same store.
    // CloudKit-backed so the log follows the user's existing iCloud account —
    // there is no sign-in. If iCloud is unavailable the same store still works
    // locally, which is why the failure below is non-fatal.
    do {
      container = try SharedModelContainer.make()
    } catch {
      container = try! ModelContainer(
        for: SharedModelContainer.schema,
        configurations: ModelConfiguration(
          schema: SharedModelContainer.schema,
          cloudKitDatabase: .none
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
