import SwiftUI

/// A large plus/minus counter.
///
/// The system `Stepper` is a 30-point control with two 15-point halves. That is
/// fine for a value you nudge once, and wrong for one you tap six times in a row
/// while remembering last night — which is exactly the backfill case this exists
/// for. Big targets, a figure you can read without looking closely, and no need to
/// be accurate with your thumb.
///
/// Two sizes:
/// - `.prominent` where the count *is* the question (the calendar's day sheet)
/// - `.inline` where it is one field among several (the drink sheet's quantity)
struct CountStepper: View {
  @Binding var value: Int
  let range: ClosedRange<Int>
  var style: Style = .prominent
  /// Describes what is being counted, for VoiceOver — "drinks", "beers".
  var unitLabel: String

  enum Style {
    case prominent
    case inline
  }

  @Environment(\.colorScheme) private var scheme

  private var controlSide: CGFloat { style == .prominent ? 64 : 44 }
  private var iconSize: CGFloat { style == .prominent ? 26 : 18 }
  private var numeralFont: Font {
    style == .prominent
      ? .system(size: 68, weight: .semibold, design: .rounded)
      : .system(.title2, design: .rounded).weight(.semibold)
  }

  var body: some View {
    HStack(spacing: style == .prominent ? GlassTokens.Spacing.section : GlassTokens.Spacing.regular) {
      button(
        systemName: "minus",
        isEnabled: value > range.lowerBound,
        label: "Decrease"
      ) {
        value = max(range.lowerBound, value - 1)
      }

      Text("\(value)")
        .font(numeralFont)
        .foregroundStyle(.primary)
        .monospacedDigit()
        .contentTransition(.numericText(value: Double(value)))
        .frame(minWidth: style == .prominent ? 96 : 44)
        .animation(.snappy(duration: 0.2), value: value)

      button(
        systemName: "plus",
        isEnabled: value < range.upperBound,
        label: "Increase"
      ) {
        value = min(range.upperBound, value + 1)
      }
    }
    .frame(maxWidth: .infinity)
    // One adjustable element rather than three focus stops. VoiceOver users change
    // the value by swiping up and down, which is the platform idiom for a stepper
    // and far quicker than finding two separate buttons.
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

  private func button(
    systemName: String,
    isEnabled: Bool,
    label: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: iconSize, weight: .semibold))
        .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
        .frame(width: controlSide, height: controlSide)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .glassSurface(cornerRadius: controlSide / 2, interactive: isEnabled)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.4)
    .accessibilityHidden(true)
    .accessibilityLabel(label)
  }
}
