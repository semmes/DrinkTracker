import ComponentsKit
import SwiftUI

/// Screen 2 — privacy, shown *before* the HealthKit permission dialog so the
/// user knows what they're agreeing to. Continue fires the real prompt.
///
/// Copy is verbatim from the prototype handoff. "We couldn't peek even if we
/// wanted to" is a factual claim, not a promise: the log lives in the user's own
/// private CloudKit database and HealthKit store, neither of which the developer
/// can read — the privacy policy spells out why.
struct PrivacyView: View {
  var onContinue: () async -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var isRequesting = false
  @State private var heroShown = false

  var body: some View {
    OnboardingScaffold {
      lockHero
        .padding(.bottom, GlassTokens.Spacing.tight)
      OnboardingHeadline(text: "Your tab is nobody's business")
      OnboardingSubtext(
        text: "Your log lives in your own iCloud and Apple Health. No account, no server, no ads. We couldn't peek even if we wanted to."
      )
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        SupportingLine(symbol: "lock", text: "Private by default")
        SupportingLine(
          symbol: "stethoscope",
          text: "Share with a doctor if you choose. Your Apple Health data can give a provider the full picture of your drinking, daily to yearly"
        )
        SupportingLine(symbol: "sun.max", text: "Change access anytime in Settings")
      }
      .padding(.top, GlassTokens.Spacing.tight)
    } actions: {
      SUButton(model: .primary("Sounds good", isEnabled: !isRequesting)) {
        Task {
          isRequesting = true
          await onContinue()
          isRequesting = false
        }
      }
    }
  }

  /// A 76pt glass circle holding an accent lock, popping in once. Decorative —
  /// hidden from VoiceOver, static under Reduce Motion.
  private var lockHero: some View {
    Image(systemName: "lock.fill")
      .font(.system(size: 36))
      .foregroundStyle(Color.accentColor)
      .frame(width: 76, height: 76)
      .glassSurface(cornerRadius: 38)
      .scaleEffect(heroShown || reduceMotion ? 1 : 0.4)
      .opacity(heroShown || reduceMotion ? 1 : 0)
      .animation(
        reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.25).delay(0.1),
        value: heroShown
      )
      .accessibilityHidden(true)
      .onAppear { heroShown = true }
  }
}

/// One feature row. Top-aligned so the two-line doctor row keeps its icon on the
/// first line rather than floating mid-paragraph.
private struct SupportingLine: View {
  let symbol: String
  let text: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.tight) {
      Image(systemName: symbol)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(width: 18)
      Text(text)
        .font(GlassTokens.Typography.supporting)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  PrivacyView {}
}
