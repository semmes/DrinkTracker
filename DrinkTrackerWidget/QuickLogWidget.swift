import AppIntents
import DrinkTrackerCore
import SwiftData
import SwiftUI
import WidgetKit

/// Home-screen counter widget.
///
/// Mirrors Today's primary control: the count of drinks, and a ＋ that logs one
/// seeded drink in a single tap. The typed quick-add buttons this widget used to
/// carry moved behind the app's "Log by type" disclosure, and the widget follows
/// the same count-first model — one mental model on both surfaces.
///
/// There is deliberately no − here. Removing an entry must retire its HealthKit
/// sample, which only the app process does reliably; see `LogOneDrinkIntent`.
///
/// Tone matches the rest of the app: today's numbers and nothing else. No goal,
/// no streak, no colour that reads as a verdict.
struct QuickLogWidget: Widget {
  static let kind = "QuickLogWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: QuickLogProvider()) { entry in
      QuickLogWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Tallyist")
    .description("See today's count and log a drink in one tap.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Timeline

struct QuickLogEntry: TimelineEntry {
  let date: Date
  /// Number of drinks logged today — the widget's headline, matching Today.
  let drinkCount: Int
  /// The same day expressed in the current region's units, for the caption.
  let total: Double
  let region: Region

  static let placeholder = QuickLogEntry(
    date: Date(timeIntervalSince1970: 0),
    drinkCount: 2,
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
    // Refresh at the next midnight so the count resets with the day. Logging
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
      return QuickLogEntry(date: now, drinkCount: 0, total: 0, region: region)
    }
    let repository = DrinkRepository(context: ModelContext(container))
    let todays = repository.drinks(on: now)
    let total = todays.reduce(0) { $0 + $1.standardDrinks(in: region) }
    return QuickLogEntry(date: now, drinkCount: todays.count, total: total, region: region)
  }
}

// MARK: - View

struct QuickLogWidgetView: View {
  let entry: QuickLogEntry

  @Environment(\.widgetFamily) private var family

  private var countLabel: String {
    entry.drinkCount == 1 ? "drink today" : "drinks today"
  }

  private var standardDrinksCaption: String {
    "≈ \(StandardDrink.formatted(entry.total)) \(entry.region.unitName(for: entry.total))"
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("\(entry.drinkCount)")
          .font(.system(size: family == .systemSmall ? 44 : 40, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary)
          .contentTransition(.numericText(value: Double(entry.drinkCount)))
        Text(countLabel)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        if entry.total > 0 && family != .systemSmall {
          Text(standardDrinksCaption)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(entry.drinkCount) \(countLabel)")

      Spacer(minLength: 0)

      // No `.buttonStyle(.plain)` — in a widget that suppresses interaction
      // handling entirely, which cost real debugging time once.
      Button(intent: LogOneDrinkIntent()) {
        Image(systemName: "plus")
          .font(.system(size: family == .systemSmall ? 22 : 24, weight: .semibold))
          .frame(
            width: family == .systemSmall ? 52 : 60,
            height: family == .systemSmall ? 52 : 60
          )
          .background(.quaternary, in: .circle)
          .contentShape(.circle)
      }
      .buttonStyle(.borderless)
      .tint(.accentColor)
      .accessibilityLabel("Log one drink")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

#Preview(as: .systemMedium) {
  QuickLogWidget()
} timeline: {
  QuickLogEntry.placeholder
}
