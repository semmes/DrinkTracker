import AppIntents
import DrinkTrackerCore
import SwiftData
import SwiftUI
import WidgetKit

/// The watch complication (watch Phase 6; ADR-0045, ADR-0046): today's count
/// in the day's band on every family — the tile shrunk to a disc, keeping its
/// job — with the sitting's dots on the rectangular card while a session
/// runs and the watch's own "Show session pace" is on, and a ＋ there that
/// logs one drink through `LogOneDrinkIntent` without opening the app.
/// `StaticConfiguration` throughout, like `QuickLogWidget`, and the same two
/// strings name it.
///
/// Every count is `.privacySensitive()`, and redacted — the watch off the
/// wrist — each family shows the drop glyph and the plural words with the
/// figure gone, never a blank (ADR-0045). The user's per-glance hide does not
/// reach the face (the owner's decision on the design's fourth question); the
/// system's redaction is what protects it.
///
/// `kind` is the identity of a placed complication across app updates.
struct CounterComplication: Widget {
  static let kind = "CounterComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: CounterProvider()) { entry in
      CounterComplicationView(entry: entry)
    }
    .configurationDisplayName("Tallyist")
    .description("See today's count and log a drink in one tap.")
    .supportedFamilies([
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryInline,
      .accessoryCorner,
    ])
  }
}

// MARK: - Timeline

struct CounterEntry: TimelineEntry {
  let date: Date
  /// Drinks logged today — the headline, matching Today and the home-screen
  /// widget (ADR-0046).
  let drinkCount: Int
  /// The same day in the region's units, for the band.
  let total: Double
  let region: Region
  let isMarkedAlcoholFree: Bool
  /// The active sitting, if any and if the watch's switch shows it — drawn
  /// as dots on the rectangular card and never as a number on the face.
  let session: DrinkSession?
  /// The rolling window's band for those dots at `date`, nil for rings.
  let sessionBand: DayIntensity?
  /// The store could not be opened: the face shows the glyph and the words
  /// and no figure, rather than a zero it cannot back, and offers no ＋.
  let isUnavailable: Bool

  /// The same fold as the counter's tile and the calendar cell (ADR-0034).
  var band: DayIntensity {
    DayIntensity.bucket(
      standardDrinks: total, isMarkedAlcoholFree: isMarkedAlcoholFree, hasEntries: drinkCount > 0
    )
  }

  static let placeholder = CounterEntry(
    date: Date(timeIntervalSince1970: 0), drinkCount: 2, total: 2, region: .unitedStates,
    isMarkedAlcoholFree: false, session: nil, sessionBand: nil, isUnavailable: false
  )

  static func unavailable(at date: Date, region: Region) -> CounterEntry {
    CounterEntry(
      date: date, drinkCount: 0, total: 0, region: region,
      isMarkedAlcoholFree: false, session: nil, sessionBand: nil, isUnavailable: true
    )
  }
}

struct CounterProvider: TimelineProvider {
  /// One read of the store, from which every entry in a timeline is derived
  /// at its own date — the session and its band are functions of the drinks
  /// and the clock, so later entries need no second read.
  struct Snapshot {
    let recent: [LoggedDrink]
    let todaysCount: Int
    let total: Double
    let region: Region
    let isMarkedAlcoholFree: Bool
    let showsSession: Bool

    func entry(at date: Date) -> CounterEntry {
      let session = showsSession ? SessionPace.currentSession(in: recent, now: date) : nil
      return CounterEntry(
        date: date, drinkCount: todaysCount, total: total, region: region,
        isMarkedAlcoholFree: isMarkedAlcoholFree,
        session: session,
        sessionBand: session == nil ? nil : SessionDots.band(in: recent, now: date, region: region),
        isUnavailable: false
      )
    }
  }

