import AppIntents
import DrinkTrackerCore

/// Surfaces logging in the Shortcuts app and to Siri.
///
/// Lives in the app target only — a shortcuts provider declared in both the app and
/// the extension would register the same phrases twice.
struct DrinkTrackerShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogDrinkIntent(drinkType: .beer),
      phrases: ["Log a beer in \(.applicationName)"],
      shortTitle: "Log Beer",
      systemImageName: "mug.fill"
    )
    AppShortcut(
      intent: LogDrinkIntent(drinkType: .wine),
      phrases: ["Log a wine in \(.applicationName)"],
      shortTitle: "Log Wine",
      systemImageName: "wineglass.fill"
    )
  }
}
