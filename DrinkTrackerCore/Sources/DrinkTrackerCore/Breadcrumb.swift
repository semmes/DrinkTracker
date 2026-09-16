import Foundation

/// The pure half of the app's diagnostic breadcrumbs, so their shape can be
/// pinned at tier 1 without a running bundle or real defaults.
///
/// A breadcrumb with no time and no process cannot be read after the fact.
/// That is not a hypothetical: on 2026-09-16 the owner tapped the home-screen
/// widget's ＋ and the only evidence that the tap never ran was a key that was
/// *absent* — which also could not say when, or which process, or whether a
/// later working tap had written over it. Every breadcrumb now says both.
public enum Breadcrumb {
  /// `"<step> · <process> · MM-dd HH:mm:ss"`, in 24-hour local time.
  public static func stamped(
    _ step: String,
    process: String,
    at date: Date,
    timeZone: TimeZone = .current
  ) -> String {
    "\(step) · \(process) · \(timestamp(date, timeZone: timeZone))"
  }

  /// `MM-dd HH:mm:ss` in `timeZone`, always 24-hour, always ASCII digits and
  /// Gregorian, so a breadcrumb reads the same whatever the device's locale.
  ///
  /// The date is not decoration. The owner tests in the evenings, so a
  /// leftover from yesterday's run carries a time much like today's, and
  /// without the date "Last widget tap: saved · 18:57:41" read the evening
  /// after would look like a tap five minutes old.
  public static func timestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: date)
    return String(
      format: "%02ld-%02ld %02ld:%02ld:%02ld",
      parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0
    )
  }

  /// `lines` with `line` appended, keeping only the newest `limit`, oldest
  /// first — a short timeline rather than a single value, because reading a
  /// single value is itself an event that overwrites it (opening the app to
  /// look is an app activation).
  public static func appending(_ line: String, to lines: [String], limit: Int) -> [String] {
    let kept = lines + [line]
    return Array(kept.suffix(max(0, limit)))
  }
}
