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

  /// The most drinks one intent invocation can log — the same ceiling as
  /// Today's counter, and a guard against a misheard "log 500 drinks".
  public static let intentQuantityLimit = 12

  /// A draft built from voice or Shortcuts parameters (ADR-0019), or nil when
  /// the request asks for no drinks at all.
  ///
  /// Unspecified values fall to the type's defaults — the same values a
  /// widget tap or the sheet's fast path produce, so "log a beer" means the
  /// identical entry everywhere. Specified values are honored with the app's
  /// own bounds: ABV clamps to the type's slider range, volume must be
  /// positive to count as specified, and quantity clamps *down* to
  /// `intentQuantityLimit`.
  ///
  /// **Nothing clamps up.** A quantity of zero or less returns nil rather
  /// than one drink, and callers must say so instead of writing. Every
  /// in-app counter treats zero as a real answer — the day sheet's minus
  /// reaches it, and bulk fill reads it as "no alcohol" — so an intent that
  /// quietly rounded a Shortcuts-computed 0 up to 1 would be the only path
  /// in the app that invents a drink the user never had. It would also
  /// clear that day's alcohol-free marker and mirror the fabrication into
  /// Health. The log may under-record; it must never over-record.
  public static func forIntent(
    type: DrinkType,
    volumeOunces: Double? = nil,
    abvPercent: Double? = nil,
    quantity: Int = 1,
    region: Region = .unitedStates
  ) -> DrinkDraft? {
    guard quantity > 0 else { return nil }
    // The untyped standard drink is the region's definition, so it is built
    // from the region rather than from the enum's US fallback (ADR-0023).
    // Size and strength are ignored here on purpose: a caller who knows the
    // ounces and the ABV is describing a drink they can name, and naming it
    // is what the other four cases are for. Honouring both at once would
    // write a row that says "no type stated" over facts that state one.
    if type == .unspecified {
      var draft = DrinkDraft.standardDrink(region: region)
      draft.quantity = min(quantity, intentQuantityLimit)
      return draft
    }
    var draft = DrinkDraft(type: type)
    if let volumeOunces, volumeOunces > 0 {
      let match = type.sizeOptions.first { $0.volumeOunces == volumeOunces }
      draft.selectedSize = match ?? .custom
      draft.customVolumeOunces = volumeOunces
    }
    if let abvPercent, abvPercent.isFinite {
      draft.abvPercent = min(max(abvPercent, type.abvRange.lowerBound), type.abvRange.upperBound)
    }
    draft.quantity = min(quantity, intentQuantityLimit)
    return draft
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

  /// What the counter's ＋ writes when the user states a number and nothing else
  /// (ADR-0023).
  ///
  /// The two answers the app has ever had to "one more drink, but which one?",
  /// now a setting rather than a decision taken on the user's behalf.
  public enum CountSeed: String, CaseIterable, Sendable {
    /// One standard drink, no type — the count taken at face value.
    case standardDrink
    /// The type logged most often, at the size and strength last logged for
    /// it. ADR-0009's original rule.
    case usualDrink
  }

  /// A draft for one standard drink with no type stated (ADR-0023).
  ///
  /// Region-aware because the drink it materialises is (see
  /// `LoggedDrink.standardDrink(in:)`); `DrinkType.unspecified`'s own defaults
  /// are the US fallback and are deliberately not used here.
  public static func standardDrink(region: Region, at date: Date = Date()) -> DrinkDraft {
    var draft = DrinkDraft(type: .unspecified, loggedAt: date)
    draft.selectedSize = .custom
    draft.customVolumeOunces = region.flOzPureAlcoholPerStandardDrink
    draft.abvPercent = 100
    return draft
  }

  /// True while this draft records an amount but not a kind — the state the
  /// detail sheet turns into a type question rather than a size form.
  public var needsType: Bool { type == .unspecified }

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
  ///
  /// **A drink with no size is never the template** (ADR-0022). The seed helpers
  /// already skip entries marked as Health imports, but that guard reads
  /// `countedDrinks`, and a row can carry the shape without the marker: a store
  /// shared with a build that predates the attribute mirrors those rows back
  /// stripped of it. Repeating one writes a zero-alcohol drink under the user's
  /// usual type, which then becomes the newest entry of that type and seeds the
  /// next tap — the fault is absorbing, not transient. So the test here is the
  /// physical facts rather than the provenance: no volume means there is no size
  /// to repeat, and that type's own defaults stand in. The type still comes from
  /// the log, so a habitual Other drinker gets Other, not a silent switch to
  /// beer.
  /// **The seed is now the user's choice** (ADR-0023). `.standardDrink` ignores
  /// the history entirely and writes one standard drink with no type — the
  /// answer for someone who drinks varied things and was being asked to pick
  /// a type they did not have. `.usualDrink` is the rule described above,
  /// unchanged. `region` is only read by `.standardDrink`, whose facts are
  /// the region's own definition.
  public static func quickCount(
    _ count: Int,
    from history: [LoggedDrink],
    seed: CountSeed = .usualDrink,
    region: Region = .unitedStates,
    at date: Date = Date()
  ) -> DrinkDraft {
    var draft: DrinkDraft
    if seed == .standardDrink {
      draft = .standardDrink(region: region, at: date)
      draft.quantity = max(1, count)
      return draft
    }
    if let type = TrendSummary.mostLoggedType(in: history) {
      if let recent = TrendSummary.mostRecentDrink(ofType: type, in: history),
         recent.isRepeatable {
        draft = .repeating(recent, at: date)
      } else {
        draft = DrinkDraft(type: type, loggedAt: date)
      }
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
