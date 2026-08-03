import DrinkTrackerCore
import Foundation
import SwiftData
import Testing

/// Tier 2 (docs/PRD.md §4) — the marker that lets the calendar tell "no alcohol"
/// apart from "nothing logged".
@Suite("Alcohol-free days")
struct AlcoholFreeDayTests {

  let context: ModelContext
  let repository: DrinkRepository

  /// Fixed to UTC so start-of-day arithmetic doesn't depend on where this runs.
  let calendar: Calendar

  init() throws {
    let container = try ModelContainer(
      for: SharedModelContainer.schema,
      configurations: ModelConfiguration(
        schema: SharedModelContainer.schema,
        isStoredInMemoryOnly: true
      )
    )
    self.context = ModelContext(container)
    self.repository = DrinkRepository(context: context)

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    self.calendar = cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  // MARK: - Marking

  @Test("Marking a day records it")
  func markRecords() {
    let day = date(2026, 8, 3)
    #expect(repository.markAlcoholFree(day, calendar: calendar))
    #expect(repository.isMarkedAlcoholFree(day, calendar: calendar))
  }

  @Test("Marking is idempotent — twice is still one marker")
  func markIsIdempotent() {
    let day = date(2026, 8, 3)
    repository.markAlcoholFree(day, calendar: calendar)
    repository.markAlcoholFree(day, calendar: calendar)
    #expect(repository.allAlcoholFreeDays().count == 1)
  }

  /// Any time of day has to land on the same marker, or an evening tap and a
  /// morning tap would record the same date twice.
  @Test("Any time of day normalises to the same marker")
  func timeOfDayIsNormalised() {
    repository.markAlcoholFree(date(2026, 8, 3, hour: 9), calendar: calendar)
    repository.markAlcoholFree(date(2026, 8, 3, hour: 22), calendar: calendar)

    #expect(repository.allAlcoholFreeDays().count == 1)
    #expect(repository.isMarkedAlcoholFree(date(2026, 8, 3, hour: 15), calendar: calendar))
  }

  @Test("Unmarking removes it, and unmarking nothing is harmless")
  func unmark() {
    let day = date(2026, 8, 3)
    repository.markAlcoholFree(day, calendar: calendar)
    repository.unmarkAlcoholFree(day, calendar: calendar)
    #expect(repository.isMarkedAlcoholFree(day, calendar: calendar) == false)

    repository.unmarkAlcoholFree(date(2026, 8, 4), calendar: calendar)
    #expect(repository.allAlcoholFreeDays().isEmpty)
  }

  @Test("Days are independent of each other")
  func daysAreIndependent() {
    repository.markAlcoholFree(date(2026, 8, 3), calendar: calendar)
    repository.markAlcoholFree(date(2026, 8, 5), calendar: calendar)

    #expect(repository.isMarkedAlcoholFree(date(2026, 8, 3), calendar: calendar))
    #expect(repository.isMarkedAlcoholFree(date(2026, 8, 4), calendar: calendar) == false)
    #expect(repository.isMarkedAlcoholFree(date(2026, 8, 5), calendar: calendar))
  }

  // MARK: - Contradiction with entries

  /// The important one. A marker on a day that has drinks is a contradiction, and
  /// keeping it dormant would be worse than refusing: it would reassert itself the
  /// moment those entries were removed, claiming abstinence the user never stated.
  @Test("A day with entries can't be marked alcohol-free")
  func refusesToMarkADayWithDrinks() {
    let day = date(2026, 8, 3, hour: 20)
    repository.save(LoggedDrink(loggedAt: day, type: .beer, volumeOunces: 12, abvPercent: 5))

    #expect(repository.markAlcoholFree(day, calendar: calendar) == false)
    #expect(repository.isMarkedAlcoholFree(day, calendar: calendar) == false)
    #expect(repository.allAlcoholFreeDays().isEmpty)
  }

  @Test("Removing the drinks makes the day markable")
  func markableOnceCleared() {
    let day = date(2026, 8, 3, hour: 20)
    let drink = LoggedDrink(loggedAt: day, type: .beer, volumeOunces: 12, abvPercent: 5)
    repository.save(drink)
    #expect(repository.markAlcoholFree(day, calendar: calendar) == false)

    repository.delete(id: drink.id)
    #expect(repository.markAlcoholFree(day, calendar: calendar))
  }

  // MARK: - Reading back

  @Test("allAlcoholFreeDays returns start-of-day dates the grid can match on")
  func allDaysAreStartOfDay() {
    repository.markAlcoholFree(date(2026, 8, 3, hour: 17), calendar: calendar)
    let days = repository.allAlcoholFreeDays()

    #expect(days.count == 1)
    #expect(days.contains(date(2026, 8, 3)))
  }

  /// End to end: the marker reaches the grid and shows up as its own bucket rather
  /// than as an unlogged day.
  @Test("A marked day reaches the calendar as alcoholFree")
  func markerReachesTheGrid() {
    let day = date(2026, 8, 4)
    repository.markAlcoholFree(day, calendar: calendar)

    let grid = TrendSummary.monthGrid(
      containing: day,
      totalsByDay: [:],
      alcoholFreeDays: repository.allAlcoholFreeDays(),
      calendar: calendar
    )

    #expect(grid.days.first { $0.date == day }?.intensity == .alcoholFree)
    #expect(grid.days.first { $0.date == date(2026, 8, 5) }?.intensity == .unlogged)
  }
}
