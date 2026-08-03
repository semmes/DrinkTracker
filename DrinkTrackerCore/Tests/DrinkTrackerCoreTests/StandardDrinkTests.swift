import Foundation
import Testing
@testable import DrinkTrackerCore

@Suite("Standard drink math")
struct StandardDrinkTests {

  @Test("US formula matches the brief exactly")
  func usFormula() {
    // volume_oz × (ABV / 100) ÷ 0.6
    #expect(abs(StandardDrink.count(volumeOunces: 12, abvPercent: 5) - 1.0) < 0.0001)
    #expect(abs(StandardDrink.count(volumeOunces: 5, abvPercent: 12) - 1.0) < 0.0001)
    #expect(abs(StandardDrink.count(volumeOunces: 1.5, abvPercent: 40) - 1.0) < 0.0001)
  }

  @Test("Zero and negative inputs produce zero, not NaN")
  func degenerateInputs() {
    #expect(StandardDrink.count(volumeOunces: 0, abvPercent: 5) == 0)
    #expect(StandardDrink.count(volumeOunces: 12, abvPercent: 0) == 0)
    #expect(StandardDrink.count(volumeOunces: -12, abvPercent: 5) == 0)
  }

  @Test("US standard drink is 14 g of ethanol")
  func usGrams() {
    #expect(abs(Region.unitedStates.gramsPureAlcoholPerStandardDrink - 14.0) < 0.05)
  }

  @Test("UK and Australian units derive from their gram definitions")
  func regionalUnits() {
    #expect(Region.unitedKingdom.gramsPureAlcoholPerStandardDrink == 8)
    #expect(Region.australia.gramsPureAlcoholPerStandardDrink == 10)

    // A UK unit is smaller than a US standard drink, so the same pint counts for more.
    let pintUS = StandardDrink.count(volumeOunces: 16, abvPercent: 5, region: .unitedStates)
    let pintUK = StandardDrink.count(volumeOunces: 16, abvPercent: 5, region: .unitedKingdom)
    let pintAU = StandardDrink.count(volumeOunces: 16, abvPercent: 5, region: .australia)
    #expect(pintUK > pintAU)
    #expect(pintAU > pintUS)
  }

  /// The brief's UK line reads "0.28 fl oz / 8g", but those two figures do not
  /// describe the same quantity: 8 g of ethanol is ~0.343 US fl oz. The gram
  /// figure matches the published UK unit, so that is what the code uses.
  @Test("UK fl oz is derived from 8 g, not the brief's 0.28 figure")
  func ukFluidOunceDiscrepancy() {
    let derived = Region.unitedKingdom.flOzPureAlcoholPerStandardDrink
    #expect(abs(derived - 0.3429) < 0.001)
    #expect(abs(derived - 0.28) > 0.05)
  }

  @Test("Formatting drops trailing decimals on whole numbers")
  func formatting() {
    #expect(StandardDrink.formatted(1.0) == "1")
    #expect(StandardDrink.formatted(2.44) == "2.4")
    #expect(StandardDrink.formatted(0) == "0")
    #expect(StandardDrink.liveEstimate(1.0) == "≈ 1 standard drink")
    #expect(StandardDrink.liveEstimate(2.5) == "≈ 2.5 standard drinks")
    #expect(StandardDrink.liveEstimate(1.0, region: .unitedKingdom) == "≈ 1 unit")
  }
}

@Suite("Per-type defaults")
struct DrinkTypeDefaultsTests {

  @Test("Defaults match the brief's configuration table")
  func defaultsTable() {
    #expect(DrinkType.beer.defaultVolumeOunces == 12)
    #expect(DrinkType.beer.defaultABVPercent == 5)
    #expect(DrinkType.wine.defaultVolumeOunces == 5)
    #expect(DrinkType.wine.defaultABVPercent == 12)
    #expect(DrinkType.spirit.defaultVolumeOunces == 1.5)
    #expect(DrinkType.spirit.defaultABVPercent == 40)
    #expect(DrinkType.other.defaultVolumeOunces == 8)
    #expect(DrinkType.other.defaultABVPercent == 10)
  }

