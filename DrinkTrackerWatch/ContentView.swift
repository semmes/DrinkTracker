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
  @Environment(\.scenePhase) private var scenePhase

  /// Whether the watch can reach the user's iCloud database, from the same
  /// probe the phone's Settings → Diagnostics shows (`CloudKitStatusProbe`).
  /// Kept in view state because the probe writes to the App Group defaults,
  /// which nothing observes.
  @State private var cloudKitStatus: String?

  /// Bumped when the phone's context lands, so the region line re-reads the
  /// App Group — the same trick `TodayView` plays with its day-change date,
  /// for the same reason: the defaults are not observable.
  @State private var bridgeRevision = 0

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
      // Which store opened, whether iCloud is reachable, and which region the
      // phone last sent — the three facts worth reading on a stub, and the
      // ones the phone shows under Settings → Diagnostics. Verbatim:
      // diagnostics, not copy.
      Text(verbatim: Diagnostics.storeMode ?? "store mode unknown")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Text(verbatim: "iCloud: \(cloudKitStatus ?? "not checked yet")")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Text(verbatim: bridgeLine)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      #endif
    }
    .padding()
    .task { await refreshCloudKitStatus() }
    .onChange(of: scenePhase) { _, phase in
      // The user can sign into iCloud on the phone while this app is in the
      // background, and the phone re-sends its settings on every foreground.
      guard phase == .active else { return }
      bridgeRevision += 1
      Task { await refreshCloudKitStatus() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .watchContextDidChange)) { _ in
      bridgeRevision += 1
    }
  }

  private var bridgeLine: String {
    _ = bridgeRevision
    guard let received = Diagnostics.lastWatchContextReceived else {
      return "region: not received yet (computing in \(AppSettings.storedRegion().rawValue))"
    }
    return "region: \(AppSettings.storedRegion().rawValue) · seed: \(AppSettings.storedCounterSeed().rawValue) · sent \(received.formatted(date: .omitted, time: .shortened))"
  }

  private func refreshCloudKitStatus() async {
    await CloudKitStatusProbe.refresh()
    cloudKitStatus = Diagnostics.cloudKitStatus
  }
}
