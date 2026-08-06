import Foundation

/// The in-flight state of the drink-detail sheet.
///
/// A draft is always immediately loggable — it is seeded with the type's defaults
/// the moment the sheet opens, which is what makes the two-tap fast path work.
public struct DrinkDraft: Equatable, Sendable {
  public var type: DrinkType
  public var selectedSize: DrinkSizeOption
  /// Volume used when `selectedSize` is the Custom pill.
  public var customVolumeOunces: Double
  public var abvPercent: Double
  /// Set when the draft came from tapping Edit on an existing entry.
  public var editingEntryID: UUID?
  /// When the drink happened.
  ///
  /// Defaults to now, so the fast path never has to think about it. Editing an
  /// entry keeps its original time, and adding a forgotten drink from History can
  /// move it back.
  public var loggedAt: Date

  /// How many identical drinks this draft records.
  ///
  /// For catching up after several of the same thing. Each one is still saved as
  /// its own entry, so they stay individually editable and removable — this is a
  /// shortcut for logging, not a "quantity" attribute on a single drink.
  ///
  /// Always 1 when editing: turning one existing entry into several by editing it
  /// would be a confusing thing for an edit to do.
  public var quantity: Int = 1

  public init(type: DrinkType, loggedAt: Date = Date()) {
    self.type = type
    self.selectedSize = type.defaultSizeOption
    self.customVolumeOunces = type.defaultVolumeOunces
    self.abvPercent = type.defaultABVPercent
    self.editingEntryID = nil
    self.loggedAt = loggedAt
  }

  /// Rebuilds a draft from an already-logged drink, for the Edit path.
  public init(editing drink: LoggedDrink) {
    self.type = drink.type
    let match = drink.type.sizeOptions.first { $0.volumeOunces == drink.volumeOunces }
    self.selectedSize = match ?? .custom
    self.customVolumeOunces = drink.volumeOunces
    self.abvPercent = drink.abvPercent
    self.editingEntryID = drink.id
    self.loggedAt = drink.loggedAt
  }

  /// Materialises the draft into a value ready to persist.
  ///
  /// Re-logging an edited drink reuses the original identity so the store
  /// replaces the previous entry's contribution rather than adding a duplicate.
  public func makeLoggedDrink(region: Region) -> LoggedDrink {
    LoggedDrink(
      id: editingEntryID ?? UUID(),
      loggedAt: loggedAt,
      type: type,
      volumeOunces: volumeOunces,
      abvPercent: abvPercent,
      region: region
    )
  }

  /// One `LoggedDrink` per unit of `quantity`, each with its own identity.
  ///
  /// Timestamps are staggered by a second so list ordering is deterministic rather
  /// than jittering between equal keys. That second is a tie-breaker, not a claim
  /// about when each drink was actually finished.
  public func makeLoggedDrinks(region: Region) -> [LoggedDrink] {
    guard editingEntryID == nil else { return [makeLoggedDrink(region: region)] }
    let count = max(1, quantity)
    return (0..<count).map { index in
      LoggedDrink(
        id: UUID(),
        loggedAt: loggedAt.addingTimeInterval(Double(index)),
        type: type,
        volumeOunces: volumeOunces,
        abvPercent: abvPercent,
        region: region
      )
    }
  }

  /// A draft that repeats an already-logged drink exactly, at a new time.
  ///
  /// Used by the one-tap repeat control: same type, size, and strength, but a new
  /// entry rather than an edit of the original.
  public static func repeating(_ drink: LoggedDrink, at date: Date = Date()) -> DrinkDraft {
    var draft = DrinkDraft(editing: drink)
    draft.editingEntryID = nil
    draft.loggedAt = date
    return draft
  }

  /// A draft for count-first logging: "N drinks", no type chosen by the user.
  ///
  /// The count is the user's statement; everything else is the best available
  /// stand-in. Seeded from the type they log most often, at the size and strength
  /// they last logged it — the same rule the calendar's day sheet describes — so a
  /// habitual wine drinker's "3 drinks" counts as three of *their* wine rather
  /// than three of an abstract unit. Every entry this produces is a real, typed,
  /// individually editable drink (ADR-0003), so precision is recoverable later.
  ///
  /// With no history at all it falls back to beer's defaults, which resolve to
  /// exactly 1.0 US standard drinks (ADR-0005) — a fresh install's "N drinks"
  /// therefore means N standard drinks until the log says otherwise.
  public static func quickCount(
    _ count: Int,
    from history: [LoggedDrink],
    at date: Date = Date()
  ) -> DrinkDraft {
    var draft: DrinkDraft
    if let type = TrendSummary.mostLoggedType(in: history),
       let recent = TrendSummary.mostRecentDrink(ofType: type, in: history) {
      draft = .repeating(recent, at: date)
    } else {
      draft = DrinkDraft(type: .beer, loggedAt: date)
    }
    draft.quantity = max(1, count)
    return draft
  }

  public var volumeOunces: Double {
    selectedSize.volumeOunces ?? customVolumeOunces
  }

  public func standardDrinks(region: Region) -> Double {
    StandardDrink.count(volumeOunces: volumeOunces, abvPercent: abvPercent, region: region)
  }

  /// Switching type resets size and ABV to that type's defaults.
  public mutating func changeType(to newType: DrinkType) {
    guard newType != type else { return }
    type = newType
    selectedSize = newType.defaultSizeOption
    customVolumeOunces = newType.defaultVolumeOunces
    abvPercent = newType.defaultABVPercent
  }
}

/// Stable identity for `.sheet(item:)` presentation: the type plus the entry
/// being edited is what actually distinguishes one presentation from another.
///
/// Lives here rather than in the app target because a conformance on a type this
/// module owns belongs to this module — declared downstream it was a retroactive
/// conformance, which breaks the moment the owner adds its own.
extension DrinkDraft: Identifiable {
  public var id: String {
    "\(type.rawValue)-\(editingEntryID?.uuidString ?? "new")"
  }
}
