import Foundation

/// A single logged drink, as a plain value.
///
/// This is the type the domain layer computes over. Persistence lives in the app
/// target as a SwiftData `@Model` class that maps to and from this struct, which
/// keeps the standard-drink math and trend aggregation free of any store and
/// directly unit-testable.
public struct LoggedDrink: Identifiable, Hashable, Sendable {
  public var id: UUID
  public var loggedAt: Date
  public var type: DrinkType
  public var volumeOunces: Double
  public var abvPercent: Double
  /// The region in effect when this drink was logged.
  ///
  /// Provenance only — it is deliberately *not* used to compute totals. Volume and
  /// ABV are the physical facts; a region is just the unit those facts get
  /// expressed in, so totals are always computed in one consistent region chosen by
  /// the caller. Summing entries by their own stored regions would add UK units to
  /// US standard drinks, which is meaningless.
  public var region: Region
  /// UUID of the HealthKit sample behind this drink, if any: one the app wrote
  /// for its own entry, or — when `countedDrinks` is set — another app's sample
  /// this entry mirrors.
  public var healthKitSampleID: UUID?
  /// Non-nil for drinks imported from Apple Health that another app recorded.
  ///
  /// External samples carry only a count and a time — no volume, no ABV — so an
  /// imported drink cannot honestly join the gram math. Instead it *is* its
  /// count: `standardDrinks(in:)` returns this value in every region, because
  /// "a drink" from an unknown source is one drink under any lens, and any
  /// conversion would be invented precision (ADR-0014).
  public var countedDrinks: Double?

  /// True for entries mirrored from another app's Health data.
  public var isImportedFromHealth: Bool { countedDrinks != nil }

  /// Whether this drink can serve as the template for another one.
  ///
  /// Volume is the test, not `isImportedFromHealth`, because provenance is not
  /// reliably recoverable (ADR-0022). Every import is a zero-volume shell by
  /// construction, but `countedDrinks` is an additive attribute: a store shared
  /// with a build that predates it mirrors those rows back with the marker
  /// stripped, and they then read as ordinary drinks. Volume survives that,
  /// and it separates the two cases exactly — the detail sheet refuses to save
  /// a drink without one, so a zero volume is never something the user typed.
  ///
  /// Strength is deliberately *not* part of the test. A real size at 0% is a
  /// drink someone chose to record that way, and rewriting it to the type's
  /// default strength would record alcohol they did not have.
  public var isRepeatable: Bool { volumeOunces > 0 }

  public init(
    id: UUID = UUID(),
    loggedAt: Date = Date(),
    type: DrinkType,
    volumeOunces: Double,
    abvPercent: Double,
    region: Region = .unitedStates,
    healthKitSampleID: UUID? = nil,
    countedDrinks: Double? = nil
  ) {
    self.id = id
    self.loggedAt = loggedAt
    self.type = type
    self.volumeOunces = volumeOunces
    self.abvPercent = abvPercent
    self.region = region
    self.healthKitSampleID = healthKitSampleID
    self.countedDrinks = countedDrinks
  }

  /// An entry mirroring `count` beverages another app recorded in Health.
  ///
  /// Type is `.other` with zero volume and strength — the physical facts are
  /// unknown, and zero says so louder than a plausible-looking default would.
  public static func importedFromHealth(
    sampleID: UUID,
    count: Double,
    loggedAt: Date
  ) -> LoggedDrink {
    LoggedDrink(
      loggedAt: loggedAt,
      type: .other,
      volumeOunces: 0,
      abvPercent: 0,
      healthKitSampleID: sampleID,
      countedDrinks: max(0, count)
    )
  }

  /// One standard drink, as the current region defines it, with no type stated
  /// (ADR-0023).
  ///
  /// **What it stores, and why it is not a beverage.** Volume and ABV are the
  /// ethanol a standard drink is *defined* as — the region's own
  /// `flOzPureAlcoholPerStandardDrink`, at 100%. Materialising 12 oz at 5%
  /// instead would have been the obvious move and is the wrong one twice: it
  /// claims a beer the user never mentioned, and it bakes the US definition
  /// into a UK user's log. The definition is the one fact actually in
  /// evidence, so it is the one stored.
  ///
  /// **Why not zero, the way an import is.** A zero-volume row is exactly the
  /// shape ADR-0022 taught us not to mint: a build predating `.unspecified`
  /// decodes the type to `.other` (see `DrinkEntry.logged`), and if the row
  /// also had no volume it would be indistinguishable from the empty
  /// "Other, 0oz, 0%" drinks of the field bug — repeatable, absorbing, and
  /// wrong. With real facts, the worst an older build can do is label it
  /// "Other" and show 0.6oz at 100%: an odd-looking row whose *arithmetic is
  /// exactly right*, in every region, and which repeats to another honest
  /// standard drink. Degrading to ugly beats degrading to false.
  ///
  /// **The region is a lens here like everywhere else** (ADR-0002). This is a
  /// physical fact, so switching to the UK re-expresses a US-logged standard
  /// drink as 1.75 units, exactly as it does a 12 oz beer. Freezing it at 1.0
  /// under every lens would have made these rows a second region-immune
  /// class alongside imports, and a day holding one of each would report two
  /// different arithmetics.
  public static func standardDrink(
    in region: Region,
    at date: Date = Date()
  ) -> LoggedDrink {
    LoggedDrink(
      loggedAt: date,
      type: .unspecified,
      volumeOunces: region.flOzPureAlcoholPerStandardDrink,
      abvPercent: 100,
      region: region
    )
  }

