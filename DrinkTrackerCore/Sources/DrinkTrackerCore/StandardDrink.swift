import Foundation

/// The standard-drink calculation from the design brief.
///
/// ```
/// standard drinks = volume_oz × (ABV / 100) ÷ 0.6
/// ```
///
/// where `0.6` is the fluid ounces of pure alcohol in one US standard drink.
/// Other regions swap that divisor for their own definition — see `Region`.
public enum StandardDrink {

  /// Number of standard drinks in a given volume at a given ABV.
  ///
  /// - Parameters:
  ///   - volumeOunces: Liquid volume in US fluid ounces.
  ///   - abvPercent: Alcohol by volume, as a percentage (e.g. `5` for 5%).
  ///   - region: The standard-drink definition to measure against.
  public static func count(
    volumeOunces: Double,
    abvPercent: Double,
    region: Region = .unitedStates
  ) -> Double {
    guard volumeOunces > 0, abvPercent > 0 else { return 0 }
    let pureAlcoholFlOz = volumeOunces * (abvPercent / 100)
    return pureAlcoholFlOz / region.flOzPureAlcoholPerStandardDrink
  }

  /// Grams of pure ethanol in a given volume at a given ABV.
  public static func gramsOfAlcohol(volumeOunces: Double, abvPercent: Double) -> Double {
    guard volumeOunces > 0, abvPercent > 0 else { return 0 }
    return Ethanol.grams(inFluidOunces: volumeOunces * (abvPercent / 100))
  }
}

// MARK: - Display formatting

extension StandardDrink {
  /// Formats a running count for the large metric on the Today screen.
  ///
  /// Whole numbers render without a decimal ("3"), everything else to one place
  /// ("2.4"), which keeps the fast-path defaults reading as a clean "1".
  public static func formatted(_ count: Double) -> String {
    let rounded = (count * 10).rounded() / 10
    if rounded == rounded.rounded() {
      return String(format: "%.0f", rounded)
    }
    return String(format: "%.1f", rounded)
  }

  /// The live "≈ N standard drink(s)" line in the drink-detail sheet.
  public static func liveEstimate(_ count: Double, region: Region = .unitedStates) -> String {
    let rounded = (count * 10).rounded() / 10
    return "≈ \(formatted(count)) \(region.unitName(for: rounded))"
  }
}
