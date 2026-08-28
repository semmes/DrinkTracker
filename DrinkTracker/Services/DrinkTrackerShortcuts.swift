import AppIntents
import DrinkTrackerCore

/// Surfaces logging in the Shortcuts app and to Siri (ADR-0019).
///
/// Lives in the app target only — a shortcuts provider declared in both the app and
/// the extension would register the same phrases twice.
///
/// The split mirrors the fast-path ethos: parameterized instant phrases for the
/// common case ("Log a beer in Tallyist" — no questions), one conversational
/// entry where Siri deliberately asks ("Log drinks…" → which, how many), and
/// the no-alcohol record. Every spoken reply is a statement of what was
/// written, reviewed like all copy.
struct DrinkTrackerShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    // "Log a beer/wine/spirit in Tallyist" — one phrase, every type, logged
    // instantly at the type's defaults. The AppEnum parameter is what lets
    // Siri hear the type inside the phrase itself.
    AppShortcut(
      intent: LogDrinkIntent(),
      phrases: [
        "Log a \(\.$drinkType) in \(.applicationName)",
        "Add a \(\.$drinkType) in \(.applicationName)",
      ],
      shortTitle: "Log a Drink",
      systemImageName: "plus.circle"
    )
    // "Log a drink in Tallyist" — typeless, seeded the way Today's counter
    // is: the type you log most, at the size you last logged it.
    AppShortcut(
      intent: LogOneDrinkIntent(),
      phrases: [
        "Log a drink in \(.applicationName)",
        "Log one drink in \(.applicationName)",
      ],
      shortTitle: "Log One Drink",
      systemImageName: "plus"
    )
    // The conversational path: Siri asks which drink and how many; size and
    // strength can ride along from a configured shortcut.
    AppShortcut(
      intent: LogDrinksIntent(),
      phrases: [
        "Log drinks in \(.applicationName)",
        "Log some drinks in \(.applicationName)",
      ],
      shortTitle: "Log Drinks",
      systemImageName: "plus.square.on.square"
    )
    AppShortcut(
      intent: RecordNoAlcoholIntent(),
      phrases: [
        "Record no alcohol in \(.applicationName)",
        "Log no alcohol in \(.applicationName)",
        "Record no alcohol today in \(.applicationName)",
      ],
      shortTitle: "Record No Alcohol",
      systemImageName: "checkmark.circle"
    )
  }
}
