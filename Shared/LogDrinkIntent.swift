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

  /// Shown when the intent is configured in Shortcuts.
  static var parameterSummary: some ParameterSummary {
    Summary("Log a \(\.$drinkType)")
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
  func perform() async throws -> some IntentResult {
    // Breadcrumb: a widget button that does nothing is indistinguishable from a
    // missed tap, and the extension's own logs are largely unreadable from the
    // simulator. If `Diagnostics.lastWidgetLog` is absent after a tap, the intent
    // was never dispatched; if it holds an error, the write itself failed.
    Diagnostics.record("entered")
    do {
      let container = try SharedModelContainer.make()
      Diagnostics.record("container-opened")
      let repository = DrinkRepository(context: container.mainContext)

      // Same defaults the sheet opens with, so a widget tap and a two-tap in-app
      // log produce identical entries.
      let draft = DrinkDraft(type: drinkType.drinkType)
      let drink = draft.makeLoggedDrink(region: AppSettings.storedRegion())
      try repository.saveOrThrow(drink)
      Diagnostics.record("saved")

      WidgetCenter.shared.reloadAllTimelines()
      return .result()
    } catch {
      Diagnostics.record("failed: \(error)")
      throw error
    }
  }
}
