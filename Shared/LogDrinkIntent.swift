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
  /// One standard drink, no type — the spoken form of the counter's ＋
  /// (ADR-0023). Makes "Log a standard drink in Tallyist" work through the
  /// existing typed phrase rather than needing a fifth shortcut.
  case standardDrink

  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "Drink Type")
  }

  static var caseDisplayRepresentations: [QuickLogDrinkType: DisplayRepresentation] {
    [
      .beer: DisplayRepresentation(title: "Beer"),
      .wine: DisplayRepresentation(title: "Wine"),
      .spirit: DisplayRepresentation(title: "Spirit"),
      .other: DisplayRepresentation(title: "Other"),
      .standardDrink: DisplayRepresentation(title: "Standard drink")
    ]
  }

  init(_ type: DrinkType) {
    switch type {
    case .beer: self = .beer
    case .wine: self = .wine
    case .spirit: self = .spirit
    case .other: self = .other
    case .unspecified: self = .standardDrink
    }
  }

  var drinkType: DrinkType {
    switch self {
    case .beer: .beer
    case .wine: .wine
    case .spirit: .spirit
    case .other: .other
    case .standardDrink: .unspecified
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
      // values get the app's own bounds (DrinkDraft.forIntent). A request for
      // zero drinks writes nothing and says so — see forIntent.
      guard let draft = DrinkDraft.forIntent(
        type: drinkType.drinkType,
        volumeOunces: volumeOunces,
        abvPercent: abvPercent,
        quantity: quantity,
        region: AppSettings.storedRegion()
      ) else {
        Diagnostics.record("nothing to log")
        return .result(dialog: IntentDialog(Self.nothingLoggedLine))
      }

      let saved = try Self.write(
        draft.makeLoggedDrinks(region: AppSettings.storedRegion()),
        to: repository
      )
      Diagnostics.record("saved")

      WidgetCenter.shared.reloadAllTimelines()
      // The widget ignores dialogs; Siri speaks them. Factual, like all copy.
      return .result(dialog: IntentDialog(Self.loggedLine(saved)))
    } catch {
      Diagnostics.record("failed: \(error)")
      throw error
    }
  }

  /// Writes each drink as its own entry (invariant 7) and returns exactly
  /// what landed.
  ///
  /// Every `saveOrThrow` is its own transaction, so a failure partway through
  /// leaves the earlier drinks durably written. Rethrowing there would tell
  /// the user the whole thing failed while some of it did not — and the
  /// natural response, saying the phrase again, would write those drinks a
  /// second time. So a partial write reports the true count instead; only a
  /// total failure throws, because then "it failed" is accurate. The error is
  /// still recorded as a breadcrumb either way.
  @MainActor
  static func write(_ drinks: [LoggedDrink], to repository: DrinkRepository) throws -> [LoggedDrink] {
    var saved: [LoggedDrink] = []
    for drink in drinks {
      do {
        try repository.saveOrThrow(drink)
        saved.append(drink)
      } catch {
        Diagnostics.record("partial: \(saved.count) of \(drinks.count) — \(error)")
        if saved.isEmpty { throw error }
        return saved
      }
    }
    return saved
  }

  /// "Logged: Beer, 12oz, 5% ABV." — built on `summaryLine` so every surface
  /// renders a drink identically. Never celebratory, never a total.
  ///
  /// `LocalizedStringResource`, not `String`: these are spoken, and a reply
  /// Siri reads aloud is as user-visible as anything on screen. The drink
  /// itself arrives already localized from the package (ADR-0020) and is
  /// interpolated through. The count picks between two forms by English's
  /// rule; the catalog carries the real plural variations.
  static func loggedLine(_ drinks: [LoggedDrink]) -> LocalizedStringResource {
    guard let first = drinks.first else { return nothingLoggedLine }
    let summary = first.summaryLine
    return drinks.count == 1
      ? "Logged: \(summary)."
      : "Logged \(drinks.count): \(summary) each."
  }

  static let nothingLoggedLine: LocalizedStringResource = "Nothing was logged."
}

// MARK: - Count-first intent

/// Logs one drink, seeded the same way as Today's counter — no parameter at all.
///
/// What that seed *is* became a setting in 1.2 (ADR-0023): one standard drink
/// with no type by default, or the user's usual drink. This intent follows
/// whichever is set rather than carrying its own rule, which is the whole
/// point of it being the counter's mirror.
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
    IntentDescription("Logs one drink, the same way the app's counter does.")
  }

  static var openAppWhenRun: Bool { false }

  init() {}

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    Diagnostics.record("entered (one-drink)")
    do {
      let container = try SharedModelContainer.make()
      let repository = DrinkRepository(context: container.mainContext)

      // Reads the same preference Today's counter does (ADR-0023), so the
      // widget's ＋ and the app's ＋ cannot mean different things. On
      // `.standardDrink` the history fetch is skipped entirely — there is
      // nothing to seed from.
      let region = AppSettings.storedRegion()
      let seed = AppSettings.storedCounterSeed()
      let history: [LoggedDrink] = seed == .standardDrink
        ? []
        : ((try? container.mainContext.fetch(FetchDescriptor<DrinkEntry>())) ?? []).loggedDrinks
      let drink = DrinkDraft
        .quickCount(1, from: history, seed: seed, region: region)
        .makeLoggedDrink(region: region)
      try repository.saveOrThrow(drink)
      Diagnostics.record("saved (one-drink)")

      WidgetCenter.shared.reloadAllTimelines()
      return .result(dialog: IntentDialog(LogDrinkIntent.loggedLine([drink])))
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

    // "None" is an answer, not a miscount: it writes nothing (see forIntent).
    guard let draft = DrinkDraft.forIntent(
      type: drinkType.drinkType,
      volumeOunces: volumeOunces,
      abvPercent: abvPercent,
      quantity: quantity,
      region: AppSettings.storedRegion()
    ) else {
      return .result(dialog: IntentDialog(LogDrinkIntent.nothingLoggedLine))
    }

    let saved = try LogDrinkIntent.write(
      draft.makeLoggedDrinks(region: AppSettings.storedRegion()),
      to: repository
    )

    WidgetCenter.shared.reloadAllTimelines()
    return .result(dialog: IntentDialog(LogDrinkIntent.loggedLine(saved)))
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

    // markAlcoholFreeOrThrow, not markAlcoholFree: the plain call swallows a
    // save failure and its Bool means "not refused", never "written". In the
    // app that self-corrects — the marker is re-read from a live query — but
    // a spoken "Recorded today as no alcohol." would be a claim about the
    // record that nothing backs. A throw here surfaces honestly instead.
    let recorded = try repository.markAlcoholFreeOrThrow(Date())
    // No widget reload on purpose, matching DrinkStore.markAlcoholFree: the
    // widget shows today's count, and a no-alcohol day totals what an
    // unlogged day totals.
    let dialog: LocalizedStringResource = recorded
      ? "Recorded today as no alcohol."
      : "Today already has drinks logged, so it wasn't recorded as no alcohol."
    return .result(dialog: IntentDialog(dialog))
  }
}
