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

/// The four quick-add categories on the Today screen.
public enum DrinkType: String, CaseIterable, Codable, Sendable, Identifiable {
  case beer
  case wine
  case spirit
  case other

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .beer: "Beer"
    case .wine: "Wine"
    case .spirit: "Spirit"
    case .other: "Other"
    }
  }

  /// SF Symbol used on the quick-add row.
  public var symbolName: String {
    switch self {
    case .beer: "mug.fill"
    case .wine: "wineglass.fill"
    case .spirit: "flask.fill"
    case .other: "cup.and.saucer.fill"
    }
  }

  public var sizeOptions: [DrinkSizeOption] {
    switch self {
    case .beer:
      [
        .init(label: "12 oz can", volumeOunces: 12),
        .init(label: "16 oz pint", volumeOunces: 16),
        .init(label: "22 oz bottle", volumeOunces: 22),
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
    case .other:
      [.custom]
    }
  }

  /// The size pill pre-selected when the sheet opens.
  ///
  /// `.other` has no presets, so it opens on Custom seeded with `defaultVolumeOunces`.
  public var defaultSizeOption: DrinkSizeOption {
    sizeOptions[0]
  }

  /// Volume the sheet opens with, in US fluid ounces.
  public var defaultVolumeOunces: Double {
    switch self {
    case .beer: 12
    case .wine: 5
    case .spirit: 1
    case .other: 8
    }
  }

  public var defaultABVPercent: Double {
    switch self {
    case .beer: 5
    case .wine: 12
    case .spirit: 40
    case .other: 10
    }
  }

  public var abvRange: ClosedRange<Double> {
    switch self {
    case .beer: 0...15
    case .wine: 0...20
    case .spirit, .other: 0...60
    }
  }
}
