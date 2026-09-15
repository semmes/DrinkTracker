import DrinkTrackerCore
import SwiftUI

/// The four drinking bands under the counter, the phone's `HeroBandLegend`
/// at watch size (ADR-0034's argument: a colour that encodes anything needs
/// its boundaries stated, so "3–5" is a fact the reader can check against the
/// figure above it). Same four bands, same keys, so the two surfaces cannot
/// disagree about what a shade means.
///
/// While the count is hidden the labels go — "3–5" is as readable across a
/// table as a count, and hiding the numeral while leaving the ranges named
/// would be theatre — but they stay laid out at zero opacity so the swatches
/// do not shift (the design's one "do not animate the gap" rule). Under
/// Always-On the swatches empty to outlines with the tile (ADR-0045).
struct WatchBandLegend: View {
  let active: DayIntensity
  let labelsHidden: Bool

  @Environment(\.redactionReasons) private var redaction
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let scheme: ColorScheme = .dark
  private static let bands: [DayIntensity] = [.low, .medium, .high, .veryHigh]

  var body: some View {
    HStack(spacing: 7) {
      ForEach(Self.bands, id: \.self) { band in
        item(band)
      }
    }
    .frame(maxWidth: .infinity)
    .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: labelsHidden)
  }

  private func item(_ band: DayIntensity) -> some View {
    let isActive = band == active
    let swatch = RoundedRectangle(cornerRadius: WatchLayout.legendSwatchRadius, style: .continuous)
    return HStack(spacing: 3) {
      swatch
        .fill(redaction.contains(.privacy) ? Color.clear : IntensityPalette.fill(band, scheme: scheme))
        .overlay {
          if redaction.contains(.privacy) {
            swatch.strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
          }
        }
        .frame(width: WatchLayout.legendSwatch, height: WatchLayout.legendSwatch)

      Text(band.legendKey)
        .font(.system(size: WatchLayout.legendLabelSize, weight: isActive ? .semibold : .regular))
        // Emphasis rides weight and ink tier, never opacity (design-system.md §3).
        .foregroundStyle(isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .monospacedDigit()
        .opacity(labelsHidden ? 0 : 1)
    }
    // One element per band, labels visible or not: hiding must not change
    // what VoiceOver speaks (ADR-0045).
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(band.legendKey)
    .accessibilityAddTraits(isActive ? [.isSelected] : [])
  }
}
