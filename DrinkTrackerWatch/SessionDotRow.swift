import DrinkTrackerCore
import SwiftUI

/// The sitting, as dots (watch Phase 5, ADR-0044): one dot per drink in the
/// session up to eight, and beneath them the count and the time since the
/// session's first drink — `5 · 1h 12m`. The phone's card has four values
/// because the phone has room; the wrist gets the one number the feature
/// exists for and one supporting figure.
///
/// Shown only while `SessionPace.currentSession` returns a value and the
/// watch's own "Show session pace" is on. When the session ends the row
/// simply stops existing: nothing is written, nothing remembered, no
/// notification exists (ADR-0017's three hard rules hold on the wrist).
///
/// The dots read the rolling two-hour window's band — `SessionPaceCard`'s
/// own rule, so a shade here means what it means on the calendar — but only
/// from `.medium` up. A dot is a graphical object needing 3:1 against its
/// ground, and the dark ramp's `.low` measures 2.59:1 on black; below
/// `.medium` the dots are rings, the design system's off-ramp channel
/// (ADR-0007).
///
/// **Concealed — the per-glance hide or Always-On redaction — the row keeps
/// its shape and not its number:** eight rings whatever the count, and no
/// line. A row of rings at the count would still be a count, readable across
/// a table up to eight, which is the leak the hide exists to close
/// (ADR-0045). VoiceOver hears the real count either way.
struct SessionDotRow: View {
  let session: DrinkSession
  /// The rolling window's band, or nil for the neutral ring.
  let band: DayIntensity?
  let now: Date
  let isCountHidden: Bool

  @Environment(\.redactionReasons) private var redaction
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Hidden by the user's tap, or redacted by the system.
  private var isConcealed: Bool {
    isCountHidden || redaction.contains(.privacy)
  }

  private var isRinged: Bool { band == nil || isConcealed }

  var body: some View {
    let row = SessionPace.dotRow(forCount: session.count)
    let dots = isConcealed ? SessionPace.dotMaximum : row.dots
    VStack(spacing: WatchLayout.dotsToSessionLine) {
      SessionDots(
        count: dots, band: band, ringed: isRinged,
        size: WatchLayout.dotSize, gap: WatchLayout.dotGap
      )
      .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isConcealed)
      // The count in rounded semibold — the user's own figure — and the
      // elapsed time in default SF, the clock's. Three verbatim pieces, so no
      // key made of specifiers and a dot reaches the catalog. Gone, not
      // placeholdered, whenever the row is concealed: `.privacySensitive()`
      // alone would draw redaction blocks the width of the digits.
      HStack(spacing: 3) {
        Text(verbatim: StandardDrink.formatted(session.count))
          .font(.system(size: WatchLayout.sessionLineSize, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.primary)
        Text(verbatim: "·")
          .font(.system(size: WatchLayout.sessionLineSize))
          .foregroundStyle(.secondary)
        Text(verbatim: elapsed(style: .abbreviated))
          .font(.system(size: WatchLayout.sessionLineSize))
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      .privacySensitive()
      .opacity(isConcealed ? 0 : 1)
    }
    // One element: the dots are decorative, the count and the elapsed time
    // carry the fact. The colour adds nothing a reader needs twice, and
    // concealing changes nothing spoken (ADR-0045).
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(sessionLine(session.count))
    .accessibilityValue(Text(verbatim: elapsed(style: .full)))
  }

  /// Since the session's first drink; `start` is never after `now` (the
  /// domain clamps future timestamps), and the floor covers a clock that
  /// moved anyway.
  private func elapsed(style: DateComponentsFormatter.UnitsStyle) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = style
    formatter.zeroFormattingBehavior = .dropLeading
    return formatter.string(from: max(0, now.timeIntervalSince(session.start))) ?? ""
  }

  /// The phone's card's own two keys (ADR-0017), so the spoken count is the
  /// same sentence on both surfaces; singular from the displayed digits.
  private func sessionLine(_ count: Double) -> LocalizedStringKey {
    let value = StandardDrink.formatted(count)
    return StandardDrink.readsAsOne(count)
      ? "\(value) drink this session"
      : "\(value) drinks this session"
  }
}
