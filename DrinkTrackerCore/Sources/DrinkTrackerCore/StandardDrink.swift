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
  ///
  /// One key per region and number, rather than a number glued to a noun: the
  /// unit's name varies by region, its form varies by count, and word order
  /// varies by language — only a whole-phrase key can carry all three.
  public static func liveEstimate(_ count: Double, region: Region = .unitedStates) -> String {
    // "≈" is a symbol, not a word: it needs no translation, so it is composed
    // onto the phrase rather than baked into four more keys. Those keys also
    // could not coexist with `amountPhrase`'s — Xcode derives a Swift symbol
    // from each key, and it strips the "≈", so the two sets collided.
    "≈ \(amountPhrase(count, region: region))"
  }

  /// The same amount without the "≈", for labels that have already said "about"
  /// or that are read aloud, where the symbol has no reading.
  ///
  /// Exists so no call site has to glue `formatted` to `Region.unitName(for:)`
  /// itself. That assembly produces a catalog key of nothing but placeholders,
  /// and it picks the noun's form from the unrounded value, so a day of 1.02
  /// drinks says "1 standard drinks".
  public static func amountPhrase(_ count: Double, region: Region = .unitedStates) -> String {
    let value = formatted(count)
    let isSingular = readsAsOne(count)
    switch region {
    case .unitedStates, .australia:
      return isSingular
        ? localized("\(value) standard drink", comment: "An amount of alcohol, exactly one standard drink")
        : localized("\(value) standard drinks", comment: "An amount of alcohol; argument may be fractional")
    case .unitedKingdom:
      return isSingular
        ? localized("\(value) unit", comment: "An amount of alcohol, exactly one UK unit")
        : localized("\(value) units", comment: "An amount of alcohol; argument may be fractional")
    }
  }

  /// `liveEstimate` worded for VoiceOver, where "≈" is not a word.
  public static func accessibleEstimate(_ count: Double, region: Region = .unitedStates) -> String {
    let value = formatted(count)
    let isSingular = readsAsOne(count)
    switch region {
    case .unitedStates, .australia:
      return isSingular
        ? localized("Approximately \(value) standard drink", comment: "Spoken estimate, exactly one standard drink")
        : localized("Approximately \(value) standard drinks", comment: "Spoken estimate; argument may be fractional")
    case .unitedKingdom:
      return isSingular
        ? localized("Approximately \(value) unit", comment: "Spoken estimate, exactly one UK unit")
        : localized("Approximately \(value) units", comment: "Spoken estimate; argument may be fractional")
    }
  }

  /// Whether the digits a reader actually sees say "one".
  ///
  /// The noun has to agree with what is on screen, not with the full-precision
  /// value behind it: `formatted` rounds to one decimal, so 1.02 displays as "1"
  /// and must take the singular. Deciding on the raw value instead is what makes
  /// a label read "1 standard drinks".
  public static func readsAsOne(_ count: Double) -> Bool {
    (count * 10).rounded() / 10 == 1
  }
}