  func placeholder(in context: Context) -> CounterEntry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
    if context.isPreview {
      completion(.placeholder)
      return
    }
    let now = Date()
    completion(Self.load(at: now)?.entry(at: now) ?? .unavailable(at: now, region: AppSettings.storedRegion()))
  }

  /// While a sitting runs, an entry at each moment the face would change on
  /// its own: when a drink leaves the two-hour window (the dots' band drains
  /// — the counter recomputes it every minute, and the face must not lag it
  /// by up to two hours) and at the session's end, `lastDrinkAt +
  /// gapThreshold`, carrying the post-session state — nothing else wakes a
  /// complication when a session ends, and without that entry a dead
  /// sitting's dots would sit on the face. The refresh is the earlier of the
  /// session's end and the next midnight, when the count resets with the
  /// day. Logging on the watch, and a change arriving from the phone's store
  /// by CloudKit, reload the timeline directly (`DrinkTrackerWatchApp`).
  func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
    let now = Date()
    let nextMidnight = Calendar.current.nextDate(
      after: now,
      matching: DateComponents(hour: 0, minute: 0),
      matchingPolicy: .nextTime
    ) ?? now.addingTimeInterval(3600)

    guard let snapshot = Self.load(at: now) else {
      completion(Timeline(
        entries: [.unavailable(at: now, region: AppSettings.storedRegion())],
        policy: .after(min(nextMidnight, now.addingTimeInterval(15 * 60)))
      ))
      return
    }

    let first = snapshot.entry(at: now)
    var entries = [first]
    var refresh = nextMidnight
    if let session = first.session {
      let end = session.lastDrinkAt.addingTimeInterval(SessionPace.gapThreshold)
      let horizon = min(end, nextMidnight)
      // A second past each exit and the end, so the recomputation sees the
      // drink outside the window rather than on its edge.
      // Capped: a long sitting has an exit per drink, and a timeline is not
      // the place to spend them. The earliest ones are the ones that change
      // the band; the refresh at the horizon rebuilds from there.
      let exits = snapshot.recent
        .map { min($0.loggedAt, now).addingTimeInterval(SessionPace.rollingWindow + 1) }
        .filter { $0 > now && $0 < horizon }
      for exit in Set(exits).sorted().prefix(12) {
        entries.append(snapshot.entry(at: exit))
      }
      if end < nextMidnight {
        entries.append(snapshot.entry(at: end.addingTimeInterval(1)))
      }
      refresh = horizon
    }
    completion(Timeline(entries: entries, policy: .after(refresh)))
  }

  /// Timeline callbacks run off the main actor, so this builds its own
  /// `ModelContext` rather than touching the container's `mainContext` —
  /// the home-screen widget's pattern. Nil when the store cannot be opened.
  static func load(at now: Date) -> Snapshot? {
    let region = AppSettings.storedRegion()
    guard let container = try? SharedModelContainer.make() else { return nil }
    let context = ModelContext(container)
    let repository = DrinkRepository(context: context)
    let todays = repository.drinks(on: now)
    let total = todays.reduce(0) { $0 + $1.standardDrinks(in: region) }

    // The sitting's raw material reaches back a day, as the counter's does,
    // so a session that began before midnight is one session (ADR-0044).
    let calendar = Calendar.current
    let floor = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
    let recent = ((try? context.fetch(FetchDescriptor<DrinkEntry>.since(floor))) ?? []).loggedDrinks

    return Snapshot(
      recent: recent,
      todaysCount: todays.count,
      total: total,
      region: region,
      isMarkedAlcoholFree: repository.isMarkedAlcoholFree(now),
      // The card's dots follow the same switch as the counter's row: the
      // sitting is a surface the wrist opts into (ADR-0044, ADR-0017).
      showsSession: AppSettings.storedShowsSessionPace()
    )
  }
}

// MARK: - View

