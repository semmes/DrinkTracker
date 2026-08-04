import ComponentsKit
import SwiftUI

/// Screen 1 — Welcome. Copy is verbatim from the prototype handoff.
struct WelcomeView: View {
  var onContinue: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    OnboardingScaffold {
      TallyHero()
        .frame(maxWidth: .infinity)
        .padding(.bottom, GlassTokens.Spacing.regular)
      OnboardingHeadline(text: "Your drinks, tallied")
      OnboardingSubtext(
        text: "One tap per drink, like tick marks on a napkin, except this napkin does charts. No goals, no lectures, no judgement."
      )
    } actions: {
      SUButton(model: .primary("Start tallying"), action: onContinue)
    }
  }
}

// MARK: - The tally hero

/// The brand mark, drawn by hand: four strokes and a slash — the canonical tally
/// of five — sketched in one by one, the way a tally actually gets made. The one
/// piece of custom drawing in the app; geometry from the prototype handoff
/// (112×118 canvas, strokes at even spacing, round caps, −4° tilt).
///
/// The slash is the accent at reduced opacity rather than a new colour: the
/// handoff's `#7FA9DD` is, to within a couple of points per channel, the accent
/// at 55% over the light background — so this reproduces it while deriving the
/// dark-mode value for free and keeping ADR-0010's "every blue is a named job"
/// rule intact.
private struct TallyHero: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var drawn = false

  /// Stroke endpoints in the 112×118 reference canvas.
  private static let verticals: [(CGPoint, CGPoint)] = [
    (CGPoint(x: 14, y: 14), CGPoint(x: 14, y: 104)),
    (CGPoint(x: 42, y: 14), CGPoint(x: 42, y: 104)),
    (CGPoint(x: 70, y: 14), CGPoint(x: 70, y: 104)),
    (CGPoint(x: 98, y: 14), CGPoint(x: 98, y: 104)),
  ]
  private static let slash = (CGPoint(x: 2, y: 96), CGPoint(x: 110, y: 24))

  /// Draw-on schedule: verticals staggered, the slash lands last.
  private static let verticalDelays: [Double] = [0.15, 0.32, 0.49, 0.66]

  var body: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      ZStack {
        ForEach(Array(Self.verticals.enumerated()), id: \.offset) { index, line in
          TallyStroke(start: line.0, end: line.1)
            .trim(from: 0, to: drawn ? 1 : 0)
            .stroke(Color.accentColor, style: strokeStyle)
            .animation(
              reduceMotion
                ? nil
                : .easeOut(duration: 0.35).delay(Self.verticalDelays[index]),
              value: drawn
            )
        }
        TallyStroke(start: Self.slash.0, end: Self.slash.1)
          .trim(from: 0, to: drawn ? 1 : 0)
          .stroke(Color.accentColor.opacity(0.55), style: strokeStyle)
          .animation(
            reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.92),
            value: drawn
          )
      }
      .frame(width: 148, height: 132)
      .rotationEffect(.degrees(-4))

      Text("(that's five)")
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .opacity(drawn ? 1 : 0)
        .animation(
          reduceMotion ? nil : .easeOut(duration: 0.4).delay(1.35),
          value: drawn
        )
    }
    // Decorative: the headline right below carries the meaning.
    .accessibilityHidden(true)
    .onAppear { drawn = true }
  }

  private var strokeStyle: StrokeStyle {
    StrokeStyle(lineWidth: 13, lineCap: .round)
  }
}

/// One straight stroke of the tally, in reference-canvas coordinates.
private struct TallyStroke: Shape {
  let start: CGPoint
  let end: CGPoint

  func path(in rect: CGRect) -> Path {
    let sx = rect.width / 112
    let sy = rect.height / 118
    var path = Path()
    path.move(to: CGPoint(x: start.x * sx, y: start.y * sy))
    path.addLine(to: CGPoint(x: end.x * sx, y: end.y * sy))
    return path
  }
}

#Preview {
  WelcomeView {}
}
