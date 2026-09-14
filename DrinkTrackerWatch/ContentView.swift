import SwiftData
import SwiftUI

/// Phase 1: the count of today's entries from the shared store, and nothing
/// else — proof that the store opens on the wrist through the same ladder as
/// the phone. Phase 3 replaces this with the counter.
///
/// The day's bounds are fixed when the view is built. The counter re-cuts the
/// day on `.NSCalendarDayChanged` and on foregrounding the way `TodayView`
/// does; a stub that is never left open overnight does not need to.
struct ContentView: View {
  @Query private var todaysEntries: [DrinkEntry]

  init(now: Date = .now, calendar: Calendar = .current) {
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
    _todaysEntries = Query(
      filter: #Predicate<DrinkEntry> { $0.loggedAt >= start && $0.loggedAt < end },
      sort: \DrinkEntry.loggedAt
    )
  }

  var body: some View {
    VStack(spacing: 4) {
      // A number the user made: rounded, tabular, and private on a wrist
      // (`DrinkTrackerWatch/CLAUDE.md`). Formatted, not localized — no key.
      Text(todaysEntries.count, format: .number)
        .font(.system(size: 46, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .privacySensitive()
      #if DEBUG
      // Which store opened — the one fact worth reading on a stub, and the
      // one Settings → Diagnostics shows on the phone. Verbatim: diagnostics,
      // not copy.
      Text(verbatim: Diagnostics.storeMode ?? "store mode unknown")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      #endif
    }
    .padding()
  }
}
