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
    case .unitedStates: "United States"
    case .unitedKingdom: "United Kingdom"
    case .australia: "Australia"
    }
  }

  /// Short label used in compact controls such as segmented pickers.
  public var shortName: String {
    switch self {
    case .unitedStates: "US"
    case .unitedKingdom: "UK"
    case .australia: "Australia"
    }
  }

  /// What one standard drink is called in this region.
  public var unitName: String {
    switch self {
    case .unitedStates, .australia: "standard drink"
    case .unitedKingdom: "unit"
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
    case .unitedStates, .australia: "standard drinks"
    case .unitedKingdom: "units"
    }
  }

  /// The form that agrees with `count`.
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
