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
        // The 22 oz bottle was dropped to keep the row to the two common cases;
        // anything larger is one tap away on Custom.
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
  /// Beer, wine, and spirit each resolve to almost exactly 1.0 US standard drink
  /// at their default ABV, so "one drink" in the app means one drink. Spirit uses
  /// the 1.5 oz shot for that reason: at 40% it is 0.6 fl oz of ethanol, which is
  /// the US definition exactly. See
  /// docs/decisions/0005-spirit-defaults-to-the-1_5-oz-shot.md.
  public var defaultVolumeOunces: Double {
    switch self {
    case .beer: 12
    case .wine: 5
    case .spirit: 1.5
    // Other is the deliberate exception: 8 oz @ 10% is 1.33 standard drinks. It
    // has no presets and no typical serving to anchor to, so its default is a
    // starting point for the Custom field rather than a claim about a real drink.
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