  /// The one-drink invariant, now a settled decision rather than a discrepancy:
  /// every type with a real serving size opens at almost exactly 1.0 standard
  /// drink. Spirit moved from the 1 oz shot (0.67) to the 1.5 oz shot, which at
  /// 40% is 0.6 fl oz of ethanol — the US definition exactly.
  /// See docs/decisions/0005-spirit-defaults-to-the-1_5-oz-shot.md.
  @Test("Every type with a real serving size defaults to 1.0 standard drink")
  func defaultsHitTheOneDrinkInvariant() {
    for type in [DrinkType.beer, .wine, .spirit] {
      #expect(abs(drinks(type) - 1.0) < 0.01, "\(type.displayName) should open at one drink")
    }
  }

  /// Other is the deliberate exception, not an oversight: it has no presets and
  /// no typical serving to anchor to, so its default seeds the Custom field
  /// rather than describing a real drink.
  @Test("Other is exempt from the one-drink invariant")
  func otherIsExempt() {
    #expect(abs(drinks(.other) - 1.3333) < 0.01)
  }

  /// The pre-selected pill and the default volume have to agree, because the
  /// pill's volume is what `DrinkDraft.volumeOunces` actually uses. Before these
  /// were derived from each other, changing one silently did nothing.
  @Test("The default pill matches the default volume for every type")
  func defaultPillMatchesDefaultVolume() {
    for type in DrinkType.allCases {
      let selected = type.defaultSizeOption.volumeOunces ?? type.defaultVolumeOunces
      #expect(selected == type.defaultVolumeOunces, "\(type.displayName) pill disagrees")
    }
    #expect(DrinkType.spirit.defaultSizeOption.label == "1.5 oz shot")
    #expect(DrinkType.other.defaultSizeOption.isCustom)
  }

  private func drinks(_ type: DrinkType) -> Double {
    StandardDrink.count(
      volumeOunces: type.defaultVolumeOunces,
      abvPercent: type.defaultABVPercent
    )
  }

  @Test("Only Other is custom-only")
  func sizeOptions() {
    #expect(DrinkType.beer.sizeOptions.count == 4)
    #expect(DrinkType.wine.sizeOptions.count == 3)
    #expect(DrinkType.spirit.sizeOptions.count == 4)
    #expect(DrinkType.other.sizeOptions == [.custom])
    for type in DrinkType.allCases {
      #expect(type.sizeOptions.contains(.custom))
    }
  }
}

@Suite("Drink draft")
struct DrinkDraftTests {

  /// Region is a display lens, not a property of the drink. An entry logged under
  /// one region must re-express in whatever region the caller asks for, otherwise
  /// totals would sum UK units and US standard drinks together.
  @Test("Totals use the caller's region, not the one stamped on the entry")
  func regionIsADisplayLens() {
    let loggedUnderUK = LoggedDrink(
      type: .beer,
      volumeOunces: 12,
      abvPercent: 5,
      region: .unitedKingdom
    )
    #expect(abs(loggedUnderUK.standardDrinks(in: .unitedStates) - 1.0) < 0.001)
    #expect(abs(loggedUnderUK.standardDrinks(in: .unitedKingdom) - 1.75) < 0.01)
    #expect(abs(loggedUnderUK.standardDrinks(in: .australia) - 1.4) < 0.01)

    // The underlying alcohol is identical regardless of the lens.
    #expect(abs(loggedUnderUK.gramsOfAlcohol - 14.0) < 0.05)
  }

