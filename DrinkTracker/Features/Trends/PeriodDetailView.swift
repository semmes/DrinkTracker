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
  let onClear: () -> Void

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

  /// The wrapping text column first, the 44pt button second, aligned on the
  /// title's first baseline so the ✕ sits on the title's own line — and stays
  /// there when the title wraps at AX sizes, since the first line is the
  /// anchor.
  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.tight) {
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

      // A real Button, the pattern PopulationReferenceCard proved receives
      // taps on a card (an onTapGesture on an SUCard never fires).
      Button(action: onClear) {
        Image(systemName: "xmark")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(
            width: GlassTokens.Layout.minimumTouchTarget,
            height: GlassTokens.Layout.minimumTouchTarget
          )
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Clear selection")
    }
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
        .font(.subheadline.weight(.semibold))
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

  @ViewBuilder
  private var figureRow: some View {
    switch detail.dayRecord {
    case .alcoholFree?:
      Label("Recorded as no alcohol", systemImage: "checkmark.circle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    case .unlogged?:
      // The calendar legend's word, so a blank bar and a blank cell read the
      // same. Not "no drinks": an unlogged day is not a day without alcohol.
      Text(DayIntensity.unlogged.legendKey)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    case .drinks?, nil:
      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Text(StandardDrink.formatted(detail.standardDrinks))
          .font(GlassTokens.Typography.cardValue)
          .monospacedDigit()
          .foregroundStyle(.primary)
          // The bar changed, not the value: a crossfade, never a roll that
          // would draw a direction between two bars (ADR-0026, design-system §5).
          .contentTransition(.opacity)
        Text(verbatim: region.unitName(for: detail.standardDrinks))
          .font(GlassTokens.Typography.cardLabel)
          .foregroundStyle(.secondary)
      }
    }
  }

  /// A bucket carries three of ADR-0006's four figures — the fourth is the
  /// total, already 28 points above. A day bar's three counts are always
  /// (1,0,0), (0,1,0) or (0,0,1), so printing them would be noise; it prints
  /// its entry count instead, which is the one fact the figure does not state,
  /// and what tells a 0%-ABV day ("0 standard drinks", one drink) from a marker
  /// day now that the composition rows are off the scrub.
  @ViewBuilder
  private var factsRow: some View {
    switch detail.dayRecord {
    case .drinks?:
      PeriodDetailView.countCaption(entryCount)
        .font(.caption2)
        .foregroundStyle(.secondary)
    case .alcoholFree(let fromHealth)? where fromHealth:
      // ADR-0025: every surface showing the marker says where it came from.
      Text("From Apple Health")
        .font(.caption2)
        .foregroundStyle(.secondary)
    case nil:
      // The design's 14pt gaps first, a tighter 8pt second, and only then a
      // stack. Measured on a 402pt screen the three reviewed captions come to
      // ~330pt at 14pt gaps — exactly the content width, so they wrapped, and a
      // wrapped row is the card growing on a selection, which is the whole
      // fault this readout exists to fix. Stacking stays the last resort for
      // the accessibility sizes, where growing beats clipping.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 14) { bucketFacts }
        HStack(alignment: .top, spacing: GlassTokens.Spacing.tight) { bucketFacts }
        VStack(alignment: .leading, spacing: 2) { bucketFacts }
      }
    default:
      EmptyView()
    }
  }

  private var entryCount: Double { detail.shares.reduce(0) { $0 + $1.count } }

  /// The em dash stays an item rather than disappearing at zero: the row would
  /// otherwise change its item count between bars inside one box, and
  /// `averageValue` already prints "—" exactly when there is nothing to average.
  @ViewBuilder
  private var bucketFacts: some View {
    fact(
      "\(detail.summary.daysWithDrinks)",
      RecentSummaryCaptions.daysWithDrinks(detail.summary.daysWithDrinks)
    )
    fact(
      RecentSummaryCaptions.averageValue(detail.summary),
      RecentSummaryCaptions.averageCaption
    )
    fact(
      "\(detail.summary.daysAlcoholFree)",
      RecentSummaryCaptions.daysWithNone(detail.summary.daysAlcoholFree)
    )
  }

  /// A rounded-semibold numeral and the calendar card's own noun for it, so one
  /// figure never carries two vocabularies on one screen (ADR-0026).
  private func fact(_ value: String, _ caption: LocalizedStringKey) -> some View {
    (Text(verbatim: value)
      .font(.system(.caption2, design: .rounded, weight: .semibold))
      .monospacedDigit()
      + Text(verbatim: " ")
      + Text(caption).font(.caption2))
      .foregroundStyle(.secondary)
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
    case .alcoholFree?:
      label = label + Text(verbatim: ", ")
        + Text(verbatim: DayIntensity.alcoholFree.accessibilityDescription)
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
