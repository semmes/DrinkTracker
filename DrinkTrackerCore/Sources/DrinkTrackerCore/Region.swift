import Foundation

/// Physical constants used to convert between volume and mass of pure ethanol.
public enum Ethanol {
  /// Density of pure ethanol at room temperature.
  public static let gramsPerMilliliter: Double = 0.789
  /// Exact definition of the US fluid ounce.
  public static let millilitersPerUSFluidOunce: Double = 29.5735295625

  public static func grams(inFluidOunces flOz: Double) -> Double {
    flOz * millilitersPerUSFluidOunce * gramsPerMilliliter
  }

  public static func fluidOunces(inGrams grams: Double) -> Double {
    grams / gramsPerMilliliter / millilitersPerUSFluidOunce
  }
}

/// The region whose "standard drink" definition the app measures against.
///
/// The brief defines the US case by volume (0.6 fl oz of pure alcohol) and the
/// UK/Australia cases by mass (8 g / 10 g). Both are represented here; the US
/// volume figure is kept as the literal constant from the brief so the fast-path
/// numbers stay byte-identical to the spec, and the other regions derive their
/// volume from the unambiguous mass definition.
public enum Region: String, CaseIterable, Codable, Sendable, Identifiable {
  case unitedStates
  case unitedKingdom
  case australia

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .unitedStates: localized("United States", comment: "Country whose standard-drink definition is in use")
    case .unitedKingdom: localized("United Kingdom", comment: "Country whose standard-drink definition is in use")
    case .australia: localized("Australia", comment: "Country whose standard-drink definition is in use")
    }
  }

  /// Short label used in compact controls such as segmented pickers.
  public var shortName: String {
    switch self {
    case .unitedStates: localized("US", comment: "Abbreviated country name, compact controls and the export's unit column")
    case .unitedKingdom: localized("UK", comment: "Abbreviated country name, compact controls and the export's unit column")
    case .australia: localized("Australia", comment: "Abbreviated country name, compact controls and the export's unit column")
    }
  }

  /// What one standard drink is called in this region.
  public var unitName: String {
    switch self {
    case .unitedStates, .australia: localized("standard drink", comment: "Singular unit of alcohol, lowercase for mid-sentence use")
    case .unitedKingdom: localized("unit", comment: "Singular UK unit of alcohol, lowercase for mid-sentence use")
    }
  }

  /// The plural form, declared rather than derived.
  ///
  /// Six call sites used to build this by appending `"s"`. That is an English rule
  /// applied by string surgery: it breaks on an irregular noun, and it breaks
  /// entirely in languages with more than two plural forms — which is most of them.
  /// The app already ships three regional unit systems, so an international
  /// audience is not hypothetical here.
  ///
  /// Centralising it does not localise anything by itself. It means a String
  /// Catalog has **one** place to replace instead of six.
  public var unitNamePlural: String {
    switch self {
    case .unitedStates, .australia: localized("standard drinks", comment: "Plural unit of alcohol, lowercase for mid-sentence use")
    case .unitedKingdom: localized("units", comment: "Plural UK unit of alcohol, lowercase for mid-sentence use")
    }
  }

  /// The form that agrees with `count`.
  ///
  /// Both forms now come from the catalog, so a translator can replace them —
  /// but the *choice between them* is still English's two-category rule, and
  /// languages with more categories need the count and the noun in one key.
  /// That is why count-bearing sentences are catalog keys at their call sites
  /// rather than assembled from this (ADR-0020): a phrase key can carry real
  /// plural variations, a noun handed back to string interpolation cannot.
  public func unitName(for count: Double) -> String {
    count == 1 ? unitName : unitNamePlural
  }

  /// Fluid ounces of pure alcohol that make up one standard drink.
  public var flOzPureAlcoholPerStandardDrink: Double {
    switch self {
    // Literal constant from the brief: 0.6 fl oz == one US standard drink.
    case .unitedStates: 0.6
    case .unitedKingdom: Ethanol.fluidOunces(inGrams: 8)
    case .australia: Ethanol.fluidOunces(inGrams: 10)
    }
  }

  /// Grams of pure alcohol that make up one standard drink.
  public var gramsPureAlcoholPerStandardDrink: Double {
    switch self {
    case .unitedStates: Ethanol.grams(inFluidOunces: 0.6)
    case .unitedKingdom: 8
    case .australia: 10
    }
  }
}