  @Test("A mixed-region history sums coherently in one unit")
  func mixedHistorySumsCoherently() {
    let drinks = [
      LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedStates),
      LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedKingdom)
    ]
    // Two identical beers are two US standard drinks, whatever they were logged under.
    let inUS = drinks.reduce(0) { $0 + $1.standardDrinks(in: .unitedStates) }
    #expect(abs(inUS - 2.0) < 0.001)

    let inUK = drinks.reduce(0) { $0 + $1.standardDrinks(in: .unitedKingdom) }
    #expect(abs(inUK - 3.5) < 0.02)
  }

  @Test("A fresh draft is immediately loggable with the type's defaults")
  func freshDraft() {
    let draft = DrinkDraft(type: .beer)
    #expect(draft.volumeOunces == 12)
    #expect(draft.abvPercent == 5)
    #expect(draft.isABVExpanded == false)
    #expect(draft.editingEntryID == nil)
    #expect(abs(draft.standardDrinks(region: .unitedStates) - 1.0) < 0.0001)
  }

  /// The end-to-end payoff of ADR-0005, at the layer the user actually touches:
  /// tapping Spirit and logging without adjusting anything records one drink.
  @Test("A fresh spirit draft opens on the 1.5 oz shot and reads as one drink")
  func freshSpiritDraft() {
    let draft = DrinkDraft(type: .spirit)
    #expect(draft.selectedSize.label == "1.5 oz shot")
    #expect(draft.volumeOunces == 1.5)
    #expect(draft.abvPercent == 40)
    #expect(abs(draft.standardDrinks(region: .unitedStates) - 1.0) < 0.0001)
  }

  @Test("Other opens on the Custom pill seeded with 8 oz")
  func otherDraft() {
    let draft = DrinkDraft(type: .other)
    #expect(draft.selectedSize.isCustom)
    #expect(draft.volumeOunces == 8)
  }

  @Test("Editing an entry restores its preset pill when one matches")
  func editRestoresPreset() {
    let entry = LoggedDrink(type: .beer, volumeOunces: 16, abvPercent: 6)
    let draft = DrinkDraft(editing: entry)
    #expect(draft.selectedSize.label == "16 oz pint")
    #expect(draft.abvPercent == 6)
    #expect(draft.editingEntryID == entry.id)
  }

  @Test("Editing an off-preset volume falls back to Custom")
  func editFallsBackToCustom() {
    let entry = LoggedDrink(type: .beer, volumeOunces: 13.5, abvPercent: 5)
    let draft = DrinkDraft(editing: entry)
    #expect(draft.selectedSize.isCustom)
    #expect(draft.customVolumeOunces == 13.5)
    #expect(draft.volumeOunces == 13.5)
  }

  @Test("Quantity produces that many separate entries with distinct identities")
  func quantityMakesSeparateEntries() {
    var draft = DrinkDraft(type: .beer)
    draft.quantity = 3
    let drinks = draft.makeLoggedDrinks(region: .unitedStates)

    #expect(drinks.count == 3)
    // Distinct ids, so each stays individually editable and removable.
    #expect(Set(drinks.map(\.id)).count == 3)
    // Same drink, so they contribute equally.
    #expect(drinks.allSatisfy { $0.volumeOunces == 12 && $0.abvPercent == 5 })
    #expect(abs(drinks.reduce(0) { $0 + $1.standardDrinks(in: .unitedStates) } - 3.0) < 0.001)
    // Staggered so ordering is deterministic, but only just.
    let times = drinks.map(\.loggedAt).sorted()
    #expect(times == drinks.map(\.loggedAt))
    #expect(times.last!.timeIntervalSince(times.first!) == 2)
  }

  @Test("Quantity is ignored when editing, and never goes below one")
  func quantityBounds() {
    let existing = LoggedDrink(type: .wine, volumeOunces: 5, abvPercent: 12)
    var editing = DrinkDraft(editing: existing)
    editing.quantity = 4
    // Editing one entry must not fan it out into four.
    #expect(editing.makeLoggedDrinks(region: .unitedStates).count == 1)
    #expect(editing.makeLoggedDrinks(region: .unitedStates).first?.id == existing.id)

    var zero = DrinkDraft(type: .beer)
    zero.quantity = 0
    #expect(zero.makeLoggedDrinks(region: .unitedStates).count == 1)
  }

  @Test("Repeating a drink copies it but makes a new entry")
  func repeatingADrink() {
    let original = LoggedDrink(
      loggedAt: Date(timeIntervalSince1970: 1_700_000_000),
      type: .beer,
      volumeOunces: 16,
      abvPercent: 6.5
    )
    let later = Date(timeIntervalSince1970: 1_700_003_600)
    let draft = DrinkDraft.repeating(original, at: later)

    #expect(draft.type == .beer)
    #expect(draft.volumeOunces == 16)
    #expect(draft.abvPercent == 6.5)
    #expect(draft.loggedAt == later)
    // Crucially not an edit — the original stays put.
    #expect(draft.editingEntryID == nil)
    #expect(draft.makeLoggedDrink(region: .unitedStates).id != original.id)
  }

  @Test("Changing type resets size and ABV to the new type's defaults")
  func changeType() {
    var draft = DrinkDraft(type: .beer)
    draft.abvPercent = 9
    draft.changeType(to: .wine)
    #expect(draft.volumeOunces == 5)
    #expect(draft.abvPercent == 12)
  }
}

