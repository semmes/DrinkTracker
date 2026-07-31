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

    // CloudKit-backed by default so the log follows the user's existing iCloud
    // account. There is no sign-in: if iCloud is unavailable the same store
    // still works locally, which is why the failure below is non-fatal.
    let schema = Schema([DrinkEntry.self])
    do {
      container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
      )
    } catch {
      container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)
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
