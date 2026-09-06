import DrinkTrackerCore
import SwiftUI

/// A large plus/minus counter.
///
/// The system `Stepper` is a 30-point control with two 15-point halves. That is
/// fine for a value you nudge once, and wrong for one you tap six times in a row
/// while remembering last night — which is exactly the backfill case this exists
/// for. Big targets, a figure you can read without looking closely, and no need to
/// be accurate with your thumb.
///
/// Three sizes:
/// - `.hero` on Today, where the counter is the screen (ADR-0034)
/// - `.prominent` where the count *is* the question (the calendar's day sheet)
/// - `.inline` where it is one field among several (the drink sheet's quantity)
struct CountStepper: View {
  @Binding var value: Int
  let range: ClosedRange<Int>
  var style: Style = .prominent
  /// Describes what is being counted, for VoiceOver — "drinks", "beers".
  ///
  /// A `LocalizedStringKey` rather than a `String`: `accessibilityLabel` has an
  /// `@_disfavoredOverload` for `StringProtocol`, so a `String` here bound the
  /// verbatim overload and none of these labels ever reached the catalog. Same
  /// family as the `Text(String)` trap the package documents.
  var unitLabel: LocalizedStringKey

  /// The day's own intensity, painted behind the numeral on `.hero`.
  ///
  /// Nil draws the plain numeral instead — the shape every other style uses.
  /// See `bandTile` for why this is the one non-calendar surface allowed to
  /// read `IntensityPalette` for a *quantity*.
  var band: DayIntensity?

  enum Style {
    case hero
    case prominent
    case inline
  }

  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var controlSide: CGFloat {
    switch style {
    case .hero: 68
    case .prominent: 64
    case .inline: 44
    }
  }

  /// The ＋ glyph is drawn two points larger than the − on `.hero`: it sits on
  /// a solid fill rather than glass, and matching them optically means matching
  /// their apparent weight, not their point size.
  private func iconSize(for systemName: String) -> CGFloat {
    switch style {
    case .hero: systemName == "plus" ? 30 : 28
    case .prominent: 26
    case .inline: 18
    }
  }

  private var numeralFont: Font {
    switch style {
    // Inside the band the figure is 68pt; without one it takes the space the
    // band would have occupied and is drawn at 84.
    case .hero: .system(size: band == nil ? 84 : 68, weight: .semibold, design: .rounded)
    case .prominent: .system(size: 68, weight: .semibold, design: .rounded)
    case .inline: .system(.title2, design: .rounded).weight(.semibold)
    }
  }

  /// A hero-only gap. Deliberately not a `GlassTokens.Spacing` step — the hero
  /// row is the one place in the app whose spacing is set by two 68pt discs and
  /// a 126pt tile rather than by the type scale.
  private var gap: CGFloat {
    switch style {
    case .hero: 26
    case .prominent: GlassTokens.Spacing.section
    case .inline: GlassTokens.Spacing.regular
    }
  }

