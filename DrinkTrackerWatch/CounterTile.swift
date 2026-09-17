import DrinkTrackerCore
import SwiftUI

/// The 86pt tile behind the count: the day's own band, painted from
/// `IntensityPalette` by name over `DayIntensity.bucket` — the same two calls
/// as the phone's hero and the calendar cell, so one day can never read one
/// amount on the wrist and another on the phone (ADR-0034; PRD invariant 10).
///
/// Four states share the frame, and nothing is added or removed between them
/// — both the numeral and its hidden-state bar stay laid out and only opacity
/// moves, the lesson ADR-0028's amendment paid for once already:
///
/// - **a logged day**: the band's fill, the count in the band's ink;
/// - **an unlogged day**: no tile — absence drawn as absence (ADR-0007) — and
///   the numeral takes the tile's room at 56;
/// - **recorded as no alcohol**: the outline channel at tile scale, with the
///   alcohol-free glyph — off the ramp, so it can never read as a small
///   amount of drinking;
/// - **redacted** (Always-On, wrist down): the fill goes too, because once
///   the digits are gone the colour *is* the figure (ADR-0045); the drop
///   glyph returns so the screen does not read as broken;
/// - **unreadable** (today's read failed — ADR-0004's 2026-09-16 amendment):
///   drawn exactly as redacted, because there is no figure to show and no
///   band to paint, and a bare 0 would claim an empty day — the complication
///   draws its unavailable entry the same way (ADR-0047).
///
/// The user's own hide (a tap on the tile) suppresses the numeral for a
/// struck-out bar in the band's ink and keeps the fill: the day's amount stays
/// fully stated by colour, to its owner, and to no one else.
struct CounterTile: View {
  let count: Int
  let band: DayIntensity
  let isCountHidden: Bool
  /// Today could not be read: the redacted drawing, whatever the count says.
  var isUnavailable: Bool = false

  @Environment(\.redactionReasons) private var redaction
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The watch renders against the dark ground only (watchOS has no light
  /// mode), which is why every palette call here reads the dark ramp.
  private let scheme: ColorScheme = .dark

  private var isRedacted: Bool { redaction.contains(.privacy) }
  /// Redacted by the system or unreadable: either way no figure and no band.
  private var isFigureless: Bool { isRedacted || isUnavailable }
  private var hasTile: Bool { band != .unlogged || isFigureless }

  var body: some View {
    ZStack {
      ground
      content
    }
    .frame(width: WatchLayout.tileSide, height: WatchLayout.tileSide)
    .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: band)
    .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isFigureless)
  }

  // MARK: Ground

  @ViewBuilder
  private var ground: some View {
    let shape = RoundedRectangle(cornerRadius: WatchLayout.tileRadius, style: .continuous)
    if isFigureless {
      // The outline channel: the design system's existing "off the ramp" state.
      shape.fill(IntensityPalette.fill(.alcoholFree, scheme: scheme))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 2))
    } else {
      shape.fill(IntensityPalette.fill(band, scheme: scheme))
        .overlay {
          if IntensityPalette.isOutlined(band) {
            shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 2)
          }
        }
    }
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    if isFigureless {
      glyph(DrinkType.Symbol.standard)
    } else if band == .alcoholFree {
      glyph(DrinkType.Symbol.alcoholFree)
    } else {
      // Numeral and bar both laid out; a crossfade, never a roll — hiding is a
      // change of subject, not of value, and a roll would draw a direction the
      // app does not assert.
      ZStack {
        numeral.opacity(isCountHidden ? 0 : 1)
        hiddenBar.opacity(isCountHidden ? 1 : 0)
      }
      .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isCountHidden)
    }
  }

  private var numeral: some View {
    // A number the user made: rounded, tabular. Formatted, not localized — no
    // catalog key. `.privacySensitive()` is what redacts it under Always-On.
    Text(count, format: .number)
      .font(.system(size: hasTile ? WatchLayout.numeralSize : WatchLayout.bareNumeralSize,
                    weight: .semibold, design: .rounded))
      .monospacedDigit()
      .minimumScaleFactor(0.6)
      // Bare — no tile — the figure is primary ink, as the phone's hero draws
      // it without a band; in a tile it takes the band's own ink.
      .foregroundStyle(hasTile ? IntensityPalette.ink(band, scheme: scheme) : Color.primary)
      .contentTransition(.numericText(value: Double(count)))
      .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: count)
      .privacySensitive()
  }

  private var hiddenBar: some View {
    RoundedRectangle(cornerRadius: WatchLayout.hiddenBarRadius, style: .continuous)
      .fill(IntensityPalette.ink(band, scheme: scheme).opacity(0.55))
      .frame(width: WatchLayout.hiddenBar.width, height: WatchLayout.hiddenBar.height)
  }

  private func glyph(_ name: String) -> some View {
    // `Image(decorative:)`: a catalog symbol speaks its asset name to VoiceOver
    // otherwise, and the counter's own label already says the number.
    Image(decorative: name)
      .font(.system(size: WatchLayout.tileGlyphSize, weight: .semibold))
      .foregroundStyle(.primary)
  }
}
