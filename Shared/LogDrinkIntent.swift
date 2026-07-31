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

  @Parameter(title: "Drink")
  var drinkType: QuickLogDrinkType

  init() {}

  init(drinkType: DrinkType) {
    self.drinkType = QuickLogDrinkType(drinkType)
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
