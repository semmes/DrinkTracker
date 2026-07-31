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
      OnboardingSubtext(
        text: "Your log is stored in Health, on this device. Nothing is sold, shared, or used for ads."
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
