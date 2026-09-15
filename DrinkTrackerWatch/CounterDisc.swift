import SwiftUI

/// One of the counter's two controls: the − on glass, the ＋ on the app's one
/// filled circular surface (`AccentFill`, as on the phone; never
/// `Color.accentColor`, the text pair, which falls under 4.5:1 for a white
/// glyph in dark mode — design review R2).
///
/// The action is told whether it came from a touch. SwiftUI does not say
/// which input fired a button, so the button style records the moment a
/// press began and the action asks how long ago that was: an activation with
/// no press within the last moment is Double Tap (ADR-0042), which the caller
/// gives its own haptic.
struct CounterDisc: View {
  enum Glyph {
    case minus
    case plus
  }

  let glyph: Glyph
  /// Drawn dimmed when false. The control still answers a touch — that is how
  /// it explains itself — so this is a look, not `.disabled`.
  var looksEnabled: Bool = true
  let action: (_ viaGesture: Bool) -> Void

  @State private var pressedAt: Date?

  var body: some View {
    Button {
      let byTouch = pressedAt.map { Date.now.timeIntervalSince($0) < 0.75 } ?? false
      action(!byTouch)
    } label: {
      Image(systemName: glyph == .plus ? "plus" : "minus")
        .font(.system(size: glyphSize, weight: .semibold))
        .foregroundStyle(glyphColour)
        // 44pt with the hit shape inside the label: a frame applied to the
        // Button would grow the layout without growing the target.
        .frame(width: WatchLayout.discSide, height: WatchLayout.discSide)
        .contentShape(.circle)
    }
    .buttonStyle(PressTrackingStyle(pressedAt: $pressedAt))
    // Double Tap fires the frontmost app's primary action, and ＋ is it —
    // logging with one hand occupied is the single best thing the platform
    // offers a drink tracker (the plan, decision 5; ADR-0042). Nothing else
    // in the app claims it, and it fires only while this screen is frontmost.
    .handGestureShortcut(.primaryAction, isEnabled: glyph == .plus)
    .background(ground)
    .opacity(looksEnabled ? 1 : 0.4)
    // The row is one adjustable VoiceOver element; the discs say nothing of
    // their own (the counter's increment and decrement are its actions).
    .accessibilityHidden(true)
  }

  private var glyphSize: CGFloat {
    glyph == .plus ? WatchLayout.plusGlyphSize : WatchLayout.minusGlyphSize
  }

  private var glyphColour: Color {
    switch glyph {
    case .plus: .white
    case .minus: looksEnabled ? Color.accentColor : Color.secondary
    }
  }

  @ViewBuilder
  private var ground: some View {
    switch glyph {
    case .plus:
      // No drop shadow, whatever a drawing says: depth in this app comes from
      // the system material (design-system.md §5).
      Circle().fill(Color("AccentFill"))
    case .minus:
      Circle()
        .fill(.clear)
        .glassEffect(.regular.interactive(), in: .circle)
    }
  }
}

/// Records when a press began, so the action can tell a touch from a gesture.
private struct PressTrackingStyle: ButtonStyle {
  @Binding var pressedAt: Date?

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.7 : 1)
      .onChange(of: configuration.isPressed) { _, isPressed in
        if isPressed { pressedAt = .now }
      }
  }
}