  /// True for a drink logged as one standard drink with no type stated.
  public var isTypeUnspecified: Bool { type == .unspecified }

  /// Whether this entry's size and strength are facts the user supplied.
  ///
  /// False for the two kinds of row that carry a count rather than a
  /// measurement: a Health import (which never had them) and an untyped
  /// standard drink (whose stored 0.6oz/100% is the *definition* it was
  /// logged against, not a serving anyone poured). Surfaces that print size
  /// and strength check this instead of testing for imports alone, so
  /// neither kind is rendered as a claim the user did not make.
  public var recordsSizeAndStrength: Bool {
    !isImportedFromHealth && !isTypeUnspecified
  }

  /// Whether this imported drink can be adopted — turned into a full typed
  /// entry (ADR-0016).
  ///
  /// Exactly the single-count imports. A multi-count sample ("3 drinks") can't
  /// become one typed entry without breaking invariant 7 (quantity is N
  /// separate entries, never a count on one), and splitting it into N entries
  /// has no honest Health story yet: only one entry can carry the external
  /// sample's id, and the rest would backfill fresh Tallyist samples on top of
  /// the external one — double-counting in Health. So the boundary sits here.
  public var isAdoptable: Bool { countedDrinks == 1 }

  /// The adopted form of an imported drink: same identity, same time, same
  /// external sample id — with the physical facts the user just typed in.
  ///
  /// Clearing `countedDrinks` is what flips every downstream behaviour at
  /// once: `standardDrinks(in:)` starts doing real math under the region
  /// lens, the row renders size and strength, and deletion sync stops
  /// treating it as a mirror. Keeping `healthKitSampleID` is load-bearing
  /// twice over — it is the dedup key that stops a re-import from
  /// resurrecting the count, and its presence keeps the entry out of the
  /// HealthKit backfill so no second sample is ever written (ADR-0016).
  public func adopting(
    type: DrinkType,
    volumeOunces: Double,
    abvPercent: Double,
    region: Region
  ) -> LoggedDrink {
    LoggedDrink(
      id: id,
      loggedAt: loggedAt,
      type: type,
      volumeOunces: volumeOunces,
      abvPercent: abvPercent,
      region: region,
      healthKitSampleID: healthKitSampleID,
      countedDrinks: nil
    )
  }

  /// This drink's contribution to a daily total, expressed in `region`'s units.
  ///
  /// Callers pass the user's *current* region, not `self.region`, so changing the
  /// setting re-expresses the whole history in the new unit rather than leaving a
  /// pile of mixed, unaddable numbers. Imported drinks are the one exception to
  /// re-expression: their count is the whole fact, so it is the same number under
  /// every lens.
  public func standardDrinks(in region: Region) -> Double {
    if let countedDrinks { return countedDrinks }
    return StandardDrink.count(volumeOunces: volumeOunces, abvPercent: abvPercent, region: region)
  }

  /// Grams of pure ethanol, which is what gets written to HealthKit alongside
  /// the beverage count.
  public var gramsOfAlcohol: Double {
    StandardDrink.gramsOfAlcohol(volumeOunces: volumeOunces, abvPercent: abvPercent)
  }

  /// The "last logged" line under the Today metric, e.g. "Beer, 12oz, 5% ABV".
  /// Whole sentences, not assembled fragments: each is one catalog key with
  /// its arguments in place, so a translation can reorder them (ADR-0020).
  /// Building this by interpolation would have frozen English word order into
  /// every surface that shows a drink — the row, the export, and the line
  /// Siri speaks.
  public var summaryLine: String {
    if let countedDrinks {
      let count = Self.format(countedDrinks)
      return countedDrinks == 1
        ? localized("From Apple Health, 1 drink", comment: "A drink imported from Apple Health, singular")
        : localized("From Apple Health, \(count) drinks", comment: "A drink imported from Apple Health; argument is a count, which may be fractional")
    }
    // An untyped drink says what it is and stops. Interpolating its stored
    // 0.6oz at 100% into the line below would print the definition back at
    // the user as though they had typed it (ADR-0023).
    if isTypeUnspecified {
      return localized(
        "One standard drink",
        comment: "A drink logged as one standard drink, with no type or size recorded"
      )
    }
    return localized(
      "\(type.displayName), \(Self.format(volumeOunces))oz, \(Self.format(abvPercent))% ABV",
      comment: "One logged drink: type, size in fluid ounces, strength as a percentage"
    )
  }

  static func format(_ value: Double) -> String {
    value == value.rounded()
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
  }
}
