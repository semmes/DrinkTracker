import AppIntents
import DrinkTrackerCore
import SwiftData
import SwiftUI
import WidgetKit

/// The watch complication (watch Phase 6; ADR-0045, ADR-0046): today's count
/// in the day's band on every family — one tile on the rectangular card and
/// in the circular slot, a disc in the corner — with the sitting's dots on
/// the rectangular card while a session runs and the watch's own "Show
/// session pace" is on, and a ＋ there that logs one drink through
/// `LogOneDrinkIntent` without opening the app. `StaticConfiguration`
/// throughout, like `QuickLogWidget`, and the same two strings name it.
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
  /// the home-screen widget's pattern.
  ///
  /// This extension holds the App Group and no iCloud container (ADR-0055), so
  /// `make()` opens the shared store without mirroring, as the phone widget's
  /// does: a timeline build reads and starts no CloudKit work. Before 1.4 each
  /// build started a mirroring delegate of its own beside the watch app's (seen
  /// in this process's log, set up and torn down within the build), the
  /// two-process collision TN3164 describes.
  ///
  /// Nil when the store cannot be *read*, not only when it cannot be opened:
  /// a failed fetch used to draw a confident empty day, no dots, and — through
  /// the marker read — a count and a band on a day recorded as no alcohol.
  /// Every read on this path now throws into the unavailable entry instead
  /// (ADR-0046, ADR-0047). And without the App Group, `make()` opens a private
  /// store of this extension's own and returns normally, so that is checked
  /// first.
  static func load(at now: Date) -> Snapshot? {
    guard AppGroup.isAvailable else { return nil }
    let region = AppSettings.storedRegion()
    do {
      let container = try SharedModelContainer.make()
      let context = ModelContext(container)
      let repository = DrinkRepository(context: context)
      let todays = try repository.drinksOrThrow(on: now)
      let total = todays.reduce(0) { $0 + $1.standardDrinks(in: region) }

      // The sitting's raw material reaches back a day, as the counter's does,
      // so a session that began before midnight is one session (ADR-0044).
      let calendar = Calendar.current
      let floor = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
      let recent = try context.fetch(FetchDescriptor<DrinkEntry>.since(floor)).loggedDrinks

      return try Snapshot(
        recent: recent,
        todaysCount: todays.count,
        total: total,
        region: region,
        isMarkedAlcoholFree: repository.isMarkedAlcoholFreeOrThrow(now),
        // The card's dots follow the same switch as the counter's row: the
        // sitting is a surface the wrist opts into (ADR-0044, ADR-0017).
        showsSession: AppSettings.storedShowsSessionPace()
      )
    } catch {
      return nil
    }
  }
}

// MARK: - View