struct CounterComplicationView: View {
  let entry: CounterEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.redactionReasons) private var redaction

  private let scheme: ColorScheme = .dark

  /// Redacted by the system, or nothing to show: the figure goes, the band's
  /// fill with it (once the digits are gone the colour is the figure), and
  /// the words are the plural — a singular noun under a glyph is a count of
  /// one.
  private var isFigureless: Bool { redaction.contains(.privacy) || entry.isUnavailable }
  private var isMarked: Bool { entry.band == .alcoholFree }

  /// Whether the marker is *shown*. Redaction wins over it: a day recorded as
  /// no alcohol is a fact about the day, and if the drinking days go behind
  /// the drop glyph while the dry ones keep their check, the glyph itself
  /// states what the reader did (ADR-0045 — private beats glanceable).
  private var showsMarker: Bool { isMarked && !isFigureless }

  var body: some View {
    switch family {
    case .accessoryRectangular: rectangular
    case .accessoryInline: inline
    case .accessoryCorner: corner
    default: circular
    }
  }

  // MARK: Families

  /// The circular: the disc in the band's fill and the count in the band's
  /// ink, and nothing else. The design drew a unit noun beneath it and the
  /// owner removed it on the device (2026-09-15): a 50pt disc reading
  /// "1 drink" is a sentence where a glance wants a number, and the noun is
  /// on the face's own label and in what VoiceOver speaks. The numeral takes
  /// the room the noun had.
  private var circular: some View {
    ZStack {
      disc(radius: nil)
      figure(size: 34)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spokenLabel)
    .containerBackground(for: .widget) { Color.clear }
  }

  /// The corner: the disc with the count, the day's words along the curve —
  /// the words only, never the count, which would print past redaction.
  private var corner: some View {
    ZStack {
      disc(radius: nil)
      figure(size: 22)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spokenLabel)
    .widgetLabel(curvedLabel)
    .containerBackground(for: .widget) { Color.clear }
  }

  /// Text only, no block — the one family where redaction means the figure
  /// simply goes and the words stay.
  private var inline: some View {
    Label {
      if showsMarker {
        Text("Recorded as no alcohol today")
      } else if isFigureless {
        Text("drinks today")
      } else {
        Text(countLabel)
          .privacySensitive()
      }
    } icon: {
      // Decorative: a catalog image otherwise speaks its asset name, and the
      // words beside it are the label (ADR-0036).
      Image(decorative: showsMarker ? DrinkType.Symbol.alcoholFree : DrinkType.Symbol.standard)
    }
    .containerBackground(for: .widget) { Color.clear }
  }

  /// The Smart Stack card: the tile, the unit word, the sitting's dots while
  /// one runs and the watch's switch shows it, and the ＋ that runs
  /// `LogOneDrinkIntent` — parameterless, so it structurally cannot repeat
  /// the home-screen dispatch bug a promptable parameter once caused (the
  /// plan, Phase 6).
  ///
  /// The real family is about 177 × 80pt on a 46mm watch, not the 264 × 118
  /// the design drew it at, so the tile and the ＋ are 44 and the ≈ line is
  /// not shown — the same trade the home-screen widget's small family makes
  /// — and the dots take a row of their own beneath.
  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        ZStack {
          disc(radius: 13)
          figure(size: 24)
        }
        .frame(width: 44, height: 44)
        // The words beside it carry the count to VoiceOver; the tile would
        // otherwise speak it a second time, which the disc families avoid by
        // being one element.
        .accessibilityHidden(true)

        Text(showsMarker ? "Recorded as no alcohol today" : unitWordToday)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(showsMarker ? 2 : 1)
          .minimumScaleFactor(0.8)
          .accessibilityLabel(spokenLabel)

        Spacer(minLength: 0)

        // No `.buttonStyle(.plain)` — in a widget that suppresses interaction
        // handling entirely (the home-screen widget's lesson). No ＋ while
        // the store cannot be opened: the intent would fail against it.
        if !entry.isUnavailable {
          Button(intent: LogOneDrinkIntent()) {
            Image(systemName: "plus")
              .font(.system(size: 22, weight: .semibold))
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .background(Color("AccentFill"), in: .circle)
              .contentShape(.circle)
          }
          .buttonStyle(.borderless)
          .accessibilityLabel("Log one drink")
        }
      }

      if let session = entry.session {
        let row = SessionPace.dotRow(forCount: session.count)
        SessionDots(
          count: isFigureless ? SessionPace.dotMaximum : row.dots,
          band: entry.sessionBand,
          ringed: entry.sessionBand == nil || isFigureless,
          size: 6, gap: 4
        )
        .accessibilityHidden(true)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .containerBackground(.fill.tertiary, for: .widget)
  }

  // MARK: Parts

  /// The band's fill, or the system's translucent ground on a day with no
  /// band to show — unlogged, recorded as no alcohol (off the ramp), or
  /// figureless, when the colour would be the figure.
  @ViewBuilder
  private func disc(radius: CGFloat?) -> some View {
    let band = entry.band
    if !isFigureless, band != .unlogged, band != .alcoholFree {
      if let radius {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .fill(IntensityPalette.fill(band, scheme: scheme))
      } else {
        Circle().fill(IntensityPalette.fill(band, scheme: scheme))
      }
    } else if let radius {
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(.quaternary)
    } else {
      AccessoryWidgetBackground()
    }
  }

  /// The count in the band's ink — or, figureless, the drop glyph; on a day
  /// recorded as no alcohol, that glyph.
  @ViewBuilder
  private func figure(size: CGFloat) -> some View {
    if showsMarker {
      Image(decorative: DrinkType.Symbol.alcoholFree)
        .font(.system(size: size * 0.75, weight: .semibold))
        .foregroundStyle(.primary)
        .widgetAccentable()
    } else if isFigureless {
      Image(decorative: DrinkType.Symbol.standard)
        .font(.system(size: size * 0.75, weight: .semibold))
        .foregroundStyle(.primary)
        .widgetAccentable()
    } else {
      Text(entry.drinkCount, format: .number)
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.6)
        .foregroundStyle(ink)
        .privacySensitive()
        .widgetAccentable()
    }
  }

  private var ink: Color {
    let band = entry.band
    return band == .unlogged || band == .alcoholFree || isFigureless
      ? .primary
      : IntensityPalette.ink(band, scheme: scheme)
  }

  private var unitWordToday: LocalizedStringKey {
    !isFigureless && entry.drinkCount == 1 ? "drink today" : "drinks today"
  }

  /// The corner's curved words: the day's, never its count.
  private var curvedLabel: LocalizedStringKey {
    showsMarker ? "Recorded as no alcohol today" : unitWordToday
  }

  /// A whole key per branch, carrying the count, so a catalog can hold real
  /// plural variations — the home-screen widget's own two keys.
  private var countLabel: LocalizedStringKey {
    entry.drinkCount == 1
      ? "\(entry.drinkCount) drink today"
      : "\(entry.drinkCount) drinks today"
  }

  /// What VoiceOver hears: the count, the marker, or — redacted, with the
  /// watch off the wrist — the words alone. The system redacts the numeral's
  /// pixels but not a label written by hand, and a locked face that speaks
  /// the count is the same disclosure the glyph exists to close. ADR-0045's
  /// "hiding does not change what VoiceOver speaks" is about the user's own
  /// tap on the counter, not about the system's lock.
  private var spokenLabel: LocalizedStringKey {
    if showsMarker { return "Recorded as no alcohol today" }
    if isFigureless { return "drinks today" }
    return countLabel
  }
}
