import Foundation
import Testing

@testable import DrinkTrackerCore

@Suite("Log export")
struct LogExportTests {

  /// UTC and Gregorian, so the expected strings don't depend on the machine
  /// running the tests.
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
  }

  @Test("A logged drink renders its physical facts and the current-region total")
  func loggedDrinkRow() {
    let csv = LogExport.csv(
      drinks: [
        LoggedDrink(loggedAt: date(2026, 8, 25, 19, 42), type: .beer, volumeOunces: 12, abvPercent: 5)
      ],
      alcoholFreeDays: [],
      region: .unitedStates,
      calendar: calendar
    )
    #expect(csv == """
    date,time,entry,volume_oz,abv_percent,standard_drinks,unit,source
    2026-08-25,19:42,Beer,12,5,1,US standard drink,Tallyist

    """)
  }

  @Test("The standard_drinks column follows the current region, not the entry's")
  func regionIsALens() {
    // Logged under the US lens; exported under the UK one. A 12oz 5% beer is
    // 1.0 US standard drinks but ~1.75 UK units (14g of alcohol over 8g).
    let drink = LoggedDrink(
      loggedAt: date(2026, 8, 25, 19, 42), type: .beer,
      volumeOunces: 12, abvPercent: 5, region: .unitedStates
    )
    let csv = LogExport.csv(
      drinks: [drink], alcoholFreeDays: [], region: .unitedKingdom, calendar: calendar
    )
    let expected = LogExport.number(drink.standardDrinks(in: .unitedKingdom))
    #expect(csv.contains("Beer,12,5,\(expected),UK unit,Tallyist"))
    #expect(expected == "1.75")
  }

  @Test("An imported drink exports its count and nothing invented")
  func importedDrinkRow() {
    let csv = LogExport.csv(
      drinks: [
        .importedFromHealth(sampleID: UUID(), count: 2, loggedAt: date(2026, 8, 24, 21, 0))
      ],
      alcoholFreeDays: [],
      region: .unitedStates,
      calendar: calendar
    )
    // Volume and ABV stay empty — zero would read as a measurement.
    #expect(csv.contains("2026-08-24,21:00,Imported drink,,,2,US standard drink,Apple Health"))
    // The count is the same number under any lens (ADR-0014).
    let uk = LogExport.csv(
      drinks: [
        .importedFromHealth(sampleID: UUID(), count: 2, loggedAt: date(2026, 8, 24, 21, 0))
      ],
      alcoholFreeDays: [],
      region: .unitedKingdom,
      calendar: calendar
    )
    #expect(uk.contains("Imported drink,,,2,UK unit,Apple Health"))
  }

  @Test("Alcohol-free days appear as recorded facts, in timeline order")
  func alcoholFreeDayRow() {
    let csv = LogExport.csv(
      drinks: [
        LoggedDrink(loggedAt: date(2026, 8, 23, 18, 5), type: .wine, volumeOunces: 5, abvPercent: 12),
        LoggedDrink(loggedAt: date(2026, 8, 25, 20, 30), type: .spirit, volumeOunces: 1.5, abvPercent: 40),
      ],
      alcoholFreeDays: [date(2026, 8, 24)],
      region: .unitedStates,
      calendar: calendar
    )
    let lines = csv.split(separator: "\n").map(String.init)
    #expect(lines.count == 4)
    #expect(lines[1].hasPrefix("2026-08-23,18:05,Wine"))
    #expect(lines[2] == "2026-08-24,,No alcohol recorded,,,0,US standard drink,Tallyist")
    #expect(lines[3].hasPrefix("2026-08-25,20:30,Spirit"))
  }

  @Test("Drinks come out oldest first regardless of input order")
  func chronologicalOrder() {
    let csv = LogExport.csv(
      drinks: [
        LoggedDrink(loggedAt: date(2026, 8, 25, 22, 0), type: .beer, volumeOunces: 12, abvPercent: 5),
        LoggedDrink(loggedAt: date(2026, 8, 25, 9, 0), type: .beer, volumeOunces: 12, abvPercent: 5),
        LoggedDrink(loggedAt: date(2026, 8, 20, 12, 0), type: .beer, volumeOunces: 12, abvPercent: 5),
      ],
      alcoholFreeDays: [],
      region: .unitedStates,
      calendar: calendar
    )
    let times = csv.split(separator: "\n").dropFirst().map { $0.split(separator: ",")[1] }
    #expect(times == ["12:00", "09:00", "22:00"])
  }

  @Test("Number formatting trims without losing the app's totals")
  func numberFormatting() {
    #expect(LogExport.number(12) == "12")
    #expect(LogExport.number(5.0) == "5")
    #expect(LogExport.number(1.3) == "1.3")
    #expect(LogExport.number(1.25) == "1.25")
    #expect(LogExport.number(1.333333) == "1.33")
  }

  @Test("Fields with commas or quotes stay one column")
  func csvEscaping() {
    #expect(LogExport.escaped("Beer") == "Beer")
    #expect(LogExport.escaped("a, b") == "\"a, b\"")
    #expect(LogExport.escaped("say \"when\"") == "\"say \"\"when\"\"\"")
  }

  @Test("An empty log is a header and nothing else")
  func emptyLog() {
    let csv = LogExport.csv(
      drinks: [], alcoholFreeDays: [], region: .unitedStates, calendar: calendar
    )
    #expect(csv == LogExport.header + "\n")
  }
}
