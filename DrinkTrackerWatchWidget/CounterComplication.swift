import SwiftUI
import WidgetKit

/// The watch complication, as the Phase 0 stub: enough for the target to
/// build, embed and register its families. Phase 6 gives it the four
/// families' real content, the two-entry timeline that expires with the
/// session, `.privacySensitive()` on every count, and `LogOneDrinkIntent` on
/// its ＋ (`docs/tallyist-watch-plan.md`, Phase 6; `docs/design/watch/`).
///
/// `kind` is the identity of a placed complication across app updates, so it
/// is its final value now rather than something to rename later.
struct CounterComplication: Widget {
  static let kind = "CounterComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: CounterProvider()) { entry in
      CounterComplicationView(entry: entry)
    }
    // Verbatim on purpose: the reviewed display name and description are
    // Phase 6's strings (docs/copy-review-1.4.3.md), and a placeholder key
    // would outlive the stub that introduced it.
    .configurationDisplayName(Text(verbatim: "Tallyist"))
    .description(Text(verbatim: "Drinks today"))
    .supportedFamilies([
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryInline,
      .accessoryCorner,
    ])
  }
}

struct CounterEntry: TimelineEntry {
  let date: Date
}

struct CounterProvider: TimelineProvider {
  func placeholder(in context: Context) -> CounterEntry {
    CounterEntry(date: .now)
  }

  func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
    completion(CounterEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
    completion(Timeline(entries: [CounterEntry(date: .now)], policy: .never))
  }
}

struct CounterComplicationView: View {
  let entry: CounterEntry

  var body: some View {
    // A system glyph only until Phase 1 moves the app's own symbols into the
    // shared catalog; the design draws `tally.standard` here.
    Image(systemName: "drop")
      .containerBackground(for: .widget) { Color.clear }
  }
}