@Suite("Trend aggregation")
struct TrendSummaryTests {

  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  private func day(_ offset: Int, from reference: Date) -> Date {
    calendar.date(byAdding: .day, value: offset, to: reference)!
  }

  @Test("Empty days are kept in the series with a zero total")
  func continuousAxis() {
    let today = Date(timeIntervalSince1970: 1_700_000_000)
    let entries = [
      LoggedDrink(loggedAt: today, type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(loggedAt: day(-2, from: today), type: .wine, volumeOunces: 5, abvPercent: 12)
    ]
    let totals = TrendSummary.dailyTotals(
      range: .week,
      endingOn: today,
      drinks: entries,
      region: .unitedStates,
      calendar: calendar
    )
    #expect(totals.count == 7)
    let dates: [Date] = totals.map(\.date)
    #expect(dates == dates.sorted())
    #expect(abs(TrendSummary.sum(totals) - 2.0) < 0.0001)
    #expect(TrendSummary.daysWithoutDrinks(totals) == 5)
    #expect(abs(TrendSummary.dailyAverage(totals) - 2.0 / 7.0) < 0.0001)
  }

  @Test("Multiple entries on one day sum together")
  func sameDaySum() {
    let today = Date(timeIntervalSince1970: 1_700_000_000)
    let entries = [
      LoggedDrink(loggedAt: today, type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(loggedAt: today, type: .beer, volumeOunces: 12, abvPercent: 5)
    ]
    let total = TrendSummary.total(
      for: today,
      in: entries,
      region: .unitedStates,
      calendar: calendar
    )
    #expect(abs(total - 2.0) < 0.0001)
  }

  @Test("Grouping puts newest day first and newest drink first within a day")
  func grouping() {
    let today = Date(timeIntervalSince1970: 1_700_000_000)
    let earlier = today.addingTimeInterval(-3600)
    let twoDaysAgo = day(-2, from: today)

    let groups = TrendSummary.groupedByDay(
      [
        LoggedDrink(loggedAt: earlier, type: .beer, volumeOunces: 12, abvPercent: 5),
        LoggedDrink(loggedAt: twoDaysAgo, type: .wine, volumeOunces: 5, abvPercent: 12),
        LoggedDrink(loggedAt: today, type: .spirit, volumeOunces: 1.5, abvPercent: 40)
      ],
      calendar: calendar
    )

    #expect(groups.count == 2)
    #expect(groups[0].day > groups[1].day)
    // Newest first within the day: the spirit was logged after the beer.
    #expect(groups[0].drinks.map(\.type) == [.spirit, .beer])
    #expect(abs(groups[0].total(in: .unitedStates) - 2.0) < 0.001)
  }

  @Test("Grouping omits days with nothing logged")
  func groupingOmitsEmptyDays() {
    let today = Date(timeIntervalSince1970: 1_700_000_000)
    let groups = TrendSummary.groupedByDay(
      [
        LoggedDrink(loggedAt: today, type: .beer, volumeOunces: 12, abvPercent: 5),
        LoggedDrink(loggedAt: day(-5, from: today), type: .beer, volumeOunces: 12, abvPercent: 5)
      ],
      calendar: calendar
    )
    // Five days apart, but only the two days with entries appear.
    #expect(groups.count == 2)
    #expect(TrendSummary.groupedByDay([], calendar: calendar).isEmpty)
  }

  @Test("Averages over an empty series do not divide by zero")
  func emptySeries() {
    #expect(TrendSummary.dailyAverage([]) == 0)
    #expect(TrendSummary.sum([]) == 0)
  }
}
