import ComponentsKit
import SwiftUI

/// Screen 2 — HealthKit context, shown *before* the system permission dialog so
/// the user knows what they're agreeing to. Continue fires the real prompt.
struct HealthContextView: View {
  var onContinue: () async -> Void

  @State private var isRequesting = false

  var body: some View {
    OnboardingScaffold {
      OnboardingHeadline(text: "Kept in Apple Health, kept private")
      // "on this device" was wrong: the store is CloudKit-mirrored, so the log
      // follows the user's iCloud account across their devices. This screen sits
      // immediately before a health-data permission prompt, which is the worst
      // possible place to overstate a privacy guarantee.
      OnboardingSubtext(
        text: "Your log stays in your own iCloud account and Apple Health. There's no account to create and no server to send it to — nothing is sold, shared, or used for ads."
      )
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        SupportingLine(symbol: "lock.fill", text: "Private by default")
        SupportingLine(symbol: "gearshape.fill", text: "Change access anytime in Settings")
      }
      .padding(.top, GlassTokens.Spacing.tight)
    } actions: {
      SUButton(model: .primary("Continue", isEnabled: !isRequesting)) {
        Task {
          isRequesting = true
          await onContinue()
          isRequesting = false
        }
      }
    }
  }
}

private struct SupportingLine: View {
  let symbol: String
  let text: String

  var body: some View {
    Label {
      Text(text)
        .font(GlassTokens.Typography.supporting)
        .foregroundStyle(.secondary)
    } icon: {
      Image(systemName: symbol)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  HealthContextView {}
}