struct CounterComplicationView: View {
  let entry: CounterEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.redactionReasons) private var redaction
  @Environment(\.widgetRenderingMode) private var renderingMode

  private let scheme: ColorScheme = .dark

  /// A tinted face keeps each view's alpha and nothing else of its colour:
  /// every fill is drawn in one flat ink and whatever is accentable in the
  /// face's tint. A band's solid fill then became a bright block with the
  /// count at 1.3:1 on it, and the ＋ a blank disc — white glyph and blue
  /// fill are one ink there (both measured on a tinted Modular, 2026-09-18;
  /// the full-circle disc before it did the same). So on a tinted face the
  /// grounds go translucent and the figures stay solid: the count survives a
  /// tint, and the band, being colour, does not.
  private var isTinted: Bool { renderingMode != .fullColor }

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

  /// The circular: the card's own tile in a clear slot, and nothing else —
  /// so on the face it reads as the calendar's rounded mark, not as a disc
  /// (the owner's design, 2026-09-18; ADR-0046's amendment of that date). It
  /// had filled the whole circle with the band and set the count at 34; the
  /// tile is as large as the round mask allows and the figure is the card's.
  /// The slot's size is the watch's and the face's, so it is read, never
  /// assumed. No unit noun, by the owner's device pass (2026-09-15): the face
  /// draws its own label, and VoiceOver speaks the whole sentence.
  private var circular: some View {
    GeometryReader { slot in
      tile(side: ComplicationTile.side(forSlotDiameter: min(slot.size.width, slot.size.height)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
  ///
  /// And it is not one size: 181pt of content on a 46mm face, 138 in a 40mm
  /// Smart Stack, where this row truncated its words ("drinks t…", "Recorded
  /// as no al…"). The tile and the ＋ keep their 44 — the ＋ is a touch
  /// target — so on a card too narrow for one line at full size the words
  /// give instead: they wrap, they take the whole column between the two, and
  /// the gaps close to the watch counter's 4 (`ComplicationCard`, tier-1
  /// tested against every case size's width). A wide card — the 46mm in both
  /// of its contexts — is drawn exactly as it always was. The width is the
  /// system's, so it is read, never assumed.
  private var rectangular: some View {
    GeometryReader { card in
      let isNarrow = ComplicationCard.isNarrow(contentWidth: card.size.width)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: isNarrow ? ComplicationCard.narrowGap : ComplicationCard.gap) {
          tile(side: ComplicationTile.cardSide)
            // The words beside it carry the count to VoiceOver; the tile would
            // otherwise speak it a second time, which the circular and corner
            // families avoid by being one element.
            .accessibilityHidden(true)

          Text(showsMarker ? "Recorded as no alcohol today" : unitWordToday)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(ComplicationCard.lineLimit(isMarker: showsMarker, isNarrow: isNarrow))
            .minimumScaleFactor(ComplicationCard.minimumScale)
            // Narrow, the words fill the column themselves, so the Spacer —
            // and the second gap it keeps — can go.
            .frame(maxWidth: isNarrow ? .infinity : nil, alignment: .leading)
            .accessibilityLabel(spokenLabel)

          if !isNarrow {
            Spacer(minLength: 0)
          }

          // No `.buttonStyle(.plain)` — in a widget that suppresses interaction
          // handling entirely (the home-screen widget's lesson). No ＋ while
          // the store cannot be opened: the intent would fail against it.
          if !entry.isUnavailable {
            Button(intent: LogOneDrinkIntent()) {
              Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: ComplicationCard.plusSide, height: ComplicationCard.plusSide)
                .background(plusGround, in: .circle)
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
    }
    .containerBackground(.fill.tertiary, for: .widget)
  }

  // MARK: Parts

  /// The count's tile, the one view the rectangular card and the circular
  /// slot both draw, so the two cannot drift apart again: the ground at the
  /// card's own corner proportion, and the figure at the card's own size
  /// whatever the side — a smaller tile is a smaller ground, not a smaller
  /// number (`ComplicationTile`, tier-1 tested).
  private func tile(side: CGFloat) -> some View {
    ZStack {
      disc(radius: ComplicationTile.cornerRadius(forSide: side))
      figure(size: 24)
    }
    .frame(width: side, height: side)
  }

  /// The band's fill, or a translucent ground on a day with no band to show
  /// — unlogged, recorded as no alcohol (off the ramp), figureless, when the
  /// colour would be the figure, or on a tinted face, where it cannot be
  /// drawn (`isTinted`). A radius draws the tile; none, the corner family's
  /// disc on the system's own ground.
  @ViewBuilder
  private func disc(radius: CGFloat?) -> some View {
    let band = entry.band
    if !isFigureless, !isTinted, band != .unlogged, band != .alcoholFree {
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
        // Three digits shrink to fit the tile and never wrap inside it.
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .foregroundStyle(ink)
        .privacySensitive()
        .widgetAccentable()
    }
  }

  private var ink: Color {
    let band = entry.band
    return band == .unlogged || band == .alcoholFree || isFigureless || isTinted
      ? .primary
      : IntensityPalette.ink(band, scheme: scheme)
  }

  /// The ＋'s disc: the accent fill, or on a tinted face the tile's own
  /// translucent ground, so the glyph is not drawn in the ink of its disc.
  private var plusGround: AnyShapeStyle {
    isTinted ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color("AccentFill"))
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
