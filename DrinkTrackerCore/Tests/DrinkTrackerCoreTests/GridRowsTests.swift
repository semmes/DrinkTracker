import Foundation
import Testing

@testable import DrinkTrackerCore

/// `MonthGrid.rows` (ADR-0027): the month as seven-wide rows for an offscreen
/// render that places cells row by row.
@Suite("Grid rows")
struct GridRowsTests {

  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.firstWeekday = 1
    return cal
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }

  private func grid(_ year: Int, _ month: Int, calendar: Calendar? = nil) -> MonthGrid {
    TrendSummary.monthGrid(
      containing: date(year, month, 1), totalsByDay: [:], alcoholFreeDays: [],
      calendar: calendar ?? self.calendar
    )
  }

  /// 1 August 2026 is a Saturday: six blanks, then the 1st in the last column.
  @Test("Rows are seven wide, blanks are nil, and every day appears once in order")
  func rowsAreSevenWide() {
    let august = grid(2026, 8)
    let rows = august.rows
    #expect(rows.count == 6)
    #expect(rows.allSatisfy { $0.count == 7 })
    #expect(rows[0].prefix(6).allSatisfy { $0 == nil })
    #expect(rows[0][6]?.date == date(2026, 8, 1))
    #expect(rows[5][0]?.date == date(2026, 8, 30))
    #expect(rows[5][1]?.date == date(2026, 8, 31))
    #expect(rows[5].suffix(5).allSatisfy { $0 == nil })

    let days = rows.flatMap { $0 }.compactMap { $0 }
    #expect(days == august.days)
  }

  @Test("Rows follow the calendar's first weekday")
  func rowsFollowFirstWeekday() {
    var mondayFirst = calendar
    mondayFirst.firstWeekday = 2
    let rows = grid(2026, 8, calendar: mondayFirst).rows
    #expect(rows[0].prefix(5).allSatisfy { $0 == nil })
    #expect(rows[0][5]?.date == date(2026, 8, 1))
    #expect(rows[0][6]?.date == date(2026, 8, 2))
  }

  /// 1 February 2026 is a Sunday and the month has 28 days: four full rows.
  @Test("A month that fits exactly has no blanks at all")
  func exactFit() {
    let rows = grid(2026, 2).rows
    #expect(rows.count == 4)
    #expect(rows.flatMap { $0 }.allSatisfy { $0 != nil })
  }

  @Test("Rows and dayIndex agree cell for cell")
  func rowsAgreeWithDayIndex() {
    let august = grid(2026, 8)
    for (row, cells) in august.rows.enumerated() {
      for (column, cell) in cells.enumerated() {
        let index = august.dayIndex(row: row, column: column)
        #expect((cell == nil) == (index == nil))
        if let index { #expect(cell == august.days[index]) }
      }
    }
  }

  @Test("An empty grid has no rows")
  func emptyGrid() {
    let empty = MonthGrid(month: date(2026, 8, 1), leadingBlanks: 3, days: [])
    #expect(empty.rows.isEmpty)
  }
}
