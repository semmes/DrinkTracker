import AppIntents
import DrinkTrackerCore
import Foundation
import SwiftData
import WidgetKit

// MARK: - Intent-facing drink type

/// Mirrors `DrinkType` for App Intents.
///
/// This exists only because the AppIntents metadata processor refuses to build an
/// `AppEnum` whose cases live in an imported framework — `DrinkType` ships in
/// DrinkTrackerCore, so it can't conform directly.
///
/// The two are mapped with exhaustive switches rather than `rawValue` lookups, so
/// adding a case to `DrinkType` fails to compile here instead of silently falling
/// through to `.other` at runtime.
enum QuickLogDrinkType: String, AppEnum, CaseIterable {
  case beer
  case wine
  case spirit
  case other

  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "Drink Type")
  }

  static var caseDisplayRepresentations: [QuickLogDrinkType: DisplayRepresentation] {
    [
      .beer: DisplayRepresentation(title: "Beer"),
      .wine: DisplayRepresentation(title: "Wine"),
      .spirit: DisplayRepresentation(title: "Spirit"),
      .other: DisplayRepresentation(title: "Other")
    ]
  }

  init(_ type: DrinkType) {
    switch type {
    case .beer: self = .beer
    case .wine: self = .wine
    case .spirit: self = .spirit
    case .other: self = .other
    }
  }

  var drinkType: DrinkType {
    switch self {
    case .beer: .beer
    case .wine: .wine
    case .spirit: .spirit
    case .other: .other
    }
  }
}

// MARK: - Intent

/// Logs one drink at its default size and ABV.
///
/// This is the widget's whole point: the brief's two-tap fast path collapses to a
/// single tap from the home screen. Anything the user wants to correct afterwards
/// is still editable in the app — edit-after, not gate-before.
struct LogDrinkIntent: AppIntent {
  static var title: LocalizedStringResource { "Log a Drink" }
  static var description: IntentDescription {
    IntentDescription("Logs a drink using its default size and strength.")
  }

  /// Keeps the tap in the background — opening the app would defeat the purpose.
  static var openAppWhenRun: Bool { false }

  /// **The default is load-bearing, not tidiness.**
  ///
  /// A non-optional `@Parameter` with no default is a parameter the system may need
  /// to *ask* for. When it can't resolve one, AppIntents' normal move is to prompt —
  /// which Shortcuts can do and a home-screen widget cannot. The tap is then
  /// abandoned before `perform()` is ever entered: no crash, no log, nothing.
  ///
  /// That is exactly the observed failure — the `Diagnostics.record("entered")`
  /// breadcrumb on the first line of `perform()` never appeared, at any widget size,
  /// while the intent was correctly present in the extension's metadata. Registration
  /// was never the problem; resolution was.
  ///
  /// With a default, resolution cannot fail, so there is nothing to prompt for. The
  /// value the button encodes still wins whenever it arrives — the default is only
  /// what makes the parameter answerable without a human.
  @Parameter(title: "Drink", default: .beer)
  var drinkType: QuickLogDrinkType

  /// Optional refinements for Shortcuts and Siri (ADR-0019). **Optional is
  /// load-bearing for the same reason the default above is**: an optional
  /// parameter resolves to nil without prompting, so the widget's tap still
  /// cannot be abandoned. Unspecified means the type's defaults — the same
  /// entry a widget tap produces.
  @Parameter(title: "Size (ounces)")
  var volumeOunces: Double?

  @Parameter(title: "Strength (% ABV)")
  var abvPercent: Double?

  /// Each drink is saved as its own entry (never a count on one — the log's
  /// standing rule), capped at the counter's ceiling of 12.
  @Parameter(title: "How many", default: 1)
  var quantity: Int

  /// Shown when the intent is configured in Shortcuts.
  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$quantity) \(\.$drinkType)") {
      \.$volumeOunces
      \.$abvPercent
    }
  }

  init() {}

  init(drinkType: DrinkType) {
    self.drinkType = QuickLogDrinkType(drinkType)
    // Which process built this, and for what. The widget extension and the app
    // both construct these, and knowing which one got as far as constructing is
    // half the answer when a tap does nothing.
    Diagnostics.recordIntentBuild(
      "\(drinkType.rawValue) · \(Bundle.main.bundleIdentifier ?? "unknown bundle")"
    )
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    // Breadcrumb: a widget button that does nothing is indistinguishable from a
    // missed tap, and the extension's own logs are largely unreadable from the
    // simulator. If `Diagnostics.lastWidgetLog` is absent after a tap, the intent
    // was never dispatched; if it holds an error, the write itself failed.
    Diagnostics.record("entered")
    do {
      let container = try SharedModelContainer.make()
      Diagnostics.record("container-opened")
      let repository = DrinkRepository(context: container.mainContext)

      // Same defaults the sheet opens with, so a widget tap, a Siri phrase,
      // and a two-tap in-app log all produce identical entries; specified
      // values get the app's own bounds (DrinkDraft.forIntent).
      let draft = DrinkDraft.forIntent(
        type: drinkType.drinkType,
        volumeOunces: volumeOunces,
        abvPercent: abvPercent,
        quantity: quantity
      )
      let drinks = draft.makeLoggedDrinks(region: AppSettings.storedRegion())
      for drink in drinks {
        try repository.saveOrThrow(drink)
      }
      Diagnostics.record("saved")

      WidgetCenter.shared.reloadAllTimelines()
      // The widget ignores dialogs; Siri speaks them. Factual, like all copy.
      return .result(dialog: IntentDialog(stringLiteral: Self.loggedLine(drinks)))
    } catch {
      Diagnostics.record("failed: \(error)")
      throw error
    }
  }

  /// "Logged: Beer, 12oz, 5% ABV." — built on `summaryLine` so every surface
  /// renders a drink identically. Never celebratory, never a total.
  static func loggedLine(_ drinks: [LoggedDrink]) -> String {
    guard let first = drinks.first else { return "Nothing was logged." }
    return drinks.count == 1
      ? "Logged: \(first.summaryLine)."
      : "Logged \(drinks.count): \(first.summaryLine) each."
  }
}

