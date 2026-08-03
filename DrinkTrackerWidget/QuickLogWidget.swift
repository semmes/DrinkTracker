import AppIntents
import DrinkTrackerCore
import SwiftData
import SwiftUI
import WidgetKit

/// Home-screen quick-log widget.
///
/// Extends the brief's fast-default pattern to its logical end: the two-tap in-app
/// path becomes one tap from the home screen, using the same per-type defaults the
/// sheet opens with. Anything needing correction is edited in the app afterwards —
/// edit-after, not gate-before.
///
/// Tone matches the rest of the app: today's number and nothing else. No goal, no
/// streak, no colour that reads as a verdict.
struct QuickLogWidget: Widget {
  static let kind = "QuickLogWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: QuickLogProvider()) { entry in
      QuickLogWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Quick Log")
    .description("See today's total and log a drink in one tap.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Timeline

struct QuickLogEntry: TimelineEntry {
  let date: Date
  let total: Double
  let region: Region

  static let placeholder = QuickLogEntry(
    date: Date(timeIntervalSince1970: 0),
    total: 2,
    region: .unitedStates
  )
}

struct QuickLogProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuickLogEntry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
    completion(context.isPreview ? .placeholder : currentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
    // Refresh at the next midnight so the total resets with the day. Logging
    // through the intent reloads the timeline directly, so there's no need to
    // poll in between.
    let entry = currentEntry()
    let nextMidnight = Calendar.current.nextDate(
      after: entry.date,
      matching: DateComponents(hour: 0, minute: 0),
      matchingPolicy: .nextTime
    ) ?? entry.date.addingTimeInterval(3600)

    completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
  }

  /// Timeline callbacks run off the main actor, so this builds its own
  /// `ModelContext` rather than touching the container's `mainContext`.
  private func currentEntry() -> QuickLogEntry {
    let now = Date()
    let region = AppSettings.storedRegion()
    guard let container = try? SharedModelContainer.make() else {
      return QuickLogEntry(date: now, total: 0, region: region)
    }
    let total = DrinkRepository(context: ModelContext(container)).total(on: now, region: region)
    return QuickLogEntry(date: now, total: total, region: region)
  }
}

// MARK: - View

struct QuickLogWidgetView: View {
  let entry: QuickLogEntry

  @Environment(\.widgetFamily) private var family

  private var unitLabel: String {
    return "\(entry.region.unitName(for: entry.total)) today"
  }

  /// Small shows beer only — the most common case — because four buttons at that
  /// size would land under the 44pt touch target.
  private var visibleTypes: [DrinkType] {
    family == .systemSmall ? [.beer] : DrinkType.allCases
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 0) {
        Text(StandardDrink.formatted(entry.total))
          .font(.system(size: family == .systemSmall ? 40 : 34, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary)
        Text(unitLabel)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(StandardDrink.formatted(entry.total)) \(unitLabel)")

      Spacer(minLength: 0)

      HStack(spacing: 6) {
        ForEach(visibleTypes) { type in
          QuickLogButton(type: type, isCompact: family != .systemSmall)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// One tap logs the type at its default size and ABV, without opening the app.
private struct QuickLogButton: View {
  let type: DrinkType
  let isCompact: Bool

  var body: some View {
    // No `.buttonStyle(.plain)` here: in a widget that suppresses the button's
    // interaction handling, so taps never dispatch the intent. The styling lives
    // inside the label instead.
    Button(intent: LogDrinkIntent(drinkType: type)) {
      HStack(spacing: 4) {
        Image(systemName: type.symbolName)
          .font(.caption)
        if !isCompact {
          Text(type.displayName)
            .font(.caption.weight(.medium))
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 32)
      .background(.quaternary, in: .rect(cornerRadius: 10, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.borderless)
    .tint(.accentColor)
    .accessibilityLabel("Log \(type.displayName.lowercased())")
  }
}

#Preview(as: .systemMedium) {
  QuickLogWidget()
} timeline: {
  QuickLogEntry.placeholder
}
