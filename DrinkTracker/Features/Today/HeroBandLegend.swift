import DrinkTrackerCore
import SwiftUI

/// The four drinking bands, under Today's counter (ADR-0034).
///
/// The hero tile encodes the day's amount as colour, and a colour that encodes
/// anything needs its boundaries stated — the same argument the calendar's
/// legend rests on. Without it the tile is a mood; with it, "3–5" is a fact the
/// reader can check against the figure one line above.
///
/// Only the drinking bands appear. `.alcoholFree` and `.unlogged` are the tile's
/// other two states, and both are already named in words directly beneath it
/// ("Recorded as no alcohol today" / "Record no alcohol today") — which is a
/// stronger channel than a swatch, and keeps the row to four items so it fits
/// on one line at default sizes.
struct HeroBandLegend: View {
  let active: DayIntensity

  @Environment(\.colorScheme) private var scheme
  /// The swatch tracks the label's size, so the row stays proportionate at
  /// every Dynamic Type step rather than becoming four dots beside big words.
  @ScaledMetric(relativeTo: .caption2) private var swatch: CGFloat = 13

  private static let bands: [DayIntensity] = [.low, .medium, .high, .veryHigh]

  var body: some View {
    FlowLayout(spacing: 11) {
      ForEach(Self.bands, id: \.self) { band in
        item(band)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func item(_ band: DayIntensity) -> some View {
    let isActive = band == active
    return HStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(IntensityPalette.fill(band, scheme: scheme))
        .frame(width: swatch, height: swatch)

      Text(band.legendKey)
        .font(.caption2.weight(isActive ? .semibold : .regular))
        // Emphasis rides weight and ink tier, never opacity: the drawing dims
        // the inactive labels to 45%, which over secondary composites to about
        // a quarter alpha at 11pt — hierarchy by thinning ink is the one thing
        // design-system.md §3 rules out.
        .foregroundStyle(isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .monospacedDigit()
    }
    // One element per band, so VoiceOver reads "1–2, selected" rather than a
    // swatch and a number as two stops. The swatch itself says nothing — the
    // label already carries the range.
    //
    // `legendKey`, not the package's `accessibilityDescription`: that phrase
    // is a hardcoded English string naming "standard drinks", so it is both
    // unreachable by a catalog and wrong under the UK lens, where the figure
    // one line above says "units". The range is unit-neutral and the noun is
    // already spoken by that figure. Same choice the calendar's legend makes.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(band.legendKey)
    .accessibilityAddTraits(isActive ? [.isSelected] : [])
  }
}
