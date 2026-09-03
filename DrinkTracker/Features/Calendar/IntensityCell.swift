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
  /// Passed in rather than read from the environment, matching `DrinkRow`: the
  /// year view renders 365 of these.
  var region: Region = .unitedStates

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
      // what's recorded. The wash goes only on blank days — the ones a bulk fill
      // can write to — so the highlight itself previews which days the action will
      // touch; recorded days get the ring alone (Tallyist prototype handoff).
      // Strokes count as glyphs, so the text accent is right here (design review
      // R2 — only solid fills under white labels need AccentFill).
      if isSelected {
        if !intensity.isRecorded {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(0.15))
        }
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
  private var accessibilityLabel: Text {
    let date = day.date.formatted(.dateTime.month(.wide).day())
    let amount = intensity.isRecorded && intensity != .alcoholFree
      ? StandardDrink.amountPhrase(day.standardDrinks, region: region)
      : intensity.accessibilityDescription
    // Both halves arrive translated already — the date from a locale format, the
    // amount from the package — so "Today" is the only word left to translate.
    // The other branch written as a key would be "%@, %@": two placeholders and
    // a comma, which asks a translator to localize punctuation.
    return isToday
      ? Text("Today, \(date), \(amount)")
      : Text(verbatim: "\(date), \(amount)")
  }
}

extension DayIntensity {
  /// Legend order, shared by the in-app legend and the share cards so the two
  /// can never drift. "Not logged" is drawn as nothing, so naming it last is
  /// what tells a reader that a blank cell means absence of data, not a zero.
  static let legendOrder: [DayIntensity] = [.alcoholFree, .low, .medium, .high, .unlogged]

  /// The legend label as a catalog key.
  ///
  /// `legendLabel` is the package's plain String, and `Text(String)` is the
  /// verbatim initializer — so the in-app legend never reached the catalog.
  /// The words are the same five. They live app-side rather than behind the
  /// package's `localized()` because `xcstringstool generate-symbols` derives
  /// a Swift identifier from every package key, and keys made of digits and
  /// punctuation ("1–2", "6+") are the ones it has no good answer for; the app
  /// catalog generates no symbols and tolerates them. Localizing the package's
  /// own labels is ADR-0020's question, deferred with the rest of translation.
  var legendKey: LocalizedStringKey {
    switch self {
    case .unlogged: "Not logged"
    case .alcoholFree: "No alcohol"
    case .low: "1–2"
    case .medium: "3–5"
    case .high: "6+"
    }
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

  var body: some View {
    FlowLayout(spacing: GlassTokens.Spacing.regular) {
      ForEach(DayIntensity.legendOrder, id: \.self) { intensity in
        HStack(spacing: 6) {
          swatch(intensity)
          Text(intensity.legendKey)
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