  var body: some View {
    HStack(spacing: gap) {
      button(systemName: "minus", isEnabled: value > range.lowerBound) {
        value = max(range.lowerBound, value - 1)
      }

      numeral

      button(systemName: "plus", isEnabled: value < range.upperBound) {
        value = min(range.upperBound, value + 1)
      }
    }
    .frame(maxWidth: .infinity)
    // One adjustable element rather than three focus stops. VoiceOver users change
    // the value by swiping up and down, which is the platform idiom for a stepper
    // and far quicker than finding two separate buttons.
    //
    // `children: .ignore` is also what keeps the band out of the accessibility
    // tree entirely, which is the point: "Drinks today, 3" already says
    // everything the colour encodes, and a second statement of it would be a
    // reader being told the same number twice.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(unitLabel)
    .accessibilityValue("\(value)")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: value = min(range.upperBound, value + 1)
      case .decrement: value = max(range.lowerBound, value - 1)
      @unknown default: break
      }
    }
    // A tap that changes nothing because you hit the bound should still feel
    // different from one that worked.
    .sensoryFeedback(.selection, trigger: value)
  }

  @ViewBuilder
  private var numeral: some View {
    let figure = Text("\(value)")
      .font(numeralFont)
      .monospacedDigit()
      .contentTransition(.numericText(value: Double(value)))
      .animation(.snappy(duration: 0.2), value: value)

    if let band, style == .hero {
      figure
        .foregroundStyle(IntensityPalette.ink(band, scheme: scheme))
        // The figure scales inside a box that also grows: a fixed 126 would
        // clip three digits, and a `@ScaledMetric` box would overflow the row
        // against two 68pt discs at large Dynamic Type sizes.
        .minimumScaleFactor(0.6)
        .padding(.horizontal, GlassTokens.Spacing.tight)
        .frame(minWidth: 126, minHeight: 126)
        .background(bandTile(band))
        // Fill and ink cross-fade on their own clock, separate from the
        // numeral's roll above. Both halves stay laid out — nothing is added
        // or removed — so there is no transition to fight (ADR-0028's
        // amendment paid for this lesson once already).
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: band)
    } else {
      figure
        .foregroundStyle(.primary)
        .frame(minWidth: style == .inline ? 44 : (style == .hero ? 104 : 96))
    }
  }

  /// The band's ground.
  ///
  /// Every value comes from `IntensityPalette` by name — no literal colour is
  /// defined here (PRD invariant 10). `.unlogged` deliberately returns `.clear`
  /// with no stroke: absence is drawn as absence (ADR-0007), and a second ring
  /// differing from the alcohol-free one only in alpha would collapse the
  /// outline channel that separates "recorded as none" from "nothing recorded".
  /// The words directly beneath the tile carry that distinction instead.
  private func bandTile(_ band: DayIntensity) -> some View {
    RoundedRectangle(cornerRadius: 36, style: .continuous)
      .fill(IntensityPalette.fill(band, scheme: scheme))
      .overlay {
        if IntensityPalette.isOutlined(band) {
          RoundedRectangle(cornerRadius: 36, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.35), lineWidth: 2)
        }
      }
  }

  private func button(
    systemName: String,
    isEnabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    // The hero's ＋ is the app's one filled circular control: it is the single
    // action the whole screen exists for, and on Today it competes with a
    // 126pt block of colour a thumb's width away.
    //
    // `AccentFill`, not `Color.accentColor` — the asset accent is the *text*
    // pair and resolves to a lighter step in dark mode, where a white glyph on
    // it falls under 4.5:1. `AccentFill` is the fill pair in both modes (design
    // review R2, the same rule the size pills and the share-card bars follow).
    //
    // No drop shadow, whatever the drawing says: depth in this app comes from
    // the system material, and `grep -rn "\.shadow(" --include=*.swift` returns
    // nothing today (design-system.md §5).
    let isFilled = style == .hero && systemName == "plus"

    return Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: iconSize(for: systemName), weight: .semibold))
        .foregroundStyle(glyphColour(isFilled: isFilled, isEnabled: isEnabled))
        .frame(width: controlSide, height: controlSide)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    // Either a solid disc or a glass one, never both: `glassEffect` draws
    // behind its content, so stacking it under an opaque fill would only cost
    // a material nobody can see.
    .modifier(CircleSurface(side: controlSide, isFilled: isFilled, isEnabled: isEnabled))
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.4)
    .accessibilityHidden(true)
  }

  private func glyphColour(isFilled: Bool, isEnabled: Bool) -> Color {
    if isFilled { return .white }
    return isEnabled ? Color.accentColor : Color.secondary
  }
}

/// The counter button's ground — a filled accent disc, or the app's standard
/// glass.
private struct CircleSurface: ViewModifier {
  let side: CGFloat
  let isFilled: Bool
  let isEnabled: Bool

  func body(content: Content) -> some View {
    if isFilled {
      content
        .background(Circle().fill(Color("AccentFill")))
    } else {
      content
        .glassSurface(cornerRadius: side / 2, interactive: isEnabled)
    }
  }
}
