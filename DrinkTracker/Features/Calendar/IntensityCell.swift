import DrinkTrackerCore
import SwiftUI

/// One day in a calendar grid.
///
/// Used at two very different sizes — a tappable cell in the month view, a few
/// points across in the year view — so everything scales from `side` rather than
/// being fixed.
struct IntensityCell: View {
  let day: CalendarDay
  /// Shown in the month view; omitted in the year view, where there is no room.
  var showsDayNumber: Bool = true
  var side: CGFloat = 40
  var isToday: Bool = false
  /// Part of an in-progress drag selection on the month grid.
  var isSelected: Bool = false

  @Environment(\.colorScheme) private var scheme

  private var intensity: DayIntensity { day.intensity }

  private var cornerRadius: CGFloat {
    // Proportional so the year view's small cells don't end up looking like pills.
    max(3, side * 0.28)
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(IntensityPalette.fill(intensity, scheme: scheme))

      // Second encoding channel, so "recorded but empty" is separable from "not
      // recorded" without relying on colour at all.
      if IntensityPalette.isOutlined(intensity) {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.35), lineWidth: max(1, side * 0.04))
      }

      if isToday {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.accentColor, lineWidth: max(1.5, side * 0.06))
      }

      // A wash and a ring rather than a solid accent fill: the day's own intensity
      // colour has to stay legible underneath, because what's selected still shows
      // what's recorded. Strokes count as glyphs, so the text accent is right here
      // (design review R2 — only solid fills under white labels need AccentFill).
      if isSelected {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.accentColor.opacity(0.22))
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.accentColor, lineWidth: max(1.5, side * 0.06))
      }

      if showsDayNumber {
        Text("\(dayNumber)")
          .font(.system(size: side * 0.38, weight: intensity.isRecorded ? .semibold : .regular))
          .foregroundStyle(IntensityPalette.ink(intensity, scheme: scheme))
          .minimumScaleFactor(0.6)
      }
    }
    .frame(width: side, height: side)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }

  private var dayNumber: Int {
    Calendar.current.component(.day, from: day.date)
  }

  /// Colour carries nothing here — the label says the date and the amount outright,
  /// which is the only version of this cell a VoiceOver user gets.
  private var accessibilityLabel: String {
    let date = day.date.formatted(.dateTime.month(.wide).day())
    let amount: String
    if intensity.isRecorded && intensity != .alcoholFree {
      amount = "\(StandardDrink.formatted(day.standardDrinks)) standard drinks"
    } else {
      amount = intensity.accessibilityDescription
    }
    return isToday ? "Today, \(date), \(amount)" : "\(date), \(amount)"
  }
}

/// Legend for the intensity ramp.
///
/// Always present. The ramp is readable without it, but a legend is what makes the
/// buckets' boundaries explicit — "1–2" is a fact about the data, not something a
/// reader should have to infer from a shade.
struct IntensityLegend: View {
  /// The year view is dense enough that a wrapped single line reads better than
  /// the two-column layout the month view uses.
  var isCompact: Bool = false

  @Environment(\.colorScheme) private var scheme

  private var shown: [DayIntensity] {
    // "Not logged" is drawn as nothing, so naming it in the legend is what tells a
    // reader that a blank cell means absence of data rather than a zero.
    [.alcoholFree, .low, .medium, .high, .unlogged]
  }

  var body: some View {
    FlowLayout(spacing: GlassTokens.Spacing.regular) {
      ForEach(shown, id: \.self) { intensity in
        HStack(spacing: 6) {
          swatch(intensity)
          Text(intensity.legendLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
      }
    }
  }

  private func swatch(_ intensity: DayIntensity) -> some View {
    let side: CGFloat = isCompact ? 12 : 14
    return ZStack {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(IntensityPalette.fill(intensity, scheme: scheme))
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .strokeBorder(
          // The unlogged swatch has no fill, so without a hairline there would be
          // nothing beside its label at all.
          IntensityPalette.isOutlined(intensity) || intensity == .unlogged
            ? Color.primary.opacity(0.35)
            : .clear,
          lineWidth: 1
        )
    }
    .frame(width: side, height: side)
  }
}
