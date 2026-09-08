import Foundation

/// One selectable size pill in the drink-detail sheet.
///
/// A `nil` volume means the "Custom" pill, which reveals a plain number input
/// for ounces instead of committing to a preset.
public struct DrinkSizeOption: Hashable, Sendable, Identifiable {
  public let label: String
  public let volumeOunces: Double?

  public var isCustom: Bool { volumeOunces == nil }
  public var id: String { label }

  public init(label: String, volumeOunces: Double?) {
    self.label = label
    self.volumeOunces = volumeOunces
  }

  public static let custom = DrinkSizeOption(label: "Custom", volumeOunces: nil)
}

/// The five categories the drink sheet offers, plus the untyped drink.
public enum DrinkType: String, CaseIterable, Codable, Sendable, Identifiable {
  case beer
  case wine
  case spirit
  /// A mixed drink, measured by the spirit in it (ADR-0035).
  ///
  /// Sits between spirit and other in every ordered list because that is
  /// where it sits in the picker. Its raw value is new to the store: a build
  /// that predates it decodes the row to `.other` (`DrinkEntry.logged`), which
  /// mislabels a row whose arithmetic is right — the degradation ADR-0023
  /// chose for the untyped drink, for the same reason.
  case cocktail
  case other
  /// One standard drink with no type stated (ADR-0023).
  ///
  /// Not a category — the *absence* of the category question. It exists
  /// because "what kind?" is a question the app asks and the user may have no
  /// answer for, and answering it wrongly to get past it is worse than not
  /// answering it at all.
  ///
  /// Deliberately outside `selectableCases`: nothing offers it as a choice
  /// alongside beer and wine, because picking "unspecified" from a list of
  /// types is not how it is meant to be reached. It comes from the counter,
  /// and it leaves by the user adding details.
  case unspecified

  public var id: String { rawValue }

  /// The types a picker offers. `.unspecified` is excluded on purpose — see
  /// the case's own note.
  ///
  /// Every type picker in the app iterates this rather than `allCases`.
  /// `allCases` keeps all six, because the tie-break in
  /// `RecentSummary.mostLoggedType` and any future persistence-order code
  /// wants the complete, stable list.
  public static let selectableCases: [DrinkType] = [.beer, .wine, .spirit, .cocktail, .other]

  public var displayName: String {
    switch self {
    case .beer: localized("Beer", comment: "Drink type")
    case .wine: localized("Wine", comment: "Drink type")
    case .spirit: localized("Spirit", comment: "Drink type: distilled spirits")
    case .cocktail: localized("Cocktail", comment: "Drink type: a mixed drink, measured by the spirit in it")
    case .other: localized("Other", comment: "Drink type: anything not beer, wine, spirits, or a cocktail")
    // Not "Standard drink": `xcstringstool` derives a Swift symbol per key and
    // folds case, so that key collides with the region unit name "standard
    // drink" and fails the build. The same class of trap as the "≈" keys —
    // see `StandardDrink.liveEstimate`. This phrase is also the whole summary
    // line for such a drink, so one key serves both.
    case .unspecified:
      localized(
        "One standard drink",
        comment: "Drink type: one standard drink, logged without saying what kind"
      )
    }
  }

  /// The type's glyph: a custom symbol in the app's asset catalog (ADR-0036).
  ///
  /// These are the owner's drawn set (`docs/design/icons/`), compiled into
  /// `DrinkTracker/Assets.xcassets` by `scripts/make-drink-symbols.py`, not
  /// SF Symbols — so a view loads one with `Image(_:)` or `Label(_:image:)`,
  /// never `Image(systemName:)`, which renders nothing for a catalog name.
  /// The two companions the surfaces pair these with are `tally.health` (an
  /// entry mirrored from Apple Health) and `tally.alcoholfree` (a day
  /// recorded as no alcohol); `Symbol` names them all in one place.
  public var symbolName: String {
    switch self {
    case .beer: Symbol.beer
    case .wine: Symbol.wine
    case .spirit: Symbol.spirit
    case .cocktail: Symbol.cocktail
    case .other: Symbol.other
    // A measure, not a vessel: every other symbol here is a thing you drink
    // from, and this case is precisely the one where that is unknown.
    case .unspecified: Symbol.standard
    }
  }

  /// The asset-catalog names of the drawn glyph set, drink types and their
  /// two companions together, so every surface that pairs them reads the
  /// same list. Kept as `String`s because the package has no images to
  /// hand out — the app's catalog is where the art lives.
  public enum Symbol {
    public static let beer = "tally.beer"
    public static let wine = "tally.wine"
    public static let spirit = "tally.spirit"
    public static let cocktail = "tally.cocktail"
    public static let other = "tally.other"
    /// The untyped standard drink: a drop, the one glyph that is a measure
    /// rather than a vessel.
    public static let standard = "tally.standard"
    /// An entry or marker mirrored from another app's Health record.
    public static let health = "tally.health"
    /// A day recorded as no alcohol. An outline by rule: the marker sits off
    /// the intensity ramp, and an outline is the design system's own signal
    /// for that (ADR-0007).
    public static let alcoholFree = "tally.alcoholfree"

