import DrinkTrackerCore
import SwiftUI

/// The facts behind one selected Trends bar (ADR-0028), under the chart in
/// the same card.
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

  /// The wrapping text column first, the 44pt button second, top-aligned so
  /// the ✕ stays pinned top-trailing when the title wraps at AX sizes.
  private var header: some View {
    HStack(alignment: .top, spacing: GlassTokens.Spacing.tight) {
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

  /// System formats only, no catalog key: a day's full date, a week's
  /// interval, a month's name — the month through `SummaryHeading` so the
  /// "through today" phrase is assembled in one place.
  private var titleText: Text {
    switch detail.unit {
    case .month:
      SummaryHeading.month(detail.start, isClipped: detail.isPartial).titleText
    default:
      Text(verbatim: Self.titleString(for: detail, calendar: calendar))
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
        .contentTransition(.numericText())
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
            countCaption(share.count)
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
  private func countCaption(_ count: Double) -> Text {
    let whole = Int(count.rounded())
    return whole == 1 ? Text("1 drink") : Text("\(whole) drinks")
  }
}
