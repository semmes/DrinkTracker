import Foundation

/// Renders the complete log as CSV — the export behind Settings' "Export log"
/// row (ADR-0015).
///
/// Lives in the domain layer so the file's exact shape is pinned by tier-1
/// tests: an export that silently drifts is worse than none, because the one
/// place it will be read carefully is across a desk from a professional.
///
/// Three row shapes share one chronological table:
/// - a drink logged in the app, carrying its physical facts (volume, ABV);
/// - a drink imported from Apple Health, carrying only its count (ADR-0014) —
///   volume and ABV stay empty rather than pretending;
/// - a day recorded as alcohol-free, because "no alcohol" is a recorded fact,
///   not an absence (the calendar's distinction, kept in the export).
///
/// The `standard_drinks` column is expressed in the *current* region, like
/// every total in the app (PRD invariant 3); the `unit` column names that
/// unit on every row so the file stays unambiguous away from the app. Volume
/// and ABV ride along so the math can be rechecked from the physical facts.
public enum LogExport {

  public static let header = "date,time,entry,volume_oz,abv_percent,standard_drinks,unit,source"

  /// The whole log, oldest first, as a CSV string.
  ///
  /// - Parameters:
  ///   - drinks: Every logged drink, in any order.
  ///   - alcoholFreeDays: Start-of-day dates the user marked alcohol-free.
  ///   - region: The unit lens for the `standard_drinks` column — the user's
  ///     current region, never a per-entry one (PRD invariant 3).
  ///   - calendar: Supplies the time zone dates are rendered in, matching how
  ///     the app itself groups entries into days.
  public static func csv(
    drinks: [LoggedDrink],
    alcoholFreeDays: Set<Date>,
    region: Region,
    calendar: Calendar = .current
  ) -> String {
    let unit = "\(region.shortName) \(region.unitName)"

    var rows: [(sortKey: Date, line: String)] = drinks.map { drink in
      (drink.loggedAt, drinkLine(drink, unit: unit, region: region, calendar: calendar))
    }
    rows += alcoholFreeDays.map { day in
      let line = fields([
        dayString(day, calendar: calendar), "", "No alcohol recorded",
        "", "", "0", unit, "Tallyist",
      ])
      return (day, line)
    }

    // Oldest first: the file reads as a timeline. Ties (an alcohol-free
    // marker never shares a day with a drink, but two drinks can share a
    // second) break by line content so the output is deterministic.
    let sorted = rows
      .sorted { ($0.sortKey, $0.line) < ($1.sortKey, $1.line) }
      .map(\.line)

    return ([header] + sorted).joined(separator: "\n") + "\n"
  }

  private static func drinkLine(
    _ drink: LoggedDrink,
    unit: String,
    region: Region,
    calendar: Calendar
  ) -> String {
    let imported = drink.isImportedFromHealth
    return fields([
      dayString(drink.loggedAt, calendar: calendar),
      timeString(drink.loggedAt, calendar: calendar),
      imported ? "Imported drink" : drink.type.displayName,
      imported ? "" : number(drink.volumeOunces),
      imported ? "" : number(drink.abvPercent),
      number(drink.standardDrinks(in: region)),
      unit,
      imported ? "Apple Health" : "Tallyist",
    ])
  }

  // MARK: - Formatting

  /// Two decimal places, trailing zeros trimmed — finer than the app's
  /// one-decimal display so summed columns track the app's own totals, without
  /// implying more precision than an ABV estimate can carry.
  static func number(_ value: Double) -> String {
    let rounded = (value * 100).rounded() / 100
    if rounded == rounded.rounded() { return String(format: "%.0f", rounded) }
    if rounded == (value * 10).rounded() / 10 { return String(format: "%.1f", rounded) }
    return String(format: "%.2f", rounded)
  }

  /// `yyyy-MM-dd` / `HH:mm` in the calendar's time zone, matching how the app
  /// assigns entries to days. Fixed `en_US_POSIX` locale: this is a data
  /// format, and a device set to a 12-hour locale must not change the file.
  /// Public because the app also dates the export's file name with it.
  public static func dayString(_ date: Date, calendar: Calendar) -> String {
    formatter(format: "yyyy-MM-dd", calendar: calendar).string(from: date)
  }

  static func timeString(_ date: Date, calendar: Calendar) -> String {
    formatter(format: "HH:mm", calendar: calendar).string(from: date)
  }

  private static func formatter(format: String, calendar: Calendar) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = format
    return formatter
  }

  // MARK: - CSV escaping

  static func fields(_ values: [String]) -> String {
    values.map(escaped).joined(separator: ",")
  }

  /// RFC 4180: quote a field containing a comma, quote, or newline; double
  /// any embedded quotes. Today's field values never need it — this exists so
  /// a future display name with a comma degrades to a correct file, not a
  /// shifted column.
  static func escaped(_ field: String) -> String {
    guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
      return field
    }
    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }
}
