import SwiftUI

/// What the summary card's title names (ADR-0026). Presentational, so it
/// lives in the app and its strings in the app catalog (ADR-0020). The window
/// itself is the caller's knowledge; the card only prints it.
enum SummaryHeading: Hashable {
  /// "Last 30 days" — the rolling window; the key carries its own count.
  case lastDays(Int)
  /// A calendar month. `isClipped` when today cut it short — derived from the
  /// data (`summary.dayCount < grid.days.count`), never from "is it the
  /// current month": on the last day of a month nothing was clipped and the
  /// plain name is exactly right.
  case month(Date, isClipped: Bool)
  /// A calendar year, on the same rule.
  case year(Int, isClipped: Bool)

  /// The title as it is drawn. A clipped period takes ", through today" — a
  /// statement of where the record stops, not of where it is going.
  var titleText: Text {
    switch self {
    case .lastDays(let count):
      return Text("Last \(count) days")
    case .month(let date, let isClipped):
      let name = date.formatted(.dateTime.month(.wide).year())
      return isClipped ? Text("\(name), through today") : Text(verbatim: name)
    case .year(let year, let isClipped):
      // The year goes in as text, not as a number: a numeric placeholder is
      // resolved through String(format:locale:), which groups the digits and
      // prints "2,026" under a navigation title still reading "2026".
      let name = String(year)
      return isClipped ? Text("\(name), through today") : Text(verbatim: name)
    }
  }

  /// Month and year titles carry the window's day count beside them, so the
  /// three day-counts on the card stay checkable against a window that is no
  /// longer always 30. The rolling title already names its count.
  var showsDayCount: Bool {
    if case .lastDays = self { return false }
    return true
  }
}
