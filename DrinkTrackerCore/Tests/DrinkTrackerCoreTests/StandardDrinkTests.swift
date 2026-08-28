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

  /// Plural forms are declared per region rather than built by appending "s".
  /// Six call sites used to do the latter, which is an English rule applied by
  /// string surgery and the first thing to break under translation.
  @Test("Each region declares both forms, and agreement picks the right one")
  func unitNameAgreement() {
    for region in Region.allCases {
      #expect(region.unitName(for: 1) == region.unitName)
      #expect(region.unitName(for: 0) == region.unitNamePlural)
      #expect(region.unitName(for: 2) == region.unitNamePlural)
      #expect(region.unitName(for: 0.5) == region.unitNamePlural)
      #expect(region.unitNamePlural != region.unitName)
    }
    #expect(Region.unitedKingdom.unitNamePlural == "units")
    #expect(Region.unitedStates.unitNamePlural == "standard drinks")
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
    // Beer dropped the 22 oz bottle: two common sizes plus Custom.
    #expect(DrinkType.beer.sizeOptions.count == 3)
    #expect(!DrinkType.beer.sizeOptions.contains { $0.volumeOunces == 22 })
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

  @Test("Quick count seeds from the most-logged type at its last-logged size")
  func quickCountSeedsFromHistory() {
    let history = [
      LoggedDrink(loggedAt: Date(timeIntervalSince1970: 1_000), type: .wine, volumeOunces: 5, abvPercent: 12),
      LoggedDrink(loggedAt: Date(timeIntervalSince1970: 3_000), type: .wine, volumeOunces: 8, abvPercent: 13),
      LoggedDrink(loggedAt: Date(timeIntervalSince1970: 2_000), type: .beer, volumeOunces: 12, abvPercent: 5)
    ]
    let draft = DrinkDraft.quickCount(3, from: history)
    #expect(draft.type == .wine)
    #expect(draft.volumeOunces == 8)
    #expect(draft.abvPercent == 13)
    #expect(draft.quantity == 3)
    #expect(draft.editingEntryID == nil)
    #expect(draft.makeLoggedDrinks(region: .unitedStates).count == 3)
  }

  @Test("Quick count with no history is beer's defaults — one standard drink each")
  func quickCountEmptyHistory() {
    let draft = DrinkDraft.quickCount(2, from: [])
    #expect(draft.type == .beer)
    #expect(abs(draft.standardDrinks(region: .unitedStates) - 1.0) < 0.01)
    #expect(draft.quantity == 2)
  }

  @Test("Quick count never produces fewer than one drink")
  func quickCountClampsToOne() {
    #expect(DrinkDraft.quickCount(0, from: []).quantity == 1)
    #expect(DrinkDraft.quickCount(-3, from: []).quantity == 1)
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

@Suite("Imported Health drinks")
struct ImportedDrinkTests {

  @Test("A count-based drink is the same number in every region")
  func countIsRegionIndependent() {
    let imported = LoggedDrink.importedFromHealth(
      sampleID: UUID(),
      count: 3,
      loggedAt: Date()
    )
    for region in Region.allCases {
      #expect(imported.standardDrinks(in: region) == 3)
    }
  }

  @Test("A gram-based drink still re-expresses per region")
  func gramBasedStillLensed() {
    let beer = LoggedDrink(type: .beer, volumeOunces: 16, abvPercent: 5)
    #expect(beer.standardDrinks(in: .unitedStates) != beer.standardDrinks(in: .unitedKingdom))
  }

  @Test("Imported drinks never seed the quick-log template")
  func importedNeverSeeds() {
    let importedOnly = [
      LoggedDrink.importedFromHealth(sampleID: UUID(), count: 2, loggedAt: Date()),
      LoggedDrink.importedFromHealth(sampleID: UUID(), count: 1, loggedAt: Date()),
    ]
    #expect(TrendSummary.mostLoggedType(in: importedOnly) == nil)

    // One real wine among many imported "other" shells: the wine wins, and the
    // most-recent lookup skips the shells too.
    let mixed = importedOnly + [LoggedDrink(type: .wine, volumeOunces: 5, abvPercent: 12)]
    #expect(TrendSummary.mostLoggedType(in: mixed) == .wine)
    #expect(TrendSummary.mostRecentDrink(ofType: .other, in: mixed) == nil)
  }

  @Test("A negative external count clamps to zero rather than subtracting")
  func negativeCountClamps() {
    let imported = LoggedDrink.importedFromHealth(sampleID: UUID(), count: -2, loggedAt: Date())
    #expect(imported.standardDrinks(in: .unitedStates) == 0)
  }

  @Test("The imported summary line says where the drink came from")
  func importedSummaryLine() {
    let one = LoggedDrink.importedFromHealth(sampleID: UUID(), count: 1, loggedAt: Date())
    let three = LoggedDrink.importedFromHealth(sampleID: UUID(), count: 3, loggedAt: Date())
    #expect(one.summaryLine == "From Apple Health, 1 drink")
    #expect(three.summaryLine == "From Apple Health, 3 drinks")
  }
}

@Suite("Long trend ranges")
struct LongTrendRangeTests {

  /// UTC and Gregorian so expected dates don't depend on the machine.
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
  }

  @Test("A quarter is 12 complete calendar weeks plus the current partial one")
  func quarterSpan() {
    // 2026-08-26 is a Wednesday; with a Sunday-first calendar the current week
    // began Sunday the 23rd, so the range starts 12 weeks before that.
    let today = date(2026, 8, 26)
    let start = TrendRange.quarter.startDate(endingOn: today, calendar: calendar)
    #expect(start == calendar.startOfDay(for: date(2026, 5, 31)))

    let totals = TrendSummary.dailyTotals(
      range: .quarter, endingOn: today, drinks: [], region: .unitedStates, calendar: calendar
    )
    // 12 full weeks + Sunday..Wednesday of the current week.
    #expect(totals.count == 12 * 7 + 4)

    let buckets = TrendSummary.bucketed(totals, by: .weekOfYear, calendar: calendar)
    #expect(buckets.count == 13)
    #expect(buckets.allSatisfy { calendar.dateInterval(of: .weekOfYear, for: $0.start)?.start == $0.start })
    #expect(buckets.dropLast().allSatisfy { $0.dayCount == 7 })
    #expect(buckets.last?.dayCount == 4)
  }

  @Test("Week starts follow the calendar's first weekday, Monday-first included")
  func quarterRespectsFirstWeekday() {
    var monday = calendar
    monday.firstWeekday = 2
    let today = date(2026, 8, 26)
    let start = TrendRange.quarter.startDate(endingOn: today, calendar: monday)
    // Monday-first: the current week began Monday the 24th; 12 weeks earlier
    // is Monday June 1st.
    #expect(start == monday.startOfDay(for: date(2026, 6, 1)))
  }

  @Test("A year is 11 complete calendar months plus the current partial one")
  func yearSpan() {
    let today = date(2026, 8, 26)
    let start = TrendRange.year.startDate(endingOn: today, calendar: calendar)
    #expect(start == calendar.startOfDay(for: date(2025, 9, 1)))

    let totals = TrendSummary.dailyTotals(
      range: .year, endingOn: today, drinks: [], region: .unitedStates, calendar: calendar
    )
    let buckets = TrendSummary.bucketed(totals, by: .month, calendar: calendar)
    #expect(buckets.count == 12)
    #expect(buckets.first?.start == calendar.startOfDay(for: date(2025, 9, 1)))
    #expect(buckets.first?.dayCount == 30)
    #expect(buckets.last?.start == calendar.startOfDay(for: date(2026, 8, 1)))
    #expect(buckets.last?.dayCount == 26)
  }

  @Test("Buckets sum their days, and empty weeks stay in the series as zero")
  func bucketSums() {
    let today = date(2026, 8, 26)
    let drinks = [
      // Two beers in the current partial week.
      LoggedDrink(loggedAt: date(2026, 8, 24), type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(loggedAt: date(2026, 8, 25), type: .beer, volumeOunces: 12, abvPercent: 5),
      // One in the first week of the range.
      LoggedDrink(loggedAt: date(2026, 6, 2), type: .beer, volumeOunces: 12, abvPercent: 5),
    ]
    let totals = TrendSummary.dailyTotals(
      range: .quarter, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar
    )
    let buckets = TrendSummary.bucketed(totals, by: .weekOfYear, calendar: calendar)
    #expect(buckets.count == 13)
    #expect(abs(buckets.first!.standardDrinks - 1.0) < 0.0001)
    #expect(abs(buckets.last!.standardDrinks - 2.0) < 0.0001)
    #expect(buckets.dropFirst().dropLast().allSatisfy { $0.standardDrinks == 0 })
    #expect(abs(TrendSummary.sum(totals) - 3.0) < 0.0001)
  }

  @Test("The bucket average uses completed buckets only")
  func bucketAverageExcludesPartial() {
    let today = date(2026, 8, 26)
    let drinks = [
      // Heavy partial week that must NOT drag the completed-week mean.
      LoggedDrink(loggedAt: date(2026, 8, 24), type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(loggedAt: date(2026, 8, 24), type: .beer, volumeOunces: 12, abvPercent: 5),
      // One drink in each of two completed weeks.
      LoggedDrink(loggedAt: date(2026, 8, 18), type: .beer, volumeOunces: 12, abvPercent: 5),
      LoggedDrink(loggedAt: date(2026, 8, 11), type: .beer, volumeOunces: 12, abvPercent: 5),
    ]
    let totals = TrendSummary.dailyTotals(
      range: .quarter, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar
    )
    let buckets = TrendSummary.bucketed(totals, by: .weekOfYear, calendar: calendar)
    let average = TrendSummary.bucketAverage(buckets, unit: .weekOfYear, calendar: calendar)
    // 2 drinks over 12 completed weeks — the partial week's 2.0 is excluded.
    #expect(average != nil)
    #expect(abs(average! - 2.0 / 12.0) < 0.0001)
  }

  @Test("No completed bucket means no average line")
  func bucketAverageNilWhenAllPartial() {
    let today = date(2026, 8, 26)
    let partialWeek = [
      PeriodTotal(start: calendar.dateInterval(of: .weekOfYear, for: today)!.start,
                  standardDrinks: 2, dayCount: 4)
    ]
    #expect(TrendSummary.bucketAverage(partialWeek, unit: .weekOfYear, calendar: calendar) == nil)
  }

  @Test("A year of mixed-region history sums under the current lens only")
  func regionLensOverAYear() {
    // Invariant 3: entries carry their logged region as provenance, but a
    // year-long total is always one region's number, never a mixed sum.
    let today = date(2026, 8, 26)
    let drinks = [
      LoggedDrink(loggedAt: date(2025, 10, 10), type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedKingdom),
      LoggedDrink(loggedAt: date(2026, 3, 3), type: .beer, volumeOunces: 12, abvPercent: 5, region: .australia),
      LoggedDrink(loggedAt: date(2026, 8, 20), type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedStates),
    ]
    let totals = TrendSummary.dailyTotals(
      range: .year, endingOn: today, drinks: drinks, region: .unitedStates, calendar: calendar
    )
    // Three identical beers = exactly 3.0 US standard drinks, regardless of
    // the regions they were logged under.
    #expect(abs(TrendSummary.sum(totals) - 3.0) < 0.0001)
  }

  @Test("Rolling ranges are unchanged: week is 7 days, month 30")
  func rollingRangesUnchanged() {
    let today = date(2026, 8, 26)
    for (range, count) in [(TrendRange.week, 7), (.month, 30)] {
      let totals = TrendSummary.dailyTotals(
        range: range, endingOn: today, drinks: [], region: .unitedStates, calendar: calendar
      )
      #expect(totals.count == count)
      #expect(totals.last?.date == calendar.startOfDay(for: today))
    }
  }
}

@Suite("Import adoption")
struct ImportAdoptionTests {

  @Test("Only single-count imports are adoptable")
  func adoptabilityBoundary() {
    let one = LoggedDrink.importedFromHealth(sampleID: UUID(), count: 1, loggedAt: Date())
    let three = LoggedDrink.importedFromHealth(sampleID: UUID(), count: 3, loggedAt: Date())
    let typed = LoggedDrink(type: .beer, volumeOunces: 12, abvPercent: 5)
    #expect(one.isAdoptable)
    #expect(!three.isAdoptable)
    #expect(!typed.isAdoptable)
  }

  @Test("Adoption keeps identity, time, and the external sample id")
  func adoptionPreservesTheRecord() {
    let sampleID = UUID()
    let loggedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let imported = LoggedDrink.importedFromHealth(sampleID: sampleID, count: 1, loggedAt: loggedAt)

    let adopted = imported.adopting(
      type: .wine, volumeOunces: 5, abvPercent: 12, region: .unitedStates
    )

    #expect(adopted.id == imported.id)
    #expect(adopted.loggedAt == loggedAt)
    // The sample id survives on purpose: it is the dedup key that stops a
    // re-import from resurrecting the count, and it keeps the entry out of
    // the HealthKit backfill (ADR-0016).
    #expect(adopted.healthKitSampleID == sampleID)
    #expect(adopted.countedDrinks == nil)
    #expect(!adopted.isImportedFromHealth)
  }

  @Test("An adopted drink counts by its physical facts, under any lens")
  func adoptionJoinsTheMath() {
    let imported = LoggedDrink.importedFromHealth(sampleID: UUID(), count: 1, loggedAt: Date())
    // As an import it is 1 in every region.
    #expect(imported.standardDrinks(in: .unitedKingdom) == 1)

    let adopted = imported.adopting(
      type: .beer, volumeOunces: 12, abvPercent: 5, region: .unitedStates
    )
    // Adopted, it is a 12oz 5% beer: 1.0 US standard drinks but ~1.75 UK
    // units — the region lens applies because the facts now exist.
    #expect(abs(adopted.standardDrinks(in: .unitedStates) - 1.0) < 0.0001)
    #expect(abs(adopted.standardDrinks(in: .unitedKingdom) - 1.75) < 0.01)
    #expect(adopted.summaryLine == "Beer, 12oz, 5% ABV")
  }
}

@Suite("Intent drafts")
struct IntentDraftTests {

  @Test("Nothing specified means the type's own defaults — identical to a widget tap")
  func defaultsMatchFastPath() {
    let intent = DrinkDraft.forIntent(type: .beer)
    let tap = DrinkDraft(type: .beer)
    #expect(intent.volumeOunces == tap.volumeOunces)
    #expect(intent.abvPercent == tap.abvPercent)
    #expect(intent.quantity == 1)
  }

  @Test("Specified size and strength are honored, including custom volumes")
  func specifiedValuesHonored() {
    let known = DrinkDraft.forIntent(type: .beer, volumeOunces: 16)
    #expect(known.volumeOunces == 16)

    let custom = DrinkDraft.forIntent(type: .wine, volumeOunces: 6.5, abvPercent: 13)
    #expect(custom.selectedSize == .custom)
    #expect(custom.volumeOunces == 6.5)
    #expect(custom.abvPercent == 13)
  }

  @Test("ABV clamps to the type's slider range, volume must be positive")
  func boundsMatchTheApp() {
    let strong = DrinkDraft.forIntent(type: .beer, abvPercent: 90)
    #expect(strong.abvPercent == DrinkType.beer.abvRange.upperBound)

    let zero = DrinkDraft.forIntent(type: .beer, volumeOunces: 0)
    #expect(zero.volumeOunces == DrinkType.beer.defaultVolumeOunces)

    let negative = DrinkDraft.forIntent(type: .beer, volumeOunces: -4)
    #expect(negative.volumeOunces == DrinkType.beer.defaultVolumeOunces)
  }

  @Test("Quantity clamps to the counter's ceiling and never below one")
  func quantityClamps() {
    #expect(DrinkDraft.forIntent(type: .beer, quantity: 0).quantity == 1)
    #expect(DrinkDraft.forIntent(type: .beer, quantity: -3).quantity == 1)
    #expect(DrinkDraft.forIntent(type: .beer, quantity: 500).quantity == DrinkDraft.intentQuantityLimit)
    #expect(DrinkDraft.forIntent(type: .beer, quantity: 3).makeLoggedDrinks(region: .unitedStates).count == 3)
  }
}