// MARK: - Count-first intent

/// Logs one drink, seeded the same way as Today's counter — no parameter at all.
///
/// This is the widget's mirror of the app's primary control. Parameterless on
/// purpose, twice over: it matches the count-first model (the user states *one
/// more*, not a type), and it structurally cannot repeat the resolution failure
/// that silently broke the typed intent — there is nothing to resolve.
///
/// Minus deliberately has no widget counterpart. Removing an entry must retire
/// its HealthKit sample, and only the app process does that reliably; a widget
/// delete would leave Health holding a sample for a drink that no longer exists.
/// Adding is safe from here because `backfillHealthKit` sweeps up unsampled
/// entries on next foreground — the asymmetry is the HealthKit mirror's, not an
/// oversight.
struct LogOneDrinkIntent: AppIntent {
  static var title: LocalizedStringResource { "Log One Drink" }
  static var description: IntentDescription {
    IntentDescription("Logs one drink, matching what you usually log.")
  }

  static var openAppWhenRun: Bool { false }

  init() {}

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    Diagnostics.record("entered (one-drink)")
    do {
      let container = try SharedModelContainer.make()
      let repository = DrinkRepository(context: container.mainContext)

      let history = ((try? container.mainContext.fetch(FetchDescriptor<DrinkEntry>())) ?? [])
        .loggedDrinks
      let drink = DrinkDraft
        .quickCount(1, from: history)
        .makeLoggedDrink(region: AppSettings.storedRegion())
      try repository.saveOrThrow(drink)
      Diagnostics.record("saved (one-drink)")

      WidgetCenter.shared.reloadAllTimelines()
      return .result(dialog: IntentDialog(stringLiteral: LogDrinkIntent.loggedLine([drink])))
    } catch {
      Diagnostics.record("failed (one-drink): \(error)")
      throw error
    }
  }
}

// MARK: - Conversational logging (Siri)

/// The Siri-facing "log drinks" — where prompting is the point (ADR-0019).
///
/// `LogDrinkIntent`'s parameters must never prompt, because a widget tap
/// cannot answer a question. This intent inverts that on purpose: type and
/// count have **no defaults**, so Siri collects them by voice — "Which
/// drink?", "How many?" — which is what makes hands-free logging with
/// specifics possible. Size and strength stay optional (defaults per type);
/// requiring them would turn a two-answer exchange into a form read aloud.
///
/// Never placed on a widget. The no-default parameters that make it
/// conversational are exactly what would silently break a widget button.
struct LogDrinksIntent: AppIntent {
  static var title: LocalizedStringResource { "Log Drinks" }
  static var description: IntentDescription {
    IntentDescription("Logs one or more drinks, asking for the type and how many.")
  }

  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Drink", requestValueDialog: "Which drink?")
  var drinkType: QuickLogDrinkType

  @Parameter(title: "How many", requestValueDialog: "How many?")
  var quantity: Int

  @Parameter(title: "Size (ounces)")
  var volumeOunces: Double?

  @Parameter(title: "Strength (% ABV)")
  var abvPercent: Double?

  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$quantity) \(\.$drinkType)") {
      \.$volumeOunces
      \.$abvPercent
    }
  }

  init() {}

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let container = try SharedModelContainer.make()
    let repository = DrinkRepository(context: container.mainContext)

    let draft = DrinkDraft.forIntent(
      type: drinkType.drinkType,
      volumeOunces: volumeOunces,
      abvPercent: abvPercent,
      quantity: quantity
    )
    let drinks = draft.makeLoggedDrinks(region: AppSettings.storedRegion())
    for drink in drinks {
      try repository.saveOrThrow(drink)
    }

    WidgetCenter.shared.reloadAllTimelines()
    return .result(dialog: IntentDialog(stringLiteral: LogDrinkIntent.loggedLine(drinks)))
  }
}

// MARK: - No alcohol today

/// Records today as alcohol-free, by voice or Shortcuts (ADR-0019).
///
/// The repository's standing rule holds here exactly as in the app: a day
/// with entries refuses the marker (evidence beats assertion), and the
/// refusal is spoken as a fact, not an error — nothing failed, the record
/// simply already says something else.
struct RecordNoAlcoholIntent: AppIntent {
  static var title: LocalizedStringResource { "Record No Alcohol Today" }
  static var description: IntentDescription {
    IntentDescription("Records today as a day with no alcohol.")
  }

  static var openAppWhenRun: Bool { false }

  init() {}

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let container = try SharedModelContainer.make()
    let repository = DrinkRepository(context: container.mainContext)

    let recorded = repository.markAlcoholFree(Date())
    // No widget reload on purpose, matching DrinkStore.markAlcoholFree: the
    // widget shows today's count, and a no-alcohol day totals what an
    // unlogged day totals.
    let dialog = recorded
      ? "Recorded today as no alcohol."
      : "Today already has drinks logged, so it wasn't recorded as no alcohol."
    return .result(dialog: IntentDialog(stringLiteral: dialog))
  }
}