    /// Every name the catalog must hold, in the generator's order.
    public static let all = [beer, wine, spirit, cocktail, other, standard, health, alcoholFree]
  }

  public var sizeOptions: [DrinkSizeOption] {
    switch self {
    case .beer:
      [
        .init(label: "12 oz can", volumeOunces: 12),
        .init(label: "16 oz pint", volumeOunces: 16),
        // The can, the pint, and the 40 oz bottle (added 2026-09-07, ADR-0035;
        // the 22 oz was dropped earlier). The default is still the can.
        .init(label: "40 oz bottle", volumeOunces: 40),
        .custom
      ]
    case .wine:
      [
        .init(label: "5 oz glass", volumeOunces: 5),
        .init(label: "8 oz glass", volumeOunces: 8),
        .custom
      ]
    case .spirit:
      [
        .init(label: "1 oz shot", volumeOunces: 1),
        .init(label: "1.5 oz shot", volumeOunces: 1.5),
        .init(label: "2 oz double", volumeOunces: 2),
        .custom
      ]
    // A cocktail's size is the spirit in it, and the labels say so: the one
    // number a drinker knows about a mixed drink is how much was poured, not
    // the glass's volume or the mix's strength (ADR-0035). The 1.5 oz pour is
    // the bar standard, 2 oz the usual stirred-cocktail recipe, 3 oz a double.
    case .cocktail:
      [
        .init(label: "1.5 oz spirit", volumeOunces: 1.5),
        .init(label: "2 oz spirit", volumeOunces: 2),
        .init(label: "3 oz spirit", volumeOunces: 3),
        .custom
      ]
    case .other:
      [.custom]
    // No sizes, because no size was stated. The sheet never renders pills for
    // an untyped drink; picking a type is what brings them into being.
    case .unspecified:
      []
    }
  }

  /// The size pill pre-selected when the sheet opens.
  ///
  /// Derived from `defaultVolumeOunces` rather than being the first pill in the
  /// list. The two have to agree — the selected pill's volume is what
  /// `DrinkDraft.volumeOunces` actually uses — and deriving one from the other
  /// makes disagreeing impossible. Position in `sizeOptions` is then free to be
  /// about presentation order, which is what it looks like it's about.
  ///
  /// `.other` has no presets, so it falls through to Custom seeded with
  /// `defaultVolumeOunces`.
  public var defaultSizeOption: DrinkSizeOption {
    sizeOptions.first { $0.volumeOunces == defaultVolumeOunces } ?? .custom
  }

  /// Volume the sheet opens with, in US fluid ounces.
  ///
  /// Beer, wine, spirit and cocktail each resolve to almost exactly 1.0 US
  /// standard drink at their default ABV, so "one drink" in the app means one
  /// drink. Spirit uses the 1.5 oz shot for that reason: at 40% it is 0.6 fl oz
  /// of ethanol, which is the US definition exactly — and a cocktail, measured
  /// by its spirit, rests on the same fact (ADR-0035). See
  /// docs/decisions/0005-spirit-defaults-to-the-1_5-oz-shot.md.
  public var defaultVolumeOunces: Double {
    switch self {
    case .beer: 12
    case .wine: 5
    case .spirit: 1.5
    // The same 1.5 oz at 40%: a cocktail is measured by its spirit, so the
    // bar-standard pour is one US standard drink exactly (ADR-0035).
    case .cocktail: 1.5
    // Other is the deliberate exception: 8 oz @ 10% is 1.33 standard drinks. It
    // has no presets and no typical serving to anchor to, so its default is a
    // starting point for the Custom field rather than a claim about a real drink.
    case .other: 8
    // The US definition, and only ever a fallback: an untyped drink's real
    // facts are the *current region's* standard drink, which this enum cannot
    // see. `LoggedDrink.standardDrink(in:)` is the constructor that knows,
    // and every path that writes one goes through it (ADR-0023).
    case .unspecified: Region.unitedStates.flOzPureAlcoholPerStandardDrink
    }
  }

  public var defaultABVPercent: Double {
    switch self {
    case .beer: 5
    case .wine: 12
    case .spirit: 40
    // The spirit's strength, not the mix's: the volume above is the pour.
    case .cocktail: 40
    case .other: 10
    // Pure alcohol. An untyped drink is stored as the ethanol a standard drink
    // is *defined* as, rather than as a plausible-looking beverage — 12 oz at
    // 5% would claim a beer nobody mentioned, and the whole point is to claim
    // nothing (ADR-0023).
    case .unspecified: 100
    }
  }

  public var abvRange: ClosedRange<Double> {
    switch self {
    case .beer: 0...15
    case .wine: 0...20
    case .spirit, .cocktail, .other: 0...60
    // Never reached by the slider — the sheet hides strength until a type is
    // chosen — but the stored 100 must lie inside its own range.
    case .unspecified: 0...100
    }
  }
}
