import DrinkTrackerCore
import SwiftUI

/// The full facts behind one selected Trends bar (ADR-0028), below the chart in
/// the same card — shown for a *stepped* selection, the one that persists
/// between actions. A scrub reads the compact `PeriodReadout` in the card's
/// header instead, which is over before a control could be reached.
///
/// A date, a figure, and what was logged by kind — the History rows for that
/// period restated so they can be checked there, with the rows summing to the
/// figure above them. A week or month bar carries the calendar card's four
/// figures in the same component the calendar uses, so the copy cannot drift.
/// Nothing here is phrased against the "Your average" line, ranked, or
/// characterised: `PeriodDetail` has no field for any of that, so the view
/// has nothing to phrase.
struct PeriodDetailView: View {
  let detail: PeriodDetail
  let region: Region
  let isToday: Bool
  var calendar: Calendar = .current

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      header

      switch detail.dayRecord {
      case .drinks?:
        dayFigure
      case .alcoholFree(let fromHealth)?:
        VStack(alignment: .leading, spacing: 2) {
          Label("Recorded as no alcohol", systemImage: "checkmark.circle")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          // The same disclosure the day sheet and Today make (ADR-0025): a
          // third surface showing the marker must say where it came from.
          if fromHealth {
            Text("From Apple Health")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .accessibilityElement(children: .combine)
      case .unlogged?:
        // The calendar legend's word, so a blank bar and a blank cell read
        // the same. Not "no drinks": an unlogged day is not a day without
        // alcohol (ADR-0006).
        Text(DayIntensity.unlogged.legendKey)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      case nil:
        RecentSummaryFigures(summary: detail.summary, region: region)
      }

      ForEach(detail.shares) { share in
        shareRow(share)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Header

  /// No dismiss control. A touch selection ends when the finger lifts, so there
  /// is nothing to close; a stepped selection is cleared by the escape gesture
  /// and by the chart's named "Clear selection" action, both of which every
  /// assistive technology that can reach the stepper can also reach. The owner
  /// ruled the ✕ out on 2026-09-05: *"You should not have another X or tap to
  /// close the information."*
  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      titleText
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
      if isToday {
        Text("Today")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      // A bucket names its day count, as the calendar card does, so the
      // three day-figures below stay checkable against it.
      if detail.unit != .day {
        Text(RecentSummaryCaptions.dayCount(detail.summary.dayCount))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private var titleText: Text { Self.titleText(for: detail, calendar: calendar) }

  /// System formats only, no catalog key: a day's full date, a week's
  /// interval, a month's name — the month through `SummaryHeading` so the
  /// "through today" phrase is assembled in one place.
  ///
  /// Static so `PeriodReadout` draws the same title through the same branch:
  /// the header and the block can then never name one bar two ways.
  static func titleText(for detail: PeriodDetail, calendar: Calendar) -> Text {
    switch detail.unit {
    case .month:
      SummaryHeading.month(detail.start, isClipped: detail.isPartial).titleText
    default:
      Text(verbatim: titleString(for: detail, calendar: calendar))
    }
  }

  /// The title as a String, for the chart's spoken value.
  ///
  /// A week is the interval from its start to noon of its last day: noon is
  /// inside the last day in every zone, where a chained day-after bound can
  /// print an extra day when the day after is a 01:00 midnight-DST day, and
  /// a "%@ – %@" key would be placeholders and punctuation only.
  static func titleString(for detail: PeriodDetail, calendar: Calendar) -> String {
    switch detail.unit {
    case .day:
      return detail.start.formatted(.dateTime.weekday(.wide).month(.wide).day())
    case .month:
      let name = detail.start.formatted(.dateTime.month(.wide).year())
      return detail.isPartial ? String(localized: "\(name), through today") : name
    default:
      let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: detail.lastDay)
        ?? detail.lastDay
      return (detail.start..<noon).formatted(date: .abbreviated, time: .omitted)
    }
  }

  // MARK: - Day figure

  /// The StatCard shape: the amount in the current unit, singular from the
  /// displayed digits. A 0% drink shows "0 standard drinks" with a row
  /// beneath it — a logged drink that rounds to zero is still a day with
  /// drinks, as the calendar holds.
  private var dayFigure: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(StandardDrink.formatted(detail.standardDrinks))
        .font(GlassTokens.Typography.cardValue)
        .foregroundStyle(.primary)
        // The bar changed, not the value: a crossfade, never a roll that
        // would draw a direction between two bars (ADR-0026, design-system
        // §5) — the same rule the four bucket figures beside it follow.
        .contentTransition(.opacity)
      Text(verbatim: region.unitName(for: detail.standardDrinks))
        .font(GlassTokens.Typography.cardLabel)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: StandardDrink.amountPhrase(detail.standardDrinks, region: region)))
  }

  // MARK: - Composition rows

  /// DrinkRow's geometry: symbol, name with its count beneath, the amount
  /// trailing. Stacks vertically at accessibility sizes so the amount wraps
  /// under the name instead of truncating. Rows are not buttons: nothing
  /// here edits anything.
  private func shareRow(_ share: DrinkShare) -> some View {
    let layout = dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
      : AnyLayout(HStackLayout(spacing: GlassTokens.Spacing.regular))

    return layout {
      HStack(spacing: GlassTokens.Spacing.regular) {
        Image(systemName: symbolName(share.kind))
          .foregroundStyle(Color.accentColor)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
          name(share.kind)
            .font(.body)
            .foregroundStyle(.primary)
          // An import's count is its amount (ADR-0014); printing both would
          // show one number twice.
          if case .type = share.kind {
            Self.countCaption(share.count)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      if !dynamicTypeSize.isAccessibilitySize {
        Spacer(minLength: GlassTokens.Spacing.tight)
      }
      Text(verbatim: StandardDrink.amountPhrase(share.standardDrinks, region: region))
        .font(.callout.weight(.medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private func symbolName(_ kind: DrinkShare.Kind) -> String {
    switch kind {
    case .type(let type): type.symbolName
    case .importedFromHealth: "heart.text.square"
    }
  }

  /// Package-localized names render verbatim (DrinkRow's precedent). The
  /// untyped drink reads "No type" — ADR-0023's own vocabulary — because its
  /// `displayName` is the whole summary line "One standard drink", which
  /// reads wrong beside a count of 3.
  private func name(_ kind: DrinkShare.Kind) -> Text {
    switch kind {
    case .type(.unspecified): Text("No type")
    case .type(let type): Text(verbatim: type.displayName)
    case .importedFromHealth: Text("From Apple Health")
    }
  }

  /// "drinks", not "entries": an entry is one drink (invariant 7), and drinks
  /// is the word every other surface uses. An Int reaches the catalog as
  /// %lld, so the pair can take real plural variations at translation time.
  static func countCaption(_ count: Double) -> Text {
    let whole = Int(count.rounded())
    return whole == 1 ? Text("1 drink") : Text("\(whole) drinks")
  }
}

/// The scrubbed bar's facts, in the chart card's header (ADR-0028 amendment).
///
/// The compact half of what `PeriodDetailView` says: the period, its total, and
/// three of ADR-0006's figures — the parts that read at a glance while a finger
/// is moving. The composition rows and the named unlogged count stay on
/// `PeriodDetailView`, which a stepped selection still shows below the chart;
/// the unlogged count is spoken here, so the scrub is never less complete than
/// the block for someone reading with VoiceOver.
///
/// **Row 2 is a numeral *or* a phrase, by design.** A day recorded as no
/// alcohol and a day with nothing logged print their words rather than a 0:
/// alcohol-free is the absence of the measured quantity, not the bottom of it
/// (ADR-0007), and a printed 0 would make the two read identically. The block's
/// optical weight therefore changes between bars, which is intended — it is not
/// to be "fixed" by printing zero.
struct PeriodReadout: View {
  let detail: PeriodDetail
  let region: Region
  let isToday: Bool
  var calendar: Calendar = .current

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      titleRow
      figureRow.padding(.top, 4)
      factsRow.padding(.top, 6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spokenLabel)
  }

  private var titleRow: some View {
    HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.tight) {
      PeriodDetailView.titleText(for: detail, calendar: calendar)
        // Footnote semibold, not subheadline: both prototypes set the period
        // title at 13px/600 (`.rdate` in the design-system card, and the live
        // row in `Trends Bar Selection.dc.html`). The handoff prose said
        // "subheadline semibold" and the prototypes win — they are the design.
        // It is also what lets the two readout states share one height.
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      trailingNote
    }
  }

  /// A bucket names its day count, as the calendar card does, so the figures
  /// below stay checkable against it — never suffixed "through today", which a
  /// month title already carries through `SummaryHeading`. A day bar has no
  /// count to name, so the slot takes "Today" when it is: the caption that
  /// moves at midnight with the range's end and the selected bar (ADR-0028).
  @ViewBuilder
  private var trailingNote: some View {
    if detail.unit != .day {
      Text(RecentSummaryCaptions.dayCount(detail.summary.dayCount))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize()
    } else if isToday {
      Text("Today")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize()
    }
  }

  /// The figure, or — for a day with nothing recorded either way — the words
  /// that say so.
  ///
  /// **A day recorded as no alcohol prints a zero; a day with nothing recorded
  /// does not.** The owner's ruling (2026-09-05): *"0 is the same as alcohol
  /// free where the user made the decision not to have alcohol and it should be
  /// recognized vs. the user not interacting with the app and it's unknown to
  /// us or not logged."* That is ADR-0006's distinction stated from the reader's
  /// side, and it is why the zero is not simply given to every empty bar: a
  /// marker is a decision the user recorded and the figure is the true count of
  /// it, while an unlogged day has no count to print — printing 0 there would
  /// claim a fact the log does not hold.
  @ViewBuilder
  private var figureRow: some View {
    switch detail.dayRecord {
    case .unlogged?:
      // The calendar legend's word, so a blank bar and a blank cell read the
      // same. Not "no drinks": an unlogged day is not a day without alcohol.
      Text(DayIntensity.unlogged.legendKey)
        .font(GlassTokens.Typography.cardValue)
        .foregroundStyle(.secondary)
        .contentTransition(.opacity)
    case .alcoholFree?, .drinks?, nil:
      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Text(StandardDrink.formatted(detail.standardDrinks))
          .font(GlassTokens.Typography.cardValue)
          .monospacedDigit()
          .foregroundStyle(IntensityPalette.liveFigure(scheme: colorScheme))
          // The bar changed, not the value: a crossfade, never a roll that
          // would draw a direction between two bars (ADR-0026, design-system §5).
          .contentTransition(.opacity)
        Text(verbatim: region.unitName(for: detail.standardDrinks))
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)
      }
    }
  }

  /// The qualifying facts under the figure.
  ///
  /// A marker day names itself here rather than in place of its zero — the
  /// zero is the count, this is which zero it is (ADR-0025/ADR-0028). A bucket
  /// carries three of ADR-0006's four figures; the fourth is the total, already
  /// 28 points above. A day bar's three counts are always (1,0,0), (0,1,0) or
  /// (0,0,1), so printing them would be noise; it prints its entry count
  /// instead, which is the one fact the figure does not state and what tells a
  /// 0%-ABV day ("0 standard drinks", one drink) from a marker day now that the
  /// composition rows are off the scrub.
  @ViewBuilder
  private var factsRow: some View {
    switch detail.dayRecord {
    case .drinks?:
      PeriodDetailView.countCaption(entryCount)
        .font(.caption2)
        .foregroundStyle(.secondary)
    case .alcoholFree(let fromHealth)?:
      // ADR-0025: every surface showing the marker says where it came from.
      HStack(spacing: 4) {
        Label("Recorded as no alcohol", systemImage: "checkmark.circle")
        if fromHealth {
          Text(verbatim: "·")
          Text("From Apple Health")
        }
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
    case .unlogged?:
      EmptyView()
    case nil:
      bucketFactsRow
    }
  }

  /// The design's 14pt gaps, tightening to 8 before it ever wraps.
  ///
  /// Chosen from the type size rather than measured by `ViewThatFits`: the box
  /// crossfades between two states, and a fitting container re-measures every
  /// frame of that crossfade, which is what made the text jitter on release.
  /// A deterministic choice animates cleanly. Measured on a 402pt screen the
  /// three captions come to ~330pt at 14pt gaps — exactly the content width —
  /// so the default already takes the 8pt gap, and a wrapped row is the card
  /// growing on a selection.
  @ViewBuilder
  private var bucketFactsRow: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 2) { bucketFacts }
    } else {
      HStack(alignment: .top, spacing: GlassTokens.Spacing.tight) { bucketFacts }
    }
  }

  private var entryCount: Double { detail.shares.reduce(0) { $0 + $1.count } }

  /// The em dash stays an item rather than disappearing at zero: the row would
  /// otherwise change its item count between bars inside one box, and
  /// `averageValue` already prints "—" exactly when there is nothing to average.
  @ViewBuilder
  private var bucketFacts: some View {
    fact("\(detail.summary.daysWithDrinks)", RecentSummaryCaptions.compactDaysWithDrinks)
    fact(RecentSummaryCaptions.averageValue(detail.summary), RecentSummaryCaptions.compactAverageCaption)
    // The prototype's third fact, and ADR-0033's figure: the longest run of
    // days *recorded* as no alcohol inside this bar. It takes the slot the
    // count of marked days held, which is the design as drawn; that count is
    // still spoken below and still printed in full by the block a stepped
    // selection shows.
    fact("\(detail.longestAlcoholFreeRun)", RecentSummaryCaptions.compactNoneInARow)
  }

  /// A rounded-semibold numeral and the calendar card's own noun for it, so one
  /// figure never carries two vocabularies on one screen (ADR-0026). The
  /// numeral sits a step darker than its noun, as both prototypes draw it
  /// (`rgba(0,0,0,.78)` against the noun's `.6`): the number is the fact and
  /// the word only names it.
  private func fact(_ value: String, _ caption: LocalizedStringKey) -> some View {
    (Text(verbatim: value)
      .font(.system(.caption2, design: .rounded, weight: .semibold))
      .monospacedDigit()
      .foregroundStyle(.primary)
      + Text(verbatim: " ")
      + Text(caption).font(.caption2).foregroundStyle(.secondary))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// Composed verbatim from parts that arrive localized. It carries the named
  /// unlogged count the compact row has no room to print — ADR-0006's rule that
  /// unlogged days are named holds on the spoken path even where the row
  /// abbreviates.
  private var spokenLabel: Text {
    var label = PeriodDetailView.titleText(for: detail, calendar: calendar)
    if detail.unit != .day {
      label = label + Text(verbatim: ", ")
        + Text(RecentSummaryCaptions.dayCount(detail.summary.dayCount))
    } else if isToday {
      label = label + Text(verbatim: ", ") + Text("Today")
    }
    switch detail.dayRecord {
    case .alcoholFree(let fromHealth)?:
      // Spoken as the marker, not as a bare "0 standard drinks": the words are
      // what carry the decision the zero stands for.
      label = label + Text(verbatim: ", ")
        + Text(verbatim: DayIntensity.alcoholFree.accessibilityDescription)
      if fromHealth {
        label = label + Text(verbatim: ", ") + Text("From Apple Health")
      }
    case .unlogged?:
      label = label + Text(verbatim: ", ")
        + Text(verbatim: DayIntensity.unlogged.accessibilityDescription)
    case .drinks?, nil:
      label = label + Text(verbatim: ", ")
        + Text(verbatim: StandardDrink.amountPhrase(detail.standardDrinks, region: region))
    }
    guard detail.unit != .day else { return label }
    label = label + Text(verbatim: ", ")
      + RecentSummaryCaptions.spokenDaysWithDrinks(detail.summary.daysWithDrinks)
      + Text(verbatim: ", ")
      + RecentSummaryCaptions.spokenDaysWithNone(detail.summary.daysAlcoholFree)
      + Text(verbatim: ", ")
      + RecentSummaryCaptions.spokenNoneInARow(detail.longestAlcoholFreeRun)
    if let unlogged = RecentSummaryCaptions.unlogged(detail.summary.daysUnlogged) {
      label = label + Text(verbatim: ", ") + Text(unlogged)
    }
    return label
  }
}

/// The average line's key: the mark's own stroke at 14 points, so the legend
/// and the rule it names cannot drift apart.
struct DashedRule: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    return path
  }
}
